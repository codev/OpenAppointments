# Messages > Notifications: the notification template editor.
class MessagesNotificationsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  ALLOWED_FIELDS = %w[title description event lead_mode lead_days lead_hours send_time
                      short_text long_text].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    script_vars(
      notifications: Notification.order(:id).map { |notification| notification_row(notification) },
      message_channels: Messaging.enabled_channels.map { |channel| { key: channel.key, label: channel.label } },
      notification_events: Notification::EVENTS,
      template_tokens: Messaging::Template::TOKENS
    )
    render :index
  end

  # POST /messages_notifications/save
  def save
    require_system_settings_edit!
    data = params.require(:notification)
    notification = data[:id].present? ? Notification.find(data[:id]) : Notification.new
    notification.assign_attributes(data.permit(*ALLOWED_FIELDS))
    notification.audiences = Array(data[:audiences]).select { |a| Notification::AUDIENCES.include?(a) }
    notification.channels = Array(data[:channels]).map(&:to_s)
    notification.save!
    render json: { success: true, id: notification.id }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    json_exception(e, status: :ok)
  end

  # POST /messages_notifications/destroy
  def destroy
    require_system_settings_edit!
    Notification.find(params.require(:notification_id)).destroy!
    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e, status: :ok)
  end

  private

  def notification_row(notification)
    notification.slice(:id, :title, :description, :event, :lead_mode, :lead_days,
                       :lead_hours, :send_time, :short_text, :long_text)
                .merge(audiences: Array(notification.audiences), channels: Array(notification.channels))
  end
end
