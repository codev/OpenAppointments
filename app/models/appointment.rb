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

  # EA availability query: events whose date range covers the given date, per provider.
  scope :covering_date, lambda { |date, provider_id, exclude_appointment_id = nil|
    relation = where(id_users_provider: provider_id)
               .where("DATE(start_datetime) <= ? AND DATE(end_datetime) >= ?", date, date)
    relation = relation.where.not(id: exclude_appointment_id) if exclude_appointment_id
    relation
  }

  # EA slot occupancy: (start <= S AND end > S) OR (start < E AND end >= E).
  def self.slot_occupancy(slot_start, slot_end, provider_id, exclude_appointment_id)
    relation = where(id_users_provider: provider_id)
               .where("(start_datetime <= :s AND end_datetime > :s) OR (start_datetime < :e AND end_datetime >= :e)",
                      s: slot_start, e: slot_end)
    relation = relation.where.not(id: exclude_appointment_id) if exclude_appointment_id
    relation
  end

  def self.attendants_for_period(slot_start, slot_end, service_id, provider_id, exclude_appointment_id = nil)
    slot_occupancy(slot_start, slot_end, provider_id, exclude_appointment_id).where(id_services: service_id).count
  end

  def self.other_service_attendants(slot_start, slot_end, service_id, provider_id, exclude_appointment_id = nil)
    slot_occupancy(slot_start, slot_end, provider_id, exclude_appointment_id)
      .where.not(id_services: service_id).where.not(id_services: nil).count
  end

  # EA has_provider_conflict: (existing_start < new_end) AND (existing_end > new_start).
  def self.provider_conflict?(provider_id, start_datetime, end_datetime, exclude_appointment_id = nil)
    relation = where(id_users_provider: provider_id).overlapping(start_datetime, end_datetime)
    relation = relation.where.not(id: exclude_appointment_id) if exclude_appointment_id
    relation.exists?
  end

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
