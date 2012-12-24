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
        if job['cron']
          Mongolicious.logger.info("Scheduled new job for #{job['db'].split('/').last} with cron:  #{job['cron']}")
          scheduler.cron job['cron'] do
            backup(job)
          end
        else
          scheduler.every job['interval'] do
            Mongolicious.logger.info("Scheduled new job for #{job['db'].split('/').last} with interval: #{job['interval']}")
            backup(job)
          end
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
      path = @filesystem.get_tmp_path(job['temp_directory'])
      s3 = @storage.parse_location(job['location'])
      db = @db.get_opts(job['db'])

      Mongolicious.logger.info("Starting job for #{db[:host]}:#{db[:port]}/#{db[:db]}")

      @db.dump(db, path)
      path = @filesystem.compress(path, job['compress_tar_file'])
      key = "#{s3[:prefix]}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.tar.bz2"

      min_file_size = 5 * (1024 * 1024) # 5 MB
      max_file_size = 4 * (1024 * 1024 * 1024) # 4 GB
      split_size = max_file_size
      file_size = File.size("#{path}")
      Mongolicious.logger.info("Total backup size: #{file_size} bytes")

      if file_size > max_file_size
        split_parts = file_size / max_file_size + (file_size % max_file_size > 0 ? 1 : 0)

        last_part_size_in_bytes = file_size -
            (max_file_size * ((split_parts - 1) <= 0 ? 1: (split_parts - 1)))

        if last_part_size_in_bytes < min_file_size
          # If we are sending the file in chunks we need to make sure that the last part of the
          # file is bigger than the 5MB otherwise the whole upload will fail.
          # If last part is smaller than 5MB then we distribute its bytes to the other parts
          split_size = max_file_size +
              (last_part_size_in_bytes/((split_parts - 1) <= 0 ? 1 : (split_parts - 1)))
        end

        Mongolicious.logger.info("Splitting file into #{split_size} bytes/part before uploading.")
        system("split -b #{split_size} #{path} #{path}.")

        Mongolicious.logger.info("Deleting tar file: #{path}")
        @filesystem.cleanup_tar_file(path)

        # Get a list of all the split files bigfile.gzip.aa/ab/ac...
        file_parts = Dir.glob("#{path}.*").sort
        upload_id = @storage.initiate_multipart_upload(s3[:bucket], key)
        part_ids = []

        Mongolicious.logger.info("Uploading #{path} in #{file_parts.count} parts.")

        file_parts.each_with_index do |part, position|
          Mongolicious.logger.info("Uploading file part: #{part}")
          part_number = (position + 1).to_s

          File.open part do |file_part|
            attempts = 0
            max_attempts = 3

            begin
              etag = @storage.upload_part(s3[:bucket], key, upload_id, part_number, file_part)
            rescue Exception => exception
              attempts += 1
              Mongolicious.logger.warn("Retry #{attempts} of #{max_attempts}. Error while uploading part: #{part}")
              Mongolicious.logger.warn(exception.message)
              Mongolicious.logger.warn(exception.backtrace)
              retry unless attempts >= max_attempts

              Mongolicious.logger.error("Aborting upload! Error uploading part: #{part}")
              @filesystem.cleanup_parts(file_parts)

              # There is nothing that we can do anymore
              # Exit this method with error code 0 so that subsequent jobs can fire as scheduled.
              return
            end

            part_ids << etag
          end
        end

        Mongolicious.logger.info("Completing multipart upload.")
        response = @storage.complete_multipart_upload(s3[:bucket], key, upload_id, part_ids)
        Mongolicious.logger.info("#{response.inspect}\n\n")

        @filesystem.cleanup_parts(file_parts)
      else
        @storage.upload(s3[:bucket], key, path)
        @filesystem.cleanup_tar_file(path)
      end

      @storage.cleanup(s3[:bucket], s3[:prefix], job['versions'])

      Mongolicious.logger.info("Finishing job for #{db[:host]}:#{db[:port]}/#{db[:db]}")
    end

  end
end
