module ModelApi
  class Utils
    API_OPERATIONS = [:index, :show, :create, :update, :patch, :destroy, :other, :filter, :sort]
    CAMELCASE_CONVERSION = true

    class << self
      def route_name(request)
        Rails.application.routes.router.recognize(request) do |route, _matches, _parameters|
          return route.name
        end
        nil
      end

      def api_attrs(obj_or_class)
        return nil if obj_or_class.nil?
        klass = obj_or_class.is_a?(Class) ? obj_or_class : obj_or_class.class
        return expand_metadata(klass.api_attributes) if klass.respond_to?(:api_attributes)
        Hash[klass.column_names.map(&:to_sym).map { |attr| [attr, { attribute: attr }] }]
      end

      def filtered_attrs(obj_or_class, operation, opts = {})
        return nil if obj_or_class.nil?
        klass = obj_or_class.is_a?(Class) ? obj_or_class : obj_or_class.class
        filtered_metadata(api_attrs(klass), klass, operation, opts)
      end

      def filtered_ext_attrs(metadata, operation = nil, opts = {})
        if operation.is_a?(Hash) && opts.blank?
          opts = operation
          operation = opts[:operation] || :show
        end
        if metadata.is_a?(ActiveRecord::Base) || (metadata.is_a?(Class) &&
            metadata < ActiveRecord::Base)
          metadata = filtered_attrs(metadata, operation, opts)
        end
        return metadata unless metadata.is_a?(Hash) && metadata.present?
        if [:filter, :sort].include?(operation)
          return Hash[metadata.map { |a, m| [ext_query_attr(a, m), m] }]
        end
        Hash[metadata.map { |a, m| [ext_attr(a, m), m] }]
      end

      def parse_request_body(request)
        request_body = request.body.read.to_s.strip
        parsed_request_body = nil
        if request.env['API_CONTENT_TYPE'] == :xml ||
            request_body.start_with?('<')
          parsed_request_body = Hash.from_xml(request_body) rescue nil
          detected_format = :xml
        end
        unless parsed_request_body.present?
          parsed_request_body = JSON.parse(request_body) rescue nil
          detected_format = :json
        end
        [parsed_request_body, detected_format]
      end

      def ext_attr(attr, attr_metadata = {})
        sym = attr.is_a?(Symbol)
        ext_attr = attr_metadata[:alias] || attr
        ext_attr = ext_attr.to_s.camelize(:lower) if CAMELCASE_CONVERSION
        sym ? ext_attr.to_sym : ext_attr.to_s
      end

      def ext_query_attr(attr, attr_metadata = {})
        sym = attr.is_a?(Symbol)
        ext_attr = attr_metadata[:alias] || attr
        ext_attr = ext_attr.to_s.underscore
        sym ? ext_attr.to_sym : ext_attr.to_s
      end

      def ext_value(value, opts = {})
        return value unless CAMELCASE_CONVERSION
        if value.is_a?(Hash)
          ext_hash(value, opts)
        elsif value.respond_to?(:map)
          value.map { |v| ext_value(v, opts) }
        else
          value
        end
      end

      def internal_value(value, opts = {})
        return value unless CAMELCASE_CONVERSION
        if value.is_a?(Hash)
          internal_hash(value, opts)
        elsif value.respond_to?(:map)
          value.map { |v| internal_value(v, opts) }
        else
          value
        end
      end

      def api_links(obj_or_class)
        klass = obj_or_class.is_a?(Class) ? obj_or_class : obj_or_class.class
        return {} unless klass.respond_to?(:api_links)
        klass.api_links.dup
      end

      def filtered_links(obj_or_class, operation, opts = {})
        return {} if obj_or_class.nil? || eval_bool(obj_or_class, opts[:exclude_api_links], opts)
        klass = obj_or_class.is_a?(Class) ? obj_or_class : obj_or_class.class
        filtered_metadata(api_links(klass), klass, operation, opts)
      end

      def eval_can(criteria, context, action_type, controller)
        return false unless criteria.present? && context.present? &&
            action_type.present? && controller.respond_to?(:can?)
        controller.can?(criteria, context)
      end

      def eval_bool(obj, expr, opts = {})
        if expr.is_a?(Hash) && opts.blank?
          obj = nil
          opts = expr
        end
        if expr.respond_to?(:call)
          return invoke_callback(expr, *([obj, opts].compact)) ? true : false
        end
        expr ? true : false
      end

      def transform_value(value, transform_method_or_proc, opts = {})
        return value unless transform_method_or_proc.present?
        if (transform_method_or_proc.is_a?(String) || transform_method_or_proc.is_a?(Symbol)) &&
            value.respond_to?(transform_method_or_proc.to_sym)
          return value.send(transform_method_or_proc.to_sym)
        end
        value = value.symbolize_keys if value.is_a?(Hash)
        return value unless transform_method_or_proc.respond_to?(:call)
        invoke_callback(transform_method_or_proc, value, opts.freeze)
      end

      def http_status_code(status)
        unless status.is_a?(Symbol)
          status_num = status.to_s.to_i
          if status_num.to_s == status.to_s
            unless Rack::Utils::HTTP_STATUS_CODES.include?(status_num)
              fail "Invalid / unrecognized HTTP status code: #{status_num}"
            end
            return status_num
          end
          status = status.to_s.to_sym
        end
        status_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status]
        fail "Invalid / unrecognized HTTP status: #{status}" unless status_code.present?
        status_code
      end

      def http_status(status)
        unless status.is_a?(Fixnum)
          status_num = status.to_s.to_i
          if status_num.to_s != status.to_s
            status_sym = status.to_s.to_sym
            unless Rack::Utils::SYMBOL_TO_STATUS_CODE.include?(status_sym)
              fail "Invalid / unrecognized HTTP status: #{status_sym}"
            end
            return status_sym
          end
          status = status_num
        end
        status_string = Rack::Utils::HTTP_STATUS_CODES[status]
        fail "Invalid / unrecognized HTTP status code: #{status}" unless status_string.present?
        status_string.downcase.gsub(/\s|-/, '_').to_sym
      end

      def response_successful?(response_status)
        http_status_code(response_status) < 400
      end

      def assoc_opts(assoc, attr_metadata, opts)
        contextual_metadata_opts(attr_metadata, opts.merge(association: assoc))
      end

      # Build options to generate metadata for a special context, e.g. for an object nested inside
      # of a parent object.
      def contextual_metadata_opts(attr_metadata, opts = {})
        context_opts = opts
        if (obj_metadata = attr_metadata[:attributes]).present?
          context_opts = context_opts.merge(metadata: obj_metadata)
        end
        except_attrs = attr_metadata[:except_attrs] || []
        if (assoc = opts[:association]).present? &&
            ![:belongs_to, :has_and_belongs_to_many].include?(assoc.macro) &&
            !assoc.through_reflection.present?
          except_attrs << assoc.foreign_key.to_sym
        end
        if except_attrs.present?
          context_opts = context_opts.merge(except: (context_opts[:except] || []) +
              except_attrs.compact.map(&:to_sym).uniq)
        end
        context_opts
      end

      def set_open_api_type_and_format(properties, type_name)
        open_api_type, open_api_format = OpenApi::Utils.open_api_type_and_format(type_name)
        if open_api_type.nil?
          open_api_type = :string
          open_api_format = type_name
        end
        if open_api_type.present?
          properties[:type] = open_api_type
          properties[:format] = open_api_format if open_api_format.present?
        end
        properties
      end

      def model_metadata(klass)
        return klass.api_model if klass.respond_to?(:api_model)
        {}
      end

      def model_name(klass)
        model_alias = (model_metadata(klass) || {})[:alias]
        ActiveModel::Name.new(klass, nil, model_alias.present? ? model_alias.to_s : nil)
      end

      def format_value(value, attr_metadata, opts)
        ModelApi::Utils.transform_value(value, attr_metadata[:render], opts)
      rescue Exception => e
        Rails.logger.warn 'Error encountered formatting API output ' \
              "(\"#{e.message}\") for value: \"#{value}\"" \
              ' ... rendering unformatted value instead.'
        value
      end

      def not_found_response_body(opts = {})
        response =
            {
              successful: false,
              status: :not_found,
              status_code: http_status_code(:not_found),
              errors: [{
                error: opts[:error] || 'No resource found',
                message: opts[:message] || 'No resource found at the path ' \
                    'provided or matching the criteria specified'
              }]
            }
        response.to_json(opts)
      end

      def invoke_callback(callback, *params)
        return nil unless callback.respond_to?(:call)
        callback.send(*(([:call] + params)[0..callback.parameters.size]))
      end

      def common_http_headers
        {
          'Cache-Control' => 'no-cache, no-store, max-age=0, must-revalidate',
          'Pragma' => 'no-cache',
          'Expires' => 'Fri, 01 Jan 1990 00:00:00 GMT'
        }
      end

      # Transforms request and response to match conventions (i.e. using camelcase attrs if
      # configured, and the standard response envelope)
      def translate_external_api_filter(controller, opts = {}, &block)
        request = controller.request
        json, _format = parse_request_body(request)
        json = internal_value(json)
        json.each { |k, v| request.parameters[k] = request.POST[k] = v } if json.is_a?(Hash)

        block.call

        obj = controller.response_body.first if controller.response_body.is_a?(Array)
        obj = (JSON.parse(obj) rescue nil) if obj.present?
        opts = opts.merge(generate_body_only: true)
        controller.response_body = [ModelApi::Renderer.render(controller,
            ModelApi::Utils.ext_value(obj), opts)]
      end

      private

      def action_filter(klass, filter_value, test_value, opts = {})
        filter_type = opts[:filter_type] || :operation
        if test_value.is_a?(Array)
          return test_value.map(&:to_sym).include?(filter_value)
        elsif test_value.is_a?(Hash)
          test_value = test_value[filter_value]
        end
        if test_value.respond_to?(:call)
          return ModelApi::Utils.invoke_callback(test_value, klass,
              opts.merge(filter_type => filter_value).freeze)
        end
        filter_value == test_value
      end

      def filtered_metadata(metadata, klass, operation, opts = {})
        if (only = opts[:only]).present?
          metadata.select! { |k, _v| only.include?(k) }
        end
        if (except = opts[:except]).present?
          metadata.reject! { |k, _v| except.include?(k) }
        end
        if (metadata_overrides = opts[:metadata]).present?
          metadata = merge_metadata_overrides(metadata, metadata_overrides)
        end
        metadata.select! do |_attr, attr_metadata|
          include_item?(attr_metadata, klass, operation, opts)
        end
        metadata
      end

      def include_item?(metadata, obj, operation, opts = {})
        return false unless metadata.is_a?(Hash)
        return false unless include_item_meets_admin_criteria?(metadata, obj, opts)
        # Stop here re: filter/sort params, as following checks involve payloads/responses only
        return eval_bool(obj, metadata[:filter], opts) if operation == :filter
        return eval_bool(obj, metadata[:sort], opts) if operation == :sort
        return false unless include_item_meets_read_write_criteria?(metadata, obj, operation, opts)
        return false unless include_item_meets_incl_excl_criteria?(metadata, obj, operation, opts)
        true
      end

      def merge_metadata_overrides(metadata, metadata_overrides)
        if metadata_overrides.is_a?(Hash)
          Hash[
              expand_metadata(metadata_overrides).map do |key, item_metadata|
                [key, item_metadata.reverse_merge(metadata[key] || {}).reverse_merge(key: key)]
              end
          ]
        elsif metadata_overrides.is_a?(Array)
          metadata.select { |key, _m| metadata_overrides.include?(key) }
        else
          metadata
        end
      end

      def expand_metadata(metadata)
        Hash[metadata.map { |k, v| [k, v.is_a?(Hash) ? v : { value: v, read_only: true }] }]
      end

      def ext_hash(hash, opts = {})
        return hash unless CAMELCASE_CONVERSION
        Hash[hash.map do |key, value|
          sym = key.is_a?(Symbol)
          key = key.to_s.camelize(:lower)
          value = ext_value(value, opts)
          [sym ? key.to_sym : key, value]
        end]
      end

      def internal_hash(hash, opts = {})
        return hash unless CAMELCASE_CONVERSION
        Hash[hash.map do |key, value|
          sym = key.is_a?(Symbol)
          key = key.to_s.underscore
          value = internal_value(value, opts)
          [sym ? key.to_sym : key, value]
        end]
      end

      def include_item_meets_admin_criteria?(metadata, obj, opts = {})
        if eval_bool(obj, metadata[:admin_only], opts)
          if opts.include?(:admin)
            return false unless opts[:admin]
          else
            return false unless opts[:user].try(:admin_api_user?)
          end
        end
        return false if eval_bool(obj, metadata[:admin_content], opts) && !opts[:admin_content]
        true
      end

      def include_item_meets_read_write_criteria?(metadata, obj, operation, opts = {})
        if [:create, :update, :patch].include?(operation)
          return false if eval_bool(obj, metadata[:read_only], opts)
        else
          return false if eval_bool(obj, metadata[:write_only], opts)
        end
        true
      end

      def include_item_meets_incl_excl_criteria?(metadata, obj, operation, opts = {})
        if (only = metadata[:only]).present?
          return false unless action_filter(obj, operation, only, opts)
        end
        if (except = metadata[:except]).present?
          return false if action_filter(obj, operation, except, opts)
        end
        action = opts[:action]
        if (only = metadata[:only_actions]).present?
          return false unless action_filter(obj, action, only, opts.merge(filter_type: :action))
        end
        if (except = metadata[:except_actions]).present?
          return false if action_filter(obj, action, except, opts.merge(filter_type: :action))
        end
        true
      end
    end
  end
end
