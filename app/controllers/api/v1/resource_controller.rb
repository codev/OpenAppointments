module Api
  module V1
    # Generic EA-style CRUD. Subclasses declare the model, serializer, and optional
    # webhook actions via the class-level config; they override the hooks below for
    # per-resource behaviour (extra filters, nested settings, side effects).
    class ResourceController < BaseController
      class_attribute :model_class, :serializer_class, :save_webhook, :delete_webhook

      def index
        records = filtered_scope(base_scope)
        order = api_order(serializer_class)
        records = records.order(Arel.sql(order)) if order
        records = records.limit(api_length).offset(api_offset)
        render json: records.map { |record| present(record) }
      end

      def show
        record = base_scope.find_by(id: params[:id])
        return head :not_found unless record

        render json: present(record)
      end

      def store
        record = build_record(api_body.except("id"))
        persist!(record)
        trigger_save_webhook(record)
        render_one(encode(record), status: :created)
      end

      def update
        record = base_scope.find_by(id: params[:id])
        return head :not_found unless record

        apply_update(record, api_body.except("id"))
        persist!(record)
        trigger_save_webhook(record)
        render_one(encode(record))
      end

      def destroy
        record = base_scope.find_by(id: params[:id])
        return head :not_found unless record

        record.destroy!
        trigger_delete_webhook(record)
        head :no_content
      end

      private

      # Overridable hooks --------------------------------------------------------

      def base_scope = model_class.all

      def build_record(attrs)
        model_class.new(serializer_class.decode(attrs))
      end

      def apply_update(record, attrs)
        record.assign_attributes(serializer_class.decode(attrs))
      end

      def persist!(record) = record.save!

      def encode(record) = serializer_class.encode(record)

      def extra_filters(scope) = scope

      # {api name => loader} for the "with" param; resources without relations keep {}.
      def with_loaders = {}

      # Shared machinery ---------------------------------------------------------

      # fields projection first, then with-embeds on top (EA order: only() then load()).
      def present(record)
        payload = project_fields(encode(record))
        embed_relations(record, payload)
      end

      # EA model->load: embeds the RAW db row(s), not the api-encoded resource. Unknown
      # names raise on resources that support relations and are ignored on those that
      # do not (their load() is empty), matching EA exactly.
      def embed_relations(record, payload)
        relations = api_with
        return payload unless relations

        loaders = with_loaders
        relations.each do |name|
          loader = loaders[name]
          if loader
            payload[name] = loader.call(record)
          elsif loaders.any?
            raise ArgumentError, "The requested relation is not supported: #{name}"
          end
        end
        payload
      end

      def raw_row(record)
        record&.attributes&.transform_values { |value| BaseSerializer.format_value(value) }
      end

      def filtered_scope(scope)
        scope = keyword_filter(scope)
        extra_filters(scope)
      end

      def keyword_filter(scope)
        keyword = api_keyword
        columns = serializer_class::SEARCH_COLUMNS
        return scope if keyword.blank? || columns.empty?

        pattern = "%#{scope.klass.sanitize_sql_like(keyword)}%"
        clause = columns.map { |column| "#{column} LIKE :pattern" }.join(" OR ")
        scope.where(clause, pattern: pattern)
      end

      def api_body
        @api_body ||= request.request_parameters.presence || {}
      end

      def trigger_save_webhook(record)
        Webhooks.trigger(save_webhook, record) if save_webhook
      end

      def trigger_delete_webhook(record)
        Webhooks.trigger(delete_webhook, record) if delete_webhook
      end
    end
  end
end
