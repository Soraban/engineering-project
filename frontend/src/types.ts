export interface Transaction {
  id: number
  date: string
  description: string | null
  description_normalized: string | null
  amount: string
  category: string | null
  status: 'pending' | 'flagged' | 'reviewed'
  source: 'manual' | 'csv'
  anomaly_flags: string[]
  metadata: Record<string, unknown>
  created_at: string
  updated_at: string
  anomalies?: Anomaly[]
}

export interface Anomaly {
  id: number
  transaction_id: number
  anomaly_type: string
  severity: 'low' | 'medium' | 'high'
  details: Record<string, unknown>
  explanation: string | null
  explanation_generated_at: string | null
  resolved: boolean
  resolved_at: string | null
  created_at: string
}

export interface Rule {
  id: number
  name: string
  condition: { field: string; operator: string; value: string }
  action: { type: string; value?: string }
  priority: number
  active: boolean
  continue_processing: boolean
  match_count: number
  last_matched_at: string | null
  match_rate: number | null
  stale: boolean
  overbroad: boolean
  created_at: string
  updated_at: string
}

export interface DashboardData {
  uncategorized_count: number
  flagged_anomalies_count: number
  total_transactions: number
  unresolved_anomalies_count: number
  resolved_anomalies_count: number
  needs_attention: NeedsAttentionRow[]
  needs_attention_breakdown: NeedsAttentionBreakdown
  needs_attention_page: number
  needs_attention_total_pages: number
  needs_attention_total: number
  spending_by_category: SpendingByCategory[]
  spending_category_range: string
  spending_trend: SpendingTrendPoint[]
  spending_trend_range: string
  spending_trend_granularity: 'day' | 'month'
}

export interface SpendingByCategory {
  category: string
  total: number
}

export interface SpendingTrendPoint {
  bucket: string // YYYY-MM-DD (daily) or YYYY-MM (monthly)
  total: number
}

export interface NeedsAttentionRow extends Transaction {
  anomalies: Anomaly[]
}

export interface NeedsAttentionBreakdown {
  all: number
  anomalies: number
  high: number
  medium: number
  low: number
  uncategorized: number
}
