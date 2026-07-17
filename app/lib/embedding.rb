# Iframe embedding of the public booking flow on an external site.
module Embedding
  # Paths a visitor hits inside the embedded wizard (cookies need SameSite=None there).
  EMBED_PATH_PREFIXES = %w[/booking /captcha /consents /localization /privacy].freeze

  module_function

  def enabled?
    Setting.get("allow_iframe_embedding", "0") == "1"
  end

  # The configured parent origin, validated down to scheme://host[:port].
  def origin
    raw = Setting.get("iframe_embed_origin").to_s.strip
    uri = URI.parse(raw)
    return "" unless %w[http https].include?(uri.scheme) && uri.host.present?

    origin = "#{uri.scheme}://#{uri.host}"
    origin += ":#{uri.port}" unless uri.default_port == uri.port
    origin
  rescue URI::InvalidURIError
    ""
  end

  def frame_ancestors
    [ "'self'", origin.presence ].compact.join(" ")
  end

  def embed_path?(path)
    path == "/" || EMBED_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }
  end

  # Cookie SameSite policy: the embedded booking flow needs None (cross-site iframe
  # POSTs must carry the session for CSRF), everything else keeps Lax.
  def same_site_for(path, enabled: enabled?)
    enabled && embed_path?(path) ? :none : :lax
  end
end
