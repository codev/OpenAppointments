require "test_helper"

# {{Customer Extra Questions}}, {{Customer Notes}} and {{Appointment Notes}} let
# a template carry what the customer told us, e.g. for the stylist's
# "appointment created" email.
class NotesAndExtraQuestionsTokensTest < ActiveSupport::TestCase
  setup do
    @customer = users(:jx)
    @appointment = appointments(:upcoming)
    Setting.set("display_custom_field_1", "1")
    Setting.set("label_custom_field_1", "Pronouns")
    Setting.set("display_custom_field_2", "1")
    Setting.set("label_custom_field_2", "Access needs")
    @customer.update!(custom_field_1: "they/them", custom_field_2: "Step-free entrance",
                      notes: "Prefers a quiet chair")
    @appointment.update!(notes: "Bring reference photo")
  end

  def appointment_context
    Messaging::Template.appointment_context(appointment: @appointment, service: services(:haircut),
                                            provider: users(:zane), customer: @customer)
  end

  test "the tokens are listed" do
    assert_includes Messaging::Template::TOKENS, "Customer Extra Questions"
    assert_includes Messaging::Template::TOKENS, "Customer Notes"
    assert_includes Messaging::Template::TOKENS, "Appointment Notes"
  end

  test "extra questions render one question and answer per line, labels from settings" do
    assert_equal "Pronouns: they/them\nAccess needs: Step-free entrance",
                 Messaging::Template.render("{{Customer Extra Questions}}", appointment_context)
  end

  test "extra questions render as a bulleted list when asked" do
    assert_equal "- Pronouns: they/them\n- Access needs: Step-free entrance",
                 Messaging::Template.render("{{Customer Extra Questions}}", appointment_context, bullets: true)
  end

  test "unanswered and hidden questions are left out" do
    @customer.update!(custom_field_2: "")
    Setting.set("display_custom_field_3", "0")
    @customer.update!(custom_field_3: "Hidden answer")
    assert_equal "Pronouns: they/them",
                 Messaging::Template.render("{{Customer Extra Questions}}", appointment_context)
  end

  test "a question with no label uses the default name" do
    Setting.set("label_custom_field_1", "")
    assert_match(/\A.+ #1: they\/them\n/, Messaging::Template.render("{{Customer Extra Questions}}", appointment_context))
  end

  test "no answered questions renders empty" do
    @customer.update!(custom_field_1: nil, custom_field_2: nil)
    assert_equal "Questions: ", Messaging::Template.render("Questions: {{Customer Extra Questions}}", appointment_context)
  end

  test "customer and appointment notes render as stored" do
    assert_equal "Prefers a quiet chair / Bring reference photo",
                 Messaging::Template.render("{{Customer Notes}} / {{Appointment Notes}}", appointment_context)
  end

  test "an incoming customer message carries the customer notes and extra questions" do
    context = Messaging::Template.customer_message_context(customer: @customer)
    assert_equal "Prefers a quiet chair\nPronouns: they/them\nAccess needs: Step-free entrance",
                 Messaging::Template.render("{{Customer Notes}}\n{{Customer Extra Questions}}", context)
  end
end
