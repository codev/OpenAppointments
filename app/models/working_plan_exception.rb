# Per-provider override of the weekly working plan for a date range.
# start_time/end_time nil means the day is off. breaks is a JSON array of {start, end}.
class WorkingPlanException < ApplicationRecord
  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider,
                        inverse_of: :working_plan_exceptions

  validates :start_date, :end_date, presence: true

  scope :covering, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }

  # EA get_by_provider: expand ranges into {"YYYY-MM-DD" => {start, end, breaks} | nil (day off)}.
  # Later exceptions overwrite earlier ones on overlapping dates (start_date order).
  def self.expanded_for(provider_id)
    result = {}
    where(id_users_provider: provider_id).order(:start_date).each do |exception|
      (exception.start_date..exception.end_date).each do |date|
        result[date.strftime("%Y-%m-%d")] =
          if exception.start_time.blank?
            nil
          else
            { "start" => exception.start_time, "end" => exception.end_time, "breaks" => exception.break_list }
          end
      end
    end
    result
  end

  def break_list
    breaks.present? ? JSON.parse(breaks) : []
  end

  def day_off?
    start_time.blank? || end_time.blank?
  end
end
