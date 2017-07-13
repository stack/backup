# frozen_string_literal: true

require 'digest'

module Backup #:nodoc:
  # One megabyte in bytes
  ONE_MB = (1024 * 1024).freeze

  # Performs a 1MB tree hash in the given data.
  class TreeHasher
    # Initialize the TreeHasher with a default digest object
    def initialize
      @digest = Digest::SHA256.new
    end

    # Hash a String or IO object.
    def hash_data(string_or_io, offset = 0, length = 0)
      if string_or_io.is_a? String
        hash_io StringIO.new(string_or_io), offset, length
      elsif string_or_io.is_a? IO
        hash_io string_or_io, offset, length
      else
        raise "TreeHashes#hash_data expects a String or IO object. Got #{string_or_io.class}"
      end
    end

    # Hash a file
    def hash_file(path, offset = 0, length = 0)
      hash = nil

      open path do |f|
        hash = hash_data f, offset, length
      end

      hash
    end

    private

    # Combine the hashed chunks into 1 hash
    def combined_hashed_chunks(hashes)
      # Continually hash pairs until there is only one!
      while hashes.count > 1
        hashes = hashes.each_slice(2).map do |slice|
          if slice.count == 1
            slice.first
          else
            @digest.reset
            @digest << slice[0].scan(/../).map { |x| x.hex }.pack('c*')
            @digest << slice[1].scan(/../).map { |x| x.hex }.pack('c*')

            @digest.hexdigest
          end
        end
      end

      hashes.first
    end

    # Break an IO object in to hashed 1MB chunks
    def generate_hashed_chunks(io, offset, length)
      # Seek to the offset
      io.seek offset

      # Start by hashing each 1MB part
      hashes = []
      bytes_read = 0

      while true
        # Have we hit the end of the data
        break if (length != 0 && bytes_read >= length)

        # How much data do we need to read?
        if length == 0
          bytes_to_read = ONE_MB
        else
          bytes_to_read = length - bytes_read
          bytes_to_read = [bytes_to_read, ONE_MB].min
        end

        # Do the read
        chunk = io.read bytes_to_read
        break if chunk.nil?

        # Digest it
        @digest.reset
        @digest << chunk

        hashes << @digest.hexdigest
        bytes_read += chunk.length
      end

      # TODO: Sanity check that bytes_read == length

      hashes
    end

    # Hash an IO object
    def hash_io(io, offset, length)
      # Hash the chunks
      hashes = generate_hashed_chunks io, offset, length
      raise 'TreeHasher generated zero chunks' if hashes.empty?

      # Combine the chunks
      combined_hashed_chunks hashes
    end
  end
end
