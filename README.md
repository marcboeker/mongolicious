# mongolicious

Mongolicious provides an easy way to backup your Mongo databases to S3.

## Installation

    gem install mongolicious
    
## Configuration

Create a new YAML file that looks like the one below. This file defines the
backup jobs, that will be run in the defined interval. 

    s3:
      access_id: <your_s3_access_id>
      secret_key: <your_s3_secret_key>

    jobs:
      - interval: 1h
        db: mongodb://user:password@host:port/database
        location: bucket_name/prefix
        versions: 5

The s3 section contains the credentials, to authenticate with AWS S3. The
jobs section contains a list ob jobs, that will be executed in the given 
interval. Each job must contain the following keys:

* **interval** - Defines the interval, the job will be executed in. This can be any numerical value followed by a quantifier like s, m, h, d for second, minute, hour, day.
* **db** - Is a URI, that defines the database host, database name and auth credentials.
* **location** - The location is the S3 bucket, where to put the dump and a prefix.
* **versions** - Keep the latest X versions of the backup.

Please consider, that the location option works like this:

    backups.example.org/foo/foo
    
results in an archive on S3 with the following object key

    backups.example.org/foo/foo_01012011_121314.tar.bz2
    
The current date will be appended to each archive.

## Usage

Simple call the mongolicious bin with the jobs.yml file as argument.

    mongolicious jobs.yml
    
This will start the scheduler and run the backup jobs as defined in the jobs.yml file. You can put the process into background or run it in a screen terminal.

    screen mongolicious jobs.yml
    
## Todo

### Near
* Add testcases.
* Catch Ctrl + C.
* Add more configuration examples.

### Far
* Add multiple storage engines (Rackspace Files, Google Storage...)

## Contributing to mongolicious
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2011 Marc Boeker. See LICENSE.txt for further details.

