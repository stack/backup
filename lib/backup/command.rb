# frozen_string_literal: true

require 'date'
require 'minitar'
require 'xz'

module Backup #:nodoc:
  # The main class to command everything
  class Command
    include Logging

    def initialize(config)
      @config = config

      # Set up the Glacier client
      credentials = Aws::Credentials.new @config.aws_access_key_id, @config.aws_secret_access_key
      @glacier_client = Aws::Glacier::Client.new({
        credentials: credentials,
        region: @config.glacier_arn
      })
    end

    def run
      # Validate the vault
      description = vault_description
      return 1 if description.nil?

      logger.info "Using vault #{vault_description.vault_arn}"

      # Get the vault
      @vault = Aws::Glacier::Vault.new({
        account_id: @config.aws_user,
        client: @glacier_client,
        name: description.vault_name
      })

      # Find any archives that may be too old
      # purge_archives

      # Backup directories
      return 1 unless backup_directories

      # Success, so return 0
      0
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

    def backup_directories
      @config.backup_directories.each do |directory|
        return false unless backup_directory(directory)
      end

      true
    end

    def compress_directory(name, path)
      destination = Dir::Tmpname.create(["#{name}-", '.tar.xz']) { }

      XZ::StreamWriter.open destination do |txz|
        Archive::Tar::Minitar.pack path, txz
      end

      destination
    end

    def upload_archive(name, path)
      uploader = ArchiveUploader.new @vault
      uploader.upload path, name: name
    end

    def purge_archives
      logger.info 'Looking for any archives that can be purged'

      begin
        @purge_job = @vault.initiate_inventory_retrieval
      rescue Aws::Glacier::Errors::ResourceNotFoundException
        logger.warn 'Skipping purge job as it cannot be scheduled yet'
        return
      end

      complete = false
      until complete
        begin
          result = @purge_job.get_output
          logger.debug "- #{result.inspect}"
        rescue Aws::Glacier::Errors::InvalidParameterValueException
          logger.debug "- Job not ready, yet."
          sleep 2.0
        end
      end

      logger.debug result.inspect

      # TODO: Complete purge job
    end

    def vault_description
      begin
        vault_description = @glacier_client.describe_vault({
          account_id: @config.aws_user,
          vault_name: @config.glacier_vault
        })
      rescue Aws::Glacier::Errors::ResourceNotFoundException => e
        logger.error "Failed to find vault \"#{@config.glacier_vault}\""
        logger.error e
        return nil
      end

      vault_description
    end
  end
end
