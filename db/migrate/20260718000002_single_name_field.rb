class SingleNameField < ActiveRecord::Migration[8.1]
  # One name field replaces first/last (EA required a surname; we do not).
  def up
    add_column :users, :name, :string
    execute "UPDATE users SET name = TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))"
    remove_column :users, :first_name
    remove_column :users, :last_name

    add_column :consents, :name, :string
    execute "UPDATE consents SET name = TRIM(COALESCE(first_name, '') || ' ' || COALESCE(last_name, ''))"
    remove_column :consents, :first_name
    remove_column :consents, :last_name
  end

  def down
    [ :users, :consents ].each do |table|
      add_column table, :first_name, :string
      add_column table, :last_name, :string
      execute <<~SQL.squish
        UPDATE #{table} SET
          first_name = CASE WHEN INSTR(name, ' ') > 0 THEN SUBSTR(name, 1, INSTR(name, ' ') - 1) ELSE name END,
          last_name  = CASE WHEN INSTR(name, ' ') > 0 THEN SUBSTR(name, INSTR(name, ' ') + 1) ELSE '' END
      SQL
      remove_column table, :name
    end
  end
end
