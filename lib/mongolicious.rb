require 'uri'
require 'tmpdir'
require 'logger'
require 'fileutils'
require 'yaml'

require 'mongolicious/backup'
require 'mongolicious/filesystem'
require 'mongolicious/storage'
require 'mongolicious/db'

LOGGER = Logger.new(STDOUT)

module Mongolicious
  def self.logger
    LOGGER
  end
end