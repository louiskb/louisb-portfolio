ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Temporarily set (or unset, when value is nil) an environment variable for
    # the duration of the block, restoring the original afterwards. Test
    # processes are isolated and run serially, so this is leak-free.
    def with_env(key, value)
      original = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
      yield
    ensure
      original.nil? ? ENV.delete(key) : ENV[key] = original
    end
  end
end

class ActionDispatch::IntegrationTest
  # Devise helpers so controller/integration tests can `sign_in users(:louis)`.
  include Devise::Test::IntegrationHelpers
end
