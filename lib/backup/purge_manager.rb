# frozen_string_literal: true

require 'date'

module Backup #:nodoc:
  # Manages the state of purge attempts
  class PurgeManager
    include Logging

    # Initialize the purge manager in the initial state
    def initialize(client, vault, config)
      @client = client
      @vault = vault
      @config = config

      @state = :initial
      @last_processed_job = Time.at 0
    end

    # Perform the next set of operations for the purge manager
    def run
      # Dispatch to the proper method based on the state
      case @state
      when :idle
        run_idle
      when :initial
        run_initial
      when :waiting
        run_waiting
      else
        raise "Invalid state #{@state} for purge manager"
      end
    end

    private

    def change_state(next_state)
      logger.debug "Purge manager switching from #{@state} to #{next_state}"
      @state = next_state
    end

    def completed_jobs
      @vault.completed_jobs.find_all do |job|
        job.action == 'InventoryRetrieval'
      end
    end

    def latest_completed_job
      completed_jobs.sort { |a, b| b.completion_date <=> a.completion_date }.first
    end

    def pending_jobs
      @vault.jobs_in_progress.find_all do |job|
        job.action == 'InventoryRetrieval'
      end
    end

    def purge(job)
      completed_at = job.completion_date
      logger.info "Purge manager purging with job #{job.id} from #{completed_at}"

      # Get the data and parse in to json
      data = JSON.parse job.get_output.body.read

      # Filter out anything that isn't in the purge window
      now = Time.now
      archives = data['ArchiveList'].find_all do |archive|
        creation_date = DateTime.parse(archive['CreationDate']).to_time
        diff = (now - creation_date) / 60 / 60

        diff > @config.purge_age
      end

      # Send a delete request for each filtered archive
      archives.each do |archive_info|
        logger.info "Purging #{archive_info['ArchiveId']} from #{archive_info['CreationDate']}"
        archive = Aws::Glacier::Archive.new({
          account_id: @vault.account_id,
          vault_name: @vault.name,
          id: archive_info['ArchiveId'],
          client: @client
        })

        archive.delete
      end

      # Mark the latest purge and switch back to idle
      @last_processed_job = completed_at
      change_state :idle
    end

    def run_initial
      logger.debug 'Purge manager running in the initial state'

      # If there is a completed job, purge it!
      job = latest_completed_job
      unless job.nil?
        purge job
        return
      end

      # If there is a pending job, switch to waiting
      jobs = pending_jobs
      unless jobs.empty?
        change_state :waiting
        return
      end

      # Otherwise, start a new inventory request
      start_inventory_request
    end

    def run_idle
      logger.debug 'Purge manager running in the idle state'

      # If there is a pending job, we should be waiting
      unless pending_jobs.empty?
        logger.warn 'Purge manager was idle with pending jobs'
        change_state :waiting
        return
      end

      # If there are no completed jobs in the past 8 hours, start a new inventory request
      now = Time.now
      jobs = completed_jobs.find_all do |job|
        job.creation_date > (now - (8 * 60 * 60))
      end

      if jobs.empty?
        start_inventory_request
      end
    end

    def run_waiting
      logger.debug 'Purge manager running in the waiting state'

      # If there is still a pending job, do nothing
      return unless pending_jobs.empty?

      # Ensure there is a completed job
      job = latest_completed_job
      if job.nil?
        logger.error 'Purge master waited for completed job that never happened'
        change_state :idle
      else
        purge job
      end
    end

    def start_inventory_request
      logger.info 'Purge manager is requesting a new inventory'

      @vault.initiate_inventory_retrieval
      change_state :waiting
    end
  end
end
