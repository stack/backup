# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe Backup::TreeHasher do
  ONE_MB = (1024 * 1024).freeze
  ONE_MB_HASH = '30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58'.freeze
  ONE_MB_ONE_B_HASH = '28638dab8d5e1754a4ecb38b0ebe6df66c844f94aed142d4d0283d208bb786cd'.freeze

  it 'hashes 1MB of zeros' do
    data = generate_bytes(ONE_MB)

    expect(data).not_to be_nil
    expect(data.length).to be(ONE_MB)
    expect(data.class).to be(String)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_data data

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_HASH)
  end

  it 'hashes 1MB + 1B of zeros' do
    data = generate_bytes(ONE_MB + 1)

    expect(data).not_to be_nil
    expect(data.length).to be(ONE_MB + 1)
    expect(data.class).to be(String)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_data data

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_ONE_B_HASH)
  end

  it 'hashes 1MB of zeros from the end of a > 1MB buffer' do
    data = generate_bytes(ONE_MB + 50)

    expect(data).not_to be_nil
    expect(data.length).to be(ONE_MB + 50)
    expect(data.class).to be(String)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_data data, 50

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_HASH)
  end

  it 'hashes 1MB + 1B of zeroes from the middle of a 1MB ones, 1MB + 1B zeros, 1MB ones buffer' do
    part_one = generate_bytes(ONE_MB, 1)
    part_two = generate_bytes(ONE_MB + 1, 0)
    part_three = generate_bytes(ONE_MB, 1)

    data = part_one + part_two + part_three

    expect(data).not_to be_nil
    expect(data.length).to be(ONE_MB * 3 + 1)
    expect(data.class).to be(String)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_data data, ONE_MB, ONE_MB + 1

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_ONE_B_HASH)
  end

  it 'hashes 1MB of zeros from a file' do
    file = generate_bytes_file(ONE_MB)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_file file.path

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_HASH)

    file.unlink
  end

  it 'hashes 1MB + 1B of zeros from a file' do
    file = generate_bytes_file(ONE_MB + 1)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_file file.path

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_ONE_B_HASH)

    file.unlink
  end

  it 'hashes 1MB of zeros from the end of a > 1MB file' do
    file = generate_bytes_file(ONE_MB + 50)

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_file file.path, 50

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_HASH)

    file.unlink
  end

  it 'hashes 1MB + 1B of zeroes from the middle of a 1MB ones, 1MB + 1B zeros, 1MB ones buffer' do
    part_one = generate_bytes(ONE_MB, 1)
    part_two = generate_bytes(ONE_MB + 1, 0)
    part_three = generate_bytes(ONE_MB, 1)

    file = Tempfile.new 'zeros'
    file.write part_one
    file.write part_two
    file.write part_three
    file.close

    hasher = Backup::TreeHasher.new
    hash = hasher.hash_file file.path, ONE_MB, ONE_MB + 1

    expect(hash).not_to be_nil
    expect(hash).to eq(ONE_MB_ONE_B_HASH)

    file.unlink
  end


  private

  def generate_bytes(number_of_bytes, value = 0)
    data = Array.new(number_of_bytes, value)
    data.pack('c*')
  end

  def generate_bytes_file(number_of_bytes, value = 0)
    file = Tempfile.new 'zeros'
    file.write generate_bytes(number_of_bytes, value)
    file.close

    file
  end
end
