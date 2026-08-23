# Admin CRUD pages rendered as Rails views inside Turbo Frames (see
# shared/_crud_page). The controller sets PAGE (privilege resource, menu, title
# key, saved/deleted message keys, optional save/delete webhooks) and defines
# record_scope, filter(scope, keyword), record_params, and optionally after_save.
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
    @record = record_scope.new
    @editing = true
    render_page
  end

  def edit
    @editing = true
    render_page
  end

  def create
    @record = record_scope.new
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

  def index_path(**query) = url_for(controller: controller_name, action: :index, **query)

  def require_privilege
    head :forbidden unless can?(action_name == "destroy" ? :delete : :edit, self.class::PAGE[:resource])
  end

  def load_record
    @record = record_scope.find(params[:id])
  end

  def render_page(status: :ok)
    backend_page_vars(page_title: helpers.lang(self.class::PAGE[:title]), active_menu: self.class::PAGE[:menu])
    @keyword = params[:keyword].to_s
    @records = filter(record_scope, @keyword)
    render :index, status: status
  end

  def save_record
    @record.assign_attributes(record_params)
    @editing = true
    return render_page(status: :unprocessable_entity) unless @record.valid?

    @record.transaction do
      @record.save!
      after_save
    end
    trigger_webhook(:save_webhook, Webhooks.to_row(@record))
    redirect_to index_path(selected: @record.id), notice: helpers.lang(self.class::PAGE[:saved])
  rescue ArgumentError => e
    @record.errors.add(:base, e.message)
    render_page(status: :unprocessable_entity)
  end

  def after_save; end

  def trigger_webhook(key, row)
    action = self.class::PAGE[key]
    Webhooks.trigger(action, row) if action
  end
end
