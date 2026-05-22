import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { fetchRules, deleteRule, updateRule } from '../api/client'
import type { Rule } from '../types'
import RuleBuilder from '../components/RuleBuilder'
import { formatCondition, formatAction } from '../utils/ruleLabels'
import { useConfirm } from '../hooks/useConfirm'

export default function Rules() {
  const [showBuilder, setShowBuilder] = useState(false)
  const [editingRule, setEditingRule] = useState<Rule | null>(null)
  const queryClient = useQueryClient()
  const { confirm, dialog: confirmDialog } = useConfirm()

  const { data: rules = [], isLoading } = useQuery<Rule[]>({
    queryKey: ['rules'],
    queryFn: fetchRules,
  })

  const handleDelete = async (rule: Rule) => {
    const ok = await confirm({
      title: `Delete rule "${rule.name}"?`,
      message: 'This will stop the rule from running on new transactions. Existing categorizations stay intact.',
      confirmLabel: 'Delete',
      danger: true,
    })
    if (!ok) return
    await deleteRule(rule.id)
    queryClient.invalidateQueries({ queryKey: ['rules'] })
  }

  const handleToggle = async (rule: Rule) => {
    await updateRule(rule.id, { active: !rule.active })
    queryClient.invalidateQueries({ queryKey: ['rules'] })
  }

  const handleSaved = () => {
    setShowBuilder(false)
    setEditingRule(null)
    queryClient.invalidateQueries({ queryKey: ['rules'] })
  }

  if (isLoading) return <div className="empty-state">Loading rules...</div>

  return (
    <>
      <div className="page-header">
        <h1 className="page-title">Rules</h1>
        <button className="btn btn-primary" onClick={() => { setEditingRule(null); setShowBuilder(true) }}>
          New Rule
        </button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Condition</th>
              <th>Action</th>
              <th>Priority</th>
              <th>Matches</th>
              <th>Active</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {rules.map((rule: Rule) => (
              <tr key={rule.id}>
                <td>
                  {rule.name}
                  {rule.stale && <div className="rule-warning">No matches in 60 days</div>}
                  {rule.overbroad && <div className="rule-warning">Matches &gt;50% of transactions</div>}
                </td>
                <td>
                  <span className="badge badge-blue">{formatCondition(rule.condition)}</span>
                </td>
                <td>
                  <span className="badge badge-purple">{formatAction(rule.action)}</span>
                </td>
                <td>{rule.priority}</td>
                <td>{rule.match_count}</td>
                <td>
                  <label className="toggle">
                    <input type="checkbox" checked={rule.active} onChange={() => handleToggle(rule)} />
                    <div className="toggle-track" />
                    <div className="toggle-thumb" />
                  </label>
                </td>
                <td className="actions">
                  <button className="btn btn-sm" onClick={() => { setEditingRule(rule); setShowBuilder(true) }}>Edit</button>
                  <button className="btn btn-sm btn-danger" onClick={() => handleDelete(rule)}>Delete</button>
                </td>
              </tr>
            ))}
            {rules.length === 0 && (
              <tr><td colSpan={7} className="empty-state">No rules yet. Create your first rule.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {showBuilder && (
        <>
          <div className="slide-over-backdrop" onClick={() => setShowBuilder(false)} />
          <div className="slide-over">
            <h2>{editingRule ? 'Edit Rule' : 'New Rule'}</h2>
            <RuleBuilder
              rule={editingRule}
              onSave={handleSaved}
              onCancel={() => setShowBuilder(false)}
            />
          </div>
        </>
      )}

      {confirmDialog}
    </>
  )
}
