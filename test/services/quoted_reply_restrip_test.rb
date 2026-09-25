require "test_helper"
require "rake"

# Replies received before quote stripping existed have the quote in the body
# and no source. The one-off task strips them, keeping the original in source.
class QuotedReplyRestripTest < ActiveSupport::TestCase
  OUTLOOK = <<~MAIL.freeze
    Greygory
    Test email reply 3rd Sept

    ________________________________
    From: Open Out <shop@example.org>
    Sent: 02 September 2026 17:10
    To: gregory.james@hotmail.com
    Subject: Your appointment is confirmed

    Your appointment is confirmed.
  MAIL

  def incoming(body, channel: "email", source: nil)
    Message.create!(direction: "incoming", channel: channel, from_address: users(:jx).email,
                    customer_id: users(:jx).id, body: body, source: source, status: "received")
  end

  setup do
    @old = incoming(OUTLOOK)
    @clean = incoming("Just a line")
    @stripped = incoming("Already stripped", source: "Already stripped\n\nOn Tue wrote:\n> old")
    @sms = incoming("Hi\n\nFrom: x\nSent: y\n\nquoted", channel: "twilio")
  end

  test "old email replies are stripped with the original kept, others untouched" do
    assert_equal 1, QuotedReplyRestrip.run
    @old.reload
    assert_equal "Greygory\nTest email reply 3rd Sept", @old.body
    assert_equal OUTLOOK, @old.source
    assert_equal [ "Just a line", nil ], [ @clean.reload.body, @clean.source ]
    assert_equal "Already stripped", @stripped.reload.body
    assert_equal "Hi\n\nFrom: x\nSent: y\n\nquoted", @sms.reload.body
    assert_equal 0, QuotedReplyRestrip.run, "a second run changes nothing"
  end

  test "a dry run counts without changing anything" do
    assert_equal 1, QuotedReplyRestrip.run(dry_run: true)
    assert_equal OUTLOOK, @old.reload.body
    assert_nil @old.source
  end

  test "the rake task prints the count and honours DRY_RUN" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("messages:restrip_quotes")
    ENV["DRY_RUN"] = "1"
    assert_output(/1 message\(s\) would be re-stripped/) { Rake::Task["messages:restrip_quotes"].execute }
    assert_nil @old.reload.source
    ENV.delete("DRY_RUN")
    assert_output(/1 message\(s\) re-stripped/) { Rake::Task["messages:restrip_quotes"].execute }
    assert_equal OUTLOOK, @old.reload.source
  ensure
    ENV.delete("DRY_RUN")
  end
end
