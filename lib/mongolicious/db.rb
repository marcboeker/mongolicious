module Mongolicious
  class DB

    # Initialize a ne DB object.
    #
    # @return [DB]    
    def initialize
      
    end

    # Parse the MongoDB URI.
    #
    # @param [String] db_uri the DB URI.
    #
    # @return [Hash]    
    def get_opts(db_uri)
      uri = URI.parse(db_uri)
    
      {
        :host => uri.host, 
        :port => uri.port, 
        :user => uri.user, 
        :password => uri.password, 
        :db => uri.path.gsub('/', '')
      }
    end 

    # Dump database using mongodump.
    #
    # @param [Hash] db the DB connection opts.
    # @param [String] path the path, where the dump should be stored.
    #
    # @return [nil]    
    def dump(db, path)
      Mongolicious.logger.info("Dumping database #{db[:db]}")
    
      cmd = "mongodump -d #{db[:db]} -h #{db[:host]}:#{db[:port]} -o #{path}"
      cmd << " -u '#{db[:user]}' -p '#{db[:password]}'" unless (db[:user].nil? || db[:user].empty?)
      cmd << " > /dev/null"
    
      system(cmd)
      raise "Error while backuing up #{db[:db]}" if $?.to_i != 0
    end
    
  end
end