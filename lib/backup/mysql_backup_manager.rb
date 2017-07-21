# frozen_string_literal: true

require 'xz'

module Backup #:nodoc:
  # Managed the backing up of MySQL databases
  class MySQLBackupManager < BackupManager
    include Logging

    def run
      logger.info 'Backing up MySQL on schedule'

      @config.mysql_databases.each do |database_info|
        return false unless backup_database database_info
      end

      true
    end

    private

    def backup_database(database_info)
      name = "#{database_info['name']}-mysql"
      database = database_info['database']

      logger.info "Backing up MySQL database #{database}"

      # Build the command to dump the database
      args = [
        'mysqldump',
        "--user=#{@config.mysql_user}",
        "--password=#{@config.mysql_password}",
        "--host=#{@config.mysql_host}",
        "--port=#{@config.mysql_port}",
        database
      ]

      # Open a temp file for storing the data
      destination = Dir::Tmpname.create(["#{name}-", '.sql.xz']) {}

      # Run the app and compress the output stream
      open(destination) do |output|
        io = IO.popen(args)
        XZ.compress_stream(io) do |chunk|
          output.write chunk
        end
      end

      logger.info "Archived \"#{database}\" to #{destination}"

      # Start the upload
      upload_archive name, destination

      # Delete the generated file
      FileUtils.rm destination

      true
    end
  end
end
