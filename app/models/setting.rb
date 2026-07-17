# Global key/value settings, ported from EA's settings table. Values are always
# strings ("1"/"0" flags, JSON blobs); do not add typed columns.
class Setting < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  def self.get(name, default = nil)
    Rails.cache.fetch("setting/#{name}") { where(name: name).pick(:value) } || default
  end

  def self.set(name, value)
    record = find_or_initialize_by(name: name)
    record.update!(value: value.to_s)
    Rails.cache.delete("setting/#{name}")
    record
  end

  def self.get_many(*names)
    names.flatten.index_with { |name| get(name) }
  end
end
