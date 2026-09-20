# Existing installs get the waiting list templates; fresh installs take them
# from db/seeds.rb with the other defaults.
class AddWaitlistNotifications < ActiveRecord::Migration[8.1]
  def up
    Notification.reset_column_information
    Messaging::Defaults.create_waitlist_notifications!
  end

  def down; end
end
