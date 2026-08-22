class AddCancellationScopeToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :cancellation_scope, :string, default: "all", null: false
  end
end
