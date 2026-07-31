class AddSortOrder < ActiveRecord::Migration[8.1]
  def change
    add_column :services, :sort_order, :integer
    add_column :service_categories, :sort_order, :integer
    add_column :users, :sort_order, :integer
  end
end
