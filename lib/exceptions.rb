# frozen_string_literal: true

module Mastodon
  class Error < StandardError; end
  class NotPermittedError < Error; end
  class ValidationError < Error; end
  class HostValidationError < ValidationError; end
  class LengthValidationError < ValidationError; end
  class DimensionsValidationError < ValidationError; end
  class StreamValidationError < ValidationError; end
  class RaceConditionError < Error; end
  
  class RateLimitExceededError < StandardError
    def initialize(cooldown_end, generated_via)
      if generated_via = 'invite'
        super("Sorry, you can only create 1 invite per week. Try again on #{cooldown_end}.")
      else 
        super("You have done this action too many times! Try  again on #{cooldown_end}.")
      end
    end
  end

  class UnexpectedResponseError < Error
    attr_reader :response

    def initialize(response = nil)
      @response = response

      if response.respond_to? :uri
        super("#{response.uri} returned code #{response.code}")
      else
        super
      end
    end
  end
end
