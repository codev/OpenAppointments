class AddOtherContactsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :other_emails, :text
    add_column :users, :other_phones, :text
  end
end
