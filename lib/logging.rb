# frozen_string_literal: true

require 'logger'

# A mixin for providing logging across the project
module Logging
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new(STDOUT)
    end
  end

  def self.included(base)
    class << base
      def logger
        Logging.logger
      end
    end
  end

  def logger
    Logging.logger
  end
end
