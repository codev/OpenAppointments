class BlockedPeriod < ApplicationRecord
  validates :name, :start_datetime, :end_datetime, presence: true
  validate :end_after_start

  # EA get_for_period: any date-level overlap with [start_date, end_date].
  scope :for_period, lambda { |start_date, end_date|
    where(<<~SQL.squish, s: start_date, e: end_date)
      (DATE(start_datetime) <= :s AND DATE(end_datetime) >= :e)
      OR (DATE(start_datetime) >= :s AND DATE(end_datetime) <= :e)
      OR (DATE(end_datetime) > :s AND DATE(end_datetime) < :e)
      OR (DATE(start_datetime) > :s AND DATE(start_datetime) < :e)
    SQL
  }

  scope :covering_date, ->(date) { where("DATE(start_datetime) <= ? AND DATE(end_datetime) >= ?", date, date) }

  # EA quirk (is_entire_date_blocked): blocked only when MORE THAN ONE period covers the date.
  def self.entire_date_blocked?(date)
    covering_date(date).count > 1
  end

  private

  def end_after_start
    return unless start_datetime && end_datetime

    errors.add(:end_datetime, "must be after start") if end_datetime <= start_datetime
  end
end
