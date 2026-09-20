# A notification template managed on Messages > Notifications. audiences and
# channels are JSON string arrays.
class Notification < ApplicationRecord
  # Dropdown order; coming_up stays on top. customer_message fires when an
  # incoming message from a known customer arrives; the waitlist events go to
  # waiting list signups, not to the audiences.
  EVENTS = %w[coming_up created created_or_updated updated cancelled missed customer_message
              waitlist_slot_freed waitlist_daily].freeze
  AUDIENCES = %w[customer provider admins].freeze
  LEAD_MODES = %w[before day_at].freeze
  # Cancelled templates: every cancellation, only those made before the late
  # cancellation window closes (in time), or only those made inside it (too late).
  CANCELLATION_SCOPES = %w[all in_time late].freeze

  # Which template events fire for a concrete trigger.
  TRIGGER_EVENTS = {
    created: %w[created created_or_updated],
    updated: %w[updated created_or_updated],
    cancelled: %w[cancelled],
    missed: %w[missed],
    customer_message: %w[customer_message],
    waitlist_slot_freed: %w[waitlist_slot_freed],
    waitlist_daily: %w[waitlist_daily]
  }.freeze

  serialize :audiences, coder: JSON
  serialize :channels, coder: JSON

  validates :title, presence: true
  validates :event, inclusion: { in: EVENTS }
  validates :lead_mode, inclusion: { in: LEAD_MODES }
  validates :cancellation_scope, inclusion: { in: CANCELLATION_SCOPES }
  validates :lead_days, numericality: { greater_than_or_equal_to: 0 }
  validates :lead_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :send_time, format: { with: /\A\d{2}:\d{2}\z/ }

  scope :coming_up, -> { where(event: "coming_up") }

  # Whether a cancelled template applies to this appointment, by how close to
  # the start it was cancelled relative to the late cancellation window.
  def applies_to_cancellation?(appointment, now = Time.current)
    return true if cancellation_scope == "all" || appointment&.start_datetime.nil?

    late = appointment.status_kind == "late_cancel" || BookingWindows.late?(appointment, now)
    cancellation_scope == "in_time" ? !late : late
  end

  def self.for_trigger(trigger)
    where(event: TRIGGER_EVENTS.fetch(trigger))
  end

  def audience?(audience)
    Array(audiences).include?(audience.to_s)
  end

  def channel?(channel)
    Array(channels).include?(channel.to_s)
  end
end
