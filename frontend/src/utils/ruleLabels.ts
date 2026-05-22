const FIELD_LABELS: Record<string, string> = {
  description: 'Description',
  amount: 'Amount',
  category: 'Category',
}

const OPERATOR_LABELS: Record<string, string> = {
  contains: 'contains',
  matches: 'matches',
  gt: 'is greater than',
  lt: 'is less than',
  eq: 'equals',
  is: 'is',
}

function formatConditionValue(field: string, value: string): string {
  if (field === 'amount') {
    const num = parseFloat(value)
    return Number.isFinite(num) ? `$${num.toLocaleString()}` : value
  }
  return `"${value}"`
}

export function formatCondition(condition: { field: string; operator: string; value: string }): string {
  const field = FIELD_LABELS[condition.field] ?? condition.field
  const op = OPERATOR_LABELS[condition.operator] ?? condition.operator
  const value = formatConditionValue(condition.field, condition.value)
  return `${field} ${op} ${value}`
}

export function formatAction(action: { type: string; value?: string }): string {
  switch (action.type) {
    case 'set_category':
      return action.value ? `Set category to ${action.value}` : 'Set category'
    case 'flag_high_value':
      return 'Flag as high value'
    case 'add_tag':
      return action.value ? `Add tag "${action.value}"` : 'Add tag'
    default:
      return action.value ? `${action.type}: ${action.value}` : action.type
  }
}
