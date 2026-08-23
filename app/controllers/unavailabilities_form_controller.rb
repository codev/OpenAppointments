# Unavailability dialog forms for the calendar pages.
class UnavailabilitiesFormController < ApplicationController
  include EventForm

  # GET /unavailabilities/new?start=&end=&provider_id=
  def new
    head :forbidden and return if cannot?(:add, :appointments)

    @unavailability = Appointment.new(start_datetime: params[:start].presence || Time.zone.now.change(min: 0) + 1.hour,
                                      end_datetime: params[:end].presence, id_users_provider: params[:provider_id].presence)
    @unavailability.end_datetime ||= @unavailability.start_datetime + 1.hour
    @providers = providers_for_form.to_a
    render_form :form
  end

  # GET /unavailabilities/:id/edit
  def edit
    head :forbidden and return if cannot?(:edit, :appointments)

    @unavailability = Appointment.unavailabilities.find(params[:id])
    ensure_event_permission!(@unavailability.id_users_provider)
    @providers = providers_for_form.to_a
    render_form :form
  end

  def create = save
  def update = save

  # DELETE /unavailabilities/:id
  def destroy
    remove_unavailability(Appointment.unavailabilities.find(params[:id]))
    render_saved(nil)
  rescue ArgumentError => e
    @unavailability = Appointment.unavailabilities.find(params[:id])
    @providers = providers_for_form.to_a
    @error = e.message
    render_form :form, status: :unprocessable_entity
  end

  private

  def save
    data = params.require(:unavailability).permit(:start_datetime, :end_datetime, :location, :notes, :id_users_provider).to_h
    data["id"] = params[:id] if params[:id].present?
    data["start_datetime"] = parse_event_datetime(data["start_datetime"])
    data["end_datetime"] = parse_event_datetime(data["end_datetime"])
    store_unavailability(data)
    render_saved(helpers.lang("unavailability_saved"))
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    @unavailability = params[:id].present? ? Appointment.find(params[:id]) : Appointment.new
    @unavailability.assign_attributes(data.except("id"))
    @providers = providers_for_form.to_a
    @error = e.message
    render_form :form, status: :unprocessable_entity
  end
end
