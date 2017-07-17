# frozen_string_literal: true

module Backup #:nodoc:
  # Manages the backing up of directories
  class DirectoryBackupManager
    include Logging

    def initialize(vault, config)
      @vault = vault
      @config = config
    end

    def run
      logger.info 'Backing up directories on schedule'

      @config.backup_directories.each do |directory|
        return false unless backup_directory(directory)
      end
    end

    private

    def backup_directory(directory)
      name = directory['name']
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

      true
    end

    def upload_archive(name, path)
      uploader = ArchiveUploader.new @vault
      uploader.upload path, name: name
    end

  end
end