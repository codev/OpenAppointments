# Phones in E.164 with indexes, so inbound SMS and shared-contact lookups are
# exact indexed matches. Rows are rewritten with UPDATE and indexes created:
# no table rebuild, so nothing that references users is touched.
class StorePhonesAsE164 < ActiveRecord::Migration[8.1]
  def up
    normalize("users", %w[phone_number mobile_number])
    normalize("waitlist_entries", %w[phone])
    add_index :users, :phone_number unless index_exists?(:users, :phone_number)
    add_index :users, :mobile_number unless index_exists?(:users, :mobile_number)
  end

  def down
    remove_index :users, :phone_number if index_exists?(:users, :phone_number)
    remove_index :users, :mobile_number if index_exists?(:users, :mobile_number)
  end

  private

  def normalize(table, columns)
    columns.each do |column|
      select_rows("SELECT id, #{column} FROM #{table} WHERE #{column} IS NOT NULL").each do |id, value|
        normalized = Messaging::Template.e164(value)
        next if normalized == value

        # connection.quote: a migration's own quote turns nil into '' instead of NULL.
        update("UPDATE #{table} SET #{column} = #{connection.quote(normalized)} WHERE id = #{id.to_i}")
      end
    end
  end
end
