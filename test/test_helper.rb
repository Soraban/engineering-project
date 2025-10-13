ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Disable fixtures by default - use factories instead
    self.use_transactional_tests = true
    
    # Include FactoryBot methods
    include FactoryBot::Syntax::Methods
    
    # Include ActiveJob test helpers
    include ActiveJob::TestHelper

    # Data-driven test helper
    # Generates test methods from an array of test cases
    #
    # @param method_name [String] Name of the method being tested (for test naming)
    # @param test_cases [Array<Hash>] Array of test cases with :input, :expected, :message keys
    # @param block [Proc] Block that takes input and returns the actual result
    #
    # Example:
    #   data_driven_tests('my_method', TEST_CASES) { |input| MyClass.my_method(input) }
    def self.data_driven_tests(method_name, test_cases, &block)
      test_cases.each do |test_case|
        input, expected, message = test_case.values_at(:input, :expected, :message)
        
        test_name = "#{method_name} with #{message}"
        define_method("test_#{test_name.gsub(/\W+/, '_')}") do
          result = block.call(input)
          if expected.nil?
            assert_nil result
          else
            assert_equal expected, result
          end
        end
      end
    end
  end
end
