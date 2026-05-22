import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { createRule, updateRule } from '../api/client'
import type { Rule } from '../types'

interface Props {
  rule?: Rule | null
  onSave: () => void
  onCancel: () => void
}

interface FormData {
  name: string
  conditionField: string
  conditionOperator: string
  conditionValue: string
  actionType: string
  actionValue: string
  priority: number
  continue_processing: boolean
}

const OPERATORS: Record<string, { label: string; value: string }[]> = {
  description: [
    { label: 'contains', value: 'contains' },
    { label: 'matches (regex)', value: 'matches' },
  ],
  amount: [
    { label: 'greater than', value: 'gt' },
    { label: 'less than', value: 'lt' },
    { label: 'equals', value: 'eq' },
  ],
  category: [
    { label: 'is', value: 'is' },
  ],
}

const CATEGORIES = ['Shopping', 'Food & Dining', 'Entertainment', 'Housing', 'Transportation', 'Utilities', 'Healthcare', 'Travel', 'Education', 'Subscriptions']

export default function RuleBuilder({ rule, onSave, onCancel }: Props) {
  const { register, handleSubmit, watch, setValue, clearErrors, formState: { errors } } = useForm<FormData>({
    defaultValues: {
      name: rule?.name || '',
      conditionField: rule?.condition?.field || 'description',
      conditionOperator: rule?.condition?.operator || 'contains',
      conditionValue: rule?.condition?.value || '',
      actionType: rule?.action?.type || 'set_category',
      actionValue: rule?.action?.value || '',
      priority: rule?.priority || 0,
      continue_processing: rule?.continue_processing || false,
    },
  })

  const field = watch('conditionField')
  const operator = watch('conditionOperator')
  const actionType = watch('actionType')

  // When the field changes, the previously-selected operator may be invalid
  // (e.g. switching from "amount > 500" to "description ?" leaves "gt" as
  // the operator, producing nonsense like 'Description is greater than "x"').
  // Reset to the first valid operator for the new field. Also resets the
  // value, since a numeric value in a description rule is similarly broken.
  useEffect(() => {
    const validOps = OPERATORS[field] || []
    if (!validOps.find(op => op.value === operator)) {
      setValue('conditionOperator', validOps[0]?.value ?? '')
      setValue('conditionValue', '')
      // Clear stale validation errors — the old "must be a number" error
      // from when this was an amount rule shouldn't haunt the description
      // input after the switch.
      clearErrors('conditionValue')
    }
  }, [field, operator, setValue, clearErrors])

  // Single registration shared across all three branches of the value input.
  // Validation runs through `validate` (closes over current field) so it stays
  // accurate regardless of how the consumer renders the input element.
  const valueRegistration = register('conditionValue', {
    required: true,
    validate: (val: string) => {
      if (field === 'amount' && val && !/^\d+(\.\d{1,2})?$/.test(val)) {
        return 'invalid-amount'
      }
      return true
    },
  })

  const onSubmit = async (data: FormData) => {
    const payload = {
      name: data.name,
      condition: { field: data.conditionField, operator: data.conditionOperator, value: data.conditionValue },
      action: { type: data.actionType, ...(data.actionValue ? { value: data.actionValue } : {}) },
      priority: data.priority,
      continue_processing: data.continue_processing,
    }

    if (rule) {
      await updateRule(rule.id, payload)
    } else {
      await createRule(payload)
    }
    onSave()
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <div className="form-group">
        <label htmlFor="ruleName">Rule Name</label>
        <input id="ruleName" {...register('name', { required: true })} placeholder="e.g. Amazon → Shopping" />
        {errors.name && <p className="error-text">Name is required</p>}
      </div>

      <div className="form-group">
        <label htmlFor="field">Field</label>
        <select id="field" {...register('conditionField')}>
          <option value="description">Description</option>
          <option value="amount">Amount</option>
          <option value="category">Category</option>
        </select>
      </div>

      <div className="form-group">
        <label htmlFor="operator">Operator</label>
        <select id="operator" {...register('conditionOperator')}>
          {(OPERATORS[field] || []).map(op => (
            <option key={op.value} value={op.value}>{op.label}</option>
          ))}
        </select>
      </div>

      <div className="form-group">
        <label htmlFor="conditionValue">{valueLabel(field, operator)}</label>
        {/*
          ONE shared register call across all three input types. If we put
          register inside each conditional branch, react-hook-form retains
          the validation rules from the previous branch — switching from
          amount (with pattern: /^\d+...) to description leaves the numeric
          pattern attached, so typing "lululemon" fails with a stale pattern
          error. The validate function below checks the CURRENT field on
          every run, so it's always consistent with what's on screen.
        */}
        {field === 'category' ? (
          <select id="conditionValue" {...valueRegistration}>
            <option value="">Select a category...</option>
            {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        ) : field === 'amount' ? (
          <input
            id="conditionValue"
            type="number"
            step="0.01"
            min="0"
            inputMode="decimal"
            placeholder="e.g. 5000"
            {...valueRegistration}
          />
        ) : (
          <input
            id="conditionValue"
            type="text"
            placeholder={operator === 'matches' ? 'e.g. ^uber.*' : 'e.g. amazon'}
            {...valueRegistration}
          />
        )}
        <span className="form-help">{valueHelp(field, operator)}</span>
        {errors.conditionValue && (
          <p className="error-text">{valueError(field, errors.conditionValue.type)}</p>
        )}
      </div>

      <div className="form-group">
        <label htmlFor="actionType">Action Type</label>
        <select id="actionType" {...register('actionType')}>
          <option value="set_category">Set Category</option>
          <option value="flag_high_value">Flag High Value</option>
          <option value="add_tag">Add Tag</option>
        </select>
      </div>

      {(actionType === 'set_category') && (
        <div className="form-group">
          <label htmlFor="category">Category</label>
          <select id="category" {...register('actionValue')}>
            <option value="">Select...</option>
            {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
      )}

      {actionType === 'add_tag' && (
        <div className="form-group">
          <label htmlFor="tagValue">Tag</label>
          <input id="tagValue" {...register('actionValue')} placeholder="e.g. recurring" />
        </div>
      )}

      <div className="form-group">
        <label htmlFor="priority">Priority</label>
        <input id="priority" type="number" {...register('priority', { valueAsNumber: true })} />
      </div>

      <div className="form-group checkbox-row">
        <input type="checkbox" id="continue" {...register('continue_processing')} />
        <label htmlFor="continue">
          Continue evaluating lower-priority rules after this one matches
          <span className="form-help">By default the first matching rule fires and stops. Enable this to chain multiple rules on the same transaction.</span>
        </label>
      </div>

      <div style={{ display: 'flex', gap: 8, marginTop: 20 }}>
        <button type="submit" className="btn btn-primary">Save Rule</button>
        <button type="button" className="btn" onClick={onCancel}>Cancel</button>
      </div>
    </form>
  )
}

function valueLabel(field: string, _operator: string): string {
  if (field === 'amount') return 'Dollar Amount'
  if (field === 'category') return 'Category'
  return 'Text to match'
}

function valueHelp(field: string, operator: string): string {
  if (field === 'amount') return 'Numbers only. Enter 5000 for $5,000.'
  if (field === 'category') return 'Pick one of the predefined categories.'
  if (operator === 'matches') return 'Regular expression pattern (case-insensitive).'
  return 'Case-insensitive substring match.'
}

function valueError(field: string, type: string): string {
  // `validate` is the type produced by our custom validate function on the
  // shared register call; the legacy `pattern` is kept as a fallback in
  // case any prior register options are still cached for the field.
  if ((type === 'validate' || type === 'pattern') && field === 'amount') {
    return 'Enter a number with up to 2 decimal places (e.g. 5000 or 49.99).'
  }
  if (field === 'amount')      return 'A dollar amount is required.'
  if (field === 'category')    return 'Pick a category.'
  return 'Text to match is required.'
}
