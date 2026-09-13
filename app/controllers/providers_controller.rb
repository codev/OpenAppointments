# Providers admin: Rails views inside Turbo Frames. The working plan editor
# (utils/working_plan.js) writes its JSON into hidden settings fields.
class ProvidersController < ApplicationController
  include UserPage

  PAGE = { resource: :users, menu: "users", title: "providers", role: Role::PROVIDER,
           save_webhook: Webhooks::PROVIDER_SAVE, delete_webhook: Webhooks::PROVIDER_DELETE,
           saved: "provider_saved", deleted: "provider_deleted" }.freeze

  before_action(only: %i[regenerate_link sort_alphabetically]) { require_privilege }

  # POST /providers/:id/regenerate_link
  def regenerate_link
    provider = record_scope.find(params[:id])
    provider.update_columns(booking_slug: BookingSlug.unique_for(User))
    redirect_to edit_provider_path(provider)
  end

  # POST /providers/reorder - persist the dragged order (1-based).
  def reorder
    raise ArgumentError, "Forbidden" if cannot?(:edit, :users)

    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    raise ArgumentError, "No order provided." if ids.empty?

    ActiveRecord::Base.transaction do
      ids.each_with_index { |id, index| User.providers.where(id: id).update_all(sort_order: index + 1) }
    end
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /providers/sort_alphabetically - clear the manual order.
  def sort_alphabetically
    User.providers.update_all(sort_order: nil)
    redirect_to providers_path
  end

  private

  def record_scope = User.providers.display_order.includes(:settings, :services)

  def page_vars = script_vars(first_weekday: Setting.get("first_weekday"))

  def record_params
    super.merge(user_fields.permit(:about, :services_description))
  end

  def setting_params
    super.merge(user_fields.fetch(:settings, {}).permit(:working_plan, :working_plan_exceptions).to_h)
  end

  # EA optional field: a new provider's working plan defaults to the company plan.
  def settings_to_apply
    settings = super
    settings[:working_plan] = Setting.get("company_working_plan") if @record.settings.nil? && settings[:working_plan].blank?
    settings
  end

  def after_save
    super
    return unless user_fields.key?(:services)

    @record.provider_service_links.delete_all
    Array(user_fields[:services]).compact_blank.each do |service_id|
      ServiceProviderLink.create!(id_users: @record.id, id_services: service_id)
    end
  end
end
