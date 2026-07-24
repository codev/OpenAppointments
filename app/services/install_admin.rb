# Creates the fresh-install administrator account. Used by the
# openappointments:install task and the full database reset.
module InstallAdmin
  # Default password, must be changed on first login (require_password_change).
  DEFAULT_PASSWORD = "let!me!in".freeze

  module_function

  def create
    return nil if User.admins.any?

    admin = User.create!(
      name: "Edson Mori",
      email: "edson.mori@example.org",
      # Taken from https://www.ofcom.org.uk/phones-and-broadband/phone-numbers/numbers-for-drama
      phone_number: "+447700900171",
      role: Role.find_by!(slug: Role::ADMIN)
    )
    admin.create_settings!(
      username: "administrator",
      password: BCrypt::Password.create(DEFAULT_PASSWORD, cost: 12),
      notifications: true,
      calendar_view: "default",
      require_password_change: true
    )
    admin
  end
end
