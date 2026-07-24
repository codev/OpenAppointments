# Secondary and background brand colours join company_color.
class AddBrandColorSettings < ActiveRecord::Migration[8.1]
  DEFAULTS = { "company_secondary_color" => "#dd2a5c", "company_background_color" => "#f2f6fa" }.freeze

  def up
    DEFAULTS.each do |name, value|
      next if select_value("SELECT 1 FROM settings WHERE name = #{connection.quote(name)}")

      execute("INSERT INTO settings (name, value, created_at, updated_at) " \
              "VALUES (#{connection.quote(name)}, #{connection.quote(value)}, datetime('now'), datetime('now'))")
    end
  end

  def down
    execute("DELETE FROM settings WHERE name IN ('company_secondary_color', 'company_background_color')")
  end
end
