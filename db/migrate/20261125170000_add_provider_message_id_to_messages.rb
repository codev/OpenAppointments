# The id a message provider gave an outgoing message, so its delivery and
# failure reports find the row.
class AddProviderMessageIdToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :provider_message_id, :string
    add_index :messages, [ :channel, :provider_message_id ]
  end
end
