# One-off tasks for the live migration off 10to8; each is safe to re-run.
namespace :messages do
  desc "One-off: strip quoted text from email replies stored before stripping existed (DRY_RUN=1 counts only)"
  task restrip_quotes: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    count = QuotedReplyRestrip.run(dry_run: dry_run)
    puts dry_run ? "#{count} message(s) would be re-stripped" : "#{count} message(s) re-stripped"
  end
end

namespace :notifications do
  desc "Launch day, before debug mode goes off: mark reminders already due as sent (DRY_RUN=1 counts only)"
  task mark_due_reminders_sent: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    count = Notifications.mark_due_reminders_sent(dry_run: dry_run)
    puts dry_run ? "#{count} reminder(s) would be marked sent" : "#{count} reminder(s) marked sent"
  end
end

namespace :openappointments do
  desc "Turn a service's appointments into busy time of a type: service_to_unavailabilities[SERVICE_ID,TYPE_NAME] (DRY_RUN=1 counts only)"
  task :service_to_unavailabilities, [ :service_id, :type_name ] => :environment do |_t, args|
    service = Service.find(args[:service_id])
    dry_run = ENV["DRY_RUN"] == "1"
    result = ServiceToUnavailabilities.run(service, args[:type_name], dry_run: dry_run)
    verb = dry_run ? "would become" : "became"
    puts "#{service.name}: #{result[:converted]} appointment(s) #{verb} #{result[:type]} busy time in #{result[:groups]} group(s), " \
         "#{result[:dispatches]} reminder record(s) removed. Delete the service when done."
  end
end
