require "test_helper"

# 10to8 service names drift from the configured catalogue (punctuation after the
# code, double spaces, curly apostrophes, a missing O-code). The loader matches
# them to the configured service instead of creating a near-duplicate.
class TenToEightServiceMatchTest < ActiveSupport::TestCase
  def configured(name)
    Service.create!(name: name, duration: 30, price: 0, currency: "GBP")
  end

  def load(data, phases:)
    TenToEight::Load.new(data, phases: phases).call
  end

  test "a 10to8 service matches the configured service with the same code" do
    colour = configured("S2 - Colour 2 hours")

    result = load({ services: [ { name: "S2. Colour 2 hours", duration: 120 } ] }, phases: %w[services])

    assert_empty result[:errors]
    assert_equal({ created: 0, matched: 1, skipped: 0, failed: 0 }, result[:counts][:services])
    assert_nil Service.find_by(name: "S2. Colour 2 hours")
    assert colour.reload
  end

  test "an uncoded 10to8 service matches the configured service whose name follows its code" do
    consultation = configured("O2 - In person consultation")

    result = load({ services: [ { name: "In person consultation" } ] }, phases: %w[services])

    assert_equal 1, result[:counts][:services][:matched]
    assert_equal [ consultation.id ], Service.where("name LIKE '%consultation%'").pluck(:id)
  end

  test "spacing and apostrophes do not stop a match when two services share a code" do
    kids = configured("C7 - Kid’s curly hair trim (under 10s)")
    configured("C7 - Curly hair restyle with scissors and clippers")

    result = load({ services: [ { name: "C7 - Kid's curly hair trim  (under 10s)" } ] }, phases: %w[services])

    assert_equal 1, result[:counts][:services][:matched]
    assert_equal 2, Service.where("name LIKE 'C7%'").count
    assert kids.reload
  end

  test "a shared code with a different name creates a new service rather than guessing" do
    configured("C7 - Kid’s curly hair trim (under 10s)")
    configured("C7 - Curly hair restyle with scissors and clippers")

    result = load({ services: [ { name: "C7 - Kid's curly hair hair trim (under 10s)" } ] }, phases: %w[services])

    assert_equal 1, result[:counts][:services][:created]
    assert_equal 3, Service.where("name LIKE 'C7%'").count
  end

  test "an appointments run without the services phase links by code too" do
    trainee = configured("TS9 - Scissor trim of layered hair WITH TRAINEE")
    alice = User.create!(name: "Alice", email: "alice@example.org", role: Role.find_by!(slug: Role::PROVIDER))
    alice.create_settings!(username: "alice", password: Passwords.hash("alicealice1"), notifications: false)
    start = Time.zone.parse("2026-07-15 10:00")
    data = {
      staff: [ { name: "Alice Stylist" } ],
      customers: [ { ext_id: "C1", name: "Bella", email: "bella@example.org", phone: "+447700900222" } ],
      appointments: [ { event_id: "E1", staff: "Alice Stylist", service: "TS9 -  Trainee stylist – scissor trim of layered hair",
                        customer_ext_id: "C1", start: start, end: start + 45.minutes, status: "Booked" } ]
    }

    result = load(data, phases: %w[customers appointments])

    assert_empty result[:errors]
    assert_equal 1, result[:counts][:appointments][:created]
    assert_equal trainee.id, Appointment.find_by(start_datetime: start).id_services
  end
end
