import { BarChart, Bar, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts'
import type { SpendingByCategory, SpendingTrendPoint } from '../types'

export type SpendingRange = '7' | '30' | '90' | '180' | '365' | 'all'

interface Props {
  byCategory: SpendingByCategory[]
  trend: SpendingTrendPoint[]
  trendGranularity: 'day' | 'month'
  categoryRange: SpendingRange
  trendRange: SpendingRange
  onCategoryRangeChange: (next: SpendingRange) => void
  onTrendRangeChange: (next: SpendingRange) => void
}

const RANGE_OPTIONS: { value: SpendingRange; label: string }[] = [
  { value: '7',   label: '7d' },
  { value: '30',  label: '30d' },
  { value: '90',  label: '90d' },
  { value: '180', label: '6mo' },
  { value: '365', label: '1y' },
  { value: 'all', label: 'All' },
]

const RANGE_LABELS: Record<SpendingRange, string> = {
  '7':   'Last 7 days',
  '30':  'Last 30 days',
  '90':  'Last 90 days',
  '180': 'Last 6 months',
  '365': 'Last 12 months',
  'all': 'All time',
}

const CURRENCY = (v: number) =>
  v >= 1000 ? `$${(v / 1000).toFixed(1)}k` : `$${v.toFixed(0)}`

function formatBucket(bucket: string, granularity: 'day' | 'month'): string {
  if (granularity === 'month') {
    const [, mm] = bucket.split('-')
    return new Date(2000, parseInt(mm, 10) - 1, 1).toLocaleString('en', { month: 'short' })
  }
  // daily: YYYY-MM-DD
  const [, mm, dd] = bucket.split('-')
  return new Date(2000, parseInt(mm, 10) - 1, parseInt(dd, 10)).toLocaleString('en', { month: 'short', day: 'numeric' })
}

interface RangePickerProps {
  value: SpendingRange
  onChange: (next: SpendingRange) => void
}

function RangePicker({ value, onChange }: RangePickerProps) {
  return (
    <div className="spending-range-picker">
      {RANGE_OPTIONS.map(opt => (
        <button
          key={opt.value}
          className={`pill ${value === opt.value ? 'active' : ''}`}
          onClick={() => onChange(opt.value)}
        >
          {opt.label}
        </button>
      ))}
    </div>
  )
}

export default function SpendingCharts({ byCategory, trend, trendGranularity, categoryRange, trendRange, onCategoryRangeChange, onTrendRangeChange }: Props) {
  const topCategories = byCategory.slice(0, 8)
  const trendData = trend.map(p => ({ ...p, label: formatBucket(p.bucket, trendGranularity) }))

  return (
    <div className="charts-row">
      <div className="chart-card">
        <div className="chart-card-header">
          <div>
            <h3 className="chart-title">Spending by Category</h3>
            <div className="chart-subtitle">{RANGE_LABELS[categoryRange]}</div>
          </div>
          <RangePicker value={categoryRange} onChange={onCategoryRangeChange} />
        </div>
        <div style={{ height: 220, marginTop: 8 }}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={topCategories} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
              <XAxis dataKey="category" tick={{ fontSize: 11, fill: 'var(--text3)' }} interval={0} angle={-30} textAnchor="end" height={60} />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text3)' }} tickFormatter={CURRENCY} width={50} />
              <Tooltip
                formatter={(value: number) => [`$${value.toLocaleString()}`, 'Total']}
                cursor={{ fill: 'rgba(0,0,0,0.04)' }}
                contentStyle={{ borderRadius: 6, border: '1px solid var(--border)', fontSize: 12 }}
              />
              <Bar dataKey="total" fill="var(--accent)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="chart-card">
        <div className="chart-card-header">
          <div>
            <h3 className="chart-title">Spending Trends</h3>
            <div className="chart-subtitle">
              {trendGranularity === 'day' ? 'Daily' : 'Monthly'} · {RANGE_LABELS[trendRange]}
            </div>
          </div>
          <RangePicker value={trendRange} onChange={onTrendRangeChange} />
        </div>
        <div style={{ height: 220, marginTop: 8 }}>
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={trendData} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--border)" vertical={false} />
              <XAxis dataKey="label" tick={{ fontSize: 11, fill: 'var(--text3)' }} />
              <YAxis tick={{ fontSize: 11, fill: 'var(--text3)' }} tickFormatter={CURRENCY} width={50} />
              <Tooltip
                formatter={(value: number) => [`$${value.toLocaleString()}`, 'Total']}
                contentStyle={{ borderRadius: 6, border: '1px solid var(--border)', fontSize: 12 }}
              />
              <Line type="monotone" dataKey="total" stroke="var(--accent)" strokeWidth={2} dot={{ r: 3 }} activeDot={{ r: 6 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
