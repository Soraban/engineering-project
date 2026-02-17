# frozen_string_literal: true

require "csv"

module Transactions
  class CsvImporter
    def initialize(file:)
      @file = file
    end

    def call
      created = 0
      skipped_duplicates = 0
      row_errors = []

      amount_stats = Transactions::AnomalyDetector.amount_stats

      CSV.foreach(@file.path, headers: true).with_index(2) do |row, line_no|
        attrs = normalize_row(row)

        if attrs[:errors].any?
          row_errors << { line: line_no, errors: attrs[:errors] }
          next
        end

        if Transaction.exists?(date: attrs[:date], description: attrs[:description], amount: attrs[:amount])
          skipped_duplicates += 1
          next
        end

        tx = Transaction.new(attrs.slice(:date, :description, :amount, :category))
        Transactions::RuleApplier.new(tx).call

        if tx.save
          Transactions::AnomalyDetector.call(tx, amount_stats: amount_stats)
          created += 1
        else
          row_errors << { line: line_no, errors: tx.errors.full_messages, row: row.to_h }
        end
      end

      { created: created, skipped_duplicates: skipped_duplicates, row_errors: row_errors }
    rescue CSV::MalformedCSVError
      raise MalformedCsvError
    end



    class MalformedCsvError < StandardError; end

    private

    def normalize_row(row)
      raw = row.to_h.transform_keys { |k| normalize_description(k) }

      date_str = raw["date"]
      desc     = normalize_description(raw["description"])
      amt_str  = raw["amount"]
      category = raw["category"]

      errors = []
      errors << "Missing date" if date_str.blank?
      errors << "Missing description" if desc.blank?
      errors << "Missing amount" if amt_str.blank?

      date = parse_date(date_str)
      errors << "Invalid date" if date_str.present? && date.nil?

      amount = parse_amount(amt_str)
      errors << "Invalid amount" if amt_str.present? && amount.nil?

      {
        date: date,
        description: desc,
        amount: amount,
        category: category&.strip,
        errors: errors
      }
    end

    def normalize_description(value)
      return nil if value.blank?
      value.to_s.strip.downcase
    end

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def parse_amount(value)
      return nil if value.blank?
      cleaned_value = value.to_s.gsub(/[$,]/, "")
      BigDecimal(cleaned_value)
    rescue ArgumentError
      nil
    end
  end
end
