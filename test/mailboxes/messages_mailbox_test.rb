require "test_helper"

class MessagesMailboxTest < ActionMailbox::TestCase
  test "inbound email from a customer becomes a message on their thread" do
    receive_inbound_email_from_mail(
      from: users(:jx).email, to: "shop@example.org",
      subject: "Running late", body: "Be there in 10"
    )
    message = Message.incoming.sole
    assert_equal users(:jx).id, message.customer_id
    assert_equal "Running late", message.subject
    assert_includes message.body, "Be there in 10"
    assert_nil message.read_at
  end

  test "the quoted reply is stripped from the body and the full text kept as the source" do
    body = "Thanks, see you Wednesday.\n\nOn Tue, 2 Sep 2026 at 17:10, Open Out <shop@example.org> wrote:\n> Your appointment is confirmed.\n"
    receive_inbound_email_from_mail(from: users(:jx).email, to: "shop@example.org", subject: "Re: Confirmed", body: body)
    message = Message.incoming.sole
    assert_equal "Thanks, see you Wednesday.", message.body
    assert_includes message.source, "> Your appointment is confirmed."
  end

  test "inbound email from an unknown sender lands in the unknown inbox" do
    receive_inbound_email_from_mail(
      from: "stranger@example.org", to: "shop@example.org",
      subject: "Hi", body: "Do you cut hair?"
    )
    assert_nil Message.incoming.sole.customer_id
    assert_equal 1, Message.unread.unknown_sender.count
  end
end
