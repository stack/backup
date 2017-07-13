# frozen_string_literal: true

module Backup #:nodoc:
  # Upload a local file to a given vault
  class ArchiveUploader
    include Logging

    DEFAULT_CHUNK_SIZE = 1024 * 1024 * 2

    def initialize(vault)
      @vault = vault
      @hasher = TreeHasher.new
    end

    def upload(path, opts = {})
      # Normalize the options
      opts[:name] ||= File.basename(path)
      opts[:chunk_size] ||= DEFAULT_CHUNK_SIZE

      # Begin the upload
      upload = create_upload path, opts[:name], opts[:chunk_size]

      # Calculate the parts
      file_size = File.size path
      total_parts = (file_size / opts[:chunk_size]).ceil

      # Upload each part
      0.upto(total_parts).each do |idx|
        start_byte = idx * opts[:chunk_size]
        end_byte = ((idx * opts[:chunk_size]) + opts[:chunk_size]) - 1

        end_byte = file_size - 1 if end_byte > file_size

        bytes = IO.read path, opts[:chunk_size], start_byte
        hash = @hasher.hash_data bytes

        logger.info "Uploading part #{idx}: #{start_byte}-#{end_byte}: #{hash}"
        result = upload.upload_part({
          checksum: hash,
          range: "bytes #{start_byte}-#{end_byte}/*",
          body: bytes
        })

        logger.debug("Upload part #{idx} result: #{result.inspect}")
      end

      # Complete the upload
      complete_upload path, upload
    end

    private

    def complete_upload(path, upload)
      file_size = File.size path
      hash = @hasher.hash_file path

      result = upload.complete({
        archive_size: file_size,
        checksum: hash
      })

      logger.debug "Upload complete result: #{result.inspect}"
    end

    def create_upload(path, name, chunk_size)
      @vault.initiate_multipart_upload({
        archive_description: name,
        part_size: chunk_size
      })
    end
  end
end
