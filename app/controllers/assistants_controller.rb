# Assistants admin: Rails views inside Turbo Frames.
class AssistantsController < ApplicationController
  include UserPage

  PAGE = { resource: :users, menu: "users", title: "assistants", role: Role::ASSISTANT,
           save_webhook: Webhooks::ASSISTANT_SAVE, delete_webhook: Webhooks::ASSISTANT_DELETE,
           saved: "assistant_saved", deleted: "assistant_deleted" }.freeze

  private

  def record_scope = super.includes(:providers)

  # EA Assistants_model::save_provider_ids: re-insert the join rows.
  def after_save
    super
    return unless user_fields.key?(:providers)

    @record.assistant_provider_links.delete_all
    Array(user_fields[:providers]).compact_blank.each do |provider_id|
      AssistantProviderLink.create!(id_users_assistant: @record.id, id_users_provider: provider_id)
    end
  end
end
