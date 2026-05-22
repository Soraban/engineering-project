import { describe, it, expect } from 'vitest'
import { formatCondition, formatAction } from '../../utils/ruleLabels'

describe('formatCondition', () => {
  it('formats description contains', () => {
    expect(formatCondition({ field: 'description', operator: 'contains', value: 'amazon' }))
      .toBe('Description contains "amazon"')
  })

  it('formats description matches (preserves the regex value in quotes)', () => {
    expect(formatCondition({ field: 'description', operator: 'matches', value: 'rent|lease' }))
      .toBe('Description matches "rent|lease"')
  })

  it('translates gt to "is greater than" and formats amount with $', () => {
    expect(formatCondition({ field: 'amount', operator: 'gt', value: '5000' }))
      .toBe('Amount is greater than $5,000')
  })

  it('translates lt to "is less than"', () => {
    expect(formatCondition({ field: 'amount', operator: 'lt', value: '100' }))
      .toBe('Amount is less than $100')
  })

  it('translates eq to "equals"', () => {
    expect(formatCondition({ field: 'amount', operator: 'eq', value: '49.99' }))
      .toBe('Amount equals $49.99')
  })

  it('formats category is', () => {
    expect(formatCondition({ field: 'category', operator: 'is', value: 'Shopping' }))
      .toBe('Category is "Shopping"')
  })

  it('falls back to the raw value when amount is not parseable', () => {
    expect(formatCondition({ field: 'amount', operator: 'gt', value: 'not-a-number' }))
      .toBe('Amount is greater than not-a-number')
  })

  it('falls back to raw operator/field strings when unknown', () => {
    expect(formatCondition({ field: 'unknown_field', operator: 'unknown_op', value: 'x' }))
      .toBe('unknown_field unknown_op "x"')
  })
})

describe('formatAction', () => {
  it('formats set_category with a value', () => {
    expect(formatAction({ type: 'set_category', value: 'Shopping' }))
      .toBe('Set category to Shopping')
  })

  it('formats flag_high_value (no value)', () => {
    expect(formatAction({ type: 'flag_high_value' }))
      .toBe('Flag as high value')
  })

  it('formats add_tag with the tag name in quotes', () => {
    expect(formatAction({ type: 'add_tag', value: 'recurring' }))
      .toBe('Add tag "recurring"')
  })

  it('falls back gracefully for unknown action types', () => {
    expect(formatAction({ type: 'unknown_action', value: 'foo' }))
      .toBe('unknown_action: foo')
    expect(formatAction({ type: 'unknown_action' }))
      .toBe('unknown_action')
  })
})
