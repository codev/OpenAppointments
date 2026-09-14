class AddSourceToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :source, :text
  end
end
