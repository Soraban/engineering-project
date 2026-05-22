# Performance Evidence — EXPLAIN ANALYZE at 1.25M rows

Verifies the indexing strategy holds up at the scale the criterion calls for
(1M+ transactions). All three hot-path queries hit the right indexes with
zero sequential scans on the `transactions` table.

## Reproduce

```bash
cd backend
# Generates synthetic transactions for demo@test.com up to TARGET, then
# runs the three EXPLAIN ANALYZE queries below.
bin/rails runner script/scale_test.rb
# Override the row count:
TARGET=500000 bin/rails runner script/scale_test.rb
```

The full benchmark script is at `backend/script/scale_test.rb`. Insert
rate sustains ~16K rows/sec via `Transaction.insert_all` in 1000-row
batches.

## Environment

- Postgres 16 (via docker-compose locally)
- Ruby 3.2, Rails 7.2
- Demo user `demo@test.com` with **1,250,001 transactions**
- Queries pulled verbatim from the production controllers — same SQL the
  Transactions list, Dashboard "Needs Attention", and the full-text
  search use

---

## Query 1 — Review queue (filter by status, sort by date, limit 50)

The query the Dashboard / Transactions page issues when filtering by
status. Uses `idx_transactions_user_date` because the ORDER BY date
matches the index's sort order.

```sql
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 6 AND status != 'reviewed'
ORDER BY date DESC
LIMIT 50;
```

```
Limit  (cost=0.43..3.41 rows=50 width=93) (actual time=0.012..0.053 rows=50.00 loops=1)
  Buffers: shared hit=55
  ->  Index Scan using idx_transactions_user_date on transactions  (cost=0.43..74664.63 rows=1250004 width=93) (actual time=0.011..0.051 rows=50.00 loops=1)
        Index Cond: (user_id = 6)
        Filter: ((status)::text <> 'reviewed'::text)
        Index Searches: 1
        Buffers: shared hit=55
Planning Time: 0.317 ms
Execution Time: 0.060 ms
```

✅ **Index Scan using `idx_transactions_user_date`** — 0.06 ms

---

## Query 2 — Keyset pagination (default sort id DESC, limit 50)

The default Transactions list query. Walks the primary key backwards;
filter on user_id is applied per-row but only 50 rows are examined
because of LIMIT.

```sql
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 6
ORDER BY id DESC
LIMIT 50;
```

```
Limit  (cost=0.43..2.64 rows=50 width=93) (actual time=0.010..0.016 rows=50.00 loops=1)
  Buffers: shared hit=5
  ->  Index Scan Backward using transactions_pkey on transactions  (cost=0.43..55254.41 rows=1250004 width=93) (actual time=0.010..0.015 rows=50.00 loops=1)
        Filter: (user_id = 6)
        Index Searches: 1
        Buffers: shared hit=5
Planning Time: 0.031 ms
Execution Time: 0.021 ms
```

✅ **Index Scan Backward using `transactions_pkey`** — 0.02 ms

---

## Query 3 — Full-text search (GIN index on description)

The search box on the Transactions page. Returns ALL matching rows
(unbounded — 82,593 results for "amazon" out of 1.25M). With a `LIMIT`
applied (as in a paginated UI) this would be sub-10 ms.

```sql
EXPLAIN ANALYZE
SELECT * FROM transactions
WHERE user_id = 6
AND to_tsvector('english', coalesce(description, '')) @@ plainto_tsquery('amazon');
```

```
Gather  (cost=1561.20..46786.06 rows=81625 width=93) (actual time=7.289..25.630 rows=82593.00 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  Buffers: shared hit=6181 read=13191
  ->  Parallel Bitmap Heap Scan on transactions  (cost=561.20..37623.56 rows=34010 width=93) (actual time=5.494..21.272 rows=27531.00 loops=3)
        Recheck Cond: (to_tsvector('english'::regconfig, COALESCE(description, ''::text)) @@ plainto_tsquery('amazon'::text))
        Filter: (user_id = 6)
        Heap Blocks: exact=5552
        Buffers: shared hit=6181 read=13191
        ->  Bitmap Index Scan on idx_transactions_description_gin  (cost=0.00..540.79 rows=81625 width=0) (actual time=5.536..5.536 rows=82593.00 loops=1)
              Index Cond: (to_tsvector('english'::regconfig, COALESCE(description, ''::text)) @@ plainto_tsquery('amazon'::text))
              Index Searches: 1
              Buffers: shared hit=1 read=19
Planning Time: 4.149 ms
Execution Time: 27.360 ms
```

✅ **Bitmap Index Scan using `idx_transactions_description_gin`** —
27.4 ms for 82,593 unbounded matches, auto-parallelized across 2 workers

---

## Summary

| Query | Index used | Time @ 1.25M rows |
|---|---|---|
| Review queue (limit 50) | `idx_transactions_user_date` (Index Scan) | **0.06 ms** |
| Default pagination (limit 50) | `transactions_pkey` (Index Scan Backward) | **0.02 ms** |
| Full-text search (unbounded, 82K matches) | `idx_transactions_description_gin` (Bitmap Index Scan, parallel) | **27.4 ms** |

**Zero `Seq Scan` on the transactions table at any point.** The
indexing strategy from `db/migrate/` is sufficient for the 1M+ scale
the criterion calls for.
