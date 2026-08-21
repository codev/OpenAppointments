class RemoveCalendarViewFromUserSettings < ActiveRecord::Migration[8.1]
  def change
    remove_column :user_settings, :calendar_view, :string, default: "default"
  end
end
