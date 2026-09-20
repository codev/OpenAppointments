# Settings page forms: fields named settings[<name>] pre-filled from the stored
# value, ids as the old pages had (name dasherized), data-field kept for the few
# page scripts that read it.
module SettingsFormHelper
  # frame: false posts the whole page (for settings the layout itself renders).
  def settings_form(url, multipart: false, frame: true, &block)
    data = frame ? { turbo_frame: "settings" } : { turbo: false }
    form_with(url: url, method: :post, id: "settings-form", multipart: multipart, data: data, &block)
  end

  def settings_flash
    safe_join([
      (tag.div(notice, class: "notice", "data-tone": "success") if notice),
      (tag.div(alert, class: "notice", "data-tone": "error") if alert)
    ].compact)
  end

  def setting_field_options(name, options)
    { id: name.dasherize, data: { field: name } }.merge(options)
  end

  # Stored value, else the messaging default (the only settings with code defaults).
  def setting_value(name)
    setting(name, Messaging::Defaults::SETTINGS[name])
  end

  def setting_text(name, **options)
    text_field_tag "settings[#{name}]", setting_value(name), setting_field_options(name, options)
  end

  # Secrets are never written into the page; a blank submission keeps the stored one.
  def setting_password(name, **options)
    password_field_tag "settings[#{name}]", nil, setting_field_options(name, options)
  end

  def setting_textarea(name, **options)
    text_area_tag "settings[#{name}]", setting_value(name), setting_field_options(name, options)
  end

  # choices: flat [[label, value]] or grouped [[group, [[label, value]]]].
  def setting_select(name, choices, **options)
    grouped = choices.first&.last.is_a?(Array) && choices.first.last.first.is_a?(Array)
    tags = grouped ? grouped_options_for_select(choices, setting_value(name)) : options_for_select(choices, setting_value(name))
    select_tag "settings[#{name}]", tags, setting_field_options(name, options)
  end

  # A form-switch storing "1"/"0"; default: value assumed while unset.
  def setting_switch(name, default: nil, **options)
    hidden_field_tag("settings[#{name}]", "0", id: nil) +
      check_box_tag("settings[#{name}]", "1", setting(name, setting_value(name) || default).to_s == "1",
                    setting_field_options(name, options))
  end

  def settings_save_button
    return unless can?(:edit, :system_settings)

    button_tag(type: "submit", id: "save-settings") do
      tag.i(class: "fas fa-check-square") + " " + lang("save")
    end
  end
end
