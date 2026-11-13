# Recurring scan (config/recurring.yml) that marks a customer's messages read
# once their appointment has happened.
class MessageReadScanJob < ApplicationJob
  queue_as :default

  def perform
    MessageReads.after_appointments
  end
end
