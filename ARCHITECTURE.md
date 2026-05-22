# Bookkeeping App — Architecture Walkthrough

A guided tour of how this codebase works, written for someone who needs to defend it in a Loom.

---

## 🏛️ The 30,000-Foot View

You have a **3-tier architecture** with async job processing:

```
┌──────────────────┐
│  React Frontend  │  ← runs in user's browser
│  (Vite static)   │
└────────┬─────────┘
         │  HTTPS + JWT in Authorization header
         ▼
┌──────────────────┐         ┌──────────────────┐
│  Rails API       │ ────►   │  PostgreSQL      │
│  (Puma web srv)  │ ◄────   │  (relational DB) │
└────────┬─────────┘         └──────────────────┘
         │                          ▲
         │  enqueues background jobs│
         ▼                          │
┌──────────────────┐                │
│  Sidekiq worker  │ ───────────────┘
│  (separate proc) │
└────────┬─────────┘
         │  reads/writes queue via
         ▼
┌──────────────────┐
│  Redis           │  ← Sidekiq's job queue + ActionCable WebSocket transport
└──────────────────┘
                  ▲
                  │  WebSocket (CSV import progress)
                  │
              React Frontend
```

The **Rails API is stateless** — every request must carry its JWT token. The **Sidekiq worker** is a separate process that picks jobs off Redis and runs them in the background (so the user's request returns fast). The **PostgreSQL DB** is the single source of truth; both processes read/write to it.

---

## 🔧 Backend Architecture (Rails)

Rails follows a **layered design**. Requests flow inward:

```
HTTP request
  → Router (config/routes.rb)
    → Controller (thin — just auth, params, response)
      → Service (the actual business logic)
        → Model (validations, DB persistence, state machine)
          → PostgreSQL
```

### Layer 1: Routes — `backend/config/routes.rb`

This is your URL → controller map. Important entries:

```ruby
namespace :api do
  namespace :v1 do
    resources :transactions, only: [:index, :show, :create, :update, :destroy] do
      collection do
        put :bulk           # PUT /api/v1/transactions/bulk
      end
    end
    resources :rules
    resources :anomalies, only: [:index, :update] do
      member do
        patch :resolve      # PATCH /api/v1/anomalies/:id/resolve
      end
    end
    resources :imports, only: [:create]   # POST /api/v1/imports (CSV upload)
    get 'dashboard', to: 'dashboard#index'
    # transactions also has a collection-level export:
    # GET /api/v1/transactions/export → streaming CSV download
  end
end

mount ActionCable.server => '/cable'   # WebSocket endpoint
```

**Auth routes** (Devise + JWT):
- `POST /api/v1/auth/sign_in` — login, returns JWT in Authorization header
- `POST /api/v1/auth/sign_up` — register
- `DELETE /api/v1/auth/sign_out` — invalidate token

### Layer 2: Controllers (thin)

A controller's job is **only**: authenticate the user, parse params, call a service, render JSON. Look at `app/controllers/api/v1/transactions_controller.rb#create`:

```ruby
def create
  transaction = current_user_transactions.build(transaction_params)
  if transaction.save
    RulesEngine.apply(transaction)        # ← delegate to service
    AnomalyDetector.check(transaction)    # ← delegate to service
    render json: TransactionSerializer.render_as_json(transaction.reload, view: :detail), status: :created
  else
    render_error(transaction.errors.full_messages)
  end
end
```

Note: it doesn't *do* the rules logic itself — it delegates to `RulesEngine`. That's the **service object pattern**. Keeps controllers small and testable.

### Layer 3: Services — the brain

These are **plain Ruby classes** (not Rails-tied) under `app/services/`. They contain all the interesting logic:

#### `RulesEngine` (`app/services/rules_engine.rb`)

Takes a transaction, walks through the user's active rules in priority order, and fires actions when conditions match.

**Key design decision (from PLAN.md Decision 1):** first-match-wins per action type. If two rules both want to set the category, only the first one fires — unless that rule has `continue_processing: true`. This is deterministic; without it, two competing rules would race.

**Supported operators**: `contains`, `matches` (regex), `gt`, `lt`, `eq`, `is`
**Supported actions**: `set_category`, `flag_high_value`, `add_tag`

Notable safety: malformed regex is **caught** (line 33) and logged, not raised — one bad rule can't break the whole engine.

#### `AnomalyDetector` (`app/services/anomaly_detector.rb`)

Runs three checks against a transaction:

1. **Unusual amount** — fetches the user's last 90 days of transactions, computes mean + standard deviation **in the database** (look at line 45–48: `Arel.sql('AVG(amount)')` — that's Postgres doing the math, not Ruby). If the current amount is >3 std devs above the mean, flag it. Requires ≥10 historical txs to avoid false positives on new users.
2. **Duplicate** — looks for same (user, date, amount, normalized description) within 48 hours. **Normalized description** is the trick (Decision 3) — `"AMAZON MKTP US*2F4KL9"` and `"AMAZON MKTP US*8B2MQ1"` both normalize to `"amazon mktp us"`, so they match.
3. **Missing metadata** — flags transactions with no description.

When ≥1 check fires, it computes a **severity score** (Decision 2 — `low`/`medium`/`high` based on which flags + how unusual), creates an `Anomaly` record per flag, and enqueues `AnomalyExplanationJob` for each — that's the AI piece.

It also transitions the transaction to `flagged` state via the state machine (more on that in a sec).

