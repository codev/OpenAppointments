# A notification template managed on Messages > Notifications. audiences and
# channels are JSON string arrays.
class Notification < ApplicationRecord
  # Dropdown order; coming_up stays on top.
  EVENTS = %w[coming_up created created_or_updated updated cancelled missed].freeze
  AUDIENCES = %w[customer provider admins].freeze
  LEAD_MODES = %w[before day_at].freeze
  # Cancelled templates: every cancellation, only those made before the Book
  # Advance Timeout closes (in time), or only those made inside it (too late).
  CANCELLATION_SCOPES = %w[all in_time late].freeze

  # Which template events fire for a concrete trigger.
  TRIGGER_EVENTS = {
    created: %w[created created_or_updated],
    updated: %w[updated created_or_updated],
    cancelled: %w[cancelled],
    missed: %w[missed]
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
  # the start it was cancelled relative to the Book Advance Timeout (minutes).
  def applies_to_cancellation?(appointment, now = Time.current)
    return true if cancellation_scope == "all" || appointment&.start_datetime.nil?

    timeout_minutes = [ Setting.get("book_advance_timeout", "0").to_i, 0 ].max
    in_time = appointment.start_datetime - now >= timeout_minutes * 60
    cancellation_scope == "in_time" ? in_time : !in_time
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
