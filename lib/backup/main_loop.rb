# frozen_string_literal: true

require 'eventmachine'

module Backup #:nodoc:
  # The main run loop to manager all things
  class MainLoop
    include Logging

    DEFAULT_OPTIONS = {
      force: false
    }.freeze

    def initialize(config, opts = {})
      @config = config
      @options = DEFAULT_OPTIONS.merge opts

      # Set up the Glacier client
      credentials = Aws::Credentials.new @config.aws_access_key_id, @config.aws_secret_access_key
      @client = Aws::Glacier::Client.new(
        credentials: credentials,
        region: @config.glacier_arn
      )
    end

    def run
      # Validate the vault
      description = vault_description
      return 1 if description.nil?

      logger.info "Using vault #{vault_description.vault_arn}"

      # Get the vault
      @vault = Aws::Glacier::Vault.new(
        account_id: @config.aws_user,
        client: @client,
        name: description.vault_name
      )

      # Build the purge manager
      @purge_manager = PurgeManager.new @client, @vault, @config

      # Build the backup managers
      @directory_backup_manager = DirectoryBackupManager.new @vault, @config
      @mysql_backup_manager = MySQLBackupManager.new @vault, @config

      EventMachine.run do
        # Schedule and run the purge manager
        @purge_manager_timer = EventMachine::PeriodicTimer.new(@config.purge_interval * 60 * 60) do
          @purge_manager.run
        end

        @purge_manager.run if @options[:force]

        # Schedule and run the backup managers
        @backup_managers_timer = EventMachine::PeriodicTimer.new(@config.backup_interval * 60 * 60) do
          @directory_backup_manager.run
          @mysql_backup_manager.run
        end

        @directory_backup_manager.run if @options[:force]
        @mysql_backup_manager.run if @options[:force]
      end

      0
    end

    def vault_description
      begin
        vault_description = @client.describe_vault(
          account_id: @config.aws_user,
          vault_name: @config.glacier_vault
        )
      rescue Aws::Glacier::Errors::ResourceNotFoundException => e
        logger.error "Failed to find vault \"#{@config.glacier_vault}\""
        logger.error e
        return nil
      end

      vault_description
    end
  end
end
