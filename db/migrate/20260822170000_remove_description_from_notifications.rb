class RemoveDescriptionFromNotifications < ActiveRecord::Migration[8.1]
  def change
    remove_column :notifications, :description, :string
  end
end
