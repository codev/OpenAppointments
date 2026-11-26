# Global key/value settings, ported from EA's settings table. Values are always
# strings ("1"/"0" flags, JSON blobs); do not add typed columns.
class Setting < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  # Rich text edited on the Legal Contents page and rendered as HTML on the
  # public pages, so it is sanitised here whichever path writes it.
  RICH_TEXT_SETTINGS = %w[booking_notice_service_content booking_notice_provider_content
                          booking_notice_time_content booking_notice_info_content booking_notice_final_content
                          booking_notice_confirmed_content
                          fully_booked_notice_content cookie_notice_content
                          terms_and_conditions_content privacy_policy_content].freeze

  def self.get(name, default = nil)
    Rails.cache.fetch("setting/#{name}") { where(name: name).pick(:value) } || default
  end

  def self.set(name, value)
    value = sanitize_rich_text(value) if RICH_TEXT_SETTINGS.include?(name)
    record = find_or_initialize_by(name: name)
    record.update!(value: value.to_s)
    Rails.cache.delete("setting/#{name}")
    record
  end

  # Timezone support on (the default) shows timezone fields and honours each
  # user's zone; off, every user and booking runs on default_timezone.
  def self.timezone_support?
    get("timezone_support", "1") == "1"
  end

  def self.sanitize_rich_text(html) = RichText.sanitize(html)

  def self.get_many(*names)
    names.flatten.index_with { |name| get(name) }
  end
end
