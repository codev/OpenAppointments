# Builds absolute app URLs for use outside a request (sync jobs, OAuth callback).
# Host comes from Action Mailer's default_url_options (APP_HOST in production).
module SyncUrls
  module_function

  def google_callback
    "#{base_url}/google/oauth_callback"
  end

  def base_url
    options = ActionMailer::Base.default_url_options.presence || { host: "localhost", port: 3000 }
    port = options[:port] ? ":#{options[:port]}" : ""
    "#{options[:protocol] || 'http'}://#{options[:host]}#{port}"
  end
end
