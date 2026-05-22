# Bookkeeping System — Development Spec for AI Copilot

## Project Summary
Build a scalable bookkeeping system with automated categorization, anomaly detection, and a transaction review dashboard. This is a take-home engineering project for Soraban.

---

## Business Logic Decisions

These are explicit, deliberate tradeoffs made before writing a single line of code. Each one answers an ambiguity that an AI-generated implementation would silently get wrong. Document these in your PR and reference them in your Loom — they are the primary signal that separates thoughtful engineering from scaffolded CRUD.

---

### Decision 1: Rules Engine — First-Match-Wins with Optional Continue Flag

**The problem:** When multiple rules match the same transaction, what happens? If Rule 1 sets category to "Shopping" and Rule 2 sets it to "Travel", which wins? Last writer wins is unpredictable and order-dependent in a non-obvious way.

**The decision:** Implement **first-match-wins**. When a rule matches and fires its action, processing stops for that action type — no subsequent rule can overwrite it. Rules are evaluated in ascending priority order (1 runs before 2).

To handle legitimate cases where multiple rules should apply, each rule has an optional `continue_processing` boolean (default `false`). Setting it to `true` means "apply this action, then keep evaluating." This mirrors how production rules engines like Drools and Braintree's fraud engine work.

**Example:**
- Rule 1 (priority 1, continue: true): description contains "Amazon" → set category "Shopping"
- Rule 2 (priority 2, continue: false): amount > 1000 → flag high value

A $1,500 Amazon charge hits Rule 1 (categorized as Shopping, continues), then hits Rule 2 (flagged as high value, stops). Both actions apply. A $20 Amazon charge hits Rule 1, continues, misses Rule 2's amount threshold — only categorized.

**Schema addition:**
```sql
ALTER TABLE rules ADD COLUMN continue_processing BOOLEAN DEFAULT false;
```

**Implementation note in `RulesEngine`:**
```ruby
def self.apply(transaction, rules: nil)
  rules ||= Rule.active_for(transaction.user_id)
  applied_action_types = Set.new

  rules.each do |rule|
    next unless matches?(rule.condition, transaction)
    action_type = rule.action['type']

    # First-match-wins: skip if this action type already fired
    next if applied_action_types.include?(action_type) && !rule.continue_processing

    fire_action(rule.action, transaction)
    applied_action_types.add(action_type)
    break unless rule.continue_processing
  end

  transaction.save! if transaction.changed?
end
```

**Why this matters:** Without this decision, two category rules on the same transaction produce non-deterministic results depending on DB query order. That's a silent bug that only surfaces in production with real data.

---

### Decision 2: Anomaly Severity Scoring — Additive Weighted Score

**The problem:** The schema has a `severity` column but "flagged" is binary in the current plan. A transaction missing a description is not equally urgent as one that is also a suspected duplicate AND statistically unusual at 10x the normal amount. Treating them the same drowns the review queue in noise.

**The decision:** Compute a numeric severity score at detection time and derive a low/medium/high label from it. The score is additive — each anomaly type contributes a base weight, with a multiplier for magnitude.

**Scoring table:**

| Anomaly Type | Base Score | Multiplier |
|---|---|---|
| `missing_metadata` | 10 | — (flat) |
| `potential_duplicate` | 25 | — (flat) |
| `unusual_amount` | 20 | +5 per std dev above threshold |

**Severity thresholds:**
- 0–20 → `low`
- 21–49 → `medium`
- 50+ → `high`

**Example:** A transaction that is a suspected duplicate (25) AND has an amount 6 standard deviations above the mean (20 + 5×3 = 35) scores 60 → `high`. A transaction that is just missing a description scores 10 → `low`.

**Implementation note in `AnomalyDetector`:**
```ruby
def compute_severity(flags:, std_devs_above_mean: 0)
  score = 0
  score += 10 if flags.include?('missing_metadata')
  score += 25 if flags.include?('potential_duplicate')
  if flags.include?('unusual_amount')
    score += 20 + ([std_devs_above_mean - 3, 0].max * 5).to_i
  end

  case score
  when 0..20   then 'low'
  when 21..49  then 'medium'
  else              'high'
  end
end
```

**UI implication:** The review dashboard sorts by severity descending — `high` anomalies surface first. The anomaly badge color maps directly: red = high, amber = medium, gray = low.

**Why this matters:** A flat "flagged" list with 200 items gets ignored. A ranked queue where the top 10 are genuinely the most suspicious gets acted on. This is the difference between a feature that gets used and one that gets turned off.

---

### Decision 3: Duplicate Detection — Fuzzy Description Normalization

**The problem:** Real bank transaction data is dirty. "AMAZON MKTP US\*2F4KL9" and "AMAZON MKTP US\*8B2MQ1" are the same merchant charged twice but will never match on exact string comparison. Exact matching produces false negatives on real data while being too aggressive on legitimate similar transactions.

**The decision:** Normalize descriptions before comparison using a deterministic pipeline, then exact-match on the normalized form. Do not use edit-distance / fuzzy string matching — it introduces a tunable threshold that requires empirical calibration on real user data we don't have.

**Normalization pipeline** (applied to both stored and incoming descriptions):
1. Downcase
2. Strip trailing reference codes: remove trailing `\*[A-Z0-9]{4,}` and `#[0-9]+`
3. Collapse whitespace
4. Strip leading/trailing whitespace

**Example:**
- `"AMAZON MKTP US*2F4KL9"` → `"amazon mktp us"`
- `"AMAZON MKTP US*8B2MQ1"` → `"amazon mktp us"` ✓ match
- `"Starbucks #1204"` → `"starbucks"` 
- `"Starbucks #9881"` → `"starbucks"` ✓ match
- `"Netflix"` → `"netflix"`
- `"Spotify"` → `"spotify"` ✗ no match (correct)

**Schema addition:** Store the normalized form to avoid recomputing on every duplicate check:
```sql
ALTER TABLE transactions ADD COLUMN description_normalized TEXT;
CREATE INDEX idx_transactions_duplicate_check
  ON transactions(user_id, date, amount, description_normalized);
```

**Duplicate window:** Same `user_id`, same `date`, same `amount`, same `description_normalized`, and `created_at` within 48 hours (extended from 24 — bank imports often arrive a day late).

**Implementation:**
```ruby
def self.normalize_description(desc)
  return nil if desc.blank?
  desc
    .downcase
    .gsub(/\*[a-z0-9]{4,}/i, '')   # strip reference codes like *2F4KL9
    .gsub(/#\d+/, '')               # strip location codes like #1204
    .gsub(/\s+/, ' ')
    .strip
end
```

**Why this matters:** Without normalization, duplicate detection fails silently on the exact data format banks actually export. A reviewer who uploads a real bank CSV and sees no duplicates detected will mark this feature as broken.

---

### Decision 4: Transaction Status — Explicit State Machine with Enforced Transitions

**The problem:** `status: pending | reviewed | flagged` as a plain string column allows any transition in any direction — a reviewed transaction can be silently re-set to pending by any update. There are no guards, no audit trail, and no definition of what each transition means.

**The decision:** Implement status as an explicit state machine using the `aasm` gem. Define valid transitions and callbacks at the model level.

**Valid transitions:**

```
pending ──► flagged    (when anomaly detected)
pending ──► reviewed   (user approves)
flagged ──► reviewed   (user approves despite flag)
flagged ──► pending    (user dismisses flag — anomaly resolved)
reviewed ──► flagged   (re-flag: user or system finds new issue)
```

