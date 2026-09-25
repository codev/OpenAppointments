# Messages > Notifications: one form per notification template.
class MessagesNotificationsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  ALLOWED_FIELDS = %w[title event cancellation_scope lead_mode lead_days lead_hours send_time
                      short_text long_text].freeze

  # GET /messages_notifications?new=1&open=ID. Add (new=1) from the page asks
  # for a stream and gets one blank panel appended to the list.
  def index
    return unless require_backend_page!(:system_settings)

    @channels = Messaging.enabled_channels
    blank = Notification.new(lead_days: 0, lead_hours: 0, lead_mode: "before", send_time: "09:00")
    if params[:new].present? && request.format.turbo_stream?
      return render turbo_stream: turbo_stream.append("notifications-list", partial: "messages_notifications/panel",
                                                                              locals: { notification: blank, open: true })
    end

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    @notifications = Notification.order(:id).to_a
    @notifications << blank if params[:new].present?
    @open_id = params[:open].to_i
    render :index
  end

  # POST /messages_notifications/save. The page form (form=1) gets a stream
  # replacing only its panel (panel_key), open, with the outcome in it; without
  # Turbo it redirects with a flash. Other callers get EA's JSON.
  def save
    notification = nil
    require_system_settings_edit!
    data = params.require(:notification)
    notification = data[:id].present? ? Notification.find(data[:id]) : Notification.new
    notification.assign_attributes(data.permit(*ALLOWED_FIELDS))
    if notification.lead_mode == "day_at" && data.key?(:day_at_days)
      notification.lead_days = data[:day_at_days]
      notification.lead_hours = 0
    end
    notification.audiences = Array(data[:audiences]).select { |a| Notification::AUDIENCES.include?(a) }
    notification.channels = Array(data[:channels]).compact_blank.map(&:to_s)
    notification.save!
    if form_post? && request.format.turbo_stream?
      render_panel(notification, notice: helpers.lang("notification_saved"))
    elsif form_post?
      redirect_to "/messages_notifications?open=#{notification.id}", notice: helpers.lang("notification_saved")
    else
      render json: { success: true, id: notification.id }
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    if form_post? && notification && request.format.turbo_stream?
      render_panel(notification, alert: e.message, status: :unprocessable_entity)
    elsif form_post?
      redirect_to("/messages_notifications", alert: e.message)
    else
      json_exception(e, status: :ok)
    end
  end

  # POST /messages_notifications/destroy
  def destroy
    require_system_settings_edit!
    notification = Notification.find(params.require(:notification_id))
    notification.destroy!
    if form_post? && request.format.turbo_stream?
      render turbo_stream: turbo_stream.remove("notification-panel-#{notification.id}")
    else
      form_post? ? redirect_to("/messages_notifications") : render(json: { success: true })
    end
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    form_post? ? redirect_to("/messages_notifications", alert: e.message) : json_exception(e, status: :ok)
  end

  private

  def form_post? = params[:form].present?

  # Replaces the submitting panel. A failed save keeps the typed values and
  # stays marked unsaved, so leaving the page still warns.
  def render_panel(notification, notice: nil, alert: nil, status: :ok)
    @channels = Messaging.enabled_channels
    key = params[:panel_key].presence || notification.id
    render turbo_stream: turbo_stream.replace("notification-panel-#{key}", partial: "messages_notifications/panel",
                                              locals: { notification: notification, open: true, notice: notice, alert: alert,
                                                        key: (notification.persisted? ? nil : key) }),
           status: status
  end
end