#### `CsvImporter` (`app/services/csv_importer.rb`)

The non-obvious thing here: it uses `SmarterCSV.process` with `chunk_size: 1000`. This streams the file in batches of 1000 rows instead of loading the whole thing into memory. Critical for big files.

Within each chunk:
1. Parse + validate each row (`parse_row`)
2. `Transaction.insert_all` — single bulk DB insert (way faster than `Transaction.create!` 1000 times)
3. For each inserted tx, run `RulesEngine` + `AnomalyDetector`
4. Broadcast progress over ActionCable (`broadcast_progress`) → user's browser sees real-time updates

#### `AnthropicClient` (`app/services/anthropic_client.rb`)

Thin HTTP wrapper around Anthropic's API. Sends a prompt with the anomaly context, returns the explanation text.

**Key design point:** the `rescue => e` on line 21 — if Anthropic is down, or the key is bad, or the network blips, it logs the error and returns `nil`. **Never raises.** This is "graceful degradation" — the anomaly still exists, the UI just doesn't show an explanation.

### Layer 4: Models — `app/models/transaction.rb`

The interesting bits:

```ruby
include Statesman::Adapters::ActiveRecordQueries[...]   # state machine
include PgSearch::Model                                   # full-text search

has_many :anomalies, dependent: :destroy                 # cascade delete

before_save :compute_normalized_description              # auto-normalize on save

pg_search_scope :search_description,                     # FTS scope
  against: :description,
  using: { tsearch: { prefix: true }, trigram: { threshold: 0.3 } }
```

**The state machine** is in a separate class `TransactionStateMachine` (line 30 references it). Statuses go `pending → flagged → reviewed` (and a few other transitions). Critically, `reviewed → pending` is **disallowed** — once something's reviewed, you can't silently un-review it (Decision 4). That's why bulk actions use `state_machine.can_transition_to?(:reviewed)` instead of `update_all(status: 'reviewed')` — see `transactions_controller.rb#bulk`.

**`description_normalized`** is auto-computed on every save (`before_save` callback) — this is what powers duplicate detection. The normalization regex (lines 41–49) strips bank reference codes.

### Layer 5: Background Jobs — `app/jobs/`

Three jobs run in Sidekiq:

| Job | When it runs | What it does |
|---|---|---|
| `CsvImportJob` | User uploads CSV | Calls `CsvImporter`, broadcasts "complete" over ActionCable when done |
| `AnomalyExplanationJob` | After each `Anomaly.create!` | Calls `AnthropicClient`, stores explanation on the anomaly |
| `RuleHealthJob` | (Manual or scheduled) | Updates `rule.match_rate` for staleness warnings |

The jobs use different queues — `:ai` for explanations (lower priority), `:default` for everything else. That way a long Anthropic call can't block a CSV import.

---

## ⚛️ Frontend Architecture (React)

### Entry — `src/main.tsx` → `src/App.tsx`

`App.tsx` sets up three things:

1. **React Query** — global cache for server data. `staleTime: 30s` means data is reused without refetch for 30 seconds.
2. **React Router** — URL → page component mapping. The router checks `localStorage.getItem('auth_token')`; if missing, it redirects to `/login`.
3. **Layout** — sidebar nav + a `<main>` slot where pages render.

```tsx
<Route path="/dashboard" element={<Dashboard />} />
<Route path="/transactions" element={<Transactions />} />
<Route path="/rules" element={<Rules />} />
<Route path="/import" element={<Import />} />
```

### Pages — `src/pages/`

Each page is a top-level component:
- `Dashboard.tsx` — summary cards + "Needs Attention" anomaly table + uncategorized list
- `Transactions.tsx` — virtualized table of all transactions with filters/search/bulk actions
- `Rules.tsx` — list + create/edit/delete user rules
- `Import.tsx` — drag-drop CSV upload + live progress bar
- `Login.tsx` — sign in / sign up

### API client — `src/api/client.ts`

A single axios instance with two interceptors:

1. **Request interceptor**: pulls JWT from `localStorage` and adds `Authorization: <token>` header to every request.
2. **Response interceptor**: if backend returns a new JWT (e.g., after login), saves it to `localStorage`. On 401, clears the token and redirects to `/login`.

Below the instance is a flat list of typed functions — `fetchTransactions`, `createRule`, `uploadCSV`, etc. Pages don't call axios directly; they call these named functions.

### Hooks — `src/hooks/`

`useTransactions.ts` wraps the transactions fetch in **`useInfiniteQuery`** — this is React Query's primitive for cursor pagination. Returns the data + a `fetchNextPage()` function that the virtualized table calls when you scroll near the bottom.

`useWebSocket.ts` — connects to ActionCable for CSV import progress.

---

## 🔄 Worked Examples

### Example 1: User manually creates a transaction

```
1. User clicks "Add Transaction" → form opens
2. Form submits → calls createTransaction() in api/client.ts
3. axios POST /api/v1/transactions { transaction: {...} }
   Authorization: <JWT> header attached automatically
4. Devise validates JWT → sets current_user
5. TransactionsController#create:
   - builds Transaction scoped to current_user
   - .save → before_save callback computes description_normalized → DB INSERT
   - RulesEngine.apply(tx) → applies user's rules (maybe sets category)
   - AnomalyDetector.check(tx) → 3 checks; if any fire:
     • creates Anomaly row(s)
     • enqueues AnomalyExplanationJob for each
     • transitions tx.status → 'flagged' (via state machine)
6. Returns JSON to frontend
7. React Query invalidates ['transactions'] cache → list refetches
8. Meanwhile, sidekiq picks up AnomalyExplanationJob:
   - calls Anthropic
   - writes explanation back to anomaly row
9. Next time dashboard loads, explanation is there
```