`reviewed → pending` is intentionally **not allowed** — once reviewed, a transaction doesn't silently revert. To re-open it, it must be explicitly re-flagged.

**Implementation:**
```ruby
# app/models/transaction.rb
include AASM

aasm column: :status do
  state :pending, initial: true
  state :flagged
  state :reviewed

  event :flag do
    transitions from: [:pending, :reviewed], to: :flagged
  end

  event :approve do
    transitions from: [:pending, :flagged], to: :reviewed
  end

  event :dismiss_flag do
    transitions from: :flagged, to: :pending,
      after: -> { anomalies.unresolved.update_all(resolved: true, resolved_at: Time.current) }
  end

  event :reflag do
    transitions from: :reviewed, to: :flagged
  end
end
```

**Cascade on delete:** When a transaction is deleted, its anomaly records are also deleted (`dependent: :destroy`). Anomaly records are never orphaned.

**Why this matters:** Without a state machine, the frontend can PUT any status value directly and the backend accepts it. A reviewer testing the API will find they can set `status: "banana"` or jump from reviewed back to pending with no record of the change. That signals the engineer didn't think about the domain.

---

### Decision 5: Rules Health — Staleness and Breadth Warnings

**The problem:** Rules accumulate over time. A rule that matched 10,000 transactions is either very useful or dangerously over-broad. A rule that hasn't matched anything in 60 days is probably wrong or obsolete. Neither condition is visible in the current plan, so the rules list becomes a graveyard that nobody maintains.

**The decision:** Track match metrics on the rules table and surface two types of warnings in the UI.

**Schema additions:**
```sql
ALTER TABLE rules ADD COLUMN match_count      INTEGER DEFAULT 0;
ALTER TABLE rules ADD COLUMN last_matched_at  TIMESTAMP;
ALTER TABLE rules ADD COLUMN match_rate       NUMERIC(5,4);  -- matches / total transactions evaluated
```

**Staleness warning:** Surface in the UI when `active = true AND last_matched_at < 60 days ago AND created_at < 60 days ago`. Label: "No matches in 60 days — consider disabling."

**Breadth warning:** Surface when `match_rate > 0.50` (rule matches more than 50% of all transactions). Label: "Matches over 50% of transactions — condition may be too broad."

**Update in `RulesEngine`:**
```ruby
def self.fire_action(rule, transaction)
  # ... apply the action ...
  rule.increment!(:match_count)
  rule.update_columns(last_matched_at: Time.current)
end
```

`match_rate` is recomputed nightly via a lightweight background job, not inline:
```ruby
# app/jobs/rule_health_job.rb
class RuleHealthJob < ApplicationJob
  def perform(user_id)
    total = Transaction.where(user_id: user_id).count
    return if total.zero?
    Rule.where(user_id: user_id).find_each do |rule|
      rule.update_columns(match_rate: rule.match_count.to_f / total)
    end
  end
end
```

**Why this matters:** Rules health is an operational concern that appears in every serious rules-based system (email filters, fraud detection, content moderation) but almost never in take-home projects. Including it signals you've thought about the system's lifecycle, not just its initial state.

---

| Layer | Technology | Notes |
|---|---|---|
| Backend | Ruby on Rails 7 (API mode) | |
| Frontend | TypeScript + React (Vite) | |
| Database | PostgreSQL | |
| Background Jobs | Sidekiq + Redis | |
| Real-time | ActionCable (WebSockets) | Built into Rails, no extra infra |
| Staging Deploy | Render.com | |
| Auth | Devise + JWT (or Devise + session cookies) | |
| CSV Parsing | `smarter_csv` | Chunked processing, handles malformed rows; do NOT use Ruby stdlib `CSV` |
| State Machine | `statesman` | Persists every transition to DB automatically — full audit trail |
| Full-text Search | `pg_search` | Clean DSL over PostgreSQL GIN; handles trigram similarity for fuzzy matching |
| Frontend Data Fetching | `@tanstack/react-query` | Caching, cursor pagination, loading/error states; replaces raw axios |
| Frontend Forms | `react-hook-form` | Uncontrolled inputs, `useFieldArray` for dynamic rule conditions |
| Frontend Virtualization | `@tanstack/react-virtual` | Same ecosystem as react-query; never render all rows in DOM |
| Backend Testing | RSpec + FactoryBot + Shoulda Matchers | |
| Frontend Testing | Vitest + React Testing Library | Vite-native, tests behavior not implementation |
| Performance Testing | Custom seed script + EXPLAIN ANALYZE | |

**Machine**: MacBook Pro (M-series or Intel). Docker is optional but recommended for local Postgres + Redis.

---

## Repository Structure

```
soraban-bookkeeping/
├── backend/               # Rails API app
│   ├── app/
│   │   ├── controllers/api/v1/
│   │   │   ├── transactions_controller.rb
│   │   │   ├── rules_controller.rb
│   │   │   ├── anomalies_controller.rb
│   │   │   └── imports_controller.rb
│   │   ├── models/
│   │   │   ├── transaction.rb
│   │   │   ├── rule.rb
│   │   │   ├── anomaly.rb
│   │   │   └── user.rb
│   │   ├── services/
│   │   │   ├── rules_engine.rb         # applies rules to transactions
│   │   │   ├── anomaly_detector.rb     # detects anomalies
│   │   │   ├── anthropic_client.rb     # Anthropic API wrapper
│   │   │   └── csv_importer.rb         # parses + validates CSV
│   │   ├── jobs/
│   │   │   ├── csv_import_job.rb
│   │   │   ├── anomaly_scan_job.rb
│   │   │   └── anomaly_explanation_job.rb  # calls Anthropic API async
│   │   └── channels/
│   │       └── import_status_channel.rb
│   ├── db/
│   │   ├── migrate/
│   │   └── seeds.rb                    # seed 10k+ transactions for demo
│   └── config/
│       └── routes.rb
├── frontend/              # React + TypeScript app (Vite)
│   ├── src/
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx
│   │   │   ├── Transactions.tsx
│   │   │   ├── Rules.tsx
│   │   │   └── Import.tsx
│   │   ├── components/
│   │   │   ├── TransactionTable.tsx    # virtualized for 1M rows
│   │   │   ├── BulkActionBar.tsx
│   │   │   ├── AnomalyBadge.tsx
│   │   │   ├── RuleBuilder.tsx
│   │   │   └── CSVDropzone.tsx
│   │   ├── hooks/
│   │   │   ├── useTransactions.ts      # @tanstack/react-query infinite query (keyset cursor)
│   │   │   └── useWebSocket.ts         # ActionCable subscription for import progress
│   │   └── api/
│   │       └── client.ts               # axios base instance (used by react-query fetchers)
│   └── vite.config.ts
├── docker-compose.yml     # local Postgres + Redis
├── render.yaml            # Render.com deploy config
├── README.md
```

**Backend test structure** (inside `backend/`):
```
spec/
├── rails_helper.rb
├── spec_helper.rb
├── factories/
│   ├── users.rb
│   ├── transactions.rb
│   ├── rules.rb
│   └── anomalies.rb
├── services/
│   ├── rules_engine_spec.rb        # highest priority
│   ├── anomaly_detector_spec.rb    # highest priority
│   └── anthropic_client_spec.rb    # mock API responses
├── models/
│   ├── transaction_spec.rb
│   └── rule_spec.rb
├── requests/
│   ├── transactions_spec.rb
│   ├── bulk_actions_spec.rb
│   └── imports_spec.rb
└── jobs/
    ├── csv_import_job_spec.rb
    ├── anomaly_scan_job_spec.rb
    └── anomaly_explanation_job_spec.rb
```

