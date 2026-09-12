# The booking wizard's steps as URL state.
module BookingWizardHelper
  # The kept query parameters at every step.
  def wizard_params(overrides = {})
    base = { first: params[:first].presence, service: params[:service].presence, provider: params[:provider].presence,
             theme: params[:theme].presence, service_id: @service_id.to_i.positive? ? @service_id : nil,
             provider_id: @provider_id.presence, date: @date, time: @time, timezone: @timezone }
    base.merge(overrides).compact
  end

  # The wizard's own route: confirm and register render steps too, and their
  # paths must not leak into links or GET forms.
  def wizard_route
    if vars(:manage_mode)
      { controller: "booking", action: "reschedule", appointment_hash: vars(:appointment_data)["hash"] }
    else
      { controller: "booking", action: "index" }
    end
  end

  def wizard_form_path
    url_for(wizard_route.merge(only_path: true))
  end

  def wizard_step_path(step, overrides = {})
    url_for(wizard_route.merge(wizard_params(overrides)).merge(step: step, only_path: true))
  end

  # Hidden fields carrying the wizard state into a form (a GET form drops the
  # URL's own query string, so everything must be posted explicitly).
  def wizard_state_fields(overrides = {})
    safe_join(wizard_params(overrides).map { |key, value| hidden_field_tag(key, value, id: nil) })
  end

  def step_number
    order = %w[first second time info final]
    (order.index(@step) || 0) + 1
  end

  def wizard_back_button(step)
    overrides = {}
    # Cards mode starts over from the category view, as the jQuery wizard did.
    overrides = { service_id: nil, provider_id: nil } if step == "first" && vars(:display_mode) == "cards"
    link_to wizard_step_path(step, overrides), id: "button-back-#{step_number}", class: "btn button-back btn-outline-secondary",
                                               data: { turbo_action: "advance" } do
      safe_join([ tag.i(class: "fas fa-chevron-left me-2"), lang("back") ])
    end
  end

  def wizard_next_button
    button_tag type: "submit", id: "button-next-#{step_number}", class: "btn button-next btn-primary" do
      safe_join([ lang("next"), tag.i(class: "fas fa-chevron-right ms-2") ])
    end
  end

  def selected_service
    vars(:available_services).find { |row| row["id"] == @service_id }
  end

  def selected_provider
    return { "name" => lang("any_provider") } if @provider_id == BookingPayloads::ANY_PROVIDER

    vars(:available_providers).find { |row| row["id"].to_s == @provider_id.to_s }
  end

  # Providers offering the chosen service (all of them before one is chosen).
  def selectable_providers
    providers = vars(:available_providers)
    providers = providers.select { |row| row["id"].to_s == vars(:provider_data)["id"].to_s } if vars(:manage_mode)
    providers = providers.select { |row| row["services"].include?(@service_id) } if @service_id.positive?
    providers
  end

  # Hours in the window are wall-clock in this zone (any provider: the first one's).
  def wizard_provider_timezone
    provider = @provider_id == BookingPayloads::ANY_PROVIDER ? selectable_providers.first : selected_provider
    provider&.dig("timezone") || Setting.get("default_timezone", "UTC")
  end

  # The zone the customer chose on the time step, when it is not fixed.
  def wizard_customer_timezone
    Setting.fixed_timezone? ? wizard_provider_timezone : (@timezone || wizard_provider_timezone)
  end

  def info_step_settings
    %i[display_email require_email display_phone_number require_phone_number require_phone_or_email
       display_address require_address display_city require_city display_zip_code require_zip_code
       display_notes require_notes].index_with { |key| vars(key) }
  end
end
