module Api
  module V1
    # EA's Webhooks_model overrides api_encode/api_decode (its api_resource map is stale):
    # the real API keys are id, name, url, actions, secretToken, isSslVerified, notes.
    # secret_header is not exposed. No isActive column exists.
    class WebhookSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "name" => "name",
        "url" => "url",
        "actions" => "actions",
        "secretToken" => "secret_token",
        "isSslVerified" => "is_ssl_verified",
        "notes" => "notes"
      }.freeze

      SEARCH_COLUMNS = %w[name url actions].freeze
    end
  end
end
