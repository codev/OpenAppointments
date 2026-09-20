class AddCalendarFeedTokenToUserSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :user_settings, :calendar_feed_token, :string
    add_index :user_settings, :calendar_feed_token, unique: true
  end
end
