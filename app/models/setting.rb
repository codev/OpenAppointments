# Global key/value settings, ported from EA's settings table. Values are always
# strings ("1"/"0" flags, JSON blobs); do not add typed columns.
class Setting < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  # Rich text edited on the Legal Contents page and rendered as HTML on the
  # public pages, so it is sanitised here whichever path writes it.
  RICH_TEXT_SETTINGS = %w[booking_notice_content cookie_notice_content terms_and_conditions_content
                          privacy_policy_content].freeze

  # The editor writes alignment as an inline style; the sanitiser keeps only
  # safe CSS properties within it.
  RICH_TEXT_ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes + [ "style" ]).freeze

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

  def self.sanitize_rich_text(html)
    Rails::HTML5::SafeListSanitizer.new.sanitize(html.to_s, attributes: RICH_TEXT_ATTRIBUTES)
  end

  def self.get_many(*names)
    names.flatten.index_with { |name| get(name) }
  end
end
