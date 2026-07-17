class Appointment < ApplicationRecord
  EVENT_MINIMUM_DURATION = 5 # minutes, EA constant

  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider,
                        inverse_of: :provider_appointments, optional: true
  belongs_to :customer, class_name: "User", foreign_key: :id_users_customer,
                        inverse_of: :customer_appointments, optional: true
  belongs_to :service, foreign_key: :id_services, optional: true

  scope :appointments, -> { where(is_unavailability: false) }
  scope :unavailabilities, -> { where(is_unavailability: true) }
  scope :overlapping, ->(start_dt, end_dt) { where("start_datetime < ? AND end_datetime > ?", end_dt, start_dt) }

  before_create :generate_booking_hash

  validates :start_datetime, :end_datetime, presence: true
  validates :id_users_provider, presence: true
  validates :id_users_customer, :id_services, presence: true, unless: :is_unavailability
  validate :minimum_duration

  def duration_minutes
    return 0 unless start_datetime && end_datetime

    ((end_datetime - start_datetime) / 60).to_i
  end

  private

  def generate_booking_hash
    self.booking_hash ||= SecureRandom.alphanumeric(12)
  end

  def minimum_duration
    return unless start_datetime && end_datetime
    if end_datetime <= start_datetime
      errors.add(:end_datetime, "must be after start")
    elsif duration_minutes < EVENT_MINIMUM_DURATION
      errors.add(:base, "duration must be at least #{EVENT_MINIMUM_DURATION} minutes")
    end
  end
end