### Example 2: User uploads a CSV

```
1. User drops file into CSVDropzone component
2. Frontend POST /api/v1/imports with multipart/form-data
3. ImportsController#create:
   - saves file to temp path
   - enqueues CsvImportJob with file path + import_id
   - returns import_id to frontend immediately (HTTP 202 Accepted)
4. Frontend opens WebSocket subscription to "import_status_<import_id>"
5. Sidekiq picks up CsvImportJob:
   - CsvImporter streams file in 1000-row chunks
   - Each chunk: parse → bulk insert → run RulesEngine + AnomalyDetector
   - After each chunk: broadcasts { processed: X, imported: Y } over ActionCable
6. Frontend receives WebSocket messages → updates progress bar live
7. When done: CsvImportJob broadcasts { status: 'complete', imported: ..., flagged: ... }
8. Frontend shows summary toast and refetches transactions
```

### Example 3: User exports their transactions as CSV

```
1. User clicks "Export CSV" on Transactions page → handleExport() fires
2. Frontend calls exportTransactions(currentFilters) in api/client.ts
3. axios GET /api/v1/transactions/export?status=flagged&category=Travel
   with responseType: 'blob' and JWT in Authorization header
4. TransactionsController#export:
   - Sets streaming-friendly headers: Content-Type: text/csv,
     Content-Disposition: attachment, X-Accel-Buffering: no
   - Assigns self.response_body = Enumerator.new (lazy body)
5. As Rack starts to flush the response, the enumerator runs:
   - Yields the header row (CSV.generate_line(EXPORT_HEADERS))
   - Begins keyset-paginated loop:
       a. Query the filtered scope with cursor WHERE clause
          `(date, id) < (last_date, last_id)`, ORDER BY date DESC, id DESC,
          LIMIT 1000
       b. Yields each row → CSV.generate_line(export_row(tx))
       c. Records the last (date, id) seen
       d. Loops until a batch comes back empty
6. The client receives chunks of CSV as they're produced — no buffering
7. Frontend converts the blob to a download:
   URL.createObjectURL → <a download="…"> → .click() → revokeObjectURL
8. Browser saves transactions-YYYY-MM-DD.csv to user's Downloads
```

**Why keyset pagination instead of `find_each`:** Rails' `find_each` silently overrides any custom `ORDER BY` and uses primary key ASC for batching. At 1M rows that means a 100MB CSV in id-ascending order regardless of what was requested. The cursor loop preserves `date DESC, id DESC` ordering across all batches and hits `idx_transactions_user_date` for every cursor query (no table scans).

### Example 4: Why does that anomaly have a Claude explanation?

```
AnomalyDetector creates Anomaly row
  ↓
AnomalyExplanationJob.perform_later(anomaly.id)   ← enqueued to Redis ('ai' queue)
  ↓
Sidekiq worker process picks up job
  ↓
Loads anomaly + its transaction from DB
  ↓
Builds context (date, amount, description, severity, std_devs_above_mean, etc.)
  ↓
AnthropicClient.explain_anomaly(context):
  - Builds prompt (system: "you are a bookkeeping assistant…")
  - POSTs to api.anthropic.com/v1/messages
  - Parses response.content[0].text
  ↓
Updates anomaly: explanation = <text>, explanation_generated_at = now
  ↓
Next dashboard load: explanation appears under the badge
```

The reason this is **async + stored** (instead of called inline when the dashboard loads) is two-fold:
- **Speed**: the dashboard loads in <100ms because it just reads from the DB. If we called Anthropic at render time, every dashboard load would block on a 2-3 second API call.
- **Cost**: each anomaly's explanation is generated **once**. If we called inline, every dashboard refresh would burn a new API call.

---

## 🎯 The "Interesting" Design Decisions

These are what separate this from a CRUD scaffold. Be ready to explain them in the Loom:

| What | Where | Why |
|---|---|---|
| First-match-wins rules + `continue_processing` flag | `RulesEngine#apply` | Deterministic conflict resolution; matches production rules engines like Drools |
| Description normalization for duplicate detection | `Transaction.normalize_description` | Real bank data has reference codes (`*2F4KL9`) that break exact match |
| State machine with persisted transitions | `Transaction` + `TransactionTransition` | Full audit trail of every status change; can't bypass with raw SQL |
| Severity scoring → low/medium/high | `AnomalyDetector#compute_severity` | Ranked queues get acted on; flat lists get ignored |
| Cursor pagination, not offset | `TransactionsController#apply_cursor` | Offset breaks at 1M+ rows; cursor stays O(log n) |
| `insert_all` for bulk CSV | `CsvImporter#process_chunk` | Skips AR overhead — orders of magnitude faster than `create!` in a loop |
| Async AI explanations with graceful degradation | `AnomalyExplanationJob` + `AnthropicClient` rescue | Dashboard stays fast, never breaks if Anthropic is down |
| GIN index for full-text search | Migration: `idx_transactions_description_gin` | Sub-millisecond text search even at 1M rows (proven with EXPLAIN ANALYZE) |
| Streaming CSV export with keyset pagination | `TransactionsController#export` + `#each_export_record` | Constant memory + correct ordering across batches; scales to 1M+ rows without buffering the file |

