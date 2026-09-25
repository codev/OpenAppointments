namespace :messages do
  desc "One-off: strip quoted text from email replies stored before stripping existed (DRY_RUN=1 counts only)"
  task restrip_quotes: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    count = QuotedReplyRestrip.run(dry_run: dry_run)
    puts dry_run ? "#{count} message(s) would be re-stripped" : "#{count} message(s) re-stripped"
  end
end
