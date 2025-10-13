# Quick Start Guide

## Get Up and Running in 5 Minutes

### 1. Start the Application

```bash
# Setup (first time only)
bundle install
bin/rails db:create db:migrate db:seed

# Start web server + background worker
bin/dev
```

Visit: **http://localhost:3000**

> **Note**: `bin/dev` starts both the Rails server AND the background worker for real-time job processing.

### 2. Explore the Dashboard

You'll see:
- **Transaction Statistics**: Total, monthly, average amounts
- **Anomaly Breakdown**: 4 types of anomalies detected
- **Needs Review**: Uncategorized and flagged transactions
- **Recent Activity**: Latest 10 transactions
- **Quick Actions**: Import, Add Transaction, Create Rule buttons

### 3. Import Sample Data

**Option A: Use the Sample CSV** (Recommended)

1. Click **"📤 Import CSV"** in navigation
2. Select `/public/sample_transactions.csv` (20 transactions included)
3. Click **"Import Transactions"**
4. **Watch real-time progress**:
   - Instant redirect (< 50ms)
   - Live transaction count during import
   - Anomaly detection progress bar
   - Completion summary with stats
5. View imported transactions

**Option B: Create Manually**

1. Click **"+ Add Transaction"**
2. Fill in the form:
   - Date (required)
   - Description (normalized automatically)
   - Amount (required)
   - Category (optional - rules can auto-categorize)
3. Submit - anomaly detection runs in background

### 4. Create Smart Categorization Rules

1. Navigate to **"Rules"**
2. Click **"+ Create Rule"**
3. Example rules to try:

   **Amazon Purchases**:
   - Name: "Amazon Purchases"
   - Type: "Description Contains"
   - Pattern: "amazon"
   - Category: "Shopping"
   - Priority: 10
   - Active: Yes

   **Large Transactions**:
   - Name: "High Value"
   - Type: "Amount Threshold"
   - Operator: ">"
   - Threshold: 1000
   - Category: "High Value"
   - Priority: 100

   **Restaurant Spending**:
   - Name: "Restaurants"
   - Type: "Description Contains"
   - Pattern: "restaurant"
   - Category: "Food & Dining"
   - Priority: 5

4. Click **"Apply Now"** to categorize existing transactions immediately

### 5. Review Flagged Transactions

1. Navigate to **"Review"** (red badge shows count)
2. You'll see four types of anomalies:
   - **Unusual Amounts**: >200% deviation from average
   - **Potential Duplicates**: Same date/amount/description
   - **Missing Metadata**: Blank description or no category
   - **Suspicious Patterns**: Round numbers, rapid transactions
3. Actions available:
   - Click **"View"** to see anomaly details
   - Click **"Edit"** to fix issues
   - Click **"Approve"** to mark as reviewed
   - Use **bulk actions** for multiple at once

### 6. Try Bulk Operations

From **Transactions** page:

1. **Select transactions**: Click checkboxes (or select all)
2. **Bulk actions bar appears** with selection count
3. **Choose action**:
   - **Apply Category**: Pick from dropdown → "Apply Category"
   - **Approve All**: Mark all as reviewed → "Approve All"
4. **Instant feedback**: All updated in single query (no page reload)

## Real-Time Import Experience

When you import a CSV file, you'll experience:

**Phase 1: Importing Transactions**
```
📥 Importing Transactions
▸ 1,245 transactions imported so far...
```

**Phase 2: Anomaly Detection**
```
🔍 Detecting Anomalies
▸ 15 of 50 batches analyzed
[██████████░░░░░░░░░░] 30%
```

**Phase 3: Complete**
```
✓ Import Complete!

📊 Import Summary
┌─────────────────────────┐
│ 4,987 Transactions Imported │
│ 13 Rows Skipped         │
│ Anomaly Detection: ✓    │
└─────────────────────────┘

⚠️ Skipped Rows
#1 Missing date → description: "Bad row", amount: 50.00
#2 Missing amount → date: "2024-01-15", description: "Another bad row"
```

## What Gets Auto-Detected

The system automatically analyzes every transaction:

### ✅ Anomaly Detection (4 Types)

1. **Unusual Amounts**: Statistical analysis
   - **Critical**: >500% deviation
   - **High**: >300% deviation
   - **Medium**: >200% deviation

2. **Potential Duplicates**: Hash-based matching
   - Same date + amount + normalized description
   - SHA-256 for fast comparison

3. **Missing Metadata**: Field validation
   - Blank description (allowed but flagged)
   - Missing category

4. **Suspicious Patterns**: Pattern matching
   - Round numbers (≥$500, multiple of $100)
   - Rapid transactions (3+ within 1 day)

### ✅ Auto-Categorization

Rules apply automatically based on priority:
- Higher priority = applied first
- Only first matching rule applies
- Happens during import/creation

