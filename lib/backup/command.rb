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
      # Initialize the upload
      upload = @vault.initiate_multipart_upload({
        archive_description: "#{name} #{DateTime.now.to_s}",
        part_size: 1024 * 1024
      })

      # Calculate segment sizes
      part_size = 1024 * 1024 # Specifically 1MB so we don't need to calculate hash trees
      file_size = File.size path
      total_parts = (file_size / part_size).ceil

      # Build a tree hasher to do all of the hashing work
      hasher = TreeHasher.new

      # Upload each part, collecting the hash
      0.upto(total_parts).each do |idx|
        start_byte = idx * part_size
        end_byte = ((idx * part_size) + part_size) - 1

        end_byte = file_size - 1 if end_byte > file_size

        bytes = IO.read path, 1024 * 1024, start_byte
        hash = hasher.hash_data bytes

        logger.info "Uploading part #{idx}: #{start_byte}-#{end_byte}: #{hash}"
        result = upload.upload_part({
          checksum: hash,
          range: "bytes #{start_byte}-#{end_byte}/*",
          body: bytes
        })

        logger.debug("Upload part #{idx} result: #{result.inspect}")
      end

      # Hash the entire thing
      hash = hasher.hash_file path

      # Finalize the upload
      result = upload.complete({
        archive_size: file_size,
        checksum: hash
      })

      logger.debug "Upload complete result: #{result.inspect}"
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
