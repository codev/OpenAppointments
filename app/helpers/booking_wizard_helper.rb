# The booking wizard's steps as URL state.
module BookingWizardHelper
  # Link parameters that prefill the details step (EA's ?name=&email=&phone=...).
  PREFILL_PARAMS = { "name" => "name", "email" => "email", "phone" => "phone_number",
                     "address" => "address", "city" => "city", "zip" => "zip_code" }.freeze

  # The kept query parameters at every step.
  def wizard_params(overrides = {})
    base = { first: params[:first].presence, service: params[:service].presence, provider: params[:provider].presence,
             theme: params[:theme].presence, service_id: @service_id.to_i.positive? ? @service_id : nil,
             provider_id: @provider_id.presence, date: @date, time: @time, timezone: @timezone }
    PREFILL_PARAMS.each_key { |key| base[key.to_sym] = params[key].presence }
    base.merge(overrides).compact
  end

  def prefilled_customer
    PREFILL_PARAMS.filter_map { |param, field| [ field, params[param].to_s.strip ] if params[param].present? }.to_h
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
    # A reschedule has its service and provider fixed: no way back from the times.
    return if step == "second" && vars(:manage_mode)

    overrides = {}
    # Cards mode starts over from the category view.
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
    vars(:available_services)&.find { |row| row["id"] == @service_id }
  end

  def selected_provider
    return { "name" => lang("any_provider") } if @provider_id == BookingPayloads::ANY_PROVIDER

    vars(:available_providers)&.find { |row| row["id"].to_s == @provider_id.to_s }
  end

  # The header line: the choices so far in wizard order, a label until chosen.
  # The second kind appears once its step is reached or it is already chosen.
  def wizard_selection_text
    names = { "service" => selected_service&.dig("name") || lang("service"),
              "provider" => selected_provider&.dig("name") || lang("provider") }
    chosen = { "service" => selected_service.present?, "provider" => selected_provider.present? }
    kinds = vars(:first_step) == "provider" ? %w[provider service] : %w[service provider]
    kinds = kinds.first(1) if step_number == 1 && !chosen[kinds.last]
    names.values_at(*kinds).join(" │ ")
  end

  # Header steps: a reschedule starts at the times, so its two selection steps are not shown.
  def wizard_header_steps
    vars(:manage_mode) ? (3..5) : (1..5)
  end

  # Completed steps in the header link back to their page, as the Back buttons do.
  def wizard_step_links
    steps = { 1 => "first", 2 => "second", 3 => "time", 4 => "info" }
    steps.select { |number, _| number < step_number && wizard_header_steps.cover?(number) }.to_h do |number, step|
      overrides = number == 1 && vars(:display_mode) == "cards" ? { service_id: nil, provider_id: nil } : {}
      [ number, wizard_step_path(step, overrides) ]
    end
  end

  # Services the chosen provider offers (all of them before one is chosen).
  def selectable_services
    services = vars(:available_services)
    return services if @provider_id.blank? || @provider_id == BookingPayloads::ANY_PROVIDER

    offered = selected_provider&.dig("services") || []
    services.select { |row| offered.include?(row["id"]) }
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