**Frontend test structure** (inside `frontend/`):
```
src/
└── __tests__/
    ├── components/
    │   ├── RuleBuilder.test.tsx     # highest priority
    │   ├── BulkActionBar.test.tsx   # highest priority
    │   └── CSVDropzone.test.tsx
    └── hooks/
        └── useTransactions.test.ts
```

---

## Database Schema

### transactions
```sql
CREATE TABLE transactions (
  id                     BIGSERIAL PRIMARY KEY,
  user_id                BIGINT NOT NULL REFERENCES users(id),
  date                   DATE NOT NULL,
  description            TEXT,
  description_normalized TEXT,           -- normalized form for duplicate detection
  amount                 NUMERIC(15,2) NOT NULL,
  category               VARCHAR(100),
  status                 VARCHAR(50) DEFAULT 'pending',  -- pending | reviewed | flagged
  source                 VARCHAR(20) DEFAULT 'manual',   -- manual | csv
  anomaly_flags          JSONB DEFAULT '[]',
  metadata               JSONB DEFAULT '{}',
  created_at             TIMESTAMP NOT NULL,
  updated_at             TIMESTAMP NOT NULL
);

-- Performance indexes for 1M+ rows
CREATE INDEX idx_transactions_user_date ON transactions(user_id, date DESC);
CREATE INDEX idx_transactions_status ON transactions(user_id, status) WHERE status != 'reviewed';
CREATE INDEX idx_transactions_category ON transactions(user_id, category);
CREATE INDEX idx_transactions_description_gin ON transactions USING gin(to_tsvector('english', coalesce(description, '')));
CREATE INDEX idx_transactions_amount ON transactions(user_id, amount);
-- Duplicate detection index on normalized description
CREATE INDEX idx_transactions_duplicate_check ON transactions(user_id, date, amount, description_normalized);
```

### rules
```sql
CREATE TABLE rules (
  id                  BIGSERIAL PRIMARY KEY,
  user_id             BIGINT NOT NULL REFERENCES users(id),
  name                VARCHAR(200) NOT NULL,
  condition           JSONB NOT NULL,   -- { "field": "description", "operator": "contains", "value": "Amazon" }
  action              JSONB NOT NULL,   -- { "type": "set_category", "value": "Shopping" }
  priority            INT DEFAULT 0,
  active              BOOLEAN DEFAULT true,
  continue_processing BOOLEAN DEFAULT false,  -- first-match-wins unless true
  match_count         INTEGER DEFAULT 0,
  last_matched_at     TIMESTAMP,
  match_rate          NUMERIC(5,4),     -- matches / total transactions evaluated (nightly)
  created_at          TIMESTAMP NOT NULL,
  updated_at          TIMESTAMP NOT NULL
);
```

### anomalies
```sql
CREATE TABLE anomalies (
  id                       BIGSERIAL PRIMARY KEY,
  transaction_id           BIGINT NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
  anomaly_type             VARCHAR(100) NOT NULL,  -- 'unusual_amount' | 'potential_duplicate' | 'missing_metadata'
  severity                 VARCHAR(20) DEFAULT 'medium',
  details                  JSONB DEFAULT '{}',
  explanation              TEXT,                   -- AI-generated plain English explanation
  explanation_generated_at TIMESTAMP,
  resolved                 BOOLEAN DEFAULT false,
  resolved_at              TIMESTAMP,
  created_at               TIMESTAMP NOT NULL
);
```

---

## Feature Specs

### Feature 1: Record & Import Transactions

**Manual add** (POST /api/v1/transactions)
- Fields: date (required), description (optional), amount (required), category (optional)
- On create: run RulesEngine.apply(transaction), run AnomalyDetector.check(transaction)
- Return: transaction JSON with any applied category + anomaly flags

**CSV import** (POST /api/v1/imports)
- Accept multipart upload of CSV file
- Enqueue CsvImportJob (async via Sidekiq)
- Stream progress back via ActionCable (ImportStatusChannel)
- Parse using `smarter_csv` in chunks of 1,000 rows — do NOT use Ruby stdlib `CSV` (single-threaded, slow above 50k rows)
- CSV columns expected: date, description, amount, category (all optional except amount+date)
- Edge cases to handle:
  - Missing description → flag as `missing_metadata` anomaly
  - Malformed date → skip row, log error, continue
  - Duplicate detection (same date+amount+normalized description) → flag as potential duplicate
  - Amount not parseable → skip row
  - Over 100k rows → process in batches of 1,000 via `smarter_csv` chunk_size option + `insert_all`

### Feature 2: Rules Engine

**Rule structure (condition operators)**:
- `description_contains` → case-insensitive string match on normalized description
- `description_matches` → regex match (invalid regex → skip rule gracefully, log warning)
- `amount_gt`, `amount_lt`, `amount_eq` → numeric comparison
- `category_is` → string match on current category

**Rule actions**:
- `set_category` → assign category string
- `flag_high_value` → add flag to anomaly_flags
- `add_tag` → append tag to metadata

**Conflict resolution:** First-match-wins per action type, with optional `continue_processing` flag. See Business Logic Decision 1.

**Rule health tracking:** `match_count`, `last_matched_at`, `match_rate` updated on every match. Stale and over-broad rules surfaced as warnings in the UI. See Business Logic Decision 5.

**RulesEngine service** (`app/services/rules_engine.rb`):
```ruby
class RulesEngine
  def self.apply(transaction, rules: nil)
    rules ||= Rule.where(user_id: transaction.user_id, active: true).order(:priority)
    applied_action_types = Set.new

    rules.each do |rule|
      next unless matches?(rule.condition, transaction)
      action_type = rule.action['type']

      next if applied_action_types.include?(action_type) && !rule.continue_processing

      fire_action(rule.action, transaction)
      applied_action_types.add(action_type)
      break unless rule.continue_processing
    end

    transaction.save! if transaction.changed?
  end
end
```

**Full-text search on descriptions:** Use `pg_search` DSL — do NOT write raw `to_tsvector` / `plainto_tsquery` SQL in controllers:
```ruby
# app/models/transaction.rb
include PgSearch::Model
pg_search_scope :search_description,
  against: :description,
  using: {
    tsearch:  { prefix: true },
    trigram:  { threshold: 0.3 }   # also powers fuzzy duplicate normalization
  }
```

**Status transitions:** Use `statesman` — do NOT assign `status` as a raw string. Every transition is persisted to `transaction_transitions` table automatically, giving a full audit trail:
```ruby
# app/models/transaction_transition.rb (generated by statesman)
class TransactionTransition < ApplicationRecord
  include Statesman::Adapters::ActiveRecordTransition
  belongs_to :transaction, inverse_of: :transitions
end
```

**Bulk action**: PUT /api/v1/transactions/bulk
- Body: `{ ids: [...], action: "set_category", value: "Travel" }`
- Processes in batches, returns count of updated records

### Feature 3: Anomaly Detection

**AnomalyDetector service** (`app/services/anomaly_detector.rb`):

Check 1 — Unusual amount:
- Compute mean + std dev of amounts for user (last 90 days)
- Minimum baseline: 10 transactions required — skip check if insufficient history
- Flag if `amount > mean + (3 * std_dev)` as `unusual_amount`
- Record `std_devs_above_mean` in anomaly `details` JSONB for severity scoring

Check 2 — Duplicate:
- Normalize both descriptions before comparison (strip reference codes, downcase). See Business Logic Decision 3.
- Match on: same `user_id`, same `date`, same `amount`, same `description_normalized`, `created_at` within 48h window
- Flag as `potential_duplicate`

