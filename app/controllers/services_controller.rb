# Services admin: Rails views inside Turbo Frames.
class ServicesController < ApplicationController
  include CrudPage
  include RecordPicture

  PAGE = { resource: :services, menu: "services", title: "services",
           save_webhook: Webhooks::SERVICE_SAVE, delete_webhook: Webhooks::SERVICE_DELETE,
           saved: "service_saved", deleted: "service_deleted" }.freeze

  before_action(only: %i[regenerate_link sort_alphabetically]) { require_privilege }

  def new
    @record = Service.new(name: "Service", duration: 30, price: 0, slot_interval: 15, attendants_number: 1)
    @editing = true
    render_page
  end

  # POST /services/:id/regenerate_link
  def regenerate_link
    service = Service.find(params[:id])
    service.update_columns(booking_slug: BookingSlug.unique_for(Service))
    redirect_to edit_service_path(service)
  end

  # POST /services/reorder - persist the dragged order (1-based).
  def reorder
    raise ArgumentError, "Forbidden" if cannot?(:edit, :services)

    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    raise ArgumentError, "No order provided." if ids.empty?

    ActiveRecord::Base.transaction do
      ids.each_with_index { |id, index| Service.where(id: id).update_all(sort_order: index + 1) }
    end
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /services/sort_alphabetically - clear the manual order.
  def sort_alphabetically
    Service.update_all(sort_order: nil)
    redirect_to services_path
  end

  private

  def record_scope = Service.display_order.includes(:category)

  def filter(scope, keyword)
    return scope if keyword.blank?

    pattern = "%#{Service.sanitize_sql_like(keyword)}%"
    scope.where("services.name LIKE :pattern OR services.description LIKE :pattern", pattern: pattern)
  end

  def record_params
    params.require(:service).permit(:name, :duration, :price, :currency, :description, :color, :location,
                                    :slot_interval, :attendants_number, :is_private, :id_service_categories)
  end

  def after_save
    fields = params[:service]
    save_record_picture(@record, fields)
    return unless fields.key?(:providers)

    @record.provider_links.delete_all
    Array(fields[:providers]).compact_blank.each do |provider_id|
      ServiceProviderLink.create!(id_services: @record.id, id_users: provider_id)
    end
  end
end
