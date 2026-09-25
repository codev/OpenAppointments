# Installs that ran 2.2.0 carry the other emails and phones columns; fresh
# installs never had them.
class RemoveOtherContactsFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_column :users, :other_emails if column_exists?(:users, :other_emails)
    remove_column :users, :other_phones if column_exists?(:users, :other_phones)
  end

  def down; end
end
