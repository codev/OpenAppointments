module Api
  module V1
    class SecretarySerializer < UserSerializer
      MAP = UserSerializer::MAP

      class << self
        def encode(record)
          payload = super
          payload["providers"] = record.providers.map(&:id)
          payload
        end

        def decode(params, base = {})
          attrs = super
          attrs["providers"] = params["providers"] if params.key?("providers")
          attrs
        end
      end
    end
  end
end
