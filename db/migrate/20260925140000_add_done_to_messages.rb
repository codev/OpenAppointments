# Inbox Done: when and by whom an admin dealt with an inbound message. Only
# adds columns (ALTER TABLE ADD COLUMN on SQLite, no table rebuild).
class AddDoneToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :done_at, :datetime
    add_column :messages, :done_by_id, :integer
  end
end