Check 3 — Missing metadata:
- If `description` is blank/nil → flag as `missing_metadata`

**Severity scoring:** Each anomaly gets a computed severity (`low` / `medium` / `high`) based on the additive weighted scoring model. See Business Logic Decision 2.

**Status transitions:** Anomaly detection calls `transaction.flag!` (AASM event), not a raw status string assignment. See Business Logic Decision 4.

Store each anomaly in the `anomalies` table and add flag to `transaction.anomaly_flags` JSONB.

**Performance**: AnomalyDetector for bulk CSV runs async in `AnomalyScanJob`, not inline.

### Feature 3b: AI Anomaly Explanation (Anthropic API)

**What it does:** After an anomaly is created, a background job calls the Anthropic API with the transaction details and statistical context. The model returns a one-to-two sentence plain-English explanation of *why* the transaction is suspicious and what the reviewer should look for. The explanation is stored on the anomaly record and displayed beneath the flag badge in the review dashboard.

**Why it's async and stored:** The LLM call is enqueued after anomaly creation — it never blocks the request cycle. The explanation is generated once and persisted on the anomaly record. Dashboard loads are instant because they read from the DB, not the API.

**Graceful degradation:** If the Anthropic API is down or returns an error, the anomaly record is created normally with `explanation: nil`. The dashboard renders the flag badge without explanation text. No retries that could flood the queue — one attempt, store result or nil.

**Schema addition:**
```sql
ALTER TABLE anomalies ADD COLUMN explanation TEXT;         -- AI-generated plain English explanation
ALTER TABLE anomalies ADD COLUMN explanation_generated_at TIMESTAMP;
```

**New job** (`app/jobs/anomaly_explanation_job.rb`):
```ruby
class AnomalyExplanationJob < ApplicationJob
  queue_as :ai

  def perform(anomaly_id)
    anomaly = Anomaly.includes(:transaction).find_by(id: anomaly_id)
    return unless anomaly && anomaly.explanation.nil?

    tx = anomaly.transaction
    context = build_context(anomaly, tx)
    explanation = AnthropicClient.explain_anomaly(context)

    anomaly.update_columns(
      explanation: explanation,
      explanation_generated_at: Time.current
    )
  end

  private

  def build_context(anomaly, tx)
    {
      anomaly_type:        anomaly.anomaly_type,
      severity:            anomaly.severity,
      transaction_date:    tx.date,
      transaction_amount:  tx.amount,
      transaction_desc:    tx.description.presence || '(no description)',
      details:             anomaly.details   # contains std_devs_above_mean etc.
    }
  end
end
```

**Trigger in AnomalyDetector** — add after every `Anomaly.create!` call:
```ruby
anomaly = Anomaly.create!(
  transaction: transaction,
  anomaly_type: type,
  severity: severity,
  details: details
)
AnomalyExplanationJob.perform_later(anomaly.id)
```

**Anthropic API client** (`app/services/anthropic_client.rb`):
```ruby
class AnthropicClient
  API_URL = 'https://api.anthropic.com/v1/messages'.freeze
  MODEL   = 'claude-sonnet-4-5'.freeze

  def self.explain_anomaly(context)
    prompt = build_prompt(context)
    response = HTTP.headers(
      'x-api-key':         Rails.application.credentials.anthropic_api_key,
      'anthropic-version': '2023-06-01',
      'content-type':      'application/json'
    ).post(API_URL, json: {
      model:      MODEL,
      max_tokens: 150,
      messages:   [{ role: 'user', content: prompt }]
    })

    body = JSON.parse(response.body)
    body.dig('content', 0, 'text')&.strip
  rescue => e
    Rails.logger.error("AnthropicClient error: #{e.message}")
    nil  # graceful degradation — caller stores nil
  end

  def self.build_prompt(ctx)
    <<~PROMPT
      You are a bookkeeping assistant. A transaction has been flagged as suspicious.
      Write 1-2 sentences in plain English explaining why this transaction looks unusual
      and what a bookkeeper should verify. Be specific, not generic.

      Transaction details:
      - Date: #{ctx[:transaction_date]}
      - Description: #{ctx[:transaction_desc]}
      - Amount: $#{ctx[:transaction_amount]}
      - Flag type: #{ctx[:anomaly_type]}
      - Severity: #{ctx[:severity]}
      - Statistical context: #{ctx[:details].to_json}

      Respond with the explanation only. No preamble, no bullet points.
    PROMPT
  end
end
```

**Gemfile addition:**
```ruby
gem 'http'   # lightweight HTTP client — cleaner than Net::HTTP for this use case
```

**Environment variable** — add to Render env vars and local credentials:
```
ANTHROPIC_API_KEY=sk-ant-...
```
In Rails: `Rails.application.credentials.anthropic_api_key`

**Sidekiq queue config** — add a dedicated `:ai` queue with lower priority so AI jobs never starve CSV import jobs:
```yaml
# config/sidekiq.yml
:queues:
  - [critical, 3]
  - [default, 2]
  - [ai, 1]
```

**Dashboard display** — in the "Flagged Anomalies" table, render the explanation beneath the badge:
```tsx
// In AnomalyRow component
<td>
  <span className={`badge badge-${severityColor(anomaly.severity)}`}>
    {anomaly.anomaly_type}
  </span>
  {anomaly.explanation && (
    <p className="anomaly-explanation">{anomaly.explanation}</p>
  )}
  {!anomaly.explanation && (
    <p className="anomaly-explanation generating">Generating explanation…</p>
  )}
</td>
```

**Example output in dashboard:**
> "This $8,500 charge is 469 standard deviations above your typical transaction amount of ~$52. Combined with a missing description, this transaction has no identifying information and should be verified against your bank statement before approving."

### Feature 4: Scalability

- Use `Transaction.insert_all` for bulk imports (bypasses ActiveRecord callbacks — call rules/anomaly scan separately in job)
- Pagination: Keyset pagination (cursor-based) not offset — e.g. `WHERE id < :cursor ORDER BY id DESC LIMIT 50`
- DB indexes: see Schema above (critical: the partial index on status ≠ 'reviewed' keeps the review queue fast)
- Background processing: all CSV imports and anomaly scans via Sidekiq
- Table partitioning (optional stretch): partition transactions by created_at year for 1M+ rows
- Caching: cache user rule set in Redis (invalidate on rule create/update/delete)
- Frontend: virtualized table via `@tanstack/react-virtual` — never render all rows in DOM

### Feature 5: Review Dashboard

**Endpoint**: GET /api/v1/dashboard
Returns:
```json
{
  "uncategorized_count": 143,
  "flagged_anomalies_count": 27,
  "recent_anomalies": [...],    // last 10, with transaction data
  "uncategorized_sample": [...] // first 10 uncategorized
}
```

**Review actions**:
- PATCH /api/v1/transactions/:id — edit + approve (sets status: 'reviewed')
- DELETE /api/v1/transactions/:id — delete transaction
- PATCH /api/v1/anomalies/:id/resolve — mark anomaly resolved

---

## API Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :transactions, only: [:index, :create, :update, :destroy] do
        collection do
          put :bulk
        end
      end
      resources :rules
      resources :anomalies, only: [:index, :update] do
        member do
          patch :resolve
        end
      end
      resources :imports, only: [:create]
      get 'dashboard', to: 'dashboard#index'
    end
  end

  mount ActionCable.server => '/cable'
