# Records that a coming_up notification fired for an appointment occurrence, so
# the reminder scan never double-sends. The key includes the appointment start:
# rescheduling produces a new key and the reminder goes out again.
class NotificationDispatch < ApplicationRecord
  belongs_to :notification
  belongs_to :appointment

  def self.record!(notification, appointment)
    create!(notification: notification, appointment: appointment, dedupe_key: key_for(notification, appointment))
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def self.recorded?(notification, appointment) = exists?(dedupe_key: key_for(notification, appointment))

  def self.key_for(notification, appointment)
    "#{notification.id}:#{appointment.id}:#{appointment.start_datetime.to_i}"
  end
end
