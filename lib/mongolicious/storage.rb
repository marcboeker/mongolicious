module Mongolicious
  class Storage

    # Initialize the storage object.
    #
    # @option opts [Hash] :access_id the Access ID of the S3 account.
    # @option opts [Hash] :secret_key the Secret Key of the S3 account.
    #
    # @return [Storage]
    def initialize(opts)
      @con = Fog::Storage.new({
        :provider => 'AWS',
        :aws_access_key_id => opts['access_id'],
        :aws_secret_access_key => opts['secret_key']
      })
    end

    # Parse the given location into a bucket and a prefix.
    #
    # @param [String] location the bucket/prefix location.
    #
    # @return [Hash]
    def parse_location(location)
      location = location.split('/')

      {:bucket => location.first, :prefix => location[1..-1].join('/')}
    end

    # Upload the given path to S3.
    #
    # @param [String] bucket the bucket where to store the archive in.
    # @param [String] key the key where the archive is stored under.
    # @param [String] path the path, where the archive is located.
    #
    # @return [Hash]
    def upload(bucket, key, path)
      Mongolicious.logger.info("Uploading archive to #{key}")

      @con.put_object(
        bucket, key, File.open(path, 'r'),
        {'x-amz-acl' => 'private', 'Content-Type' => 'application/x-tar'}
      )
    end

    # Initiate a multipart upload to S3
    # content of this upload will be private
    #
    # @param [String] bucket the bucket where to store the archive in.
    # @param [String] key the key where the archive is stored under.
    #
    # @return [String] UploadId the id where amazon will save all the parts.
    #                  When uploading all the parts this will need to be provided.
    def initiate_multipart_upload(bucket, key)
      response = @con.initiate_multipart_upload(bucket, key,
        {'x-amz-acl' => 'private', 'Content-Type' => 'application/x-tar'})

      return response.body['UploadId']
    end

    # Upload a part for a multipart upload
    #
    # @param [String] bucket Name of bucket to add part to
    # @param [String] key Name of object to add part to
    # @param [String] upload_id Id of upload to add part to
    # @param [String] part_number Index of part in upload
    # @param [String] data Contect of part
    #
    # @return [String] ETag etag of new object. Will be needed to complete upload
    def upload_part(bucket, key, upload_id, part_number, data)
      response = @con.upload_part(bucket, key, upload_id, part_number, data)

      return response.headers['ETag']
    end

    # Complete a multipart upload
    #
    # @param [String] bucket Name of bucket to complete multipart upload for
    # @param [String] key Name of object to complete multipart upload for
    # @param [String] upload_id Id of upload to add part to
    # @param [String] parts Array of etags for parts
    #
    # @return [Excon::Response]
    def complete_multipart_upload(bucket, key, upload_id, parts)
      response = @con.complete_multipart_upload(bucket, key, upload_id, parts)

      return response
    end

    # Aborts a multipart upload
    #
    # @param [String] bucket Name of bucket to abort multipart upload on
    # @param [String] key Name of object to abort multipart upload on
    # @param [String] upload_id Id of upload to add part to
    #
    # @return [nil]
    def abort_multipart_upload(bucket, key, upload_id)
      @con.abort_multipart_upload(bucket, key, upload_id)
    end

    # Remove old versions of a backup.
    #
    # @param [String] bucket the bucket where the archive is stored in.
    # @param [String] prefix the prefix where to look for outdated versions.
    # @param [Integer] versions number of versions to keep.
    #
    # @return [nil]
    def cleanup(bucket, prefix, versions)
      objects = @con.get_bucket(bucket, :prefix => prefix).body['Contents']

      return if objects.size <= versions

      objects[0...(objects.size - versions)].each do |o|
       Mongolicious.logger.info("Removing outdated version #{o['Key']}")
       @con.delete_object(bucket, o['Key'])
      end
    end

  end
end
