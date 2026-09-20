# A customer waiting for a slot: matched against freed slots and the daily
# availability check until the entry expires or they unsubscribe. Signing up
# copies the service duration so a later service edit does not change what
# the customer asked for.
class WaitlistEntry < ApplicationRecord
  belongs_to :service
  belongs_to :provider, class_name: "User", optional: true

  validates :name, :email, presence: true
  before_validation :set_defaults, on: :create

  scope :live, ->(now = Time.current) { where("expires_at > ?", now) }
  scope :oldest_first, -> { order(:created_at, :id) }

  def self.days = Setting.get("waitlist_days", "14").to_i
  def self.max_notices = Setting.get("waitlist_max_notices", "7").to_i

  # Live entries a freed slot of this length with this provider could serve:
  # the slot fits their duration, the provider offers their service and they
  # either chose this provider or any. Longest waiting first.
  def self.for_freed_slot(provider, minutes, now = Time.current)
    live(now).oldest_first
             .where("duration <= ?", minutes)
             .where(provider_id: [ nil, provider.id ])
             .where(service_id: provider.services.select(:id))
             .select(&:notices_left?)
  end

  def notices_left? = notices_sent < self.class.max_notices
  def expired?(now = Time.current) = expires_at <= now

  # Message channels address a recipient like a user.
  def phone_number = phone
  def mobile_number = nil

  private

  def set_defaults
    self.duration ||= service&.duration
    self.expires_at ||= self.class.days.days.from_now
    self.unsubscribe_token ||= SecureRandom.alphanumeric(24)
  end
end
