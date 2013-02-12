module Mongolicious
  class Filesystem

    # Initialize a ne Filesystem object.
    #
    # @return [Filesytem]
    def initialize

    end

    # Compress the dump to an tar.bz2 archive.
    #
    # @param [String] path the path, where the dump is located.
    #
    # @return [String]
    def compress(path, compress_tar_file)
      Mongolicious.logger.info("Compressing database #{path}")

      system("cd #{path} && tar -cpf#{compress_tar_file ? 'j' : ''} #{path}.tar.bz2 .")
      raise "Error while compressing #{path}" if $?.to_i != 0

      # Remove mongo dump now that we have the bzip
      FileUtils.rm_rf(path)

      return "#{path}.tar.bz2"
    end

    # Generate tmp path for dump.
    #
    # @return [String]
    def get_tmp_path(temp_path)
      if not temp_path
        temp_path = Dir.tmpdir
      end

      Mongolicious.logger.info("Using #{temp_path} as root for our temp backup.")
      return "#{temp_path}/#{Time.now.to_i}"
    end

    # Remove dump from tmp path.
    #
    # @param [String] path the path, where the dump/archive is located.
    #
    # @return [nil]
    def cleanup_tar_file(path)
      Mongolicious.logger.info("Cleaning up local path #{path}")
      begin
        File.delete(path)
      rescue => exception
        Mongolicious.logger.error("Error trying to delete: #{path}")
        Mongolicious.logger.info(exception.message)
      end
    end

    # Remove all the bzip parts
    #
    # @param [Array] file_parts an array of paths
    #
    # @return [nill]
    def cleanup_parts(file_parts)
      Mongolicious.logger.info("Cleaning up file parts.")

      if file_parts
        file_parts.each do |part|
          Mongolicious.logger.info("Deleting part: #{part}")
          begin
            File.delete(part)
          rescue => exception
            Mongolicious.logger.error("Error trying to delete part: #{part}")
            Mongolicious.logger.error(exception.message)
            Mongolicious.logger.error(exception.backtrace)
          end
        end
      end
    end

  end
end
