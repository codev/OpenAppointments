# Recurring scan (config/recurring.yml, or the openappointments:reminders cron
# target) that sends due coming-up notifications.
class ReminderScanJob < ApplicationJob
  queue_as :default

  def perform
    Notifications.scan_coming_up
  end
end
