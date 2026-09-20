# Recurring daily scan (config/recurring.yml, or the openappointments:waitlist
# cron target).
class WaitlistDailyJob < ApplicationJob
  def perform
    Waitlist.scan_daily
  end
end
