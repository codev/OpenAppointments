class BlockedPeriod < ApplicationRecord
  validates :name, :start_datetime, :end_datetime, presence: true
  validate :end_after_start

  scope :for_period, ->(start_dt, end_dt) { where("start_datetime < ? AND end_datetime > ?", end_dt, start_dt) }

  def self.entire_date_blocked?(date)
    day_start = date.to_time
    day_end = day_start + 1.day
    where("start_datetime <= ? AND end_datetime >= ?", day_start, day_end).exists?
  end

  private

  def end_after_start
    return unless start_datetime && end_datetime

    errors.add(:end_datetime, "must be after start") if end_datetime <= start_datetime
  end
end
