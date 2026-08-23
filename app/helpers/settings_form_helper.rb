# Settings page forms: fields named settings[<name>] pre-filled from the stored
# value, ids as the old pages had (name dasherized), data-field kept for the few
# page scripts that read it.
module SettingsFormHelper
  def settings_form(url, &block)
    form_with(url: url, method: :post, id: "settings-form", data: { turbo_frame: "settings" }, &block)
  end

  def settings_flash
    safe_join([
      (tag.div(notice, class: "alert alert-success") if notice),
      (tag.div(alert, class: "alert alert-danger") if alert)
    ].compact)
  end

  def setting_field_options(name, options)
    { id: name.dasherize, data: { field: name } }.merge(options)
  end

  def setting_text(name, **options)
    text_field_tag "settings[#{name}]", setting(name), setting_field_options(name, { class: "form-control" }.merge(options))
  end

  # Secrets are never written into the page; a blank submission keeps the stored one.
  def setting_password(name, **options)
    password_field_tag "settings[#{name}]", nil, setting_field_options(name, { class: "form-control" }.merge(options))
  end

  def setting_textarea(name, **options)
    text_area_tag "settings[#{name}]", setting(name), setting_field_options(name, { class: "form-control" }.merge(options))
  end

  def setting_select(name, choices, **options)
    select_tag "settings[#{name}]", options_for_select(choices, setting(name)),
               setting_field_options(name, { class: "form-select" }.merge(options))
  end

  # A form-switch storing "1"/"0".
  def setting_switch(name, **options)
    hidden_field_tag("settings[#{name}]", "0", id: nil) +
      check_box_tag("settings[#{name}]", "1", setting(name).to_s == "1",
                    setting_field_options(name, { class: "form-check-input" }.merge(options)))
  end

  def settings_save_button
    return unless can?(:edit, :system_settings)

    button_tag(type: "submit", id: "save-settings", class: "btn btn-primary") do
      tag.i(class: "fas fa-check-square me-2") + lang("save")
    end
  end
end
