module ModelApi
  module OpenApiExtensions
    module ClassMethods
      def add_open_api_action(action, operation, opts = {})
        return unless respond_to?(:open_api_action) # Must have open_api gem installed
        opts = opts.merge(action: action, operation: operation)
        if ENV['ADMIN'].present? && ENV['ADMIN'].to_s != '0'
          opts[:admin_content] = true
        elsif opts[:admin_only]
          open_api_action action, hidden: :true
          return
        end
        open_api_spec = {}
        open_api_spec[:description] = opts[:description] if opts.include?(:description)
        response_class = opts[:response] || model_class
        if operation == :index || opts[:collection]
          response = Utils.define_api_collection_response(self, response_class, opts)
          open_api_spec[:query_string] = Utils.filter_and_sort_params(self, response_class, opts)
        else
          response = Utils.define_api_response(self, response_class,
              opts.merge(operation: :show))
        end
        open_api_spec[:responses] = { 200 => { schema: response } } if response.present?
        if [:create, :update, :patch].include?(operation)
          payload = opts[:payload] || model_class
          if payload.present?
            open_api_spec[:body] = { description: 'Payload', schema: Utils.define_open_api_object(
                self, payload, opts.merge(object_context: :payload)) }
          end
        end
        open_api_action action, open_api_spec
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end

    class Utils
      class << self
        def define_api_response(controller_class, model_class, opts = {})
          object_name = define_open_api_object(controller_class, model_class, opts)
          return nil unless object_name.present?
          wrapper_object_name = "#{object_name}:response"
          response_object_metadata = { type: :object, required: true }
          response_object_metadata[:'$ref'] = object_name if object_name.present?
          controller_class.send(:open_api_object, wrapper_object_name,
              successful: { type: :boolean, required: true,
                  description: 'Returns true if successfully processed; otherwise false' },
              status: { type: :string, required: true, description: 'HTTP status' },
              statusCode: { type: :integer, required: true,
                  description: 'Numeric HTTP status code' },
              ModelApi::Utils.ext_attr(opts[:root] ||
                  ModelApi::Utils.model_name(model_class).singular) => response_object_metadata)
          wrapper_object_name
        end

        def filter_and_sort_params(controller_class, model_class, opts = {})
          params = opts[:parameters] || {}
          opts = opts.merge(attr_types: attr_types_from_columns(model_class))
          attr_prefix = opts[:attr_prefix]
          sort_attrs = []

          filter_metadata = ModelApi::Utils.filtered_ext_attrs(model_class, :filter, opts)
          filter_metadata.each do |attr, attr_metadata|
            if attr_metadata[:type] == :association
              next unless (assoc = attr_metadata[:association]).present? &&
                  assoc.respond_to?(:klass)
              assoc_params = filter_and_sort_params(controller_class, assoc.klass,
                  opts.merge(attr_prefix: "#{attr}."))
              sort_attrs += assoc_params.delete(:sort_by) || []
              assoc_params.each { |assoc_attr, property_hash| params[assoc_attr] ||= property_hash }
            else
              property_hash = open_api_attr_hash(controller_class, model_class, attr, attr_metadata,
                  opts)
              property_hash.merge!(
                  description: filter_description(attr_prefix, attr, property_hash, attr_metadata),
                  required: false)
              next if property_hash.include?(:'$ref')
              params[:"#{attr_prefix}#{attr}"] ||= property_hash
            end
          end

          add_sort_params(params, model_class, sort_attrs, opts)
        end

        def add_sort_params(params, model_class, addl_sort_attrs, opts)
          attr_prefix = opts[:attr_prefix]
          if (sort_metadata = ModelApi::Utils.filtered_ext_attrs(model_class, :sort, opts)).present?
            if attr_prefix.present?
              params[:sort_by] = sort_metadata.keys.sort.map { |k| :"#{attr_prefix}#{k}" }
            else
              addl_sort_attrs = (sort_metadata.keys + addl_sort_attrs).compact.sort
              params[:sort_by] = { type: :string,
                  description: "Sortable fields: #{addl_sort_attrs.join(', ')} " \
                    '(optionally append " asc" or " desc" on field(s) to indicate sort order)' }
            end
          end
          params
        end

        def filter_description(attr_prefix, attr, property_hash, attr_metadata)
          return attr_metadata[:filter_description] if attr_metadata[:filter_description].present?
          desc = "Filter by #{attr_prefix}#{attr}"
          case property_hash[:type]
          when :string
            case property_hash[:format]
            when :date, :'date-time'
              "#{desc} (supports <, <=, !=, >= > operator prefixes, comma-delimited criteria)"
            else
              "#{desc} (supports comma-delimited values)"
            end
          when :boolean
            "#{desc} (must be true or false)"
          when :integer, :number
            "#{desc} (supports comma-delimited values, <, <=, !=, >= > operator prefixes)"
          else
            desc
          end
        end

        def define_api_collection_response(controller_class, model_class, opts = {})
          object_name = define_open_api_object(controller_class, model_class, opts)
          return nil unless object_name.present?
          wrapper_object_name = "#{object_name}:response"
          array_metadata = { type: :array, required: true }
          array_metadata[:'$ref'] = object_name if object_name.present?
          controller_class.send(:open_api_object, wrapper_object_name,
              successful: { type: :boolean, required: true,
                  description: 'Returns true if successfully processed; otherwise false' },
              status: { type: :string, description: 'HTTP status', required: true },
              statusCode: { type: :integer, description: 'Numeric HTTP status code',
                  required: true },
              ModelApi::Utils.model_name(model_class).plural => array_metadata,
              count: { type: :integer, description: 'Total items available', required: true },
              page: { type: :integer, description: 'Index (1-based) of page returned',
                  required: true },
              pageCount: { type: :integer, description: 'Total number of pages available',
                  required: true },
              pageSize: { type: :integer, description: 'Maximum item count per page returned',
                  required: true })
          wrapper_object_name
        end

        def define_open_api_object(controller_class, define_open_api_object, opts = {})
          define_open_api_objects(controller_class, define_open_api_object, opts).first
        end

        def define_open_api_objects(controller_class, *define_open_api_objects)
          if define_open_api_objects.size > 1 && (opts = define_open_api_objects.last).is_a?(Hash)
            define_open_api_objects = define_open_api_objects[0..-2]
          else
            opts = {}
          end
          object_names = []
          define_open_api_objects.compact.uniq.each do |model_class|
            object_names << define_open_api_object_from_model(controller_class, model_class, opts)
          end
          object_names.compact
        end

        def define_open_api_object_from_model(controller_class, model_class, opts = {})
          operation = opts[:operation] || :show
          metadata_opts = opts.merge(ModelApi::Utils.contextual_metadata_opts(opts))
          metadata = ModelApi::Utils.filtered_attrs(model_class, operation, metadata_opts)
          return nil unless metadata.present?

          action = (opts = opts.dup).delete(:action) # Prevent inheritance

          object_name = ModelApi::Utils.model_name(model_class).name
          if (parent_object_context = opts[:object_context]).present?
            object_name = "#{parent_object_context}|#{object_name}"
          end
          object_name = "#{object_name}|#{action}" if action.present?

          @open_api_views_processed ||= {}
          return object_name if @open_api_views_processed[object_name]
          @open_api_views_processed[object_name] = model_class

          class_model_base(metadata, controller_class, model_class,
              opts.merge(object_context: object_name))
          object_name
        end

        def class_model_base(metadata, controller_class, model_class, opts)
          properties = {}
          opts = opts.merge(attr_types: attr_types_from_columns(model_class))
          metadata.each do |attr, attr_metadata|
            properties[ModelApi::Utils.ext_attr(attr, attr_metadata)] = open_api_attr_hash(
                controller_class, model_class, attr, attr_metadata, opts)
          end
          controller_class.send(:open_api_object, opts[:object_context].to_sym, properties)
        end

        # rubocop:disable Metrics/ParameterLists
        def open_api_attr_hash(controller_class, model_class, attr, attr_metadata, opts)
          property_hash = class_model_base_property(model_class, attr, attr_metadata)
          if (attr_type = attr_metadata[:type]).is_a?(Symbol) &&
              ![:attribute, :association].include?(attr_type)
            ModelApi::Utils.set_open_api_type_and_format(property_hash, attr_type)
          else
            attr_types = opts[:attr_types] || attr_types_from_columns(model_class)
            if (attr_type = attr_types[attr_metadata[:key]]).present?
              ModelApi::Utils.set_open_api_type_and_format(property_hash, attr_type)
            elsif (assoc = model_class.reflect_on_association(attr)).present?
              property_hash = class_model_assoc_property(property_hash, controller_class,
                  attr_metadata, opts.merge(association: assoc))
            end
          end
          property_hash[:type] ||= :string unless property_hash.include?(:'$ref')
          property_hash
        end

        # rubocop:enable Metrics/ParameterLists

        def class_model_base_property(model_class, attr, attr_metadata)
          if (required = attr_metadata[:required]).nil?
            required_attrs ||= required_attrs_from_validators(model_class)
            required = required_attrs.include?(attr)
          end
          property_hash = { required: required ? true : false }
          if (description = attr_metadata[:description]).present?
            property_hash[:description] = description
          end
          property_hash
        end

        def class_model_assoc_property(property_hash, controller_class, attr_metadata, opts)
          assoc = opts[:association]
          return property_hash unless assoc.present?
          assoc_class = assoc.class_name.constantize
          assoc_opts = ModelApi::Utils.assoc_opts(assoc, attr_metadata, opts)
          assoc_opts = assoc_opts.reject do |k, _v|
            [:result, :collection_result].include?(k)
          end
          assoc_model = define_open_api_object(controller_class, assoc_class, assoc_opts)
          if assoc.collection?
            property_hash[:type] = :array
            property_hash[:items] = { :'$ref' => assoc_model } if assoc_model.present?
          else
            property_hash[:'$ref'] = assoc_model if assoc_model.present?
          end
          property_hash
        end

        def attr_types_from_columns(model_class)
          Hash[model_class.columns.map { |col| [col.name.to_sym, col.type] }]
        end

        def required_attrs_from_validators(model_class)
          model_class.validators
              .select { |v| v.is_a?(ActiveRecord::Validations::PresenceValidator) }
              .map(&:attributes)
              .flatten
        end

        # def add_open_api_view_params(parameters, operation, _opts = {})
        #   parameters = {}
        #   if operation == :index
        #     api.param :query, :page, :integer, :optional,
        #         'Index (1-based) of the result set page to return'
        #     api.param :query, :page_size, :integer, :optional,
        #         'Number of records to return per page (cannot exceed 1000)'
        #   end
        #   if [:index, :show].include?(operation)
        #     api.param :query, :fields, :array, :optional, 'Field(s) to include ' \
        #       'in the response', 'items' => { 'type' => 'string' }
        #   end
        # end
        #
        # def add_open_api_common_errors(api, operation, _opts = {})
        #   if [:show, :update, :delete].include?(operation)
        #     api.response :not_found, 'No entity found matching the ID provided'
        #   end
        #   api.response :unauthorized,
        #       'Missing a valid access token (access_token parameter or X-Access-Token header)'
        #   api.response :bad_request, 'One or more malformed / invalid ' \
        #     'parameters identified for the request'
        #   api.param :query, :access_token, :string, :optional, 'Access token ' \
        #     'used to authenticate client'
        #   api.param :header, :'X-Access-Token', :string, :optional,
        #       'Access token used to authenticate client'
        # end
      end
    end
  end
end
