# Customers admin: Rails views inside Turbo Frames. search stays as JSON for the
# appointments modal customer picker.
class CustomersController < ApplicationController
  include CrudPage

  PAGE = { resource: :customers, menu: "customers", title: "customers", per_page: 20,
           save_webhook: Webhooks::CUSTOMER_SAVE, delete_webhook: Webhooks::CUSTOMER_DELETE,
           saved: "customer_saved", deleted: "customer_deleted" }.freeze

  FIELDS = %i[name email phone_number address city state zip_code notes timezone language
              custom_field_1 custom_field_2 custom_field_3 custom_field_4 custom_field_5 ldap_dn].freeze

  # Most recently active customers first: latest of profile update, appointment
  # change or message (SQLite scalar MAX compares the uniform datetime strings).
  LAST_INTERACTION_ORDER = <<~SQL.squish.freeze
    MAX(
      users.updated_at,
      COALESCE((SELECT MAX(appointments.updated_at) FROM appointments
                WHERE appointments.id_users_customer = users.id), users.updated_at),
      COALESCE((SELECT MAX(messages.created_at) FROM messages
                WHERE messages.customer_id = users.id), users.updated_at)
    ) DESC
  SQL

  before_action :require_customer_access, only: %i[edit update destroy]
  before_action :require_add_allowed, only: %i[new create]

  # GET /customers?customer_id=N[&section=messages] is the deep link from the
  # messages log and calendar popovers: open the record on the messages panel.
  def index
    return redirect_to edit_customer_path(params[:customer_id], section: params[:section]) if params[:customer_id].present?

    super
  end

  # POST /customers/search - JSON rows for the appointments modal.
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :customers)

    customers = paginate_search(filter(record_scope, params[:keyword].to_s), params.fetch(:limit, 1000).to_i,
                                params.fetch(:offset, 0).to_i)
    unread_counts = Message.unread_counts_for(customers.map(&:id))
    render json: customers.map { |customer| EaRows.customer_row(customer).merge("unread_messages" => unread_counts[customer.id] || 0) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def record_scope = User.customers.with_attached_picture.order(Arel.sql(LAST_INTERACTION_ORDER))

  def new_record = User.new(role: Role.find_by!(slug: Role::CUSTOMER))

  def filter(scope, keyword)
    if keyword.present?
      pattern = "%#{User.sanitize_sql_like(keyword)}%"
      scope = scope.where(<<~SQL.squish, pattern: pattern)
        users.name LIKE :pattern OR email LIKE :pattern
        OR phone_number LIKE :pattern OR address LIKE :pattern OR city LIKE :pattern
        OR zip_code LIKE :pattern OR notes LIKE :pattern
      SQL
    end
    return scope if session[:role_slug] == Role::ADMIN || Setting.get("limit_customer_access") != "1"

    # EA Permissions::has_customer_access as a query: customers with an appointment with the user's providers.
    provider_ids = session[:role_slug] == Role::PROVIDER ? [ session[:user_id] ] : assistant_provider_ids
    scope.where(id: Appointment.where(id_users_provider: provider_ids).select(:id_users_customer))
  end

  def record_params
    permitted = params.require(:customer).permit(*FIELDS)
    permitted.delete(:ldap_dn) unless Setting.get("ldap_is_active").to_s == "1"
    permitted
  end

  def page_vars
    script_vars(timezones: helpers.timezones)
    html_vars(**field_display_flags, can_add: can_add?, unread_counts: Message.unread_counts_for(@records.map(&:id)))
  end

  def can_add? = can?(:add, :customers) && (Setting.get("limit_customer_access") != "1" || session[:role_slug] == Role::ADMIN)

  # Appointments the signed in user may see for the record, as the old page filtered.
  def visible_appointments(customer)
    appointments = Appointment.appointments.where(id_users_customer: customer.id).includes(:service, :provider, :appointment_status)
                              .order(start_datetime: :desc)
    case session[:role_slug]
    when Role::PROVIDER then appointments.where(id_users_provider: session[:user_id])
    when Role::ASSISTANT then appointments.where(id_users_provider: assistant_provider_ids)
    else appointments
    end
  end
  helper_method :visible_appointments

  def require_customer_access
    head :forbidden unless customer_access?(params[:id])
  end

  def require_add_allowed
    head :forbidden unless can_add?
  end
end
