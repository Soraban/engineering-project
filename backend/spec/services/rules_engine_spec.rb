require 'rails_helper'

RSpec.describe RulesEngine do
  let(:user) { create(:user) }

  describe 'description_contains operator' do
    it 'assigns category when description matches (case-insensitive)' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      tx = create(:transaction, user: user, description: 'AMAZON PURCHASE', category: nil)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.category).to eq('Shopping')
    end

    it 'does not match when description is nil' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      tx = create(:transaction, user: user, description: nil, category: nil)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.category).to be_nil
    end
  end

  describe 'amount_gt operator' do
    it 'flags as high value when amount exceeds threshold' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'amount', 'operator' => 'gt', 'value' => '1000' },
        action: { 'type' => 'flag_high_value' })
      tx = create(:transaction, user: user, amount: 1500.00)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.anomaly_flags).to include('high_value')
    end

    it 'does not flag when amount is below threshold' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'amount', 'operator' => 'gt', 'value' => '1000' },
        action: { 'type' => 'flag_high_value' })
      tx = create(:transaction, user: user, amount: 99.99)

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.anomaly_flags).to be_empty
    end
  end

  describe 'description_matches (regex) operator' do
    it 'matches using case-insensitive regex' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'matches', 'value' => 'rent|lease' },
        action: { 'type' => 'set_category', 'value' => 'Housing' })
      tx = create(:transaction, user: user, description: 'Monthly Lease Payment')

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.category).to eq('Housing')
    end

    it 'does not crash on malformed regex — falls back gracefully' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'matches', 'value' => '[invalid(' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      tx = create(:transaction, user: user, description: 'Some purchase')

      expect { RulesEngine.apply(tx, rules: [rule]) }.not_to raise_error
    end
  end

  describe 'first-match-wins conflict resolution' do
    it 'first rule wins when both match the same action type' do
      rule1 = create(:rule, user: user, priority: 1,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'store' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      rule2 = create(:rule, user: user, priority: 2,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'store' },
        action: { 'type' => 'set_category', 'value' => 'Other' })
      tx = create(:transaction, user: user, description: 'Grocery Store', category: nil)

      RulesEngine.apply(tx, rules: [rule1, rule2])
      expect(tx.reload.category).to eq('Shopping')
    end

    it 'allows continue_processing to apply multiple actions' do
      rule1 = create(:rule, user: user, priority: 1, continue_processing: true,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      rule2 = create(:rule, user: user, priority: 2,
        condition: { 'field' => 'amount', 'operator' => 'gt', 'value' => '1000' },
        action: { 'type' => 'flag_high_value' })
      tx = create(:transaction, user: user, description: 'Amazon Purchase', amount: 1500, category: nil)

      RulesEngine.apply(tx, rules: [rule1, rule2])
      tx.reload
      expect(tx.category).to eq('Shopping')
      expect(tx.anomaly_flags).to include('high_value')
    end

    it 'breaks priority ties deterministically by id when default-fetched (older rule wins)' do
      # Two rules with the SAME priority — without the (:priority, :id) tiebreaker
      # the winner would be whichever Postgres returns first, which is undefined.
      first = create(:rule, user: user, priority: 5,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'rideshare' },
        action: { 'type' => 'set_category', 'value' => 'Travel' })
      _second = create(:rule, user: user, priority: 5,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'rideshare' },
        action: { 'type' => 'set_category', 'value' => 'Transportation' })
      tx = create(:transaction, user: user, description: 'Rideshare to airport', category: nil)

      RulesEngine.apply(tx)  # no rules: kwarg — exercises the DB-fetched default ordering

      # First-created (lower id) wins the tie
      expect(tx.reload.category).to eq('Travel')
      expect(first.id).to be < Rule.order(:id).last.id
    end
  end

  describe 'inactive rules' do
    it 'skips rules where active is false' do
      rule = create(:rule, user: user, active: false,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'amazon' },
        action: { 'type' => 'set_category', 'value' => 'Shopping' })
      tx = create(:transaction, user: user, description: 'Amazon Purchase', category: nil)

      RulesEngine.apply(tx)
      expect(tx.reload.category).to be_nil
    end
  end

  describe 'add_tag action' do
    it 'adds a tag to transaction metadata' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'recurring' },
        action: { 'type' => 'add_tag', 'value' => 'subscription' })
      tx = create(:transaction, user: user, description: 'Recurring Netflix')

      RulesEngine.apply(tx, rules: [rule])
      expect(tx.reload.metadata['tags']).to include('subscription')
    end
  end

  describe 'rule health tracking' do
    it 'increments match_count and updates last_matched_at on match' do
      rule = create(:rule, user: user,
        condition: { 'field' => 'description', 'operator' => 'contains', 'value' => 'test' },
        action: { 'type' => 'set_category', 'value' => 'Test' })
      tx = create(:transaction, user: user, description: 'Test Transaction')

      RulesEngine.apply(tx, rules: [rule])
      rule.reload
      expect(rule.match_count).to eq(1)
      expect(rule.last_matched_at).to be_present
    end
  end
end
