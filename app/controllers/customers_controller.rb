# Customers admin CRUD, port of EA's Customers controller. This is the reference
# pattern for all backend CRUD controllers: page GET + search/find/store/update/destroy
# POST endpoints with EA's JSON shapes and permission checks.
class CustomersController < ApplicationController
  include BackendPage

  layout "backend"

  ALLOWED_FIELDS = %w[id first_name last_name email phone_number address city state zip_code
                      notes timezone language custom_field_1 custom_field_2 custom_field_3
                      custom_field_4 custom_field_5 ldap_dn].freeze

  before_action :require_session, except: [ :index ]

  def index
    return unless require_backend_page!(:customers)

    backend_page_vars(page_title: helpers.lang("customers"), active_menu: "customers")
    script_vars(secretary_providers: secretary_provider_ids)
    html_vars(
      available_languages: Localization.available_languages,
      **%w[first_name last_name email phone_number address city zip_code]
        .index_with { |field| Setting.get("require_#{field}") }
        .transform_keys { |field| "require_#{field}".to_sym }
    )
    render :index
  end

  # GET /customers/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :customers)

    customer_id = params.require(:customer_id).to_i
    raise ArgumentError, "Invalid customer ID provided." unless customer_id.positive?
    return head :forbidden unless customer_access?(customer_id)

    render json: EaRows.customer_row(User.customers.find(customer_id))
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /customers/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :customers)

    customers = search_customers(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
                                 params.fetch(:offset, 0).to_i)

    payload = customers.filter_map do |customer|
      next unless customer_access?(customer.id)

      appointments = Appointment.appointments.where(id_users_customer: customer.id)
      appointments = filter_appointments_by_role(appointments)
      row = EaRows.customer_row(customer)
      row["appointments"] = appointments.includes(:service, :provider).map do |appointment|
        EaRows.appointment_row(appointment).merge(
          "service" => appointment.service && EaRows.service_row(appointment.service),
          "provider" => appointment.provider && EaRows.provider_row(appointment.provider)
        )
      end
      row
    end

    render json: payload
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /customers/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :customers)
    if session[:role_slug] != Role::ADMIN && Setting.get("limit_customer_visibility") == "1"
      return head :forbidden
    end

    customer = User.new(role: Role.find_by!(slug: Role::CUSTOMER))
    save_customer(customer)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /customers/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :customers)

    customer_params = permitted_customer
    return head :forbidden unless customer_access?(customer_params["id"])

    customer = User.customers.find(customer_params["id"])
    save_customer(customer)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /customers/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :customers)

    customer_id = params.require(:customer_id).to_i
    raise ArgumentError, "Invalid customer ID provided." unless customer_id.positive?
    return head :forbidden unless customer_access?(customer_id)

    customer = User.customers.find(customer_id)
    row = EaRows.customer_row(customer)
    customer.destroy!
    Webhooks.trigger(Webhooks::CUSTOMER_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_customer
    value = params.require(:customer)
    value = value.permit(*ALLOWED_FIELDS.map(&:to_sym)).to_h if value.is_a?(ActionController::Parameters)
    value
  end

  def save_customer(customer)
    customer_params = permitted_customer
    customer.assign_attributes(customer_params.except("id"))
    customer.last_name = customer.first_name if customer.last_name.blank?
    customer.save!
    Webhooks.trigger(Webhooks::CUSTOMER_SAVE, EaRows.customer_row(customer))
    render json: { success: true, id: customer.id }
  end

  def search_customers(keyword, limit, offset)
    scope = User.customers.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{User.sanitize_sql_like(keyword)}%"
    scope.where(<<~SQL.squish, pattern: pattern)
      first_name LIKE :pattern OR last_name LIKE :pattern OR email LIKE :pattern
      OR phone_number LIKE :pattern OR address LIKE :pattern OR city LIKE :pattern
      OR zip_code LIKE :pattern OR notes LIKE :pattern
    SQL
  end

  def filter_appointments_by_role(appointments)
    case session[:role_slug]
    when Role::PROVIDER
      appointments.where(id_users_provider: session[:user_id])
    when Role::SECRETARY
      appointments.where(id_users_provider: secretary_provider_ids)
    else
      appointments
    end
  end
end
