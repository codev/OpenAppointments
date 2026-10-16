require "test_helper"

# Messages screens say send and receive, never incoming and outgoing.
class MessagesVocabularyTest < ActionDispatch::IntegrationTest
  def english
    I18n.t("ea", locale: :en, fallback: false)
  end

  test "English message and inbox texts avoid incoming and outgoing" do
    offenders = english.select do |key, text|
      key.to_s.start_with?("messages_", "inbox_") && text.to_s.match?(/incoming|outgoing/i)
    end
    assert_empty offenders.keys
  end

  test "provider badges and log direction labels read send and receive" do
    assert_equal "Send and receive", english[:messages_provider_incoming_outgoing]
    assert_equal "Send only", english[:messages_provider_outgoing]
    assert_equal "Received", english[:messages_incoming_label]
    assert_equal "Sent", english[:messages_outgoing_label]
  end
end
