# Reduce SQL logging noise in development
if Rails.env.development?
  ActiveRecord::Base.logger.level = Logger::INFO

  # Optionally suppress SQL logs entirely during bulk operations
  module QuietSql
    def self.suppress_sql_logs
      old_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = nil
      yield
    ensure
      ActiveRecord::Base.logger = old_logger
    end
  end
end
