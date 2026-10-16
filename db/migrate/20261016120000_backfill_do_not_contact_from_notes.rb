# Customers imported before the do_not_contact column carried the flag as a
# notes prefix. Rows only: no table rebuild.
class BackfillDoNotContactFromNotes < ActiveRecord::Migration[8.1]
  PREFIX = "[DO NOT CONTACT - consent not granted]".freeze

  def up
    execute <<~SQL.squish
      UPDATE users
      SET do_not_contact = 1, notes = TRIM(SUBSTR(notes, #{PREFIX.length + 1}))
      WHERE notes LIKE #{connection.quote("#{PREFIX}%")}
    SQL
  end

  def down; end
end
