require "test_helper"

# Export -> OdsExtract -> Load fidelity for the manage-data backup format.
class DataExportTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  def export_to_file
    path = Rails.root.join("tmp", "data-export-test-#{SecureRandom.hex(4)}.ods").to_s
    File.binwrite(path, DataExport.generate)
    @paths ||= []
    @paths << path
    path
  end

  teardown { Array(@paths).each { |path| FileUtils.rm_f(path) } }


  test "sheets carry headers plus one row per record" do
    sheets = DataExport.sheets
    assert_equal %w[name description picture is_hidden sort_order], sheets["Service Categories"].first
    assert_equal User.customers.count, sheets["Customers"].length - 1
    assert_equal Appointment.count, sheets["Appointments"].length - 1
    assert_equal Setting.count, sheets["Settings"].length - 1

    provider_row = sheets["Providers"][1]
    header = sheets["Providers"].first
    assert_equal users(:zane).email, provider_row[header.index("email")]
    assert_includes provider_row[header.index("services")], services(:haircut).name
  end

  test "extract reads the export back with the same shape the loader expects" do
    users(:jx).update!(custom_field_1: "they/them", custom_field_2: "Step-free access",
                       city: "London", zip_code: "E1 6AN",
                       notes: "#{TenToEight::Load::DO_NOT_CONTACT_PREFIX} vip")
    path = export_to_file

    data = OdsExtract.new(path, today: Date.new(2026, 7, 20), days_back: 30, days_forward: 30).call

    customer = data[:customers].find { |row| row[:ext_id] == users(:jx).id.to_s }
    assert_equal "they/them", customer[:pronoun]
    assert_equal "Step-free access", customer[:access]
    assert_equal "London", customer[:city]
    assert customer[:do_not_contact]
    assert_equal "vip", customer[:notes]

    staff = data[:staff].find { |row| row[:email] == users(:zane).email }
    assert_includes staff[:services], services(:haircut).name
    assert_kind_of Hash, staff[:working_plan]
    assert staff[:working_plan]["monday"].present?

    appointment = data[:appointments].find { |row| row[:customer_ext_id] == users(:jx).id.to_s }
    assert_equal users(:zane).name, appointment[:staff]
    assert_equal services(:haircut).name, appointment[:service]
    assert_equal appointments(:upcoming).start_datetime, appointment[:start]
  end

  test "extract applies the appointment window and skips unavailabilities" do
    path = export_to_file

    outside = OdsExtract.new(path, today: Date.new(2027, 1, 1), days_back: 7, days_forward: 7).call
    assert_empty outside[:appointments]

    inside = OdsExtract.new(path, today: Date.new(2026, 7, 20), days_back: 7, days_forward: 7).call
    assert_equal Appointment.appointments.count, inside[:appointments].length
    assert(inside[:appointments].none? { |row| row[:staff].blank? })
  end

  test "reimporting an export after a reset restores field level detail" do
    services(:haircut).update!(price: 12.5, description: "A tidy trim", is_private: false)
    users(:jx).update!(custom_field_1: "they/them", city: "London", zip_code: "E1 6AN")
    original_plan = users(:zane).settings.working_plan
    original_start = appointments(:upcoming).start_datetime
    users(:zane).settings.update!(notifications: false, caldav_sync: true, caldav_url: "https://cal.example.org",
                                  caldav_username: "zane", caldav_password: "secret", sync_past_days: 7)
    WorkingPlanException.create!(provider: users(:zane), start_date: Date.new(2026, 8, 3),
                                 end_date: Date.new(2026, 8, 7))
    WorkingPlanException.create!(provider: users(:zane), start_date: Date.new(2026, 8, 5), end_date: Date.new(2026, 8, 5),
                                 start_time: "10:00", end_time: "14:00", breaks: [ { start: "12:00", end: "12:30" } ].to_json)
    Notification.delete_all
    Notification.create!(title: "Reminder", event: "coming_up", audiences: %w[customer], channels: %w[email sms],
                         lead_days: 1, lead_hours: 0, lead_mode: "day_at", send_time: "09:00",
                         short_text: "See you tomorrow", long_text: "Long body")
    Webhook.create!(name: "n8n", url: "https://n8n.example.org/hook", actions: "appointment_save",
                    secret_token: "tok", is_ssl_verified: false, notes: "glue")
    Consent.create!(type: "book", name: "J", email: "j@example.org", ip: "127.0.0.1", created_at: Time.new(2026, 7, 1, 9, 0, 0))
    path = export_to_file

    ResetDatabase.run

    data = OdsExtract.new(path, today: Date.new(2026, 7, 20), days_back: 30, days_forward: 30).call
    TenToEight::Load.new(data, phases: TenToEight::Load::PHASES, create_providers: true).call

    service = Service.find_by!(name: "Trim Cut")
    assert_equal 12.5, service.price.to_f
    assert_equal "A tidy trim", service.description
    assert_equal "Hair", service.category&.name

    customer = User.customers.find_by!(email: "j@example.org")
    assert_equal "they/them", customer.custom_field_1
    assert_equal "London", customer.city
    assert_equal "E1 6AN", customer.zip_code

    provider = User.providers.find_by!(email: "zane@example.org")
    assert_equal JSON.parse(original_plan), JSON.parse(provider.settings.working_plan)
    assert_equal "janedoe", provider.settings.username

    appointment = Appointment.appointments.sole
    assert_equal provider.id, appointment.id_users_provider
    assert_equal customer.id, appointment.id_users_customer
    assert_equal original_start, appointment.start_datetime

    settings = provider.settings
    assert_equal false, settings.notifications
    assert_equal true, settings.caldav_sync
    assert_equal "https://cal.example.org", settings.caldav_url
    assert_equal "secret", settings.caldav_password
    assert_equal 7, settings.sync_past_days

    exceptions = provider.working_plan_exceptions.order(:start_date).to_a
    assert_equal 2, exceptions.size
    assert_equal [ Date.new(2026, 8, 3), nil ], [ exceptions.first.start_date, exceptions.first.start_time ]
    assert_equal "12:30", exceptions.last.break_list.first["end"]

    notification = Notification.find_by!(title: "Reminder")
    assert_equal %w[email sms], notification.channels
    assert_equal "day_at", notification.lead_mode
    assert_equal "Long body", notification.long_text

    webhook = Webhook.find_by!(name: "n8n")
    assert_equal "tok", webhook.secret_token
    assert_equal false, webhook.is_ssl_verified

    consent = Consent.find_by!(email: "j@example.org")
    assert_equal "book", consent.type
    assert_equal Time.new(2026, 7, 1, 9, 0, 0), consent.created_at
  end

  test "reimporting twice does not duplicate" do
    path = export_to_file
    ResetDatabase.run

    2.times do
      data = OdsExtract.new(path, today: Date.new(2026, 7, 20), days_back: 30, days_forward: 30).call
      TenToEight::Load.new(data, phases: TenToEight::Load::PHASES, create_providers: true).call
    end

    assert_equal 1, User.customers.where(email: "j@example.org").count
    assert_equal 1, Service.where(name: "Trim Cut").count
    assert_equal 1, Appointment.appointments.count
    assert_equal Notification.distinct.count(:title), Notification.count
    assert_equal Webhook.distinct.count(:name), Webhook.count
  end
end
