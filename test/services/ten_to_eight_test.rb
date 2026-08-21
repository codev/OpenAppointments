require "test_helper"

class TenToEightTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 7, 10)

  def extract(**options)
    TenToEight::Extract.new(file_fixture("ten_to_eight_export.csv").to_s, today: TODAY, **options).call
  end

  test "extract dedupes events and customers and filters the window" do
    data = extract
    assert_equal %w[E1 E2 E6], data[:appointments].map { |a| a[:event_id] }.sort
    e1 = data[:appointments].find { |a| a[:event_id] == "E1" }
    assert_equal "2026-07-15 10:00:00", e1[:start].strftime("%Y-%m-%d %H:%M:%S")
    assert_equal "2026-07-15 10:30:00", e1[:end].strftime("%Y-%m-%d %H:%M:%S")
    assert_equal "note one", e1[:note]
    assert_equal 3, data[:customers].size
  end

  test "extract derives the recent service catalogue with categories" do
    services = extract[:services].index_by { |s| s[:name] }
    assert_equal %w[C\ Curl\ cut TC\ Buzz TS\ Short\ trim], services.keys.sort
    assert_equal "Scissor trims", services["TS Short trim"][:category]
    assert_equal "Curly hair", services["C Curl cut"][:category]
    assert_equal "Clipper trims", services["TC Buzz"][:category]
    assert_equal 30, services["TS Short trim"][:duration]
    assert_not services.key?("Blocked Time")
  end

  test "extract normalises phones and consent" do
    customers = extract[:customers].index_by { |c| c[:ext_id] }
    assert_equal "+447700900222", customers["C1"][:phone]
    assert_equal "+447700900333", customers["C2"][:phone]
    assert_equal "she/her", customers["C1"][:pronoun]
    assert customers["C2"][:do_not_contact]
    assert_not customers["C1"][:do_not_contact]
    assert_equal "Cher", customers["C2"][:name]
  end

  test "extract respects a custom window" do
    data = extract(days_back: 200, days_forward: 21)
    assert_includes data[:appointments].map { |a| a[:event_id] }, "E5"
  end

  test "load creates the catalogue, providers, customers and appointments" do
    data = extract
    counts = TenToEight::Load.new(data, phases: TenToEight::Load::PHASES, create_providers: true).call[:counts]

    assert_equal 3, counts[:categories][:created]
    assert_equal 3, counts[:services][:created]
    assert_equal 2, counts[:providers][:created]
    assert_equal 3, counts[:customers][:created]
    assert_equal 3, counts[:appointments][:created]

    alice = User.providers.find_by(email: "alice@example.org")
    assert_equal "alice", alice.settings.username
    assert_includes alice.services.map(&:name), "TS Short trim"

    bella = User.customers.find_by(email: "bella@example.org")
    assert_equal "she/her", bella.custom_field_1
    assert_equal "Larger chair please", bella.custom_field_2

    cher = User.customers.find_by(name: "Cher")
    assert_match(/DO NOT CONTACT/, cher.notes)

    appointment = Appointment.find_by(id_users_customer: bella.id, start_datetime: "2026-07-15 10:00:00")
    assert_equal alice.id, appointment.id_users_provider
    assert_equal "note one", appointment.notes
  end

  test "load is idempotent and matches existing records by email" do
    data = extract
    TenToEight::Load.new(data, phases: TenToEight::Load::PHASES, create_providers: true).call
    second = TenToEight::Load.new(data, phases: TenToEight::Load::PHASES, create_providers: true).call[:counts]

    assert_equal 0, second[:customers][:created]
    assert_equal 0, second[:services][:created]
    assert_equal 0, second[:appointments][:created]
    assert_equal 1, User.customers.where(email: "bella@example.org").count
  end

  test "load respects the phase selection" do
    data = extract
    counts = TenToEight::Load.new(data, phases: %w[categories services]).call[:counts]
    assert_equal 3, counts[:services][:created]
    assert_nil counts[:customers]
    assert_equal 0, User.customers.where(email: "bella@example.org").count
  end

  test "record failures are collected and do not abort the run" do
    data = { services: [ { name: nil, duration: 30 }, { name: "Good Service", duration: 30 } ] }
    result = TenToEight::Load.new(data, phases: %w[services]).call

    assert_equal 1, result[:counts][:services][:failed]
    assert_equal 1, result[:counts][:services][:created]
    assert Service.exists?(name: "Good Service")
    error = result[:errors].first
    assert_equal "services", error[:phase]
    assert error[:message].present?
  end

  test "short service durations are clamped to the five minute minimum" do
    data = { services: [ { name: "Quick Fringe", duration: 2 } ] }
    result = TenToEight::Load.new(data, phases: %w[services]).call

    assert_empty result[:errors]
    assert_equal 5, Service.find_by(name: "Quick Fringe").duration
  end

  test "appointments land under an existing provider matched by first name" do
    data = extract
    TenToEight::Load.new(data, phases: %w[categories services customers]).call
    alice = User.create!(name: "Alice", email: "a@example.org", role: Role.find_by!(slug: Role::PROVIDER))
    alice.create_settings!(username: "alice", password: Passwords.hash("alicealice1"), notifications: false)

    counts = TenToEight::Load.new(data, phases: %w[appointments]).call[:counts]

    assert_equal 2, counts[:appointments][:created]
    assert_equal 1, counts[:appointments][:skipped], "the other staff member has no provider"
    assert_equal 2, Appointment.where(id_users_provider: alice.id).count
  end

  test "providers phase matches an existing provider by name and links the services" do
    data = extract
    TenToEight::Load.new(data, phases: %w[categories services]).call
    alice = User.create!(name: "alice stylist", email: "a@example.org", role: Role.find_by!(slug: Role::PROVIDER))
    alice.create_settings!(username: "alice", password: Passwords.hash("alicealice1"), notifications: false)

    counts = TenToEight::Load.new(data, phases: %w[providers]).call[:counts]

    assert_equal 1, counts[:providers][:matched]
    assert_includes alice.reload.services.map(&:name), "TS Short trim"
    assert_equal 1, User.providers.where("lower(users.name) LIKE 'alice%'").count
  end

  test "phases run as separate imports still link and resolve via the database" do
    data = extract
    TenToEight::Load.new(data, phases: %w[categories]).call
    TenToEight::Load.new(data, phases: %w[services]).call
    TenToEight::Load.new(data, phases: %w[providers], create_providers: true).call
    TenToEight::Load.new(data, phases: %w[customers]).call
    counts = TenToEight::Load.new(data, phases: %w[appointments]).call[:counts]

    assert_equal 3, counts[:appointments][:created]
    imported = Service.where(name: data[:services].map { |s| s[:name] })
    assert_equal 3, imported.count
    assert imported.all? { |s| s.id_service_categories.present? }
    alice = User.providers.find_by(email: "alice@example.org")
    assert_includes alice.services.map(&:name), "TS Short trim"
  end
end
