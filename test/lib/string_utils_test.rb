require "test_helper"

class StringUtilsTest < ActiveSupport::TestCase
  # Data-driven tests for clean_spaces (light normalization for display)
  CLEAN_SPACES_TESTS = [
    { input: nil, expected: nil, message: 'nil value' },
    { input: '', expected: nil, message: 'empty string' },
    { input: '   ', expected: nil, message: 'whitespace only' },
    { input: '  Hello World  ', expected: 'Hello World', message: 'strips and collapses spaces' },
    { input: "  Mixed\tCase  \r\nWith\tTabs  ", expected: 'Mixed Case With Tabs', message: 'handles tabs and line breaks' },
    { input: 'Keep special chars!!!', expected: 'Keep special chars!!!', message: 'preserves special characters and case' }
  ].freeze

  data_driven_tests('clean_spaces', CLEAN_SPACES_TESTS) do |input|
    StringUtils.clean_spaces(input)
  end

  # Data-driven tests for normalize_for_hash (aggressive normalization for duplicates)
  NORMALIZE_FOR_HASH_TESTS = [
    { input: nil, expected: nil, message: 'nil value' },
    { input: '', expected: nil, message: 'empty string' },
    { input: '   ', expected: nil, message: 'whitespace only' },
    { input: '  Hello World  ', expected: 'hello world', message: 'strips, collapses spaces, and lowercases' },
    { input: 'hello-world!!!', expected: 'hello-world', message: 'removes special chars but preserves hyphens' },
    { input: "Amazon   Purchase!!!  - Electronics", expected: 'amazon purchase - electronics', message: 'complex real-world example' },
    { input: "Line1\r\nLine2", expected: 'line1 line2', message: 'handles line breaks' },
    { input: 'Payment - Electric Bill ($120.00)', expected: 'payment - electric bill 12000', message: 'removes currency symbols and periods' }
  ].freeze

  data_driven_tests('normalize_for_hash', NORMALIZE_FOR_HASH_TESTS) do |input|
    StringUtils.normalize_for_hash(input)
  end

  # Integration test: hashing similar descriptions
  def test_hash_detection_catches_variations
    variations = [
      "Amazon Purchase",
      "amazon purchase!!!",
      "  AMAZON   PURCHASE  ",
      "Amazon @@ Purchase"
    ]
    
    hashes = variations.map { |v| StringUtils.normalize_for_hash(v) }
    
    # All should normalize to the same string
    assert_equal 1, hashes.uniq.count, "Expected all variations to normalize to same value"
    assert_equal "amazon purchase", hashes.first
  end
end
