module Mongolicious
  
  class Backup
   
    def initialize(jobs)
      @conf = YAML.load(File.read(jobs))
      @con = Fog::Storage.new({
        :provider => 'AWS',
        :aws_access_key_id => @conf['s3']['access_id'],
        :aws_secret_access_key => @conf['s3']['secret_key']
      })
      @logger = Logger.new(STDOUT)    
                 
      schedule(@conf['jobs'])
    rescue Errno::ENOENT
      @logger.error("Could not find job file at #{ARGV[0]}")
    rescue ArgumentError => e
      @logger.error("Could not parse job file #{ARGV[0]} - #{e}")
    end 
  
    def schedule(jobs)
      scheduler = Rufus::Scheduler.start_new
    
      jobs.each do |job|
        @logger.info("Scheduled new job with interval #{job['interval']}")
        scheduler.every job['interval'] do
          backup(job)
        end
      end 
    
      scheduler.join
    end         
  
    def backup(job)
      path = get_path(job['db'])
      s3 = get_s3_opts(job['location'])
      db = get_db_opts(job['db'])
    
      @logger.info("Starting job for #{db[:host]}:#{db[:port]}/#{db[:db]}")

      dump(db, path)
      compress(path)
      beam_up(s3[:bucket], s3[:prefix], path)
    
      cleanup_local(path)
      cleanup_remote(s3[:bucket], s3[:prefix], job['versions'])
    end
  
    def get_s3_opts(s3)
      s3 = s3.split('/')

      {:bucket => s3.first, :prefix => s3[1..-1].join('/')}
    end 
  
    def get_db_opts(db)
      uri = URI.parse(db)
    
      {
        :host => uri.host, 
        :port => uri.port, 
        :user => uri.user, 
        :password => uri.password, 
        :db => uri.path.gsub('/', '')
      }
    end 
  
    def get_path(db_uri)     
      uri = URI.parse(db_uri)
    
      "#{Dir.tmpdir}/#{uri.path.gsub('/', '')}"    
    end
  
    def dump(db, path)
      @logger.info("Dumping database #{db[:db]}")
    
      cmd = "mongodump -d #{db[:db]} -h #{db[:host]}:#{db[:port]} -o #{path}"
      cmd << " -u '#{db[:user]}' -p '#{db[:password]}'" unless db[:user].empty?
      cmd << " > /dev/null"
    
      system(cmd)
      raise "Error while backuing up #{db[:db]}" if $?.to_i != 0
    end
  
    def compress(path)
      @logger.info("Compressing database #{path}")
    
      system("cd #{path} && tar -cjpf #{path}.tar.bz2 .")
      raise "Error while compressing #{path}" if $?.to_i != 0
    end
  
    def beam_up(bucket, prefix, path)
      key = "#{prefix}_#{Time.now.strftime('%m%d%Y_%H%M%S')}.tar.bz2"
      @logger.info("Uploading archive to #{key}")
                                                   
      @con.put_object(
    	  bucket, key, File.open("#{path}.tar.bz2", 'r'), 
    	  {'x-amz-acl' => 'private', 'Content-Type' => 'application/x-tar'}
    	)
    end
  
    def cleanup_local(path)
      @logger.info("Cleaning up local path #{path}")
    
      FileUtils.rm_rf(path)
      File.delete("#{path}.tar.bz2")
    end

    def cleanup_remote(bucket, prefix, versions)
      objects = @con.get_bucket(bucket, :prefix => prefix).body['Contents']
    
      return if objects.size <= versions
    
      objects[0...(objects.size - versions)].each do |o|
       @logger.info("Removing outdated version #{o['Key']}")
       @con.delete_object(bucket, o['Key'])
      end
    end

  end

end
