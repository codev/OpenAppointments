# Messages > Notifications: one form per notification template.
class MessagesNotificationsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  ALLOWED_FIELDS = %w[title event cancellation_scope lead_mode lead_days lead_hours send_time
                      short_text long_text].freeze

  # GET /messages_notifications?new=1&open=ID
  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    @notifications = Notification.order(:id).to_a
    @notifications << Notification.new(lead_days: 0, lead_hours: 0, lead_mode: "before", send_time: "09:00") if params[:new].present?
    @open_id = params[:open].to_i
    @channels = Messaging.enabled_channels
    render :index
  end

  # POST /messages_notifications/save. The page form (form=1) comes back with a
  # flash and the saved panel open; other callers get EA's JSON.
  def save
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
    if form_post?
      redirect_to "/messages_notifications?open=#{notification.id}", notice: helpers.lang("notification_saved")
    else
      render json: { success: true, id: notification.id }
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    form_post? ? redirect_to("/messages_notifications", alert: e.message) : json_exception(e, status: :ok)
  end

  # POST /messages_notifications/destroy
  def destroy
    require_system_settings_edit!
    Notification.find(params.require(:notification_id)).destroy!
    form_post? ? redirect_to("/messages_notifications") : render(json: { success: true })
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    form_post? ? redirect_to("/messages_notifications", alert: e.message) : json_exception(e, status: :ok)
  end

  private

  def form_post? = params[:form].present?
end