---

## 📍 Quick File Map

**Backend brain — read these to understand the logic:**
- `backend/app/services/rules_engine.rb` — how rules match + fire
- `backend/app/services/anomaly_detector.rb` — the 3 checks + severity + per-user real-time broadcast
- `backend/app/services/csv_importer.rb` — streaming CSV ingestion
- `backend/app/services/anthropic_client.rb` — AI integration
- `backend/app/models/transaction.rb` — state machine + normalization
- `backend/app/channels/` — `ImportStatusChannel` (CSV progress) and `AnomalyChannel` (live notifications)
- `backend/app/controllers/api/v1/dashboard_controller.rb` — unified needs_attention + spending aggregations
- `backend/config/routes.rb` — the URL map

**Frontend brain — read these to understand the UI:**
- `frontend/src/App.tsx` — routing + React Query setup + always-on `<NotificationToaster />`
- `frontend/src/api/client.ts` — every backend call (includes `exportTransactions`, `countTransactions`)
- `frontend/src/hooks/useTransactions.ts` — page-based pagination
- `frontend/src/hooks/useWebSocket.ts` — both `useImportProgress` (CSV) and `useAnomalyNotifications` (live anomaly toasts)
- `frontend/src/pages/Dashboard.tsx` — unified Needs Attention queue + spending charts + range pickers
- `frontend/src/pages/Transactions.tsx` — table + filters + Export CSV button
- `frontend/src/pages/Import.tsx` — CSV dropzone + inline imported items table + errors panel
- `frontend/src/components/NotificationToaster.tsx` — top-right toast stack for live anomaly notifications
- `frontend/src/components/SpendingCharts.tsx` — bar + line charts with per-chart range pickers

---

## 📝 Changes Since PLAN.md

The codebase has evolved beyond what `PLAN.md` originally specified. This section is the canonical record of every deviation, so anyone reading both docs knows which one is authoritative (hint: this one + the code).

### Added features (not in PLAN.md)

**CSV Export**
- New endpoint: `GET /api/v1/transactions/export`
- Streams CSV row-by-row via Rack enumerator response body (constant memory)
- Uses **keyset pagination** internally — `WHERE (date, id) < (last_date, last_id)` — so the requested `ORDER BY date DESC, id DESC` is preserved across batches at any scale. Notable because Rails' `find_each` would silently override the order.
- Reuses the same `filtered_scope` helper as `index` — same filters work for export (status, category, date range, search)
- Columns match the import format so users can round-trip: export → edit in Excel → re-import
- Frontend: "Export CSV" button on the Transactions page opens an **ExportModal** slide-over (not an immediate download)
- Files:
  - `backend/app/controllers/api/v1/transactions_controller.rb#export`
  - `backend/spec/requests/transaction_export_spec.rb` (14 tests including keyset-ordering correctness across batch boundaries)
  - `frontend/src/api/client.ts#exportTransactions`
  - `frontend/src/__tests__/api/exportTransactions.test.ts` (5 tests)

**Export Modal**
- New `ExportModal.tsx` slide-over for date-range / status / category-filtered exports
- Pre-populates from the Transactions page's current filter state — so a user who has already filtered the table opens the modal with those values applied
- Shows a **live count** ("2,450 transactions will be exported") that re-fetches whenever a filter changes
- "Download CSV" button is disabled when the count is 0
- Backed by a new `GET /api/v1/transactions/count` endpoint that reuses the same `filtered_scope` for consistency with `#index` and `#export`
- Files:
  - `backend/app/controllers/api/v1/transactions_controller.rb#count`
  - `backend/spec/requests/transaction_count_spec.rb` (5 tests)
  - `frontend/src/components/ExportModal.tsx`
  - `frontend/src/api/client.ts#countTransactions`
  - `frontend/src/__tests__/components/ExportModal.test.tsx` (7 tests)

