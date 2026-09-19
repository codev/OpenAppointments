# The Fixed timezone switch becomes Timezone support with the opposite meaning:
# fixed on -> support off. Installs without the old row get support on.
class ReplaceFixedTimezoneWithTimezoneSupport < ActiveRecord::Migration[8.1]
  def up
    fixed = Setting.find_by(name: "fixed_timezone")
    unless Setting.exists?(name: "timezone_support")
      Setting.create!(name: "timezone_support", value: fixed&.value == "1" ? "0" : "1")
    end
    fixed&.destroy
    Rails.cache.delete("setting/fixed_timezone")
    Rails.cache.delete("setting/timezone_support")
  end

  def down
    support = Setting.find_by(name: "timezone_support")
    Setting.find_or_create_by!(name: "fixed_timezone") { |row| row.value = support&.value == "0" ? "1" : "0" }
    support&.destroy
  end
end