end
```

---

## Staging Deployment (Render.com)

### render.yaml
```yaml
services:
  - type: web
    name: bookkeeping-api
    env: ruby
    buildCommand: bundle install && bundle exec rails db:migrate
    startCommand: bundle exec puma -C config/puma.rb
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: bookkeeping-db
          property: connectionString
      - key: REDIS_URL
        fromService:
          name: bookkeeping-redis
          type: redis
          property: connectionString
      - key: RAILS_MASTER_KEY
        sync: false
      - key: ANTHROPIC_API_KEY
        sync: false   # set manually in Render dashboard

  - type: worker
    name: bookkeeping-sidekiq
    env: ruby
    buildCommand: bundle install
    startCommand: bundle exec sidekiq
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: bookkeeping-db
          property: connectionString
      - key: REDIS_URL
        fromService:
          name: bookkeeping-redis
          type: redis
          property: connectionString

  - type: web
    name: bookkeeping-frontend
    env: static
    buildCommand: npm install && npm run build
    staticPublishPath: ./dist
    envVars:
      - key: VITE_API_URL
        value: https://bookkeeping-api.onrender.com

databases:
  - name: bookkeeping-db
    databaseName: bookkeeping
    user: bookkeeping

  - name: bookkeeping-redis
    type: redis
```

### Seed data for reviewers
In `db/seeds.rb`, generate 10,000+ transactions with:
- Mix of categorized and uncategorized
- Several duplicates
- Several high-value anomalies
- Several missing descriptions
- Spread across 12 months

---

## Mock UI Screens (feed to copilot instead of screenshots)

### Screen 1: Transaction List
- Top bar: "Transactions" title, "Add Transaction" button, "Import CSV" button
- Filter row: date range picker, category dropdown, status filter (All / Flagged / Uncategorized / Reviewed), search box
- Table columns: checkbox, Date, Description, Amount, Category (badge or dropdown), Status (pill), Actions (edit/delete)
- Flagged rows: amber left border + anomaly badge (e.g. "Duplicate", "High Value")
- Bulk action bar appears at bottom when rows checked: "Categorize as..." dropdown + "Apply" button, row count shown
- Pagination: "Load more" button (keyset cursor), shows total count

### Screen 2: Review Dashboard
- Summary cards row: "Uncategorized (143)", "Flagged Anomalies (27)", "Reviewed Today (12)", "Total Transactions (10,482)"
- Section: "Needs Attention" — table of flagged transactions with anomaly type badge, Approve / Edit / Delete per row
- Section: "Uncategorized" — table of uncategorized transactions with inline category dropdown + "Approve" button
- Spending chart (bonus): bar chart by category for current month

### Screen 3: Rules Builder
- List of active rules with name, condition summary, action, on/off toggle, edit/delete
- "New Rule" button opens slide-over panel:
  - Name field
  - Condition: field selector (Description / Amount / Category) → operator dropdown → value input
  - Action: type selector (Set Category / Flag / Add Tag) → value input
  - Priority (drag handle or number)
  - "Save Rule" button

### Screen 4: CSV Import
- Drag-and-drop zone ("Drop CSV here or click to browse")
- On file select: show preview table of first 5 rows with column mapping UI
- "Import" button triggers upload
- Progress bar with real-time status via WebSocket ("Processing row 1,234 of 50,000...")
- Summary after complete: "Imported 49,891 | Skipped 109 (errors) | 23 flagged"
- Download error report link

---

## Development Phases

### Phase 1 (Days 1–2): Core Rails API + DB
- [ ] `rails new backend --api --database=postgresql`
- [ ] Add RSpec, FactoryBot, Shoulda Matchers to Gemfile — configure from day 1
- [ ] Create migrations for transactions, rules, anomalies (include `explanation` + `explanation_generated_at`), users
- [ ] Write factories for all four models
- [ ] Implement Transaction CRUD
- [ ] Basic CSV import (synchronous first, async later)
- [ ] Seed script with 10k transactions

### Phase 2 (Days 3–4): Business Logic + AI + Tests
- [ ] `RulesEngine` service — write spec first, then implement
- [ ] `AnomalyDetector` service — write spec first, then implement
- [ ] `CsvImporter` service — write edge case specs, then implement
- [ ] Bulk action endpoint + request spec
- [ ] Background jobs (Sidekiq) for CSV + anomaly scan + job specs
- [ ] ActionCable for import progress
- [ ] `AnthropicClient` service — implement with mocked spec (never call real API in tests)
- [ ] `AnomalyExplanationJob` — enqueue after every anomaly creation, spec with stubbed client
- [ ] Add `ANTHROPIC_API_KEY` to Rails credentials + verify one real call works locally

### Phase 3 (Days 5–6): Frontend + Component Tests
- [ ] Vite + React + TypeScript scaffold — add Vitest + RTL immediately
- [ ] `TransactionTable` with virtualization
- [ ] `BulkActionBar` + test
- [ ] `RuleBuilder` component + test
- [ ] Dashboard page — anomaly rows show explanation text beneath badge
- [ ] Handle `explanation: null` state with "Generating explanation…" placeholder
- [ ] CSV import with drag-drop + progress

### Phase 4 (Day 7 + buffer): Performance + Deploy
- [ ] Add DB indexes, verify with `EXPLAIN ANALYZE` on 100k rows
- [ ] Screenshot index scan results for PR / Loom
- [ ] Run full test suite — `bundle exec rspec` + `npm test` — both green
- [ ] Deploy to Render.com — set `ANTHROPIC_API_KEY` in Render environment dashboard
- [ ] Verify staging URL works end-to-end
- [ ] Verify AI explanations generating on staging (check Sidekiq dashboard)
- [ ] Record Loom walkthrough — show a flagged transaction with its AI explanation

---

## Testing Strategy

### Philosophy
Write tests alongside the code, not after. Services (`RulesEngine`, `AnomalyDetector`) are pure Ruby objects with clear inputs/outputs — design them to be testable from the start. Skip testing Rails boilerplate (basic CRUD controllers, model validations that just wrap DB constraints). Focus test effort on the business logic that reviewers are actually evaluating.

**Priority order**: RulesEngine → AnomalyDetector → Bulk actions → CSV edge cases → AnomalyExplanationJob → Frontend components → Jobs

---

### Backend: RSpec Setup

**Gemfile additions:**
```ruby
group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
  gem 'faker'
end

group :test do
  gem 'database_cleaner-active_record'
end
```

**`spec/rails_helper.rb` config additions:**
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.before(:suite) { DatabaseCleaner.strategy = :transaction }
  config.before(:each)  { DatabaseCleaner.start }
  config.after(:each)   { DatabaseCleaner.clean }
end

Shoulda::Matchers.configure do |config|
  config.integrate { |with| with.test_framework(:rspec).and.library(:rails) }
end
```

---

### RulesEngine Spec (highest priority)

`spec/services/rules_engine_spec.rb` — test every operator and conflict scenario:

