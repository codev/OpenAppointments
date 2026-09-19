# Existing installs get the Customer Message Received template; fresh installs
# take it from db/seeds.rb with the other defaults.
class AddCustomerMessageNotification < ActiveRecord::Migration[8.1]
  def up
    Notification.reset_column_information
    Messaging::Defaults.create_customer_message_notification!
  end

  def down; end
end
