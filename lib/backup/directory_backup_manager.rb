# frozen_string_literal: true

module Backup #:nodoc:
  # Manages the backing up of directories
  class DirectoryBackupManager < BackupManager
    include Logging

    def run
      logger.info 'Backing up directories on schedule'

      @config.directories.each do |directory|
        return false unless backup_directory(directory)
      end

      true
    end

    private

    def backup_directory(directory)
      name = "#{directory['name']}-directory"
      path = directory['path']

      logger.info "Backing up directory #{path}"

      # Ensure it exists
      unless Dir.exist? path
        logger.error "Backup directory #{path} does not exist"
        return false
      end

      # Generate a temp archive to store the data in
      logger.info "Archiving \"#{name}\""
      destination = compress_directory name, path
      logger.info "Archived \"#{name}\" to #{destination}"

      # Start the upload
      upload_archive name, destination

      # Delete the generated file
      FileUtils.rm destination

      true
    end

    def compress_directory(name, path)
      directory = File.basename path
      parent_directory = File.dirname path

      destination = Dir::Tmpname.create(["#{name}-", '.tar.xz']) {}

      previous_dir = Dir.getwd
      Dir.chdir parent_directory

      args = ['tar', 'cfJ', destination, directory]
      system(*args)

      Dir.chdir previous_dir

      destination
    end
  end
end
