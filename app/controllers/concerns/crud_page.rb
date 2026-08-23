# Admin CRUD pages rendered as Rails views inside Turbo Frames (see
# shared/_crud_page). The controller sets PAGE (privilege resource, menu, title
# key, saved/deleted message keys, optional save/delete webhooks) and defines
# record_scope, filter(scope, keyword), record_params, and optionally
# before_save / after_save.
module CrudPage
  extend ActiveSupport::Concern

  included do
    include BackendPage
    layout "backend"

    before_action :require_session, except: [ :index ]
    before_action -> { require_backend_page!(self.class::PAGE[:resource]) }, only: %i[index new edit]
    before_action :require_privilege, only: %i[create update destroy]
    before_action :load_record, only: %i[edit update destroy]
  end

  # GET /<resource>?keyword=&selected=
  def index
    @record = record_scope.find_by(id: params[:selected]) if params[:selected].present?
    render_page
  end

  # new and edit return the whole page too: Turbo pulls the detail frame out of it.
  def new
    @record = new_record
    @editing = true
    render_page
  end

  def edit
    @editing = true
    render_page
  end

  def create
    @record = new_record
    save_record
  end

  def update
    save_record
  end

  def destroy
    row = Webhooks.to_row(@record)
    @record.destroy!
    trigger_webhook(:delete_webhook, row)
    redirect_to index_path, notice: helpers.lang(self.class::PAGE[:deleted])
  end

  private

  def new_record = record_scope.new

  def index_path(**query) = url_for(controller: controller_name, action: :index, **query)

  def require_privilege
    head :forbidden unless can?(action_name == "destroy" ? :delete : :edit, self.class::PAGE[:resource])
  end

  def load_record
    @record = record_scope.find(params[:id])
  end

  def render_page(status: :ok)
    if request.format.json?
      return render json: { success: false, message: @record.errors.full_messages.to_sentence }, status: status
    end

    backend_page_vars(page_title: helpers.lang(self.class::PAGE[:title]), active_menu: self.class::PAGE[:menu])
    @keyword = params[:keyword].to_s
    @records = paginate(filter(record_scope, @keyword))
    page_vars
    render :index, status: status
  end

  # PAGE[:per_page] windows the list (old pages used 20); without it the whole
  # list renders, as the drag-to-reorder pages need. The selected record's page
  # is used when no page is asked for, so a saved record stays in view.
  def paginate(records)
    per_page = self.class::PAGE[:per_page]
    return records unless per_page

    ids = records.is_a?(Array) ? records.map(&:id) : records.unscope(:includes, :preload).pluck(:id)
    @page = params[:page].to_i
    @page = (ids.index(@record.id) || 0) / per_page + 1 if @page < 1 && @record&.persisted?
    @page_count = [ (ids.length + per_page - 1) / per_page, 1 ].max
    @page = @page.clamp(1, @page_count)
    offset = (@page - 1) * per_page
    records.is_a?(Array) ? records.slice(offset, per_page) || [] : records.offset(offset).limit(per_page)
  end

  def save_record
    @record.assign_attributes(record_params)
    @editing = true
    return render_page(status: :unprocessable_entity) unless @record.valid?

    before_save
    @record.transaction do
      @record.save!
      after_save
    end
    trigger_webhook(:save_webhook, Webhooks.to_row(@record))
    respond_to do |format|
      format.html { redirect_to index_path(selected: @record.id), notice: helpers.lang(self.class::PAGE[:saved]) }
      format.json { render json: { success: true, id: @record.id } }
    end
  rescue ArgumentError => e
    @record.errors.add(:base, e.message)
    render_page(status: :unprocessable_entity)
  end

  # Hooks: page_vars adds html/script vars after @records is set; before_save
  # raises ArgumentError for cross-field checks; after_save persists dependent
  # data inside the save transaction.
  def page_vars; end

  def before_save; end

  def after_save; end

  def trigger_webhook(key, row)
    action = self.class::PAGE[key]
    Webhooks.trigger(action, row) if action
  end
end
