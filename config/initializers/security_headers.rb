# Security response headers, ported from EA's routes.php header set. Applied to every
# response so the ported frontend behaves the same as it did under EA.
Rails.application.config.action_dispatch.default_headers.merge!(
  "X-Frame-Options" => "SAMEORIGIN",
  "X-Content-Type-Options" => "nosniff",
  "X-XSS-Protection" => "1; mode=block",
  "Referrer-Policy" => "strict-origin-when-cross-origin",
  "Permissions-Policy" => "geolocation=(), microphone=(), camera=()"
)
