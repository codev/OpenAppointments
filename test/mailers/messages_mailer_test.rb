require "test_helper"

class MessagesMailerTest < ActionMailer::TestCase
  test "a web address in the body is a link in the html part" do
    message = outgoing_message("View or change the appointment: https://example.org/booking/reschedule/abc\nThank you")
    html = html_body(MessagesMailer.outgoing(message))
    assert_match %r{<a href="https://example.org/booking/reschedule/abc">https://example.org/booking/reschedule/abc</a>}, html
    assert_match "<br", html
  end

  test "markup in the body stays text" do
    message = outgoing_message("Notes: <b>bold</b> & a < b")
    html = html_body(MessagesMailer.outgoing(message))
    assert_match "&lt;b&gt;bold&lt;/b&gt; &amp; a &lt; b", html
    assert_no_match "<b>", html
  end

  private

  # The html part when the mail carries an attachment, else the whole body.
  def html_body(mail)
    (mail.html_part || mail).body.to_s
  end

  def outgoing_message(body)
    Message.create!(direction: "outgoing", channel: "email", audience: "customer",
                    to_address: "someone@example.org", subject: "Booked", body: body, status: "queued")
  end
end
