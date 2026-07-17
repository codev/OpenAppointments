# Service categories admin CRUD, port of EA's Service_categories controller.
class ServiceCategoriesController < ApplicationController
  include BackendPage
  include PictureUpload

  layout "backend"

  ALLOWED_FIELDS = %w[id name description].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:services)

    backend_page_vars(page_title: helpers.lang("service_categories"), active_menu: "services")
    render :index
  end

  # POST /service_categories/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :services)

    categories = search_categories(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
                                   params.fetch(:offset, 0).to_i)

    render json: categories.map { |category| EaRows.service_category_row(category) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /service_categories/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :services)

    save_category(ServiceCategory.new)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /service_categories/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :services)

    category_id = params.require(:service_category_id).to_i
    raise ArgumentError, "Invalid service category ID provided." unless category_id.positive?

    render json: EaRows.service_category_row(ServiceCategory.find(category_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /service_categories/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :services)

    save_category(ServiceCategory.find(permitted_category.fetch("id")))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /service_categories/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :services)

    category_id = params.require(:service_category_id).to_i
    raise ArgumentError, "Invalid service category ID provided." unless category_id.positive?

    category = ServiceCategory.find(category_id)
    row = EaRows.service_category_row(category)
    category.destroy!
    Webhooks.trigger(Webhooks::SERVICE_CATEGORY_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_category
    value = params.require(:service_category)
    value = value.permit(*ALLOWED_FIELDS.map(&:to_sym)).to_h if value.is_a?(ActionController::Parameters)
    value
  end

  def save_category(category)
    category.assign_attributes(permitted_category.except("id"))
    category.save!
    Webhooks.trigger(Webhooks::SERVICE_CATEGORY_SAVE, EaRows.service_category_row(category))
    render json: { success: true, id: category.id }
  end

  def search_categories(keyword, limit, offset)
    scope = ServiceCategory.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{ServiceCategory.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR description LIKE :pattern", pattern: pattern)
  end

  def picture_record = ServiceCategory.find(params[:id])

  def picture_permission_resource = :services
end
