class AddHiddenToServiceCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :service_categories, :is_hidden, :boolean, default: false, null: false
  end
end
