class DefaultCompanyColor < ActiveRecord::Migration[8.1]
  # "#ffffff" was the seeded "no colour" sentinel; the default is now green.
  # Installs that kept white (unset) pick up the new default; custom colours stay.
  def up
    execute <<~SQL.squish
      UPDATE settings SET value = '#39824f'
      WHERE name = 'company_color' AND value = '#ffffff'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE settings SET value = '#ffffff'
      WHERE name = 'company_color' AND value = '#39824f'
    SQL
  end
end