```ruby
RSpec.describe RulesEngine do
  let(:user) { create(:user) }

  describe 'description_contains operator' do
    it 'assigns category when description matches (case-insensitive)' do
      rule = create(:rule, user: user,
        condition: { field: 'description', operator: 'contains', value: 'amazon' },
        action:    { type: 'set_category', value: 'Shopping' })
      tx = create(:transaction, user: user, description: 'AMAZON PURCHASE', category: nil)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.category).to eq('Shopping')
    end

    it 'does not match when description is nil' do
      rule = create(:rule, user: user,
        condition: { field: 'description', operator: 'contains', value: 'amazon' },
        action:    { type: 'set_category', value: 'Shopping' })
      tx = create(:transaction, user: user, description: nil, category: nil)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.category).to be_nil
    end
  end

  describe 'amount_gt operator' do
    it 'flags as high value when amount exceeds threshold' do
      rule = create(:rule, user: user,
        condition: { field: 'amount', operator: 'gt', value: '1000' },
        action:    { type: 'flag_high_value' })
      tx = create(:transaction, user: user, amount: 1500.00)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.anomaly_flags).to include('high_value')
    end

    it 'does not flag when amount is below threshold' do
      rule = create(:rule, user: user,
        condition: { field: 'amount', operator: 'gt', value: '1000' },
        action:    { type: 'flag_high_value' })
      tx = create(:transaction, user: user, amount: 99.99)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.anomaly_flags).to be_empty
    end
  end

  describe 'description_matches (regex) operator' do
    it 'matches using case-insensitive regex' do
      rule = create(:rule, user: user,
        condition: { field: 'description', operator: 'matches', value: 'rent|lease' },
        action:    { type: 'set_category', value: 'Housing' })
      tx = create(:transaction, user: user, description: 'Monthly Lease Payment')

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.category).to eq('Housing')
    end

    it 'does not crash on malformed regex — falls back gracefully' do
      rule = create(:rule, user: user,
        condition: { field: 'description', operator: 'matches', value: '[invalid(' },
        action:    { type: 'set_category', value: 'Shopping' })
      tx = create(:transaction, user: user, description: 'Some purchase')

      expect { RulesEngine.apply(tx, rules: [rule]) }.not_to raise_error
    end
  end

  describe 'rule priority ordering' do
    it 'applies lower priority number first' do
      rule_first  = create(:rule, user: user, priority: 1,
        condition: { field: 'description', operator: 'contains', value: 'transfer' },
        action:    { type: 'set_category', value: 'Banking' })
      rule_second = create(:rule, user: user, priority: 2,
        condition: { field: 'description', operator: 'contains', value: 'transfer' },
        action:    { type: 'set_category', value: 'Other' })
      tx = create(:transaction, user: user, description: 'Wire Transfer', category: nil)

      RulesEngine.apply(tx, rules: [rule_second, rule_first])
      # priority 1 runs first, priority 2 overwrites — last writer wins by default
      expect(tx.reload.category).to eq('Other')
    end
  end

  describe 'inactive rules' do
    it 'skips rules where active is false' do
      rule = create(:rule, user: user, active: false,
        condition: { field: 'description', operator: 'contains', value: 'amazon' },
        action:    { type: 'set_category', value: 'Shopping' })
      tx = create(:transaction, user: user, description: 'Amazon Purchase', category: nil)

      RulesEngine.apply(tx)
      expect(tx.reload.category).to be_nil
    end
  end
end
```

---

### AnomalyDetector Spec (highest priority)

`spec/services/anomaly_detector_spec.rb` — test statistical logic with controlled fixture data:

```ruby
RSpec.describe AnomalyDetector do
  let(:user) { create(:user) }

  describe 'unusual amount detection' do
    before do
      # Establish baseline: 90 days of ~$50 transactions (mean ~$50, low std dev)
      90.times do |i|
        create(:transaction, user: user,
          amount: 45 + rand(10),
          date: i.days.ago.to_date)
      end
    end

    it 'flags a transaction 3+ std devs above the mean' do
      tx = create(:transaction, user: user, amount: 8500.00, date: Date.today)
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).to include('unusual_amount')
      expect(Anomaly.find_by(transaction: tx, anomaly_type: 'unusual_amount')).to be_present
    end

    it 'does not flag a transaction within normal range' do
      tx = create(:transaction, user: user, amount: 55.00, date: Date.today)
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).not_to include('unusual_amount')
    end

    it 'does not flag when user has fewer than 10 transactions (insufficient baseline)' do
      new_user = create(:user)
      create_list(:transaction, 5, user: new_user, amount: 50)
      tx = create(:transaction, user: new_user, amount: 9999.00)

      AnomalyDetector.check(tx)
      expect(tx.reload.anomaly_flags).not_to include('unusual_amount')
    end
  end

  describe 'duplicate detection' do
    it 'flags a transaction with same date, amount, and description within 24 hours' do
      original = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase',
        created_at: 2.hours.ago)
      duplicate = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase')

      AnomalyDetector.check(duplicate)
      expect(duplicate.reload.anomaly_flags).to include('potential_duplicate')
    end

    it 'does not flag when same amount but different description' do
      create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase')
      tx = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Spotify')

      AnomalyDetector.check(tx)
      expect(tx.reload.anomaly_flags).not_to include('potential_duplicate')
    end

    it 'does not flag when duplicate is older than 24 hours' do
      create(:transaction, user: user,
        date: 2.days.ago.to_date, amount: 49.99, description: 'Amazon Purchase',
        created_at: 2.days.ago)
      tx = create(:transaction, user: user,
        date: Date.today, amount: 49.99, description: 'Amazon Purchase')

      AnomalyDetector.check(tx)
      expect(tx.reload.anomaly_flags).not_to include('potential_duplicate')
    end
  end

  describe 'missing metadata detection' do
    it 'flags a transaction with nil description' do
      tx = create(:transaction, user: user, description: nil)
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).to include('missing_metadata')
      expect(Anomaly.find_by(transaction: tx, anomaly_type: 'missing_metadata')).to be_present
    end

    it 'flags a transaction with blank description' do
      tx = create(:transaction, user: user, description: '   ')
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).to include('missing_metadata')
    end

    it 'does not flag when description is present' do
      tx = create(:transaction, user: user, description: 'Starbucks')
      AnomalyDetector.check(tx)

      expect(tx.reload.anomaly_flags).not_to include('missing_metadata')
    end
  end

  describe 'multiple anomalies on one transaction' do
    it 'can flag both high value and missing metadata simultaneously' do
      tx = create(:transaction, user: user, amount: 8500.00, description: nil)
      # Seed baseline so statistical check fires
      90.times { create(:transaction, user: user, amount: 50, date: 30.days.ago.to_date) }

      AnomalyDetector.check(tx)
      flags = tx.reload.anomaly_flags
      expect(flags).to include('unusual_amount', 'missing_metadata')
    end
  end
end
```

---

### Request Specs

`spec/requests/bulk_actions_spec.rb` — the most complex API surface:

```ruby
RSpec.describe 'PUT /api/v1/transactions/bulk' do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it 'categorizes multiple transactions in one request' do
    txs = create_list(:transaction, 5, user: user, category: nil)

    put '/api/v1/transactions/bulk',
      params: { ids: txs.map(&:id), action: 'set_category', value: 'Travel' },
      headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body['updated_count']).to eq(5)
    txs.each { |t| expect(t.reload.category).to eq('Travel') }
  end

  it 'rejects bulk action on transactions belonging to another user' do
    other_user = create(:user)
    txs = create_list(:transaction, 3, user: other_user)

    put '/api/v1/transactions/bulk',
      params: { ids: txs.map(&:id), action: 'set_category', value: 'Travel' },
      headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body['updated_count']).to eq(0)  # silently scoped to current user
  end
end
```

`spec/requests/imports_spec.rb` — CSV edge cases:

