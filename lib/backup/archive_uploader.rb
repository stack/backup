# frozen_string_literal: true

require 'concurrent/executors'

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
      opts[:chunk_size] ||= DEFAULT_CHUNK_SIZE
      opts[:name] ||= File.basename(path)
      opts[:workers] ||= Concurrent.processor_count

      # Begin the upload
      upload = create_upload opts[:name], opts[:chunk_size]

      # Calculate the parts
      file_size = File.size path
      total_parts = (file_size.to_f / opts[:chunk_size].to_f).ceil

      # Build a thread pool for parallelizing work
      pool = Concurrent::FixedThreadPool.new opts[:workers]
      latch = Concurrent::CountDownLatch.new total_parts

      # Upload each part
      0.upto(total_parts - 1).each do |idx|
        start_byte = idx * opts[:chunk_size]
        end_byte = ((idx * opts[:chunk_size]) + opts[:chunk_size]) - 1

        end_byte = file_size - 1 if end_byte > file_size

        bytes = IO.read path, opts[:chunk_size], start_byte
        hash = @hasher.hash_data bytes

        pool.post do
          logger.info "Uploading part #{idx}: #{start_byte}-#{end_byte}"

          upload.upload_part(
            checksum: hash,
            range: "bytes #{start_byte}-#{end_byte}/*",
            body: bytes
          )

          latch.count_down
        end
      end

      # Wait for the pool to finish
      latch.wait

      # Complete the upload
      complete_upload path, upload
    end

    private

    def complete_upload(path, upload)
      file_size = File.size path
      hash = @hasher.hash_file path

      result = upload.complete(
        archive_size: file_size,
        checksum: hash
      )

      logger.debug "Upload complete for #{result.archive_id}"
    end

    def create_upload(name, chunk_size)
      @vault.initiate_multipart_upload(
        archive_description: name,
        part_size: chunk_size
      )
    end
  end
end
