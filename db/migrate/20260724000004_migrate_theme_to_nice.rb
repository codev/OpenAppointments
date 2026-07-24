# The bootswatch-era themes are gone; anything not in the new set becomes nice.
class MigrateThemeToNice < ActiveRecord::Migration[8.1]
  NEW_THEMES = %w[brutalism coder fruit material nice outline solid].freeze

  def up
    placeholders = NEW_THEMES.map { |theme| connection.quote(theme) }.join(", ")
    execute("UPDATE settings SET value = 'nice' WHERE name = 'theme' AND value NOT IN (#{placeholders})")
    Rails.cache.delete("setting/theme")
  end

  def down; end
end
