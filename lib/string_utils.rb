class StringUtils
  class << self
    # Light normalization for display - keeps description readable
    # - Strips whitespace
    # - Collapses multiple spaces
    #
    # @param str [String, nil] The string to normalize
    # @return [String, nil] The normalized string, or nil if input is blank
    def clean_spaces(str)
      str.to_s.strip.gsub(/\s+/, ' ').presence
    end

    # Aggressive normalization for duplicate detection hashing
    # - Removes all special characters (except hyphens)
    # - Converts to lowercase
    # - Collapses spaces
    #
    # Used internally for description_hash generation
    #
    # @param str [String, nil] The string to normalize for hashing
    # @return [String, nil] The aggressively normalized string
    def normalize_for_hash(str)
      str.to_s.strip
         .gsub(/[^\w\s\-]/, '')     # Remove special chars except hyphens 
         .gsub(/\s+/, ' ')          # Collapse spaces
         .downcase                  # Lowercase for case-insensitive matching
         .presence
    end

    def normalize_and_hash(str)
      normalized = StringUtils.normalize_for_hash(str)
      return if normalized.blank?

      Digest::SHA256.hexdigest(normalized)
    end
  end
end
