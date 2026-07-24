namespace :openappointments do
  desc "Prepare the database, seed defaults and create the initial admin (EA: console install)"
  task install: :environment do
    Rake::Task["db:prepare"].invoke
    Rake::Task["db:seed"].invoke

    if User.admins.none?
      # Using a default password which should be changed on first login
      password = "let!me!in" # SecureRandom.alphanumeric(12)
      admin = User.create!(
        name: "Edson Mori",
        email: "edson.mori@example.org",
        # Taken from https://www.ofcom.org.uk/phones-and-broadband/phone-numbers/numbers-for-drama
        phone_number: "+447700900171",
        role: Role.find_by!(slug: Role::ADMIN)
      )
      admin.create_settings!(
        username: "administrator",
        password: BCrypt::Password.create(password, cost: 12),
        notifications: true,
        calendar_view: "default"
      )
      puts "Admin account created. Change password on first login. Username: administrator  Password: #{password}"
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
