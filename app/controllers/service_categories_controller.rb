# Service categories admin: Rails views inside Turbo Frames. search stays as JSON
# for the services page category select.
class ServiceCategoriesController < ApplicationController
  include CrudPage
  include RecordPicture

  PAGE = { resource: :services, menu: "services", title: "service_categories",
           save_webhook: Webhooks::SERVICE_CATEGORY_SAVE, delete_webhook: Webhooks::SERVICE_CATEGORY_DELETE,
           saved: "service_category_saved", deleted: "service_category_deleted" }.freeze

  before_action(only: :sort_alphabetically) { require_privilege }

  # POST /service_categories/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :services)

    categories = paginate_search(filter(record_scope, params[:keyword].to_s), params.fetch(:limit, 1000).to_i,
                                 params.fetch(:offset, 0).to_i)
    render json: categories.map { |category| EaRows.service_category_row(category) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /service_categories/reorder - persist the dragged order (1-based).
  def reorder
    raise ArgumentError, "Forbidden" if cannot?(:edit, :services)

    ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
    raise ArgumentError, "No order provided." if ids.empty?

    ActiveRecord::Base.transaction do
      ids.each_with_index { |id, index| ServiceCategory.where(id: id).update_all(sort_order: index + 1) }
    end
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /service_categories/sort_alphabetically - clear the manual order.
  def sort_alphabetically
    ServiceCategory.update_all(sort_order: nil)
    redirect_to service_categories_path
  end

  private

  def record_scope = ServiceCategory.display_order

  def filter(scope, keyword)
    return scope if keyword.blank?

    pattern = "%#{ServiceCategory.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR description LIKE :pattern", pattern: pattern)
  end

  def record_params
    params.require(:service_category).permit(:name, :description, :is_hidden)
  end

  def after_save = save_record_picture(@record, params[:service_category])
end
