# Bookkeeping System - Backend API

A scalable Ruby on Rails API for managing bookkeeping transactions with automated categorization, anomaly detection, and bulk operations.

## Features

✅ **Transaction Management** - Full CRUD operations for transactions
✅ **CSV Import** - Bulk import transactions from CSV files with error handling
✅ **Rule-Based Categorization** - Automatic categorization based on customizable rules
✅ **Anomaly Detection** - Identifies suspicious transactions (duplicates, large amounts, unusual patterns)
✅ **Bulk Operations** - Categorize multiple transactions at once
✅ **Review Dashboard** - Highlights transactions needing review
✅ **Performance Optimized** - Database indexing and pagination for handling 1M+ transactions
✅ **RESTful API** - Clean API endpoints with proper error handling

## Tech Stack

- **Ruby** 3.4+
- **Rails** 8.0+
- **PostgreSQL** (with advanced indexing)
- **Redis** (for caching and background jobs)
- **Sidekiq** (for async processing)

## Prerequisites

- Ruby 3.4 or higher
- PostgreSQL 12+
- Redis 6+

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd backend
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials
   ```

4. **Create and setup database**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

5. **Start the server**
   ```bash
   rails server
   ```

The API will be available at `http://localhost:3000`

## Database Schema

### Tables

**transactions**
- `transaction_date` (date) - Date of transaction
- `description` (text) - Transaction description
- `amount` (decimal) - Transaction amount
- `category_id` (foreign key) - Category reference
- `reviewed` (boolean) - Manual review status
- `flagged_as_anomaly` (boolean) - Anomaly flag
- `anomaly_reason` (string) - Reason for flagging
- `metadata` (jsonb) - Additional data

**categories**
- `name` (string, unique) - Category name
- `color` (string) - Display color
- `description` (text) - Category description

**rules**
- `name` (string) - Rule name
- `condition_type` (string) - Type of condition (description_contains, amount_greater_than, etc.)
- `condition_value` (string) - Value to match
- `action_type` (string) - Action to take (categorize, flag)
- `action_value` (string) - Additional action data
- `category_id` (foreign key) - Category to assign
- `active` (boolean) - Rule status
- `priority` (integer) - Rule priority

## API Endpoints

### Transactions

- `GET /api/v1/transactions` - List all transactions (paginated)
  - Query params: `page`, `per_page`, `category_id`, `flagged`, `uncategorized`
- `GET /api/v1/transactions/:id` - Get single transaction
- `POST /api/v1/transactions` - Create transaction
- `PATCH /api/v1/transactions/:id` - Update transaction
- `DELETE /api/v1/transactions/:id` - Delete transaction
- `POST /api/v1/transactions/import` - Import CSV file
- `POST /api/v1/transactions/bulk_categorize` - Bulk categorize transactions
- `GET /api/v1/transactions/review_dashboard` - Get dashboard data

### Categories

- `GET /api/v1/categories` - List all categories
- `GET /api/v1/categories/:id` - Get single category
- `POST /api/v1/categories` - Create category
- `PATCH /api/v1/categories/:id` - Update category
- `DELETE /api/v1/categories/:id` - Delete category

### Rules

- `GET /api/v1/rules` - List all rules
- `GET /api/v1/rules/:id` - Get single rule
- `POST /api/v1/rules` - Create rule
- `PATCH /api/v1/rules/:id` - Update rule
- `DELETE /api/v1/rules/:id` - Delete rule
- `POST /api/v1/rules/:id/apply` - Apply rule to all transactions

## Example Requests

### Create a Transaction
```bash
curl -X POST http://localhost:3000/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transaction": {
      "transaction_date": "2025-01-15",
      "description": "Amazon purchase",
      "amount": 49.99
    }
  }'
```

### Import CSV
```bash
curl -X POST http://localhost:3000/api/v1/transactions/import \
  -F "file=@transactions.csv"
```

### Bulk Categorize
```bash
curl -X POST http://localhost:3000/api/v1/transactions/bulk_categorize \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_ids": [1, 2, 3],
    "category_id": 5
  }'
```

### Create a Rule
```bash
curl -X POST http://localhost:3000/api/v1/rules \
  -H "Content-Type: application/json" \
  -d '{
    "rule": {
      "name": "Amazon Shopping",
      "condition_type": "description_contains",
      "condition_value": "amazon",
      "action_type": "categorize",
      "category_id": 1,
      "priority": 10
    }
  }'
```

## CSV Import Format

Your CSV file should have the following columns (case-insensitive):
- `date` or `transaction_date`
- `description`
- `amount`

Example CSV:
```csv
date,description,amount
2025-01-15,Amazon.com Purchase,49.99
2025-01-16,Starbucks Coffee,5.50
2025-01-17,Uber Ride,23.45
```

## Anomaly Detection

The system automatically detects:
1. **Large Amounts** - Transactions > $1,000
2. **Duplicates** - Same amount and date within 7 days
3. **Missing Description** - Transactions without descriptions
4. **Unusual Patterns** - Amounts > 3 standard deviations from user's average

## Performance Optimization

- **Database Indexes** - Optimized queries on frequently accessed columns
- **Pagination** - Default 50 items per page (max 100)
- **GIN Indexes** - Fast JSONB metadata searches
- **Composite Indexes** - Efficient filtering on multiple columns
- **Batch Processing** - Bulk operations for large datasets

## Rule Types

### Condition Types
- `description_contains` - Matches if description contains text
- `amount_greater_than` - Matches if amount > value
- `amount_less_than` - Matches if amount < value
- `amount_equals` - Matches if amount == value

### Action Types
- `categorize` - Assigns transaction to category
- `flag` - Flags transaction as anomaly

## Development

### Run tests
```bash
rspec
```

### Console
```bash
rails console
```

### Reset database
```bash
rails db:reset
```

## Production Deployment

1. Set environment variables
2. Precompile assets (if needed)
3. Run migrations: `rails db:migrate`
4. Seed database: `rails db:seed`
5. Start server with production settings

## Architecture Decisions

- **API-only Rails** - Lightweight, focused on backend logic
- **Service Objects** - RuleEngine and AnomalyDetector for complex business logic
- **Background Jobs Ready** - Sidekiq configured for async processing
- **JSONB Metadata** - Flexible storage for additional transaction data
- **Comprehensive Indexing** - Optimized for scale (1M+ transactions)

## License

MIT
