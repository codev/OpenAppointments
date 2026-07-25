class RenameSecretaryToAssistant < ActiveRecord::Migration[8.1]
  def up
    rename_table :secretaries_providers, :assistants_providers
    rename_column :assistants_providers, :id_users_secretary, :id_users_assistant

    execute "UPDATE roles SET slug = 'assistant' WHERE slug = 'secretary'"
    execute <<~SQL.squish
      UPDATE webhooks SET actions =
        REPLACE(REPLACE(actions, 'secretary_save', 'assistant_save'),
                'secretary_delete', 'assistant_delete')
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE webhooks SET actions =
        REPLACE(REPLACE(actions, 'assistant_save', 'secretary_save'),
                'assistant_delete', 'secretary_delete')
    SQL
    execute "UPDATE roles SET slug = 'secretary' WHERE slug = 'assistant'"

    rename_column :assistants_providers, :id_users_assistant, :id_users_secretary
    rename_table :assistants_providers, :secretaries_providers
  end
end
