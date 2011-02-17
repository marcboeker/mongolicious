module Mongolicious
  class Backup
    
    # Initialize the backup system.
    #
    # @param [String] jobfile the path of the job configuration file.
    #
    # @return [Backup]
    def initialize(jobfile)
      @conf = parse_jobfile(jobfile)
      
      @storage = Storage.new(@conf['s3'])
      @filesystem = Filesystem.new
      @db = DB.new
                 
      schedule_jobs(@conf['jobs'])
    end
    
    protected

    # Parse YAML job configuration.
    #
    # @param [String] jobfile the path of the job configuration file.
    #
    # @return [Hash]
    def parse_jobfile(jobfile)   
      YAML.load(File.read(jobfile))      
    rescue Errno::ENOENT
      Mongolicious.logger.error("Could not find job file at #{ARGV[0]}")
      exit
    rescue ArgumentError => e
      Mongolicious.logger.error("Could not parse job file #{ARGV[0]} - #{e}")
      exit
    end
    
    # Schedule the jobs to be executed in the given interval.
    #
    # This method will block and keep running until it gets interrupted.
    #
    # @param [Array] jobs the list of jobs to be scheduled.
    #
    # @return [nil] 
    def schedule_jobs(jobs)
      scheduler = Rufus::Scheduler.start_new
    
      jobs.each do |job|
        Mongolicious.logger.info("Scheduled new job for #{job['db'].split('/').last} with interval #{job['interval']}")
        scheduler.every job['interval'] do
          backup(job)
        end
      end 
    
      scheduler.join
    end         
    
    # Dump database, compress and upload it.
    #
    # @param [Hash] job the job to execute.
    #
    # @return [nil]
    def backup(job)
      path = @filesystem.get_tmp_path
      s3 = @storage.parse_location(job['location'])
      db = @db.get_opts(job['db'])
    
      Mongolicious.logger.info("Starting job for #{db[:host]}:#{db[:port]}/#{db[:db]}")

      @db.dump(db, path)
      @filesystem.compress(path) 
      
      key = "#{s3[:prefix]}_#{Time.now.strftime('%m%d%Y_%H%M%S')}.tar.bz2"
      @storage.upload(s3[:bucket], key, path)
    
      @filesystem.cleanup(path)
      @storage.cleanup(s3[:bucket], s3[:prefix], job['versions'])
      
      Mongolicious.logger.info("Finishing job for #{db[:host]}:#{db[:port]}/#{db[:db]}")      
    end

  end
end
