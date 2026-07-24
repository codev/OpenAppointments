namespace :openappointments do
  desc "Prepare the database, seed defaults and create the initial admin (EA: console install)"
  task install: :environment do
    Rake::Task["db:prepare"].invoke
    Rake::Task["db:seed"].invoke

    if InstallAdmin.create
      puts "Admin account created. Change password on first login. " \
           "Username: administrator  Password: #{InstallAdmin::DEFAULT_PASSWORD}"
    else
      puts "Admin account already exists, skipping."
    end
  end

  desc "Pull remote Google Calendar changes for providers with sync enabled (cron target)"
  task sync: :environment do
    result = CalendarPull.run
    puts "Calendar sync: #{result[:providers]} providers, " \
         "#{result[:imported]} imported, #{result[:removed]} removed."
  end

  desc "GDPR data retention cleanup: purge customers past data_retention_days (cron target)"
  task cleanup: :environment do
    result = Cleanup.run
    if result[:enabled]
      puts "Data retention cleanup: deleted #{result[:deleted]} customer(s)."
    else
      puts "Data retention is disabled (data_retention_days = 0)."
    end
    puts "Message retention: deleted #{result[:messages_deleted]} message(s)."
  end

  desc "Send due coming-up notifications (cron target)"
  task reminders: :environment do
    Notifications.scan_coming_up
    puts "Reminder scan complete."
  end

  desc "Fetch unread incoming email over IMAP into Action Mailbox (cron target)"
  task fetch_mail: :environment do
    FetchImapEmailsJob.perform_now
    puts "Mail fetch complete."
  end

  desc "Back up the SQLite databases to storage/backups or the given path"
  task :backup, [ :path ] => :environment do |_t, args|
    path = args[:path] || Rails.root.join("storage/backups").to_s
    FileUtils.mkdir_p(path)
    stamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
    db_path = ActiveRecord::Base.connection_db_config.database
    target = File.join(path, "openappointments-backup-#{stamp}.sqlite3")
    ActiveRecord::Base.connection.execute("VACUUM INTO #{ActiveRecord::Base.connection.quote(target)}")
    puts "Backup written to #{target}"
  end
end
