const TYPE_LABELS: Record<string, { label: string; color: string }> = {
  unusual_amount: { label: 'High Value', color: 'red' },
  potential_duplicate: { label: 'Duplicate', color: 'amber' },
  missing_metadata: { label: 'Missing Info', color: 'gray' },
  high_value: { label: 'High Value', color: 'red' },
  uncategorized: { label: 'Uncategorized', color: 'blue' },
}

export default function AnomalyBadge({ type }: { type: string }) {
  const config = TYPE_LABELS[type] || { label: type, color: 'gray' }
  return <span className={`badge badge-${config.color}`} style={{ marginRight: 4 }}>{config.label}</span>
}
