# Nightly: top every open series up to the Future Booking Limit, emailing the
# failure report addresses about any newly skipped dates.
class AppointmentSeriesExtendJob < ApplicationJob
  queue_as :default

  def perform
    report = []
    AppointmentSeries.open.includes(:provider, :customer, :service).find_each do |series|
      result = series.materialise
      report << [ series, result[:skipped] ] if result[:skipped].any?
    rescue StandardError => e
      Rails.logger.error("Appointment series #{series.id} not extended: #{e.message}")
    end
    AlertMailer.series_skipped(report).deliver_later if report.any?
  end
end
