class Appointment < ApplicationRecord
  EVENT_MINIMUM_DURATION = 5 # minutes, EA constant

  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider,
                        inverse_of: :provider_appointments, optional: true
  belongs_to :customer, class_name: "User", foreign_key: :id_users_customer,
                        inverse_of: :customer_appointments, optional: true
  belongs_to :service, foreign_key: :id_services, optional: true
  belongs_to :series, class_name: "AppointmentSeries", foreign_key: :series_id,
                      inverse_of: :appointments, optional: true
  belongs_to :appointment_status, foreign_key: :status_id, inverse_of: :appointments, optional: true
  belongs_to :rescheduled_to, class_name: "Appointment", optional: true

  scope :appointments, -> { where(is_unavailability: false) }
  scope :unavailabilities, -> { where(is_unavailability: true) }
  scope :overlapping, ->(start_dt, end_dt) { where("start_datetime < ? AND end_datetime > ?", end_dt, start_dt) }
  # Rows whose status kind is not one of the given (no status counts as active).
  scope :not_kind, lambda { |kinds|
    where(status_id: nil).or(where.not(status_id: AppointmentStatus.where(kind: kinds).select(:id)))
  }
  # Rows that still occupy their slot: anything not cancelled, late cancelled or rescheduled.
  scope :active, -> { not_kind(AppointmentStatus::FREE_SLOT_KINDS) }

  # EA availability query: events whose date range covers the given date, per provider.
  scope :covering_date, lambda { |date, provider_id, exclude_appointment_id = nil|
    relation = active.where(id_users_provider: provider_id)
                     .where("DATE(start_datetime) <= ? AND DATE(end_datetime) >= ?", date, date)
    relation = relation.where.not(id: exclude_appointment_id) if exclude_appointment_id
    relation
  }

  # The next appointment to start and the latest one already started, by real
  # start time. Stored starts are the stylist's wall clock, so rows within a
  # day of now are decided by BookingWindows.starts_at; beyond that the stored
  # order is enough.
  def self.next_and_last(scope, now = Time.current)
    rows = scope.includes(:provider)
    near = rows.where(start_datetime: (now - 1.day)..(now + 1.day)).to_a
    started, upcoming = near.partition { |appointment| BookingWindows.starts_at(appointment) < now }
    [
      upcoming.min_by { |appointment| BookingWindows.starts_at(appointment) } ||
        rows.where("start_datetime > ?", now + 1.day).order(:start_datetime).first,
      started.max_by { |appointment| BookingWindows.starts_at(appointment) } ||
        rows.where("start_datetime < ?", now - 1.day).order(start_datetime: :desc).first
    ]
  end

  # EA has_provider_conflict: (existing_start < new_end) AND (existing_end > new_start).
  def self.provider_conflict?(provider_id, start_datetime, end_datetime, exclude_appointment_id = nil)
    relation = active.where(id_users_provider: provider_id).overlapping(start_datetime, end_datetime)
    relation = relation.where.not(id: exclude_appointment_id) if exclude_appointment_id
    relation.exists?
  end

  before_create :generate_booking_hash

  validates :start_datetime, :end_datetime, presence: true
  validates :id_users_provider, presence: true
  validates :id_users_customer, :id_services, presence: true, unless: :is_unavailability
  validate :minimum_duration

  # Status by name, for the API, imports, templates and the calendar payloads.
  def status = appointment_status&.name.to_s

  def status=(name)
    self.appointment_status = AppointmentStatus.resolve(name)
  end

  def status_kind = appointment_status&.kind || "custom"

  def frees_slot? = appointment_status&.frees_slot? || false

  # Mark cancelled (or late cancelled) keeping the row; the slot becomes bookable.
  def cancel!(kind: "cancelled", reason: nil)
    self.appointment_status = AppointmentStatus.of(kind)
    self.notes = [ notes.presence, reason.presence ].compact.join("\n")
    save!
  end

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
