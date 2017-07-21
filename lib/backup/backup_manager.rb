# frozen_string_literal: true

module Backup #:nodoc:
  # Base class for all backup managers
  class BackupManager
    include Logging

    # Initialize the backup manager with the vault and config
    def initialize(vault, config)
      @vault = vault
      @config = config
    end

    # Run the backup manager
    def run
      raise NotImplementedError
    end

    protected

    # Upload a generated archive from the path
    def upload_archive(name, path)
      uploader = ArchiveUploader.new @vault
      uploader.upload path, name: name
    end
  end
end