```ruby
RSpec.describe 'POST /api/v1/imports' do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  it 'accepts a valid CSV and enqueues a job' do
    csv = fixture_file_upload('valid_transactions.csv', 'text/csv')

    expect {
      post '/api/v1/imports', params: { file: csv }, headers: headers
    }.to have_enqueued_job(CsvImportJob)

    expect(response).to have_http_status(:accepted)
  end

  it 'rejects non-CSV files' do
    pdf = fixture_file_upload('document.pdf', 'application/pdf')
    post '/api/v1/imports', params: { file: pdf }, headers: headers
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

---

### CSV Importer Unit Spec

`spec/services/csv_importer_spec.rb` — edge cases are the whole point:

```ruby
RSpec.describe CsvImporter do
  let(:user) { create(:user) }

  def import(csv_string)
    CsvImporter.new(user: user, csv_content: csv_string).import
  end

  it 'imports valid rows' do
    result = import("date,description,amount\n2024-01-15,Starbucks,6.75")
    expect(result.imported_count).to eq(1)
    expect(result.error_count).to eq(0)
  end

  it 'skips rows with unparseable amount and records the error' do
    result = import("date,description,amount\n2024-01-15,Starbucks,not_a_number")
    expect(result.imported_count).to eq(0)
    expect(result.errors.first).to match(/amount/)
  end

  it 'skips rows with malformed date and continues processing' do
    csv = "date,description,amount\nnot-a-date,Starbucks,6.75\n2024-01-16,Netflix,15.99"
    result = import(csv)
    expect(result.imported_count).to eq(1)
    expect(result.error_count).to eq(1)
  end

  it 'flags duplicate rows within the same import' do
    csv = "date,description,amount\n2024-01-15,Amazon,49.99\n2024-01-15,Amazon,49.99"
    result = import(csv)
    expect(result.imported_count).to eq(2)
    expect(result.flagged_count).to be >= 1
  end

  it 'handles completely empty CSV gracefully' do
    result = import("date,description,amount\n")
    expect(result.imported_count).to eq(0)
    expect(result.errors).to be_empty
  end

  it 'processes 10,000 rows without raising' do
    rows = (1..10_000).map { |i| "2024-01-#{(i % 28) + 1},Purchase #{i},#{rand(10..500)}" }
    csv = "date,description,amount\n#{rows.join("\n")}"
    expect { import(csv) }.not_to raise_error
  end
end
```

---

### AnthropicClient Spec

`spec/services/anthropic_client_spec.rb` — always mock the HTTP call, never hit the real API in tests:

```ruby
RSpec.describe AnthropicClient do
  describe '.explain_anomaly' do
    let(:context) do
      {
        anomaly_type:       'unusual_amount',
        severity:           'high',
        transaction_date:   Date.today,
        transaction_amount: 8500.00,
        transaction_desc:   '(no description)',
        details:            { std_devs_above_mean: 469.2 }
      }
    end

    it 'returns explanation string from API response' do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(
          status: 200,
          body: {
            content: [{ type: 'text', text: 'This transaction is unusually large.' }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = AnthropicClient.explain_anomaly(context)
      expect(result).to eq('This transaction is unusually large.')
    end

    it 'returns nil and does not raise when API call fails' do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_return(status: 500, body: 'Internal Server Error')

      expect { AnthropicClient.explain_anomaly(context) }.not_to raise_error
      expect(AnthropicClient.explain_anomaly(context)).to be_nil
    end

    it 'returns nil on network timeout' do
      stub_request(:post, 'https://api.anthropic.com/v1/messages')
        .to_timeout

      expect(AnthropicClient.explain_anomaly(context)).to be_nil
    end
  end
end
```

Add `gem 'webmock'` to the test group for HTTP stubbing:
```ruby
group :test do
  gem 'database_cleaner-active_record'
  gem 'webmock'
end
```

### AnomalyExplanationJob Spec

`spec/jobs/anomaly_explanation_job_spec.rb`:

```ruby
RSpec.describe AnomalyExplanationJob do
  let(:anomaly) { create(:anomaly, explanation: nil) }

  it 'stores explanation on the anomaly record' do
    allow(AnthropicClient).to receive(:explain_anomaly).and_return('This charge looks suspicious.')

    AnomalyExplanationJob.perform_now(anomaly.id)

    expect(anomaly.reload.explanation).to eq('This charge looks suspicious.')
    expect(anomaly.reload.explanation_generated_at).to be_present
  end

  it 'stores nil gracefully when API returns nil' do
    allow(AnthropicClient).to receive(:explain_anomaly).and_return(nil)

    AnomalyExplanationJob.perform_now(anomaly.id)

    expect(anomaly.reload.explanation).to be_nil
  end

  it 'does not call API if explanation already exists' do
    anomaly.update!(explanation: 'Already generated.')
    expect(AnthropicClient).not_to receive(:explain_anomaly)

    AnomalyExplanationJob.perform_now(anomaly.id)
  end

  it 'does nothing if anomaly record no longer exists' do
    expect { AnomalyExplanationJob.perform_now(999_999) }.not_to raise_error
  end
end
```

---

### FactoryBot Factories

`spec/factories/anomalies.rb`:
```ruby
FactoryBot.define do
  factory :anomaly do
    transaction
    anomaly_type  { 'unusual_amount' }
    severity      { 'medium' }
    details       { { std_devs_above_mean: 4.2 } }
    explanation   { nil }
    resolved      { false }
  end
end
```

`spec/factories/transactions.rb`:
```ruby
FactoryBot.define do
  factory :transaction do
    user
    date        { Faker::Date.between(from: 1.year.ago, to: Date.today) }
    description { Faker::Commerce.product_name }
    amount      { Faker::Commerce.price(range: 5.0..500.0) }
    category    { nil }
    status      { 'pending' }
    source      { 'manual' }
    anomaly_flags { [] }
    metadata    { {} }
  end
end
```

`spec/factories/rules.rb`:
```ruby
FactoryBot.define do
  factory :rule do
    user
    name      { Faker::Lorem.sentence(word_count: 3) }
    condition { { field: 'description', operator: 'contains', value: 'Amazon' } }
    action    { { type: 'set_category', value: 'Shopping' } }
    priority  { 0 }
    active    { true }
  end
end
```

---

### Frontend: Vitest + React Testing Library Setup

**`package.json` additions:**
```json
{
  "devDependencies": {
    "vitest": "^1.0.0",
    "@testing-library/react": "^14.0.0",
    "@testing-library/user-event": "^14.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "jsdom": "^24.0.0"
  },
  "scripts": {
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage"
  }
}
```

**`vite.config.ts` test block:**
```ts
export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test-setup.ts'],
  },
})
```

**`src/test-setup.ts`:**
```ts
import '@testing-library/jest-dom'
```

---

### RuleBuilder Component Test (highest priority)

`src/__tests__/components/RuleBuilder.test.tsx`:
```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { RuleBuilder } from '../../components/RuleBuilder'

describe('RuleBuilder', () => {
  it('renders condition fields and action fields', () => {
    render(<RuleBuilder onSave={vi.fn()} onCancel={vi.fn()} />)
    expect(screen.getByLabelText(/rule name/i)).toBeInTheDocument()
    expect(screen.getByRole('combobox', { name: /field/i })).toBeInTheDocument()
  })

  it('calls onSave with correct JSON structure when form is submitted', async () => {
    const onSave = vi.fn()
    render(<RuleBuilder onSave={onSave} onCancel={vi.fn()} />)

    await userEvent.type(screen.getByLabelText(/rule name/i), 'Amazon rule')
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /field/i }), 'description')
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /operator/i }), 'contains')
    await userEvent.type(screen.getByPlaceholderText(/value/i), 'Amazon')
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /action type/i }), 'set_category')
    await userEvent.selectOptions(screen.getByRole('combobox', { name: /category/i }), 'Shopping')

    fireEvent.click(screen.getByRole('button', { name: /save rule/i }))

    expect(onSave).toHaveBeenCalledWith(expect.objectContaining({
      name: 'Amazon rule',
      condition: { field: 'description', operator: 'contains', value: 'Amazon' },
      action: { type: 'set_category', value: 'Shopping' },
    }))
  })

  it('does not submit when name is empty' , async () => {
    const onSave = vi.fn()
    render(<RuleBuilder onSave={onSave} onCancel={vi.fn()} />)
    fireEvent.click(screen.getByRole('button', { name: /save rule/i }))
    expect(onSave).not.toHaveBeenCalled()
  })
})
```

---

### BulkActionBar Component Test (highest priority)

`src/__tests__/components/BulkActionBar.test.tsx`:
```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { BulkActionBar } from '../../components/BulkActionBar'

