# The event dialog: forms rendered into the calendar pages' event frame (a
# Bootstrap modal). A save answers with the saved partial, which the page
# script turns into a closed dialog, a notification and a calendar reload.
module EventForm
  extend ActiveSupport::Concern

  included do
    include BackendPage
    include EventSaving
    layout "backend"
    before_action :require_session
    rescue_from EventSaving::Forbidden, with: -> { head :forbidden }
  end

  private

  def render_form(template, status: :ok)
    render template, status: status
  end

  # message nil: close the dialog and reload without a notification (as the
  # jQuery delete did).
  def render_saved(message, skipped: [])
    render partial: "shared/event_saved", locals: { message: message, skipped: skipped }, layout: false
  end

  # Values typed into the flatpickr fields are in the date_format + time_format
  # display formats; ISO values (from the calendar selection) pass through.
  def parse_event_datetime(value)
    value = value.to_s.strip
    return value if value.blank? || value.match?(/\A\d{4}-\d{2}-\d{2}/)

    date_format = MailerFormatHelper::DATE_FORMATS[Setting.get("date_format")] || MailerFormatHelper::DATE_FORMATS["DMY"]
    time_format = Setting.get("time_format") == "military" ? "%H:%M" : "%I:%M %p"
    Time.zone.strptime(value, "#{date_format} #{time_format}").strftime("%Y-%m-%d %H:%M:%S")
  rescue ArgumentError => e
    raise ArgumentError, "#{value}: #{e.message}"
  end

  def providers_for_form
    providers = User.providers.joins(:provider_service_links).distinct.order(:name, :email).includes(:services)
    case session[:role_slug]
    when Role::PROVIDER then providers.where(id: session[:user_id])
    when Role::ASSISTANT then providers.where(id: assistant_provider_ids)
    else providers
    end
  end
end
