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
        transform_value(value, attr_metadata[:render], opts)
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
        controller.response_body = [ModelApi::Renderer.render(controller, ext_value(obj), opts)]
      end

      def resolve_assoc_obj(parent_obj, assoc, assoc_payload, opts = {})
        klass = parent_obj.class
        assoc = klass.reflect_on_association(assoc) if assoc.is_a?(Symbol) || assoc.is_a?(String)
        fail "Unrecognized association '#{assoc}' on class '#{klass.name}'" if assoc.nil?
        assoc_class = assoc.class_name.constantize
        model_metadata = model_metadata(assoc_class)
        do_resolve_assoc_obj(model_metadata, assoc, assoc_class, assoc_payload, parent_obj, opts)
      end

      def update_api_attr(obj, attr, value, opts = {})
        attr = attr.to_sym
        attr_metadata = get_attr_metadata(obj, attr, opts)
        begin
          value = transform_value(value, attr_metadata[:parse], opts)
        rescue Exception => e
          Rails.logger.warn "Error encountered parsing API input for attribute \"#{attr}\" " \
                  "(\"#{e.message}\"): \"#{value.to_s.first(1000)}\" ... using raw value instead."
        end
        begin
          if attr_metadata[:type] == :association && attr_metadata[:parse].blank?
            attr_metadata = opts[:attr_metadata]
            assoc = attr_metadata[:association]
            if assoc.macro == :has_many
              update_has_many_assoc(obj, attr, value, opts)
            elsif assoc.macro == :belongs_to
              update_belongs_to_assoc(obj, attr, value, opts)
            else
              add_ignored_field(opts[:ignored_fields], attr, value, attr_metadata)
            end
          else
            set_api_attr(obj, attr, value, opts)
          end
        rescue Exception => e
          handle_api_setter_exception(e, obj, attr_metadata, opts)
        end
      end

      def find_by_id_attrs(id_attributes, assoc_class, assoc_payload)
        return nil unless id_attributes.present?
        id_attributes.each do |id_attr_set|
          query = nil
          id_attr_set.each do |id_attr|
            unless assoc_payload.include?(id_attr.to_s)
              query = nil
              break
            end
            query = (query || assoc_class).where(id_attr => assoc_payload[id_attr.to_s])
          end
          return query unless query.nil?
        end
        nil
      end

      def add_ignored_field(ignored_fields, attr, value, attr_metadata)
        return unless ignored_fields.is_a?(Array)
        attr_metadata ||= {}
        external_attr = ext_attr(attr, attr_metadata)
        return unless external_attr.present?
        ignored_fields << { external_attr => value }
      end

      def apply_updates(obj, req_obj, operation, opts = {})
        opts = opts.merge(object: opts[:object] || obj)
        metadata = filtered_ext_attrs(opts[:api_attr_metadata] ||
            filtered_attrs(obj, operation, opts), operation, opts)
        set_context_attrs(obj, opts)
        req_obj.each do |attr, value|
          attr = attr.to_sym
          attr_metadata = metadata[attr]
          unless attr_metadata.present?
            add_ignored_field(opts[:ignored_fields], attr, value, attr_metadata)
            next
          end
          update_api_attr(obj, attr, value, opts.merge(attr_metadata: attr_metadata))
        end
      end

      def extract_error_msgs(obj, opts = {})
        object_errors = []
        attr_prefix = opts[:attr_prefix] || ''
        api_metadata = opts[:api_attr_metadata] || api_attrs(obj.class)
        obj.errors.each do |attr, attr_errors|
          attr_errors = [attr_errors] unless attr_errors.is_a?(Array)
          attr_errors.each do |error|
            attr_metadata = api_metadata[attr] || {}
            qualified_attr = "#{attr_prefix}#{ext_attr(attr, attr_metadata)}"
            assoc_errors = nil
            if attr_metadata[:type] == :association
              assoc_errors = extract_assoc_error_msgs(obj, attr, opts.merge(
                  attr_metadata: attr_metadata))
            end
            if assoc_errors.present?
              object_errors += assoc_errors
            else
              error_hash = {}
              error_hash[:object] = attr_prefix if attr_prefix.present?
              error_hash[:attribute] = qualified_attr unless attr == :base
              object_errors << error_hash.merge(error: error,
                  message: (attr == :base ? error : "#{qualified_attr} #{error}"))
            end
          end
        end
        object_errors
      end
      
      def save_obj(obj, opts = {})
        operation = opts[:operation] || (obj.new_record? ? :create : :update)
        model_metadata = opts.delete(:model_metadata) || model_metadata(obj.class)
        before_validate_callbacks(model_metadata, obj, opts)
        validate_operation(obj, operation, opts.merge(model_metadata: model_metadata))
        validate_preserving_existing_errors(obj)
        new_obj = obj.new_record?
        before_save_callbacks(model_metadata, obj, new_obj, opts)
        obj.instance_variable_set(:@readonly, false) if obj.instance_variable_get(:@readonly)
        successful = obj.save unless obj.errors.present?
        after_save_callbacks(model_metadata, obj, new_obj, opts) if successful
        successful
      end

      def validate_operation(obj, operation, opts = {})
        klass = find_class(obj, opts)
        model_metadata = opts[:model_metadata] || model_metadata(klass)
        return nil unless operation.present?
        opts = opts.frozen? ? opts : opts.dup.freeze
        if obj.nil?
          invoke_callback(model_metadata[:"validate_#{operation}"], opts)
        else
          invoke_callback(model_metadata[:"validate_#{operation}"], obj, opts)
        end
      end

      def process_collection_includes(collection, opts = {})
        klass = find_class(collection, opts)
        metadata = filtered_ext_attrs(klass, opts[:operation] || :index, opts)
        model_metadata = opts[:model_metadata] || model_metadata(klass)
        includes = []
        if (metadata_includes = model_metadata[:collection_includes]).is_a?(Array)
          includes += metadata_includes.map(&:to_sym)
        end
        metadata.each do |_attr, attr_metadata|
          includes << attr_metadata[:key] if attr_metadata[:type] == :association
        end
        includes = includes.compact.uniq
        collection = collection.includes(includes) if includes.present?
        collection
      end

      def find_class(obj, opts = {})
        return nil if obj.nil?
        opts[:class] || (obj.respond_to?(:klass) ? obj.klass : obj.class)
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
          return invoke_callback(test_value, klass, opts.merge(filter_type => filter_value).freeze)
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

      def update_has_many_assoc(obj, attr, value, opts = {})
        attr_metadata = opts[:attr_metadata]
        assoc = attr_metadata[:association]
        assoc_class = assoc.class_name.constantize
        model_metadata = model_metadata(assoc_class)
        value_array = value.to_a rescue nil
        unless value_array.is_a?(Array)
          obj.errors.add(attr, 'must be supplied as an array of objects')
          return
        end
        opts = opts.merge(model_metadata: model_metadata)
        opts[:ignored_fields] = [] if opts.include?(:ignored_fields)
        assoc_objs = []
        value_array.each_with_index do |assoc_payload, index|
          opts[:ignored_fields].clear if opts.include?(:ignored_fields)
          assoc_objs << update_has_many_assoc_obj(obj, assoc, assoc_class, assoc_payload,
              opts.merge(model_metadata: model_metadata))
          if opts[:ignored_fields].present?
            external_attr = ext_attr(attr, attr_metadata)
            opts[:ignored_fields] << { "#{external_attr}[#{index}]" => opts[:ignored_fields] }
          end
        end
        set_api_attr(obj, attr, assoc_objs, opts)
      end

      def update_has_many_assoc_obj(parent_obj, assoc, assoc_class, assoc_payload, opts = {})
        model_metadata = opts[:model_metadata] || model_metadata(assoc_class)
        assoc_obj, assoc_oper, assoc_opts = resolve_has_many_assoc_obj(model_metadata, assoc,
            assoc_class, assoc_payload, parent_obj, opts)
        if (inverse_assoc = assoc.options[:inverse_of]).present? &&
            assoc_obj.respond_to?("#{inverse_assoc}=")
          assoc_obj.send("#{inverse_assoc}=", parent_obj)
        elsif !parent_obj.new_record? && assoc_obj.respond_to?("#{assoc.foreign_key}=")
          assoc_obj.send("#{assoc.foreign_key}=", obj.id)
        end
        apply_updates(assoc_obj, assoc_payload, assoc_oper, assoc_opts)
        invoke_callback(model_metadata[:after_initialize], assoc_obj,
            assoc_opts.merge(operation: assoc_oper).freeze)
        assoc_obj
      end

      def resolve_has_many_assoc_obj(model_metadata, assoc, assoc_class, assoc_payload,
          parent_obj, opts = {})
        assoc_obj = do_resolve_assoc_obj(model_metadata, assoc, assoc_class, assoc_payload,
            parent_obj, opts.merge(auto_create: true))
        if assoc_obj.new_record?
          assoc_oper = :create
          opts[:create_opts] ||= opts.merge(api_attr_metadata: filtered_attrs(
              assoc_class, :create, opts))
          assoc_opts = opts[:create_opts]
        else
          assoc_oper = :update
          opts[:update_opts] ||= opts.merge(api_attr_metadata: filtered_attrs(
              assoc_class, :update, opts))

          assoc_opts = opts[:update_opts]
        end
        [assoc_obj, assoc_oper, assoc_opts]
      end

      def update_belongs_to_assoc(parent_obj, attr, assoc_payload, opts = {})
        unless assoc_payload.is_a?(Hash)
          parent_obj.errors.add(attr, 'must be supplied as an object')
          return
        end
        attr_metadata = opts[:attr_metadata]
        assoc = attr_metadata[:association]
        assoc_class = assoc.class_name.constantize
        model_metadata = model_metadata(assoc_class)
        assoc_obj, assoc_oper, assoc_opts = resolve_belongs_to_assoc_obj(model_metadata, assoc,
            assoc_class, assoc_payload, parent_obj, opts)
        apply_updates(assoc_obj, assoc_payload, assoc_oper, assoc_opts)
        invoke_callback(model_metadata[:after_initialize], assoc_obj,
            opts.merge(operation: assoc_oper).freeze)
        if assoc_opts[:ignored_fields].present?
          external_attr = ext_attr(attr, attr_metadata)
          opts[:ignored_fields] << { external_attr.to_s => assoc_opts[:ignored_fields] }
        end
        set_api_attr(parent_obj, attr, assoc_obj, opts)
      end

      def resolve_belongs_to_assoc_obj(model_metadata, assoc, assoc_class, assoc_payload,
          parent_obj, opts = {})
        assoc_opts = opts[:ignored_fields].is_a?(Array) ? opts.merge(ignored_fields: []) : opts
        assoc_obj = do_resolve_assoc_obj(model_metadata, assoc, assoc_class, assoc_payload,
            parent_obj, opts.merge(auto_create: true))
        assoc_oper = assoc_obj.new_record? ? :create : :update
        assoc_opts = assoc_opts.merge(
            api_attr_metadata: filtered_attrs(assoc_class, assoc_oper, opts))
        return [assoc_obj, assoc_oper, assoc_opts]
      end

      def do_resolve_assoc_obj(model_metadata, assoc, assoc_class, assoc_payload, parent_obj,
          opts = {})
        if opts[:resolve].try(:respond_to?, :call)
          assoc_obj = invoke_callback(opts[:resolve], assoc_payload, opts.merge(
              parent: parent_obj, association: assoc, association_metadata: model_metadata))
        else
          assoc_obj = find_by_id_attrs(model_metadata[:id_attributes], assoc_class, assoc_payload)
          assoc_obj = assoc_obj.first unless assoc_obj.nil? || assoc_obj.count != 1
          assoc_obj ||= assoc_class.new if opts[:auto_create]
        end
        assoc_obj
      end

      def set_api_attr(obj, attr, value, opts)
        attr = attr.to_sym
        attr_metadata = get_attr_metadata(obj, attr, opts)
        internal_field = attr_metadata[:key] || attr
        setter = attr_metadata[:setter] || "#{(internal_field)}="
        unless obj.respond_to?(setter)
          Rails.logger.warn "Error encountered assigning API input for attribute \"#{attr}\" " \
                  '(setter not found): skipping.'
          add_ignored_field(opts[:ignored_fields], attr, value, attr_metadata)
          return
        end
        obj.send(setter, value)
      end

      def handle_api_setter_exception(e, obj, attr_metadata, opts = {})
        return unless attr_metadata.is_a?(Hash)
        on_exception = attr_metadata[:on_exception]
        fail e unless on_exception.present?
        on_exception = { Exception => on_exception } unless on_exception.is_a?(Hash)
        opts = opts.frozen? ? opts : opts.dup.freeze
        on_exception.each do |klass, handler|
          klass = klass.to_s.constantize rescue nil unless klass.is_a?(Class)
          next unless klass.is_a?(Class) && e.is_a?(klass)
          if handler.respond_to?(:call)
            invoke_callback(handler, obj, e, opts)
          elsif handler.present?
            # Presume handler is an error message in this case
            obj.errors.add(attr_metadata[:key], handler.to_s)
          else
            add_ignored_field(opts[:ignored_fields], nil, opts[:value],
                attr_metadata)
          end
          break
        end
      end

      def get_attr_metadata(obj, attr, opts)
        attr_metadata = opts[:attr_metadata]
        return attr_metadata unless attr_metadata.nil?
        operation = opts[:operation] || :update
        metadata = filtered_ext_attrs(opts[:api_attr_metadata] ||
            filtered_attrs(obj, operation, opts), operation, opts)
        metadata[attr] || {}
      end

      def set_context_attrs(obj, opts = {})
        klass = (obj.class < ActiveRecord::Base ? obj.class : nil)
        (opts[:context] || {}).each do |key, value|
          begin
            setter = "#{key}="
            next unless obj.respond_to?(setter)
            if (column = klass.try(:columns_hash).try(:[], key.to_s)).present?
              case column.type
              when :integer, :primary_key then
                obj.send("#{key}=", value.to_i)
              when :decimal, :float then
                obj.send("#{key}=", value.to_f)
              else
                obj.send(setter, value.to_s)
              end
            else
              obj.send(setter, value.to_s)
            end
          rescue Exception => e
            Rails.logger.warn "Error encountered assigning context parameter #{key} to " \
              "'#{value}' (skipping): \"#{e.message}\")."
          end
        end
      end

      # rubocop:disable Metrics/MethodLength
      def extract_assoc_error_msgs(obj, attr, opts)
        object_errors = []
        attr_metadata = opts[:attr_metadata] || {}
        processed_assoc_objects = {}
        assoc = attr_metadata[:association]
        assoc_class = assoc.class_name.constantize
        external_attr = ext_attr(attr, attr_metadata)
        attr_metadata_create = attr_metadata_update = nil
        if assoc.macro == :has_many
          obj.send(attr).each_with_index do |assoc_obj, index|
            next if processed_assoc_objects[assoc_obj]
            processed_assoc_objects[assoc_obj] = true
            attr_prefix = "#{external_attr}[#{index}]."
            if assoc_obj.new_record?
              attr_metadata_create ||= filtered_attrs(assoc_class, :create, opts)
              object_errors += extract_error_msgs(assoc_obj, opts.merge(
                  attr_prefix: attr_prefix, api_attr_metadata: attr_metadata_create))
            else
              attr_metadata_update ||= filtered_attrs(assoc_class, :update, opts)
              object_errors += extract_error_msgs(assoc_obj, opts.merge(
                  attr_prefix: attr_prefix, api_attr_metadata: attr_metadata_update))
            end
          end
        else
          assoc_obj = obj.send(attr)
          return object_errors unless assoc_obj.present? && !processed_assoc_objects[assoc_obj]
          processed_assoc_objects[assoc_obj] = true
          attr_prefix = "#{external_attr}->"
          if assoc_obj.new_record?
            attr_metadata_create ||= filtered_attrs(assoc_class, :create, opts)
            object_errors += extract_error_msgs(assoc_obj, opts.merge(
                attr_prefix: attr_prefix, api_attr_metadata: attr_metadata_create))
          else
            attr_metadata_update ||= filtered_attrs(assoc_class, :update, opts)
            object_errors += extract_error_msgs(assoc_obj, opts.merge(
                attr_prefix: attr_prefix, api_attr_metadata: attr_metadata_update))
          end
        end
        object_errors
      end

      # rubocop:enable Metrics/MethodLength

      def before_validate_callbacks(model_metadata, obj, opts)
        
        invoke_callback(model_metadata[:before_validate], obj, opts.dup)
        invoke_callback(opts[:before_validate], obj, opts.dup)
      end

      def before_save_callbacks(model_metadata, obj, new_obj, opts)
        invoke_callback(model_metadata[:before_create], obj, opts.dup) if new_obj
        invoke_callback(opts[:before_create], obj, opts.dup) if new_obj
        invoke_callback(model_metadata[:before_save], obj, opts.dup)
        invoke_callback(opts[:before_save], obj, opts.dup)
      end

      def after_save_callbacks(model_metadata, obj, new_obj, opts)
        invoke_callback(model_metadata[:after_create], obj, opts.dup) if new_obj
        invoke_callback(opts[:after_create], obj, opts.dup) if new_obj
        invoke_callback(model_metadata[:after_save], obj, opts.dup)
        invoke_callback(opts[:after_save], obj, opts.dup)
      end

      def validate_preserving_existing_errors(obj)
        if obj.errors.present?
          errors = obj.errors.messages.dup
          obj.valid?
          errors = obj.errors.messages.merge(errors)
          obj.errors.clear
          errors.each { |field, error| obj.errors.add(field, error) }
        else
          obj.valid?
        end
      end
    end
  end
end
