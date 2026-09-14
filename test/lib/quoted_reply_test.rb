require "test_helper"

# Reply text as the common mail clients quote it; only the new text is kept.
class QuotedReplyTest < ActiveSupport::TestCase
  test "gmail: On ... wrote: line and > quoted lines go, even when the header wraps" do
    text = <<~MAIL
      Thanks, see you Wednesday.

      On Tue, 2 Sep 2026 at 17:10, Open Out
      <shop@example.org> wrote:
      > Your appointment is confirmed.
      > Service: RC1
    MAIL
    assert_equal "Thanks, see you Wednesday.", Messaging::QuotedReply.strip(text)
  end

  test "outlook: underscore rule with From/Sent headers and the Original Message marker go" do
    text = <<~MAIL
      Greygory
      Test email reply 3rd Sept

      ________________________________
      From: Open Out <shop@example.org>
      Sent: 02 September 2026 17:10
      To: gregory.james@hotmail.com
      Subject: Your appointment is confirmed

      Your appointment is confirmed.
    MAIL
    assert_equal "Greygory\nTest email reply 3rd Sept", Messaging::QuotedReply.strip(text)

    text = "Yes please\n\n-----Original Message-----\nFrom: Open Out\nSent: 02 September 2026 17:10\n\nConfirmed"
    assert_equal "Yes please", Messaging::QuotedReply.strip(text)

    text = "Running late\n\nFrom: Open Out <shop@example.org>\nSent: 02 September 2026 17:10\nTo: me\nSubject: Hi\n\nConfirmed"
    assert_equal "Running late", Messaging::QuotedReply.strip(text)
  end

  test "apple mail: quoted On ... wrote: header inside > lines goes" do
    text = <<~MAIL
      Can I move it to 3pm?

      > On 2 Sep 2026, at 17:10, Open Out <shop@example.org> wrote:
      >
      > Your appointment is confirmed.
    MAIL
    assert_equal "Can I move it to 3pm?", Messaging::QuotedReply.strip(text)
  end

  test "the -- signature separator ends the message" do
    text = "See you then\n-- \nRachel\nOpen Out"
    assert_equal "See you then", Messaging::QuotedReply.strip(text)
    assert_equal "See you then", Messaging::QuotedReply.strip("See you then\n--\nRachel")
  end

  test "a From: line without mail headers after it is ordinary text" do
    text = "From: the bottom of my heart, thank you\nSee you Tuesday"
    assert_equal text, Messaging::QuotedReply.strip(text)
  end

  test "a reply that is nothing but quote keeps its text" do
    text = "> just a forward\n> of the old mail"
    assert_equal text, Messaging::QuotedReply.strip(text)
  end
end
