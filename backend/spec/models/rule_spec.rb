require 'rails_helper'

RSpec.describe Rule, type: :model do
  let(:user) { create(:user) }

  describe 'associations' do
    it 'belongs to a user' do
      rule = create(:rule, user: user)
      expect(rule.user).to eq(user)
    end
  end

  describe 'JSONB condition + action storage' do
    it 'persists the condition hash with string keys (matches RulesEngine expectations)' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' })

      expect(rule.reload.condition).to eq(
        'field' => 'description', 'operator' => 'contains', 'value' => 'amazon'
      )
    end

    it 'persists the action hash with string keys' do
      rule = create(:rule, user: user,
        action: { 'type' => 'set_category', 'value' => 'Shopping' })

      expect(rule.reload.action).to eq('type' => 'set_category', 'value' => 'Shopping')
    end
  end

  describe 'defaults' do
    it 'defaults active to true' do
      rule = create(:rule, user: user)
      expect(rule.active).to be true
    end

    it 'defaults continue_processing to false' do
      rule = create(:rule, user: user)
      expect(rule.continue_processing).to be false
    end

    it 'defaults priority to 0' do
      rule = Rule.new(user: user, name: 'X',
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'x' },
        action: { 'type' => 'set_category', 'value' => 'Other' })
      rule.save!
      expect(rule.priority).to eq(0)
    end

    it 'defaults match_count to 0' do
      rule = create(:rule, user: user)
      expect(rule.match_count).to eq(0)
    end
  end

  describe 'match tracking' do
    it 'increments match_count and last_matched_at when the engine fires the action' do
      rule = create(:rule, user: user, priority: 1,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      tx = create(:transaction, user: user, description: 'Amazon Purchase', category: nil)

      expect {
        RulesEngine.apply(tx, rules: [rule])
      }.to change { rule.reload.match_count }.from(0).to(1)

      expect(rule.last_matched_at).to be_within(2.seconds).of(Time.current)
    end
  end
end