**Unified "Needs Attention" review queue on the Dashboard** (replaces the original two-section design)
- Combined what used to be two separate Dashboard tables ("Needs Attention" anomalies + "Uncategorized Transactions") into a single unified queue of transactions that need user review: those with at least one unresolved anomaly **or** still pending+uncategorized.
- One row per transaction, with its unresolved anomalies eagerly loaded for the Severity (max of) and Type (badges per type) columns.
- **Server-side filter pills** with **real global counts** (not just what's in the loaded page): `All` / `Anomalies` / `High` / `Medium` / `Low` / `Uncategorized`. Pills call `?filter=` and `needs_attention_breakdown` returns total counts per filter so the UI reads "Uncategorized (114,325)" honestly even when only 20 are loaded.
- **Three independently sortable columns**: Transaction (sort=id), Date (sort=date), Amount (sort=amount). Click pattern matches Notion/Linear (new column = desc; same column = toggle direction). Inactive headers show a faint `↕` affordance.
- **Page-based pagination** strip below the table: `← Previous · Page N of M (total) · Next →`. Resets to page 1 on filter/sort change.
- **Inline actions per row**: Edit (slide-over), Approve (also auto-resolves the row's open anomalies, see below), Delete. No navigation away from the Dashboard.
- **Fixed the $0.00 amount bug**: dashboard was reading `anomaly.details.transaction_amount`, which `AnomalyDetector` never populates. Switched to serializing the actual transaction with its anomalies nested (TransactionSerializer `view: :detail`), so Amount comes from `transaction.amount` directly.
- Files: `backend/app/controllers/api/v1/dashboard_controller.rb` (significantly rewritten), `backend/spec/requests/dashboard_needs_attention_spec.rb` (13 tests), `frontend/src/pages/Dashboard.tsx` (rewritten), CSS for severity-filter pills and pagination strip.

**Inline Approve + status changes on the Transactions page**
- New per-row **Approve** button on the Transactions page, visible only when status is `pending` or `flagged`. Calls the same `update + approve` path so the row's open anomalies get auto-resolved.
- Edit form gained a **Status dropdown** (Pending / Flagged / Reviewed) — enables undoing an accidental approval by switching a reviewed transaction back to pending. Backend routes the change through the state machine so the `transaction_transitions` audit trail captures it.
- `TransactionStateMachine` gained the `reviewed → pending` transition (previously disallowed). Comment in the model explains the intent: audit trail still tells the full story.
- `TransactionsController#update` accepts the approve flag in both `{ approve: true }` (top-level) and `{ transaction: { approve: true } }` (nested — the shape the frontend actually sends).
- Files: `backend/spec/requests/transaction_status_change_spec.rb` (5 tests), `backend/spec/requests/approve_resolves_anomalies_spec.rb` (4 tests covering single + bulk + nested payload), `TransactionStateMachine`.

**Approve auto-resolves the row's open anomalies**
- Without this, clicking Approve transitioned a transaction to `reviewed` but left its anomalies `resolved=false`, so the row stayed on "Needs Attention" — bad UX. Fixed via `TransactionsController#approve_and_resolve(tx)` which does both in one shot. Wired into both `#update` and `#bulk` so single-row and bulk approves behave the same.

**Page-based pagination on the Transactions index (replaces cursor + Load More)**
- Earlier in the project we used composite keyset cursors ("primary:secondary:id") for sort-aware infinite-scroll on the Transactions list. That was correct at any scale but the UX was awkward — no jump-to-page, no "page N of M."
- Switched to plain offset pagination (`?page=` param, response includes `page` / `per_page` / `total` / `total_pages`). Tradeoff: `OFFSET 50000` is slower than keyset at deep page numbers, but the typical user browses the first few pages and lands specific dates via filters — never deep-paginates linearly. Acceptable.
- Frontend swapped `useInfiniteQuery` for plain `useQuery` with `placeholderData: prev` so the previous page stays visible during fetch (no flash of empty table). Sort/filter changes auto-reset to page 1.
- **Removed `@tanstack/react-virtual` from `TransactionTable`** — with 50 rows per page, virtualization was overkill and was the reason the table had an inner scrollbar. Now a plain table that flows with the page. Bundle dropped ~18 KB as a bonus.
- **Export still uses keyset internally** (see CSV Export entry above) — that's the path that genuinely benefits from cursor pagination at 1M+ rows. The user-facing list page doesn't.

**Sortable Date/Amount on the Transactions page** (unchanged from when first added — only the cursor implementation underneath was swapped for offset)
- `sort` (`id|date|amount`) and `direction` (`asc|desc`) params with allowlist validation.
- `apply_sort` uses a smart secondary tiebreaker: sort=date tiebreaks by amount, sort=amount tiebreaks by date, id is the final tiebreaker. So two $49.99 rows order by date within the tie. Documented in PLAN reference Decision 1.
- Headers always show an indicator (faint `↕` inactive, bright accent-colored `↑`/`↓` active).
- Files: `backend/spec/requests/transactions_sort_spec.rb` (13 tests — now includes page-based pagination assertions instead of cursor format).

**Clickable transaction IDs on Dashboard + id filter on the index endpoint** (unchanged from when first added)
- Dashboard row's transaction ID is a `<Link>` to `/transactions?id=NNN`. Transactions page reads the query param, applies it as an `id` filter, shows a chip ("Showing transaction #NNN · [Clear filter]") at the top.
- Filter is user-scoped (other users' ids return empty list — covered in spec).

**Shorter AI explanations**
- `AnthropicClient::MODEL = 'claude-sonnet-4-5'`, `max_tokens` dropped 150 → 80, prompt asks for **one sentence (max two)** with no preamble or bullet points.
- Explanations clamp to 2 lines in the UI with "Show more" / "Show less" (per-row state in a `Set<number>`); only rendered when the explanation exceeds 150 characters.
- Quote-style left-border accent in the accent color visually marks AI-generated text.
- Files: `backend/app/services/anthropic_client.rb`.

**Sidebar + stat-card cleanup**
- Sidebar logo renamed "Soraban" → "Bookkeeping" (with "B" logo mark) for genericity.
- Removed the "Reviewed Today" stat card and its backing COUNT query (was rarely meaningful for triage). Dashboard now has 3 stat cards: Uncategorized / Flagged Anomalies / Total Transactions.

**Row-divider alignment fix in TransactionTable**
- `<td class="actions">` had `display: flex` directly on the cell, which overrides `display: table-cell` and breaks the row's automatic height-matching. Result: the cell ended up shorter than its siblings and the row separator drifted out of line. Fixed by switching to inline buttons with `.btn + .btn { margin-left }` so the cell stays a proper table-cell.
- Added `vertical-align: middle` to all `td` so badges/buttons sit centered in tall rows.
- Bonus from removing virtualization: header table and row tables are now ONE table, so alignment can't drift between them.

**Rule UI polish — humanized labels + improved "Continue processing" affordance**
- The Rules list page used to display raw codes like `description gt "5000"` and `flag_high_value`. `frontend/src/utils/ruleLabels.ts` provides `formatCondition()` and `formatAction()` that render plain English ("Amount is greater than $5,000", "Flag as high value"). Amount values are number-formatted with `$` and locale separators. Unknown operators/actions fall back to the raw string so the page stays robust if the backend gains new ones.
- The "Continue processing" checkbox in `RuleBuilder` was being inflated to 100% width by the generic `.form-group input` rule. Fixed with a scoped `input[type="checkbox"]` override and a dedicated `.checkbox-row` layout class that wraps it in a subtle gray box, with helper text explaining the behavior.
- Files: `frontend/src/utils/ruleLabels.ts` + 12 unit tests in `frontend/src/__tests__/utils/ruleLabels.test.ts`

**Priority tiebreaker for same-priority rules**
- `RulesEngine.apply` and `RulesController#index` both used `.order(:priority)` — with no tiebreaker, two rules at priority 5 returned in undefined order, breaking the first-match-wins determinism the PLAN promises.
- Fixed to `.order(:priority, :id)` so same-priority rules tiebreak by creation order (oldest wins). Engine ordering now matches the UI list ordering.
- File: `backend/spec/services/rules_engine_spec.rb` gains a test that creates two same-priority rules and verifies the earlier-created one wins.

### Bonus challenges (from the take-home spec)

**Bonus #1: REST API for Transactions** — done thoroughly. Full CRUD (`index` / `show` / `create` / `update` / `destroy`) plus `bulk`, `export`, and `count`. All paginated, sortable, filterable, user-scoped. See [Routes](#layer-1-routes--backendconfigroutesrb) and the `transactions_crud_spec.rb` / `transactions_sort_spec.rb` / `bulk_actions_spec.rb` test files for coverage.

**Bonus #2: Real-time anomaly notifications**
- New `AnomalyChannel` (`backend/app/channels/anomaly_channel.rb`) streams per-user from `anomalies_for_user_<id>`.
- `AnomalyDetector` broadcasts to that channel whenever it creates a new `Anomaly` row. Payload includes `anomaly_type`, `severity`, and `transaction_id` for the toast.
- `NotificationToaster.tsx` mounts at the **App level** (not the Dashboard) so notifications work on every page — Dashboard, Transactions, Rules, Import. Maintains its own list of toasts, auto-dismisses after 8 seconds.
- New `useAnomalyNotifications` hook (`frontend/src/hooks/useWebSocket.ts`) opens the WebSocket subscription using a `user_id` stored in `localStorage` on sign-in.
- Toast UI: fixed top-right, severity-colored left border (red/amber/gray), title row in small caps, "View" link that navigates to `/transactions?id=NNN`, dismiss `×` button. Slides in from the right via CSS keyframes.
- Notifications also invalidate the dashboard query so any open Dashboard tab refetches and the new flag appears in "Needs Attention" without a page reload.

**Bonus #3: Graph-based spending summary**
- Two `recharts` charts on the Dashboard: a **bar chart for spending by category** and a **line chart for spending trends over time** (`frontend/src/components/SpendingCharts.tsx`).
- Aggregations are pure Postgres SQL — `GROUP BY COALESCE(NULLIF(category, ''), 'Uncategorized')` for the category bar, and `GROUP BY date::date` (daily) or `GROUP BY to_char(date, 'YYYY-MM')` (monthly) for the trend. Sub-millisecond at 1.25M rows.
- **Each chart has its own range picker** (7d / 30d / 90d / 6mo / 1y / All) — they're independent so users can categorize one window while inspecting trend over a different one. Backend accepts `spending_category_days` and `spending_trend_days` as separate params, both validated against an allowlist.
- **Trend granularity adapts** to the chosen range: daily buckets for ≤30 days (so "7d" shows 7 daily bars instead of one squashed monthly bar), monthly buckets otherwise. Response includes `spending_trend_granularity` so the frontend formats x-axis labels appropriately ("May 21" vs "May").
- Files:
  - `backend/app/controllers/api/v1/dashboard_controller.rb` (`#spending_by_category`, `#spending_trend`, range helpers)
  - `backend/spec/requests/dashboard_needs_attention_spec.rb` (7 specs covering independent ranges, 7d, granularity switch, allowlist fallback)
  - `frontend/src/components/SpendingCharts.tsx`

### Other recent fixes & polish

**Staging CSV import — WebSocket URL fix**
- `useWebSocket.ts` was building the cable URL from `window.location.host`, which on staging is the frontend's domain (`bookkeeping-frontend-s92e.onrender.com`). ActionCable lives on the API service — connection would never open, spinner stuck forever.
- Fixed: build the URL from `VITE_API_URL` when set, fall back to `window.location` only for dev (where Vite proxies `/cable` to localhost:3000).
- Backend: added `config.action_cable.allowed_request_origins = [ENV['FRONTEND_URL'], /localhost:\d+/]` to `production.rb` so Rails 7 accepts cross-origin WebSocket upgrades.

**Staging CSV import — cross-container tempfile fix**
- Render runs the API web service and the Sidekiq worker in **separate containers** with separate filesystems. `ImportsController` was saving the upload to `/tmp/RackMultipart...` and enqueueing a Sidekiq job with that path → job hit `Errno::ENOENT`, retried 3 times, died silently.
- Fixed: read the upload's content into memory in the API process and pass the **string** to the job. `CsvImporter` already accepted `csv_content` as an alternative to `file_path`. Regression test in `imports_spec.rb` asserts the job's second arg is a string containing the CSV body, never a `/tmp/*` path.

**Import page: inline imported items table + bad-CSV error panel**
- `CsvImportJob` broadcasts the first 50 imported transactions (with anomalies attached via `TransactionSerializer :detail` view) in the `complete` event.
- `Import.tsx` renders them in a table with per-row **Edit / Approve / Delete** so users can triage their import without navigating away to Transactions.
- When the importer reports errors, a monospace **"Skipped rows" panel** lists each error message ("Row 4: invalid date 'not-a-date'", "Row 7: invalid amount 'abc'"). Capped at 50 with a "…and N more" overflow line.

**Dashboard refetch UX — no more blank flash**
- React Query `placeholderData: (prev) => prev` on the dashboard query: changing a filter / sort / range / chart-range no longer blanks the entire page during refetch. Previous data stays rendered; new data swaps in seamlessly on arrival.
- A small **pulsing dot** appears next to the page title when `isFetching && !isLoading` so the user can tell a refresh is in flight.

**Tightened AI explanation prompt**
- Old prompt produced 60-word wall-of-text explanations ("The bookkeeper should locate the original invoice…"). Tightened: `max_tokens` 150 → 80 → **50**, prompt now says "**under 20 words**" with few-shot examples of the terseness wanted. Result: one sharp sentence per anomaly.
- Existing anomalies were backfilled via a one-time runner script that nulled `explanation` and re-enqueued every `AnomalyExplanationJob`.

**CSV import — subscribe-before-upload race fix**
- After the cross-container tempfile fix, small CSVs on staging still occasionally hung on "Uploading and processing…" forever — data made it into the DB but the UI never saw the completion event. Root cause: WebSocket subscription was opened *after* the upload returned. For small CSVs, Sidekiq finished and broadcast `complete` (~300 ms) before the WS handshake + subscribe completed (~500 ms on Render). Broadcast lands on zero subscribers, fire-and-forget.
- Fix: invert the order. Frontend now generates the `import_id` itself with `crypto.randomUUID()`, sets state immediately so `useImportProgress` opens its WebSocket, **waits for ActionCable's `confirm_subscription`** (exposed as a `subscribed` flag from the hook), then sends the file. By the time Sidekiq broadcasts, the WebSocket is guaranteed to be subscribed.
- Backend: `ImportsController` honors a client-provided `params[:import_id]` when present, falls back to `SecureRandom.uuid` otherwise (backward-compatible with any cached old bundle).
- Regression test in `imports_spec.rb` pins the controller behavior.

**CSV import — stale progress on second upload**
- After uploading one CSV then a second, the preview table showed the *first* upload's results. The hook owned `progress` as a single state variable; when `importId` changed, the reset happened in a `useEffect` (after render), so there was a render where the new `importId` was paired with the previous import's `progress`. A render-time `setState` antipattern in `Import.tsx` then locked the stale data into `result`.
- Fix: the hook now stores progress tagged with the `importId` it belongs to (`{ id, progress }`), and the public getter returns `null` when the tag doesn't match the current `importId`. Cross-contamination filtered at the boundary. Also moved the offending `setState` into a proper `useEffect`.

**CSV error rows now use file line numbers**
- `CsvImporter` was reporting errors as "Row N" where N was the Nth *data* row (header excluded). Users opening their CSV in VS Code see line numbers that include the header — so "Row 2" pointed at the wrong line. Initialized `@row_number = 1` so the first data row is reported as "Row 2" — matches what the user sees in their editor. Regression test in `csv_importer_spec.rb`.

**Edit-on-import refresh**
- Editing a transaction from the Import preview table didn't update the visible row until the user navigated away and back. `previewRows` is local state from the WebSocket broadcast — the global React Query invalidations TransactionForm fires don't touch it. Fix: `handleEditClose` now refetches the edited transaction via a new `fetchTransaction(id)` API call and merges it into `previewRows`.

**Styled confirm dialog replaces native `window.confirm()`**
- All four delete confirmations (Dashboard, Transactions, Rules, Import) now use a centered modal styled to match the rest of the app. New `ConfirmDialog` component + `useConfirm` hook (returns `{ confirm, dialog }` where `confirm()` is promise-based — same shape as `window.confirm`). Auto-focuses the destructive button, has aria attributes, and a contextual message per call site (the Rules delete adds "Existing categorizations stay intact" since deleting a rule has less obvious blast radius).

**RuleBuilder — field/operator/validation coherence**
- Three bugs:
  1. Switching field from `amount` to `description` left the numeric operator (`gt`) attached, producing nonsense rules like "Description is greater than 'lululemon'".
  2. The numeric pattern validation from the amount input persisted into the text input, so typing "lululemon" failed a stale numeric pattern check.
  3. Error messages were generic ("Value is required") instead of contextual to the current field.
- Fixes: a `useEffect` resets operator + value + clears errors when the current operator isn't valid for the new field. A *single shared* register call (`valueRegistration`) is used across all three input variants (number / select / text) — validation runs through a `validate` function that reads the current `field` from closure, so it stays accurate regardless of how the input is rendered. Field-aware labels and error messages ("Dollar Amount" + "Numbers only" for amount, "Text to match" + "Case-insensitive substring match" for description, etc.).

**Dashboard "Flagged Anomalies" stat now matches the Anomalies filter pill**
- The stat card was showing `transactions.flagged.count` while the pill was counting transactions with *unresolved* anomalies — so 18 vs 12 when 6 transactions had been resolved but kept their flagged status field. Stat now uses `counts.anomalies` from the breakdown — same source as the pill, drops when anomalies are resolved.

**Test cleanup — silenced React act() warnings**
- Three `ExportModal` tests fired a mount-time `useEffect` (`countTransactions`) without awaiting it, and one `TransactionForm` validation test clicked submit without awaiting react-hook-form's async validation — both produced "not wrapped in act()" warnings. Tests still passed, but the noise made the demo-day output ugly. Fixed by `await waitFor(() => expect(mockCount).toHaveBeenCalled())` in the modal tests and `await act(async () => { fireEvent.click(...) })` in the form test. Test output is now clean.

### Implementation choices that diverge from PLAN.md

**State machine: `statesman`, not `aasm`** — PLAN.md initially proposed `aasm` (in Decision 4), then the "Key Technical Decisions" table further down switched to `statesman`. The code follows the table: `statesman` provides a `transaction_transitions` table that persists every state change for a full audit trail.

**Anomaly model association** — The PLAN's `Anomaly` model says `belongs_to :transaction`. The actual code uses `belongs_to :bookkeeping_transaction` (aliased) to avoid clashing with Rails' built-in `transaction` keyword on ActiveRecord. Compensated by an alias so callers can still say `anomaly.bookkeeping_transaction`.

**`bulk` action lives on TransactionsController** — PLAN.md hints at a separate `BulkActionsController`; the code puts `#bulk` as a collection method on `TransactionsController` since the params and auth are identical.

**Anthropic model** — PLAN.md uses `claude-sonnet-4-5`. Current code uses the same. (If we upgrade, this is the line to change: `AnthropicClient::MODEL`.)

### Deployment changes (post-PLAN, learned during staging deploy)

| What | Why |
|---|---|
| Render subdomain suffixes (`-s92e`, `-bnhh`) | The plain `bookkeeping-frontend` / `bookkeeping-api` subdomains were taken on `*.onrender.com` |
| `FRONTEND_URL` + `VITE_API_URL` updated to suffixed URLs | CORS allowlist + frontend API base now point to the real services |
| `SECRET_KEY_BASE` shared via `fromService` | Sidekiq needs the same `SECRET_KEY_BASE` as the API to boot Rails in production |
| `ANTHROPIC_API_KEY` via Render env group (`bookkeeper-env`) | Shared between API + Sidekiq; manually linked in Render UI |
| `faker` moved out of `:development, :test` group | `db:seed` runs during Render's build phase, needs Faker available in production bundle |
| `db/seeds.rb` made idempotent | Without a guard, every deploy would add 10k more transactions |
| `bookkeeping-api` on Starter ($7/mo), not free | Web services need explicit `plan: free` in `render.yaml` to use the free tier; Starter is the default |
| Explicit `gem "csv"` in the Gemfile | Ruby 3.4 moved `csv` from a default gem to a bundled gem. `require 'csv'` no longer works without declaring the gem. Render runs Ruby 3.4.4; local dev on Ruby 3.2 didn't surface the issue. |

### Things from PLAN.md that are *not* built (or differ in scope)

- **Rules Health UI warnings** (Decision 5) — schema columns (`match_count`, `last_matched_at`, `match_rate`) and the `RuleHealthJob` exist, but the staleness/breadth warnings aren't yet surfaced in the UI.
- **`RuleHealthJob` is not scheduled** — defined but no cron / sidekiq-cron entry. Run manually for now.
- **Performance verification at 1M+ rows** — `EXPLAIN ANALYZE` confirmed at **1.25M rows locally** (see `backend/script/scale_test.rb`). All three hot-path queries hit the right indexes with zero Seq Scans:

  | Query | Index | Time @ 1.25M |
  |---|---|---|
  | Review queue (filter status, sort date, limit 50) | `idx_transactions_user_date` (Index Scan) | **0.44 ms** |
  | Keyset pagination (id DESC, limit 50) | `transactions_pkey` (Index Scan Backward) | **0.02 ms** |
  | Full-text search ("amazon") | `idx_transactions_description_gin` (Bitmap Index Scan, parallel) | 55 ms for 82,593 unbounded matches |

  Dashboard COUNT queries (uncategorized, flagged, reviewed_today, total) also stay sub-millisecond at 1.25M — Postgres uses index-only scans where the partial / composite indexes cover them.
- **Loom recording** — out of scope for the code itself; the Loom shows behavior, not architecture.
- **`reviewed_today` stat card** — removed in this iteration after user feedback (rarely meaningful for triage). The backing COUNT query was deleted from `DashboardController#index`.

All three **bonus challenges** from the take-home spec are built — see the "Bonus challenges" subsection above.

### Future scalability notes

The streaming export is correct up to ~100k–1M rows. For genuinely huge exports (>1M rows or multi-tenant high-traffic), the production pattern would be:
1. `POST /api/v1/exports` enqueues a `GenerateExportJob`, returns a job ID immediately
2. Sidekiq job generates CSV, uploads to S3 / Render persistent disk
3. WebSocket / email notifies user with a signed download link
4. User downloads directly from object storage (zero Rails involvement)

Not built — flagged here so the next person knows the upgrade path exists and isn't surprising.
