# Recurring sweep (config/recurring.yml, or the openappointments:payment_sweep
# cron target) that settles checkout bookings nobody returned from.
class PaymentSweepJob < ApplicationJob
  queue_as :default

  def perform
    BookingPayment.sweep
  end
end
