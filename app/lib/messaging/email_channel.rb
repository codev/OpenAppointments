require "net/imap"
require "net/smtp"

# Email channel. Outgoing goes through the app server mail config ("server"
# mode, Cloudron sendmail addon) or admin-entered SMTP. Incoming is fetched over
# IMAP (or the Cloudron mailbox addon env) into Action Mailbox.
module Messaging
  module EmailChannel
    module_function

    def key = "email"

    def label = "Email"

    def supports_long_text? = true

    def enabled?
      Setting.get("messages_email_enabled", "1") == "1"
    end

    def incoming?
      Setting.get("messages_email_incoming") == "1"
    end

    def address_for(user)
      user&.email.presence
    end

    # With a config the mail goes the way that config says (the provider page's
    # test send); without one the mailer applies the stored SMTP settings itself.
    def deliver(message, config = nil)
      mail = MessagesMailer.outgoing(message)
      if config
        smtp = smtp_settings(config)
        method = ActionMailer::Base.delivery_method
        smtp ? mail.delivery_method(:smtp, smtp) : mail.delivery_method(method, ActionMailer::Base.public_send("#{method}_settings"))
      end
      mail.deliver_now
    end

    # [ok, message]: sending and receiving checked one after the other, each
    # reported on its own line so a failure names the side that failed.
    def check_credentials(config = Messaging.config)
      results = [ check_outgoing(config), check_incoming(config) ]
      [ results.all?(&:first), results.map(&:last).join(" ") ]
    end

    def check_outgoing(config)
      smtp = smtp_settings(config)
      return [ false, "#{I18n.t('ea.messages_test_outgoing_failed')} #{I18n.t('ea.messages_smtp_host')}" ] if config["messages_email_mode"] == "smtp" && smtp.nil?
      return [ true, I18n.t("ea.messages_test_outgoing_server") ] unless smtp

      client = Net::SMTP.new(smtp[:address], smtp[:port])
      client.open_timeout = 5
      client.read_timeout = 10
      smtp[:enable_starttls_auto] ? client.enable_starttls_auto : client.disable_starttls
      client.start("localhost", smtp[:user_name], smtp[:password], smtp[:authentication]) { nil }
      [ true, I18n.t("ea.messages_test_outgoing_ok") ]
    rescue StandardError => e
      [ false, "#{I18n.t('ea.messages_test_outgoing_failed')} #{e.message}" ]
    end

    def check_incoming(config)
      return [ true, I18n.t("ea.messages_test_incoming_off") ] unless config["messages_email_incoming"] == "1"

      imap = imap_settings(config)
      return [ false, "#{I18n.t('ea.messages_test_incoming_failed')} #{I18n.t('ea.messages_imap_host')}" ] if imap[:host].blank?

      ssl = imap[:verify_tls] == false ? { verify_mode: OpenSSL::SSL::VERIFY_NONE } : true
      client = Net::IMAP.new(imap[:host], port: imap[:port], ssl: ssl, open_timeout: 5)
      client.login(imap[:username], imap[:password])
      client.logout
      client.disconnect
      [ true, I18n.t("ea.messages_test_incoming_ok") ]
    rescue StandardError => e
      [ false, "#{I18n.t('ea.messages_test_incoming_failed')} #{e.message}" ]
    end

    # nil when outgoing mode is "server" (use the environment delivery config).
    def smtp_settings(config = Messaging.config)
      return nil unless config["messages_email_mode"] == "smtp"

      host = config["messages_email_smtp_host"].presence
      return nil unless host

      username = config["messages_email_smtp_username"].presence
      {
        address: host,
        port: config["messages_email_smtp_port"].to_i,
        user_name: username,
        password: config["messages_email_smtp_password"].presence,
        authentication: username ? :plain : nil,
        enable_starttls_auto: config["messages_email_smtp_tls"] == "1"
      }.compact
    end

    def imap_settings(config = Messaging.config)
      if config["messages_email_incoming_mode"] == "server"
        {
          host: ENV["IMAP_HOST"].presence,
          port: ENV.fetch("IMAP_PORT", "993").to_i,
          username: ENV["IMAP_USERNAME"].presence,
          password: ENV["IMAP_PASSWORD"].presence,
          # The internal mail host's certificate names the public mail domain,
          # not the addon alias, so hostname verification cannot pass.
          verify_tls: false
        }
      else
        {
          host: config["messages_email_imap_host"].presence,
          port: config["messages_email_imap_port"].to_i,
          username: config["messages_email_imap_username"].presence,
          password: config["messages_email_imap_password"].presence
        }
      end
    end
  end
end
