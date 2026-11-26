# Busy time (unavailability) dialog forms for the calendar pages. One form can
# cover several providers: a row each, saved and removed as a group.
class UnavailabilitiesFormController < ApplicationController
  include EventForm

  # GET /unavailabilities/new?start=&end=&provider_id=
  def new
    head :forbidden and return if cannot?(:add, :appointments)

    @unavailability = Appointment.new(start_datetime: params[:start].presence || BookingWindows.wall_clock_now.change(min: 0) + 1.hour,
                                      end_datetime: params[:end].presence, id_users_provider: params[:provider_id].presence)
    @unavailability.end_datetime ||= @unavailability.start_datetime + 1.hour
    form_vars([ params[:provider_id].presence&.to_i ].compact)
    render_form :form
  end

  # GET /unavailabilities/:id/edit
  def edit
    head :forbidden and return if cannot?(:edit, :appointments)

    @unavailability = Appointment.unavailabilities.find(params[:id])
    ensure_event_permission!(@unavailability.id_users_provider)
    form_vars(unavailability_group_rows(@unavailability).map(&:id_users_provider))
    render_form :form
  end

  def create = save
  def update = save

  # DELETE /unavailabilities/:id: the whole group as far as the user can see it.
  def destroy
    @unavailability = Appointment.unavailabilities.find(params[:id])
    remove_unavailability_group(@unavailability, providers_for_form.map(&:id))
    render_saved(nil)
  rescue ArgumentError => e
    form_vars(unavailability_group_rows(@unavailability).map(&:id_users_provider))
    @error = e.message
    render_form :form, status: :unprocessable_entity
  end

  private

  def save
    data = params.require(:unavailability).permit(:start_datetime, :end_datetime, :location, :notes, :id_users_provider,
                                                  :unavailability_type_id, provider_ids: []).to_h
    provider_ids = Array(data.delete("provider_ids")).reject(&:blank?).map(&:to_i)
    provider_ids = [ data["id_users_provider"].to_i ] if provider_ids.empty? && data["id_users_provider"].present?
    data["id"] = params[:id] if params[:id].present?
    data["start_datetime"] = parse_event_datetime(data["start_datetime"])
    data["end_datetime"] = parse_event_datetime(data["end_datetime"])
    store_unavailability_group(data, provider_ids, providers_for_form.map(&:id))
    render_saved(helpers.lang("unavailability_saved"))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    @unavailability = params[:id].present? ? Appointment.find(params[:id]) : Appointment.new
    @unavailability.assign_attributes(data.except("id", "id_users_provider"))
    form_vars(provider_ids)
    @error = e.message
    render_form :form, status: :unprocessable_entity
  end

  # The providers the user may pick, the ticked ones (the group's, within those)
  # and the types.
  def form_vars(selected_ids)
    @providers = providers_for_form.to_a
    @selected_provider_ids = selected_ids & @providers.map(&:id)
    @types = UnavailabilityType.ordered.to_a
  end
end
