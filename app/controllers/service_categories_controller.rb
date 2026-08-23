# Service categories admin: Rails views inside Turbo Frames (the first admin page
# converted off EA's jQuery page script and JSON endpoints).
class ServiceCategoriesController < ApplicationController
  include BackendPage

  layout "backend"

  before_action :require_session, except: [ :index ]
  before_action -> { require_backend_page!(:services) }, only: %i[index new edit]
  before_action :require_privilege, only: %i[create update destroy sort_alphabetically]
  before_action :load_category, only: %i[edit update destroy]

  # GET /service_categories?keyword=&selected= - list plus the selected record's form.
  def index
    @category = ServiceCategory.find_by(id: params[:selected]) if params[:selected].present?
    render_page
  end

  # new and edit return the whole page too: Turbo pulls the detail frame out of it.
  def new
    @category = ServiceCategory.new
    render_page
  end

  def edit
    render_page
  end

  # POST /service_categories
  def create
    @category = ServiceCategory.new
    save_category
  end

  # PATCH /service_categories/:id
  def update
    save_category
  end

  # DELETE /service_categories/:id
  def destroy
    row = EaRows.service_category_row(@category)
    @category.destroy!
    Webhooks.trigger(Webhooks::SERVICE_CATEGORY_DELETE, row)
    redirect_to service_categories_path, notice: helpers.lang("service_category_deleted")
  end

  # POST /service_categories/search - JSON rows for the services page category select.
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :services)

    categories = search_categories(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
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

  def require_privilege
    head :forbidden unless can?(action_name == "destroy" ? :delete : :edit, :services)
  end

  def load_category
    @category = ServiceCategory.find(params[:id])
  end

  def category_params
    params.require(:service_category).permit(:name, :description, :is_hidden)
  end

  def render_page(status: :ok)
    backend_page_vars(page_title: helpers.lang("service_categories"), active_menu: "services")
    @keyword = params[:keyword].to_s
    @categories = filtered_categories(@keyword)
    render :index, status: status
  end

  def save_category
    @category.assign_attributes(category_params)
    return render_page(status: :unprocessable_entity) unless @category.valid?

    ServiceCategory.transaction do
      @category.save!
      update_picture
    end
    Webhooks.trigger(Webhooks::SERVICE_CATEGORY_SAVE, EaRows.service_category_row(@category))
    redirect_to service_categories_path(selected: @category.id), notice: helpers.lang("service_category_saved")
  rescue ArgumentError => e
    @category.errors.add(:base, e.message)
    render_page(status: :unprocessable_entity)
  end

  def update_picture
    picture = params.dig(:service_category, :picture)
    if ActiveModel::Type::Boolean.new.cast(params.dig(:service_category, :remove_picture))
      %i[picture picture_padded picture_zoomed].each { |name| @category.public_send(name).purge }
    end
    return unless picture.respond_to?(:content_type)

    PictureUpload.validate!(picture)
    PictureVariants.attach(@category, picture.tempfile.path, filename: picture.original_filename,
                                                             content_type: picture.content_type)
  end

  def filtered_categories(keyword)
    scope = ServiceCategory.display_order
    return scope if keyword.blank?

    pattern = "%#{ServiceCategory.sanitize_sql_like(keyword)}%"
    scope.where("name LIKE :pattern OR description LIKE :pattern", pattern: pattern)
  end

  def search_categories(keyword, limit, offset)
    paginate_search(filtered_categories(keyword), limit, offset)
  end
end
