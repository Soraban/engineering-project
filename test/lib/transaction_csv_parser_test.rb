require "test_helper"

class TransactionCsvParserTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  
  # Test helper - parse and import CSV file
  def parse_csv_file(file_path, start_offset: 0)
    parser = TransactionCsvParser.new(file_path)
    results = { success: 0, errors: [], imported_ids: [] }
    
    parser.each_batch(start_offset: start_offset) do |batch_data, offset, batch_size|
      next if batch_data.empty?
      
      service = TransactionCreationService.new
      Transaction.transaction do
        service.create_bulk(batch_data)
      end
      
      results[:success] += service.results[:success]
      results[:errors].concat(service.results[:errors])
      results[:imported_ids].concat(service.results[:imported_ids])
    end
    
    results
  end
  
  setup do
    # Use unique temp directory per process for parallel testing
    @temp_dir = Rails.root.join('tmp', 'test_uploads', "process_#{$$}")
    FileUtils.mkdir_p(@temp_dir)
    
    # Clean database before each test
    Transaction.delete_all
    AnomalyFlag.delete_all
    CategorizationRule.delete_all
  end

  teardown do
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)
  end

  def test_parses_valid_csv_file_successfully
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Amazon Purchase,299.99,Shopping
      2024-01-16,Grocery Store,67.50,Food & Dining
    CSV

    file_path = create_csv_file('valid.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 2, results[:success], "Expected 2 successful imports. Errors: #{results[:errors].inspect}"
    assert_empty results[:errors], "Unexpected errors: #{results[:errors].inspect}"
    assert_equal 2, Transaction.count
  end

  def test_handles_missing_date_field
    csv_content = <<~CSV
      date,description,amount,category
      ,Amazon Purchase,299.99,Shopping
      2024-01-16,Valid Transaction,50.00,
    CSV

    file_path = create_csv_file('missing_date.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 1, results[:success]
    assert_equal 1, results[:errors].length
    assert_match(/Missing date/, results[:errors].first)
  end

  def test_handles_missing_amount_field
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Amazon Purchase,,Shopping
      2024-01-16,Valid Transaction,50.00,
    CSV

    file_path = create_csv_file('missing_amount.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 1, results[:success]
    assert_equal 1, results[:errors].length
    assert_match(/Missing amount/, results[:errors].first)
  end

  def test_handles_zero_amount
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Zero Amount,0.00,Shopping
    CSV

    file_path = create_csv_file('zero_amount.csv', csv_content)
    results = parse_csv_file(file_path)

    # Zero amounts are allowed (could be refunds, adjustments, etc.)
    assert_equal 1, results[:success]
    assert_equal 0.0, Transaction.last.amount
  end

  def test_handles_missing_description
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,,299.99,Shopping
    CSV

    file_path = create_csv_file('missing_description.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 1, results[:success]
    # Missing description should be nil or empty
    assert_nil Transaction.last.description
  end

  def test_parses_duplicate_rows_successfully
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Amazon Purchase,299.99,Shopping
      2024-01-15,Amazon Purchase,299.99,Shopping
    CSV

    file_path = create_csv_file('duplicates.csv', csv_content)
    results = parse_csv_file(file_path)

    # Parser just parses - doesn't prevent duplicates
    assert_equal 2, results[:success]
    assert_equal 2, Transaction.count
  end

  def test_skips_completely_empty_rows
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Amazon Purchase,299.99,Shopping
      ,,,
      2024-01-16,Valid Transaction,50.00,
    CSV

    file_path = create_csv_file('empty_rows.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 2, results[:success]
    assert_equal 2, Transaction.count
  end

  def test_parses_multiple_date_formats
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,YYYY-MM-DD Format,50.00,
      01/15/2024,MM/DD/YYYY Format,60.00,
      2024/01/15,YYYY/MM/DD Format,80.00,
    CSV

    file_path = create_csv_file('date_formats.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 3, results[:success]
    assert_equal 3, Transaction.count
  end

  def test_parses_amounts_with_currency_symbols
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,With Dollar Sign,$299.99,
      2024-01-16,With Commas,"1,234.56",
    CSV

    file_path = create_csv_file('currency_formats.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 2, results[:success]
    transactions = Transaction.order(:date)
    assert_equal 299.99, transactions.first.amount
    assert_equal 1234.56, transactions.last.amount
  end

  def test_parses_negative_amounts
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Negative Amount,-100.00,
      2024-01-16,Accounting Format,"(50.00)",
    CSV

    file_path = create_csv_file('negative_amounts.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 2, results[:success]
    transactions = Transaction.order(:date)
    assert_equal(-100.0, transactions.first.amount)
    assert_equal(-50.0, transactions.last.amount)
  end

  def test_normalizes_descriptions_on_import
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,  Amazon   Purchase!!!  ,299.99,Shopping
    CSV

    file_path = create_csv_file('normalize_test.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 1, results[:success]
    transaction = Transaction.last
    # Light normalization preserves case
    assert_equal 'Amazon Purchase!!!', transaction.description
    # But hash is generated for duplicate detection
    assert_not_nil transaction.description_hash
  end

  def test_handles_malformed_csv_file
    csv_content = "This is not a valid CSV\nJust random text"
    file_path = create_csv_file('malformed.csv', csv_content)
    
    results = parse_csv_file(file_path)
    
    # Should handle gracefully and report errors
    assert_equal 0, results[:success]
  end

  def test_handles_non_existent_file
    error = assert_raises(RuntimeError) do
      parse_csv_file('/path/to/nonexistent/file.csv')
    end
    
    assert_match(/File not found/, error.message)
  end

  def test_handles_non_csv_file_extension
    file_path = @temp_dir.join('test.txt')
    File.write(file_path, "not a csv")
    
    error = assert_raises(RuntimeError) do
      parse_csv_file(file_path)
    end
    
    assert_match(/must be a CSV file/, error.message)
  end

  def test_handles_empty_file
    file_path = @temp_dir.join('empty.csv')
    File.write(file_path, "")
    
    error = assert_raises(RuntimeError) do
      parse_csv_file(file_path)
    end
    
    assert_match(/File is empty/, error.message)
  end

  def test_returns_imported_transaction_ids
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,Transaction 1,50.00,
      2024-01-16,Transaction 2,60.00,
    CSV

    file_path = create_csv_file('with_ids.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 2, results[:success]
    assert_equal 2, results[:imported_ids].length
    assert results[:imported_ids].all? { |id| id.is_a?(Integer) }
  end

  def test_handles_csv_with_missing_category_gracefully
    csv_content = <<~CSV
      date,description,amount,category
      2024-01-15,No Category,50.00,
      2024-01-16,With Category,60.00,Shopping
    CSV

    file_path = create_csv_file('optional_category.csv', csv_content)
    results = parse_csv_file(file_path)

    assert_equal 2, results[:success]
    assert_nil Transaction.first.category
    assert_equal 'Shopping', Transaction.last.category.name
  end

  private

  def create_csv_file(filename, content)
    file_path = @temp_dir.join(filename)
    File.write(file_path, content)
    file_path.to_s
  end
end
