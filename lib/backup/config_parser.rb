# frozen_string_literal: true

require 'aws-sdk'
require 'time'
require 'yaml'

module Backup #:nodoc:
  # A parser of a given Yaml config file or string
  class ConfigParser
    attr_reader :aws_access_key_id
    attr_reader :aws_secret_access_key
    attr_reader :aws_user

    attr_reader :glacier_arn
    attr_reader :glacier_vault

    attr_reader :backup_directories
    attr_reader :backup_interval

    attr_reader :mysql_host
    attr_reader :mysql_port
    attr_reader :mysql_user
    attr_reader :mysql_password
    attr_reader :mysql_databases

    attr_reader :purge_age
    attr_reader :purge_interval

    DEFAULT_OPTIONS = {
      'aws_access_key_id'     => '',
      'aws_secret_access_key' => '',
      'aws_user'              => '-',
      'glacier_arn'           => '',
      'glacier_vault'         => '',
      'backup_directories'    => [],
      'backup_interval'       => 24, # Every 24 hours
      'mysql_host'            => 'localhost',
      'mysql_port'            => 3306,
      'mysql_user'            => 'me',
      'mysql_password'        => 'password',
      'mysql_databases'       => [],
      'purge_age'             => 432, # 18 days, in hours
      'purge_interval'        => 1, # Every 1 hour
    }.freeze

    def initialize
      reset
    end

    def self.load(value)
      yaml = YAML.safe_load value

      parser = ConfigParser.new
      parser.parse! yaml

      parser
    end

    def self.load_file(path)
      yaml = YAML.load_file path

      parser = ConfigParser.new
      parser.parse! yaml

      parser
    end

    def parse!(yaml)
      # Reset to defaults

      # Merge the yaml with the defaults
      yaml ||= {}
      opts = DEFAULT_OPTIONS.merge yaml

      # Parse the AWS settings
      @aws_access_key_id = opts['aws_access_key_id']
      @aws_secret_access_key = opts['aws_secret_access_key']

      # Parse the Glacier settings
      @glacier_arn = opts['glacier_arn']
      @glacier_vault = opts['glacier_vault']

      # Parse the backup directories
      @backup_directories = opts['backup_directories']
      @backup_interval = opts['backup_interval']

      # Parse the MySQL database settings
      @mysql_host = opts['mysql_host']
      @mysql_port = opts['mysql_port']
      @mysql_user = opts['mysql_user']
      @mysql_password = opts['mysql_password']
      @mysql_databases = opts['mysql_databases']

      # Parse the purge parameters
      @purge_age = opts['purge_age'].to_i
      @purge_interval = opts['purge_interval'].to_i

      # TODO: Validate options
    end

    private

    def reset
      @aws_access_key_id = DEFAULT_OPTIONS['aws_access_key_id']
      @aws_secret_access_key = DEFAULT_OPTIONS['aws_secret_access_key']
      @aws_user = DEFAULT_OPTIONS['aws_user']

      @glacier_arn = DEFAULT_OPTIONS['glacier_arn']
      @glacier_vault = DEFAULT_OPTIONS['glacier_vault']

      @backup_directories = DEFAULT_OPTIONS['backup_directories']
      @backup_interval = DEFAULT_OPTIONS['backup_interval']

      @mysql_host = DEFAULT_OPTIONS['mysql_host']
      @mysql_port = DEFAULT_OPTIONS['mysql_port']
      @mysql_user = DEFAULT_OPTIONS['mysql_user']
      @mysql_password = DEFAULT_OPTIONS['mysql_password']
      @mysql_databases = DEFAULT_OPTIONS['mysql_databases']

      @purge_age = DEFAULT_OPTIONS['purge_age']
      @purge_interval = DEFAULT_OPTIONS['purge_interval']
    end
  end
end
