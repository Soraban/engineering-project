class Rule < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :condition, presence: true
  validates :action, presence: true

  scope :active_for, ->(user_id) { where(user_id: user_id, active: true).order(:priority) }

  def stale?
    active? && last_matched_at.present? && last_matched_at < 60.days.ago && created_at < 60.days.ago
  end

  def overbroad?
    match_rate.present? && match_rate > 0.50
  end
end