### ✅ Description Normalization

All descriptions normalized for duplicate detection:
- Lowercase conversion
- Extra whitespace removal
- SHA-256 hashing for fast comparison

## Sample Rules to Create

### E-Commerce Detection
```
Type: Description Contains
Pattern: amazon|ebay|etsy
Category: Shopping
Priority: 10
```

### Subscription Services
```
Type: Description Contains
Pattern: subscription|netflix|spotify|monthly
Category: Entertainment
Priority: 15
```

### Large Purchases
```
Type: Amount Threshold
Operator: >
Threshold: 500
Category: High Value
Priority: 100
```

### Small Transactions
```
Type: Amount Threshold
Operator: <=
Threshold: 5
Category: Small Purchase
Priority: 1
```

## Testing & Development

### Run Tests
```bash
# All tests (158 tests, 394 assertions)
bin/rails test

# By type
bin/rails test test/controllers/
bin/rails test test/models/
bin/rails test test/jobs/
bin/rails test test/services/

# Watch for changes
bin/rails test --verbose
```

### Test CSV Import Edge Cases

Create a CSV with intentional errors:
```csv
date,description,amount,category
2024-01-15,Good Transaction,100.00,Shopping
,Missing Date,50.00,Food
2024-01-16,Missing Amount,,Entertainment
2024-01-17,Duplicate,25.00,Shopping
2024-01-17,Duplicate,25.00,Shopping
2024-01-18,$1,000.00 with symbol,1000,Shopping
```

Watch how the system handles:
- Missing required fields
- Duplicate detection
- Currency symbol removal
- Detailed error reporting

## Performance Features

Built for **1M+ transactions**:

### Speed Optimizations
- **Instant redirect**: Import never blocks (< 50ms)
- **Real-time updates**: WebSocket-based (no polling)
- **Parallel processing**: Anomaly detection in batches
- **Database indexes**: 7 strategic indexes
- **Bulk operations**: Single query for 100+ updates
- **Smart caching**: 5-minute dashboard stats cache

### Query Performance
- **Anomaly detection**: 10-50x faster per batch
- **Rule application**: Cached rules, eager loading
- **Dashboard**: All stats pre-calculated and cached
- **Filtering**: Index-optimized queries

## Advanced Features

### Bulk Selection
- Select individual transactions
- "Select All" for current page
- Selection count indicator
- Applies to filtered results

### Advanced Filtering
Combine multiple filters:
- Category + Flagged + Date Range
- Status + Uncategorized
- Severity + Category

### Export
- Export filtered transactions to CSV
- Same format as import
- Includes all transaction data

## Troubleshooting

### No transactions showing?
- Import the sample CSV: `/public/sample_transactions.csv`
- Or create a few manually
- Check filters aren't too restrictive

### Rules not applying?
- Verify rules are **Active**
- Check priority (higher applies first)
- Only first matching rule applies
- Use "Apply All Rules" to reprocess

### Anomalies not appearing?
- Need at least 3-5 transactions for statistical analysis
- Unusual amounts based on your average spending
- Background jobs may take a few seconds

### Import status not updating?
- Ensure `bin/dev` is running (not just `rails server`)
- Check browser console for WebSocket connection
- Hard refresh the page (Cmd+Shift+R or Ctrl+Shift+R)

### Background jobs not running?
```bash
# Make sure worker is running
bin/dev  # Starts both web + worker

# Or manually start worker
bin/jobs start
```

## What's Next?

1. **Import your data**: Prepare your CSV and import
2. **Create custom rules**: Match your spending patterns
3. **Review anomalies**: Check flagged transactions
4. **Set up workflow**: Configure rules for auto-categorization
5. **Monitor dashboard**: Track statistics and trends

## Architecture Overview

### Multi-Process Setup
```
bin/dev
├── Web Server (Rails)      → Handles HTTP requests
└── Background Worker       → Processes jobs (import, anomaly detection)
```

### Real-Time Flow
```
User uploads CSV
↓
Instant redirect to status page
↓
Background job starts
├── Import Phase: Broadcasts progress
└── Anomaly Phase: Broadcasts batch completion
↓
WebSocket → Browser → UI updates instantly
```

### Technology Stack
- **Rails 8.0** + **Ruby 3.4.2**
- **Solid Queue**: Background jobs (database-backed)
- **Solid Cable**: WebSockets (database-backed)
- **Hotwire Turbo**: Real-time updates
- **SQLite**: Development/test
- **PostgreSQL**: Production-ready

## Support

- **Full Documentation**: [README.md](README.md)
- **Feature Details**: [FEATURES.md](FEATURES.md)
- **Sample Data**: `/public/sample_transactions.csv`
- **Tests**: Examples in `test/` directory

---

**Ready to start?** Run `bin/dev` and visit http://localhost:3000 🚀
