module Api
  module V1
    # Ported from each EA model's api_resource map. encode -> camelCase API hash,
    # decode -> attribute hash, db_field -> inverse lookup for sort. Datetimes are
    # naive Y-m-d H:i:s strings, never iso8601.
    class BaseSerializer
      class << self
        # {api_field => db_column}; subclasses set MAP.
        def map = self::MAP

        def encode(record)
          map.to_h do |api_field, db_column|
            [ api_field, format_value(record.public_send(db_column)) ]
          end
        end

        def decode(params, base = {})
          attrs = base.dup
          map.each do |api_field, db_column|
            attrs[db_column] = params[api_field] if params.key?(api_field)
          end
          attrs
        end

        def db_field(api_field) = map[api_field]

        def format_value(value)
          case value
          when Time, DateTime then value.strftime("%Y-%m-%d %H:%M:%S")
          when Date then value.strftime("%Y-%m-%d")
          when BigDecimal then value.to_f
          else value
          end
        end
      end
    end
  end
end
