# The phone-or-email rule replaces individually required contact fields: where it
# is on (the default), clear the old require_email/require_phone_number flags.
class RelaxContactRequireFlags < ActiveRecord::Migration[8.1]
  def up
    or_rule = select_value("SELECT value FROM settings WHERE name = 'require_phone_or_email'")
    return if or_rule == "0"

    execute("UPDATE settings SET value = '0' WHERE name IN ('require_email', 'require_phone_number')")
    Rails.cache.delete("setting/require_email")
    Rails.cache.delete("setting/require_phone_number")
  end

  def down; end
end
