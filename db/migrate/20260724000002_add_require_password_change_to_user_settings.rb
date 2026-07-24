class AddRequirePasswordChangeToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :require_password_change, :boolean, default: false, null: false
  end
end
