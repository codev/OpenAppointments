require "test_helper"

class EmailChannelImapTest < ActiveSupport::TestCase
  test "server mode reads env, disables cert verification for the internal host" do
    Setting.set("messages_email_incoming_mode", "server")
    ENV["IMAP_HOST"] = "mail"
    ENV["IMAP_PORT"] = "9993"
    ENV["IMAP_USERNAME"] = "booking@example.org"
    ENV["IMAP_PASSWORD"] = "secret"

    config = Messaging::EmailChannel.imap_settings
    assert_equal "mail", config[:host]
    assert_equal 9993, config[:port]
    assert_equal false, config[:verify_tls]
  ensure
    %w[IMAP_HOST IMAP_PORT IMAP_USERNAME IMAP_PASSWORD].each { |key| ENV.delete(key) }
  end

  test "manual IMAP mode keeps full verification" do
    Setting.set("messages_email_incoming_mode", "imap")
    Setting.set("messages_email_imap_host", "my.example.org")
    config = Messaging::EmailChannel.imap_settings
    assert_equal "my.example.org", config[:host]
    assert_nil config[:verify_tls]
  end
end
