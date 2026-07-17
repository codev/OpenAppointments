namespace :openappointments do
  desc "Prepare the database, seed defaults and create the initial admin (EA: console install)"
  task install: :environment do
    Rake::Task["db:prepare"].invoke
    Rake::Task["db:seed"].invoke

    if User.admins.none?
      password = SecureRandom.alphanumeric(12)
      admin = User.create!(
        first_name: "John",
        last_name: "Doe",
        email: "john@example.org",
        phone_number: "+10000000000",
        role: Role.find_by!(slug: Role::ADMIN)
      )
      admin.create_settings!(
        username: "administrator",
        password: BCrypt::Password.create(password, cost: 12),
        notifications: true,
        calendar_view: "default"
      )
      puts "Admin account created. Username: administrator  Password: #{password}"
    else
      puts "Admin account already exists, skipping."
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
