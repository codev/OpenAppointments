class AddDoNotContactToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :do_not_contact, :boolean, default: false, null: false
  end
end
