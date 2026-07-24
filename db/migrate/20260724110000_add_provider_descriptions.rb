class AddProviderDescriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :about, :text
    add_column :users, :services_description, :text
  end
end
