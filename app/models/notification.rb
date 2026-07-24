# A notification template managed on Messages > Notifications. audiences and
# channels are JSON string arrays.
class Notification < ApplicationRecord
  # Dropdown order; coming_up stays on top.
  EVENTS = %w[coming_up created created_or_updated updated cancelled missed].freeze
  AUDIENCES = %w[customer provider admins].freeze
  LEAD_MODES = %w[before day_at].freeze

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
  validates :lead_days, numericality: { greater_than_or_equal_to: 0 }
  validates :lead_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :send_time, format: { with: /\A\d{2}:\d{2}\z/ }

  scope :coming_up, -> { where(event: "coming_up") }

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
