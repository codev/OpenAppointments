require "test_helper"

# A template naming a token we do not know still saves; the page lists the
# unknown ones so a typo does not go out as a blank.
class UnknownTokensTest < ActiveSupport::TestCase
  test "tokens not in the list are returned once each, as written" do
    assert_equal [ "Custmer Name", "Colour" ],
                 Messaging::Template.unknown_tokens("Hi {{Custmer Name}} {{ Colour }}", "{{custmer name}} {{Service Name}}")
  end

  test "known tokens match case-insensitively and blank texts have none" do
    assert_equal [], Messaging::Template.unknown_tokens("{{customer name}} {{APPOINTMENT NOTES}}", nil)
  end

  test "a notification reports the unknown tokens of both texts" do
    notification = Notification.new(short_text: "{{Nope}}", long_text: "{{Customer Name}} {{Also Nope}}")
    assert_equal [ "Nope", "Also Nope" ], notification.unknown_tokens
  end
end
