import { render, screen, fireEvent } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi } from 'vitest'
import RuleBuilder from '../../components/RuleBuilder'

vi.mock('../../api/client', () => ({
  createRule: vi.fn(() => Promise.resolve({})),
  updateRule: vi.fn(() => Promise.resolve({})),
}))

describe('RuleBuilder', () => {
  it('renders condition fields and action fields', () => {
    render(<RuleBuilder onSave={vi.fn()} onCancel={vi.fn()} />)
    expect(screen.getByLabelText(/rule name/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/field/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/operator/i)).toBeInTheDocument()
  })

  it('does not submit when name is empty', async () => {
    const onSave = vi.fn()
    render(<RuleBuilder onSave={onSave} onCancel={vi.fn()} />)
    fireEvent.click(screen.getByRole('button', { name: /save rule/i }))
    // form validation should prevent submission
    expect(onSave).not.toHaveBeenCalled()
  })

  it('calls onCancel when cancel is clicked', () => {
    const onCancel = vi.fn()
    render(<RuleBuilder onSave={vi.fn()} onCancel={onCancel} />)
    fireEvent.click(screen.getByRole('button', { name: /cancel/i }))
    expect(onCancel).toHaveBeenCalled()
  })

  it('populates fields when editing an existing rule', () => {
    const rule = {
      id: 1,
      name: 'Test Rule',
      condition: { field: 'description', operator: 'contains', value: 'Amazon' },
      action: { type: 'set_category', value: 'Shopping' },
      priority: 1,
      active: true,
      continue_processing: false,
      match_count: 10,
      last_matched_at: null,
      match_rate: null,
      stale: false,
      overbroad: false,
      created_at: '',
      updated_at: '',
    }
    render(<RuleBuilder rule={rule} onSave={vi.fn()} onCancel={vi.fn()} />)
    expect(screen.getByLabelText(/rule name/i)).toHaveValue('Test Rule')
  })
})
