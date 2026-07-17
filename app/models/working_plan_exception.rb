# Per-provider override of the weekly working plan for a date range.
# start_time/end_time nil means the day is off. breaks is a JSON array of {start, end}.
class WorkingPlanException < ApplicationRecord
  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider,
                        inverse_of: :working_plan_exceptions

  validates :start_date, :end_date, presence: true

  scope :covering, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }

  def break_list
    breaks.present? ? JSON.parse(breaks) : []
  end

  def day_off?
    start_time.blank? || end_time.blank?
  end
end
