require "net/imap"

# Pulls unread mail from the configured IMAP inbox ("server" mode reads the
# Cloudron mailbox addon env) into Action Mailbox. Recurring via
# config/recurring.yml, or the openappointments:fetch_mail cron target.
class FetchImapEmailsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Messaging::EmailChannel.enabled? && Messaging::EmailChannel.incoming?

    config = Messaging::EmailChannel.imap_settings
    return if config[:host].blank? || config[:username].blank?

    each_imap_message_id(config) do |msg_id, imap|
      raw_source = imap.fetch(msg_id, "RFC822").first.attr["RFC822"]
      begin
        ActionMailbox::InboundEmail.create_and_extract_message_id!(raw_source)
      rescue ActiveRecord::RecordNotUnique
        # Already ingested (concurrent fetch); just mark it read.
      end
      imap.store(msg_id, "+FLAGS", [ :Seen ])
    end
  end

  private

  def each_imap_message_id(config)
    imap = Net::IMAP.new(config[:host], port: config[:port], ssl: true)
    imap.login(config[:username], config[:password])
    begin
      imap.select("INBOX")
      imap.search([ "UNSEEN" ]).each { |msg_id| yield msg_id, imap }
    ensure
      imap.logout
      imap.disconnect
    end
  end
end
