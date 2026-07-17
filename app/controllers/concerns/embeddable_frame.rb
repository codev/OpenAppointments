# Included by the public booking-flow controllers: when embedding is enabled,
# replaces the global X-Frame-Options: SAMEORIGIN with a frame-ancestors CSP
# allowing the configured parent origin.
module EmbeddableFrame
  extend ActiveSupport::Concern

  included do
    after_action :set_frame_headers
  end

  private

  def set_frame_headers
    return unless Embedding.enabled?

    response.headers.delete("X-Frame-Options")
    response.headers["Content-Security-Policy"] = Embedding.frame_ancestors.then { |value| "frame-ancestors #{value}" }
  end
end