describe('BulkActionBar', () => {
  it('is hidden when no rows are selected', () => {
    const { container } = render(<BulkActionBar selectedIds={[]} onApply={vi.fn()} />)
    expect(container.firstChild).not.toHaveClass('visible')
  })

  it('shows count when rows are selected', () => {
    render(<BulkActionBar selectedIds={[1, 2, 3]} onApply={vi.fn()} />)
    expect(screen.getByText(/3 selected/i)).toBeInTheDocument()
  })

  it('calls onApply with selected ids and chosen category', async () => {
    const onApply = vi.fn()
    render(<BulkActionBar selectedIds={[1, 2]} onApply={onApply} />)

    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'Travel' } })
    fireEvent.click(screen.getByRole('button', { name: /apply/i }))

    expect(onApply).toHaveBeenCalledWith({
      ids: [1, 2],
      action: 'set_category',
      value: 'Travel',
    })
  })
})
```

---

### Performance Test (not automated — manual verification)

Run after seeding 100k+ rows. Document `EXPLAIN ANALYZE` output in your PR.

```sql
-- Should use idx_transactions_status partial index, not seq scan
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 1 AND status != 'reviewed'
ORDER BY date DESC
LIMIT 50;

-- Should use idx_transactions_user_date, rows examined should be ~50 not 100k
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 1
ORDER BY id DESC
LIMIT 50;

-- Full-text search should use GIN index
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 1
AND to_tsvector('english', coalesce(description, '')) @@ plainto_tsquery('amazon');
```

Expected output for each: `Index Scan` or `Bitmap Index Scan` — **never** `Seq Scan` on the transactions table at scale. Screenshot these and include in your Loom.

---

## Key Technical Decisions

| Decision | Choice | Reason |
|---|---|---|
| Pagination | Keyset (cursor) | Offset breaks at 1M+ rows |
| Bulk insert | `insert_all` | Bypasses AR overhead for CSV |
| Virtualization | `@tanstack/react-virtual` | DOM stays fast at any row count |
| Real-time | ActionCable (WS) | Already in Rails, no extra infra |
| Rule storage | JSONB conditions | Flexible without schema changes |
| Anomaly storage | Separate table + JSONB flag | Query by type + fast transaction reads |
| Staging | Render.com | Free tier, one-click DB+web+worker |
| CSV parsing | `smarter_csv` not stdlib `CSV` | Chunked, handles malformed rows, significantly faster above 50k rows |
| State machine | `statesman` not `aasm` | Persists every transition — full audit trail in `transaction_transitions` table |
| Full-text search | `pg_search` not raw SQL | Clean DSL, handles both tsearch and trigram similarity over existing GIN index |
| Data fetching | `@tanstack/react-query` not raw axios | Caching, `useInfiniteQuery` for cursor pagination, built-in loading/error states |
| Forms | `react-hook-form` | `useFieldArray` for dynamic rule conditions; uncontrolled inputs = better perf |
| Rule conflict resolution | First-match-wins + `continue_processing` flag | Deterministic, matches production rules engine patterns |
| Duplicate detection | Normalized description + 48h window | Handles real bank data formats; exact match fails silently on reference codes |
| Anomaly severity | Additive weighted score → low/medium/high | Ranked queue gets acted on; flat "flagged" list gets ignored |
| AI explanations | Anthropic API (async, stored) | LLM handles presentation layer only; detection logic stays pure Ruby |
| AI HTTP client | `http` gem not Net::HTTP | Cleaner API, better timeout handling, less boilerplate |
| AI test strategy | WebMock stubs, never real API | Tests stay fast, deterministic, and free |
| Frontend testing | Vitest + RTL | Vite-native; RTL tests behavior not implementation |
| Test philosophy | Services first, no controller boilerplate | Maximizes signal; reviewers care about business logic coverage |

---

## Dependency Reference

### Backend — Gemfile (key gems)

```ruby
# Core
gem 'rails', '~> 7.1'
gem 'pg'
gem 'puma'
gem 'rack-cors'

# Auth
gem 'devise'
gem 'devise-jwt'          # if using JWT; swap for session cookies if preferred

# Business logic libraries
gem 'smarter_csv'         # CSV parsing — chunked, handles malformed rows
gem 'statesman'           # State machine with persisted transition history
gem 'pg_search'           # Full-text + trigram search DSL over PostgreSQL
gem 'sidekiq'             # Background jobs
gem 'redis'               # Required by Sidekiq + ActionCable
gem 'http'                # Lightweight HTTP client for Anthropic API calls

# Serialization
gem 'blueprinter'         # Fast JSON serializer (alternative: jsonapi-serializer)

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'shoulda-matchers'
  gem 'faker'
end

group :test do
  gem 'database_cleaner-active_record'
end
```

### Frontend — package.json (key dependencies)

```json
{
  "dependencies": {
    "react": "^18",
    "react-dom": "^18",
    "axios": "^1.6",
    "@tanstack/react-query": "^5",
    "@tanstack/react-virtual": "^3",
    "react-hook-form": "^7",
    "recharts": "^2"
  },
  "devDependencies": {
    "typescript": "^5",
    "vite": "^5",
    "@vitejs/plugin-react": "^4",
    "vitest": "^1",
    "@testing-library/react": "^14",
    "@testing-library/user-event": "^14",
    "@testing-library/jest-dom": "^6",
    "jsdom": "^24"
  }
}
```

**Library usage notes for copilot:**
- Use `useInfiniteQuery` from `@tanstack/react-query` for the transaction list — not `useQuery` with manual pagination state
- Use `useFieldArray` from `react-hook-form` for dynamic rule condition rows in `RuleBuilder.tsx`
- Use `useVirtualizer` from `@tanstack/react-virtual` inside `TransactionTable.tsx` — the table body renders only visible rows
- Use `SmarterCSV.process(file, chunk_size: 1000)` in `CsvImporter` — never `CSV.foreach`
- Use `transaction.state_machine.transition_to!(:flagged)` via statesman — never `transaction.update(status: 'flagged')`
- Use `Transaction.search_description(query)` via pg_search scope — never raw `WHERE to_tsvector...` in controllers

---

## Sample CSV for Testing

```
date,description,amount,category
2024-01-15,Amazon Purchase,49.99,Shopping
2024-01-15,Amazon Purchase,49.99,Shopping
2024-01-16,Whole Foods,127.43,
2024-01-17,,8500.00,
2024-01-18,Netflix,15.99,Entertainment
2024-01-19,Rent Payment,2200.00,Housing
2024-01-20,AMZN MKTP US,23.11,
2024-01-21,Starbucks,6.75,Food
```

Row 2 = duplicate of row 1 | Row 4 = missing description + high value | Row 3 = missing category
