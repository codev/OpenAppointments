# Installs that ran 2.2.0 carry the other emails and phones columns; fresh
# installs never had them.
#
# SQLite drops the columns in place. remove_column would rebuild the users
# table, and inside the migration transaction the foreign keys stay on, so
# dropping the old table cascades and deletes every user's settings,
# appointments and links.
class RemoveOtherContactsFromUsers < ActiveRecord::Migration[8.1]
  def up
    execute "ALTER TABLE users DROP COLUMN other_emails" if column_exists?(:users, :other_emails)
    execute "ALTER TABLE users DROP COLUMN other_phones" if column_exists?(:users, :other_phones)
  end

  def down; end
end
