# Unavailabilities CRUD, port of EA's Unavailabilities controller. Works on the
# appointments table rows with is_unavailability set. EA has no page for this
# resource, only the JSON endpoints.
class UnavailabilitiesController < ApplicationController
  include BackendPage
  include UserCrud

  ALLOWED_FIELDS = %w[id start_datetime end_datetime location notes is_unavailability
                      id_users_provider].freeze

  before_action :require_session

  # POST /unavailabilities/search
  def search
    raise ArgumentError, "Forbidden" if cannot?(:view, :appointments)

    unavailabilities = search_unavailabilities(params[:keyword].to_s, params.fetch(:limit, 1000).to_i,
                                               params.fetch(:offset, 0).to_i).to_a

    case session[:role_slug]
    when Role::PROVIDER
      unavailabilities.select! { |u| u.id_users_provider == session[:user_id].to_i }
    when Role::SECRETARY
      unavailabilities.select! { |u| secretary_provider_ids.include?(u.id_users_provider) }
    end

    render json: unavailabilities.map { |unavailability| EaRows.appointment_row(unavailability) }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /unavailabilities/store
  def store
    raise ArgumentError, "Forbidden" if cannot?(:add, :appointments)

    save_unavailability(Appointment.new)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # GET/POST /unavailabilities/find
  def find
    raise ArgumentError, "Forbidden" if cannot?(:view, :appointments)

    unavailability_id = positive_id!(params.require(:unavailability_id), "unavailability")
    unavailability = Appointment.unavailabilities.find(unavailability_id)
    check_unavailability_access!(unavailability)
    return if performed?

    render json: EaRows.appointment_row(unavailability)
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  # POST /unavailabilities/update
  def update
    raise ArgumentError, "Forbidden" if cannot?(:edit, :appointments)

    unavailability_params = permitted_unavailability
    record = Appointment.unavailabilities.find(unavailability_params.fetch("id"))
    check_unavailability_access!(record)
    return if performed?

    save_unavailability(record)
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /unavailabilities/destroy
  def destroy
    raise ArgumentError, "Forbidden" if cannot?(:delete, :appointments)

    unavailability_id = positive_id!(params.require(:unavailability_id), "unavailability")
    unavailability = Appointment.unavailabilities.find(unavailability_id)
    check_unavailability_access!(unavailability)
    return if performed?

    row = EaRows.appointment_row(unavailability)
    unavailability.destroy!
    Webhooks.trigger(Webhooks::UNAVAILABILITY_DELETE, row)

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def permitted_unavailability
    value = params.require(:unavailability)
    value = value.permit(*ALLOWED_FIELDS.map(&:to_sym)).to_h if value.is_a?(ActionController::Parameters)
    value
  end

  def save_unavailability(record)
    unavailability_params = permitted_unavailability
    record.assign_attributes(unavailability_params.except("id"))
    record.is_unavailability = true
    record.book_datetime ||= Time.now
    record.save!

    Synchronization.unavailability_saved(record, record.provider)
    Webhooks.trigger(Webhooks::UNAVAILABILITY_SAVE, EaRows.appointment_row(record))

    render json: { success: true, id: record.id }
  end

  # EA check_unavailability_access: secretaries limited to their providers,
  # providers limited to themselves.
  def check_unavailability_access!(unavailability)
    provider_id = unavailability.id_users_provider.to_i
    case session[:role_slug]
    when Role::SECRETARY
      head :forbidden unless secretary_provider_ids.include?(provider_id)
    when Role::PROVIDER
      head :forbidden unless session[:user_id].to_i == provider_id
    end
  end

  def search_unavailabilities(keyword, limit, offset)
    scope = Appointment.unavailabilities.order(updated_at: :desc).limit(limit).offset(offset)
    return scope if keyword.blank?

    pattern = "%#{Appointment.sanitize_sql_like(keyword)}%"
    scope.joins("INNER JOIN users AS providers ON providers.id = appointments.id_users_provider")
         .where(<<~SQL.squish, pattern: pattern)
           appointments.start_datetime LIKE :pattern OR appointments.end_datetime LIKE :pattern
           OR appointments.location LIKE :pattern OR appointments.booking_hash LIKE :pattern
           OR appointments.notes LIKE :pattern OR providers.first_name LIKE :pattern
           OR providers.last_name LIKE :pattern OR providers.email LIKE :pattern
           OR providers.phone_number LIKE :pattern
         SQL
  end
end
