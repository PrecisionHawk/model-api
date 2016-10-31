module ModelApi
  class ApiContext
    def initialize(context_parent)
      @context_parent = context_parent
    end

    def model_class
      return @model_class if instance_variable_defined?(:@model_class)
      @model_class = @context_parent.send(:model_class)
    end

    def prepare_options(opts)
      return opts if opts[:options_initialized]
      if @context_parent.respond_to?(:prepare_options, true)
        return @context_parent.send(:prepare_options, opts)
      end
      opts
    end

    def api_query(klass, opts = {})
      opts = prepare_options(opts)
      model_metadata = opts[:model_metadata] || ModelApi::Utils.model_metadata(klass)
      unless klass < ActiveRecord::Base
        fail 'Expected model class to be an ActiveRecord::Base subclass'
      end
      query = ModelApi::Utils.invoke_callback(model_metadata[:base_query], opts) || klass.all
      if (deleted_col = klass.columns_hash['deleted']).present?
        case deleted_col.type
        when :boolean
          query = query.where(deleted: false)
        when :integer, :decimal
          query = query.where(deleted: 0)
        end
      end
      apply_context(query, opts)
    end

    def common_object_query(id_attribute, id_value, opts = {})
      klass = opts[:model_class] || model_class
      coll_query = apply_context(api_query(klass, opts), opts)
      query = coll_query.where(id_attribute => id_value)
      if !opts[:admin_user]
        unless opts.include?(:user_filter) && !opts[:user_filter] && opts[:user]
          query = user_query(query, opts[:user], opts.merge(model_class: klass))
        end
      elsif id_attribute != :id && !id_attribute.to_s.ends_with?('.id') &&
          klass.column_names.include?('id') && !query.exists?
        # Admins can optionally use record ID's if the ID field happens to be something else
        query = coll_query.where(id: id_value)
      end
      unless (not_found_error = opts[:not_found_error]).blank? || query.exists?
        not_found_error = not_found_error.call(params[:id]) if not_found_error.respond_to?(:call)
        if not_found_error == true
          not_found_error = "#{klass.model_name.human} '#{id_value}' not found."
        end
        fail ModelApi::NotFoundException.new(opts[:id_param] || id_attribute, not_found_error.to_s)
      end
      query
    end

    def user_query(query, user, opts = {})
      klass = opts[:model_class] || query.klass
      user_id_col = opts[:user_id_column] || :user_id
      user_assoc = opts[:user_association] || :user
      user_id = user.try(opts[:user_id_attribute] || :id)
      if klass.columns_hash.include?(user_id_col.to_s)
        query = query.where(user_id_col => user_id)
      elsif (assoc = klass.reflect_on_association(user_assoc)).present? &&
          [:belongs_to, :has_one].include?(assoc.macro)
        query = query.joins(user_assoc).where(
            "#{assoc.klass.table_name}.#{assoc.klass.primary_key}" => user_id)
      elsif opts[:user_filter]
        fail "Unable to filter results by user; no '#{user_id_col}' column or " \
                "'#{user_assoc}' association found!"
      end
      query
    end

    def validate_read_operation(obj, operation, opts = {})
      opts = prepare_options(opts)
      status, errors = ModelApi::Utils.validate_operation(obj, operation,
          opts.merge(model_metadata: opts[:api_model_metadata] || opts[:model_metadata]))
      return true if status.nil? && errors.nil?
      if errors.nil? && (status.is_a?(Array) || status.present?)
        return true if (errors = status).blank?
        status = :bad_request
      end
      return true unless errors.present?
      errors = [errors] unless errors.is_a?(Array)
      simple_error(status, errors, opts)
      false
    end

    def get_updated_object(obj_or_class, operation, request_body, opts = {})
      opts = prepare_options(opts.symbolize_keys)
      opts[:operation] = operation
      if obj_or_class.is_a?(Class)
        klass = class_or_sti_subclass(obj_or_class, request_body, operation, opts)
        obj = nil
      elsif obj_or_class.is_a?(ActiveRecord::Base)
        obj = obj_or_class
        klass = obj.class
      elsif obj_or_class.is_a?(ActiveRecord::Relation)
        klass = obj_or_class.klass
        obj = obj_or_class.first
      end
      opts[:api_attr_metadata] = ModelApi::Utils.filtered_attrs(klass, operation, opts)
      opts[:api_model_metadata] = model_metadata = ModelApi::Utils.model_metadata(klass)
      opts[:ignored_fields] = []
      return [nil, opts.merge(bad_payload: true)] if request_body.nil?
      obj = klass.new if obj.nil?
      verify_update_request_body(request_body, opts[:format], opts)
      root_elem = opts[:root] = ModelApi::Utils.model_name(klass).singular
      request_obj = opts[:request_obj] = object_from_req_body(root_elem, request_body,
          opts[:format])
      opts[:request_hash] = ModelApi::Utils.internal_value(request_obj).deep_symbolize_keys
      ModelApi::Utils.apply_updates(obj, request_obj, operation, opts)
      ModelApi::Utils.invoke_callback(model_metadata[:after_initialize], obj, opts)
      [obj, opts]
    end

    def filter_collection(collection, filter_params, opts = {})
      return [collection, {}] if filter_params.blank? # Don't filter if no filter params
      klass = opts[:class] || ModelApi::Utils.find_class(collection, opts)
      assoc_values, metadata, attr_values = process_filter_params(filter_params, klass, opts)
      result_filters = {}
      metadata.values.each do |attr_metadata|
        collection = apply_filter_param(attr_metadata, collection,
            opts.merge(attr_values: attr_values, result_filters: result_filters, class_name: klass))
      end
      assoc_values.each do |assoc, assoc_filter_params|
        ar_assoc = klass.reflect_on_association(assoc)
        next unless ar_assoc.present?
        collection = collection.joins(assoc) unless collection.joins_values.include?(assoc)
        collection, assoc_result_filters = filter_collection(collection, assoc_filter_params,
            opts.merge(class: ar_assoc.klass, filter_table: ar_assoc.table_name))
        result_filters[assoc] = assoc_result_filters if assoc_result_filters.present?
      end
      [collection, result_filters]
    end

    def process_filter_params(filter_params, klass, opts = {})
      assoc_values = {}
      filter_metadata = {}
      attr_values = {}
      metadata = ModelApi::Utils.filtered_ext_attrs(klass, :filter, opts)
      filter_params.each do |attr, value|
        attr = attr.to_s
        if attr.length > 1 && ['>', '<', '!', '='].include?(attr[-1])
          value = "#{attr[-1]}=#{value}" # Effectively allows >= / <= / != / == in query string
          attr = attr[0..-2].strip
        end
        if attr.include?('.')
          process_filter_assoc_param(attr, metadata, assoc_values, value, opts)
        else
          process_filter_attr_param(attr, metadata, filter_metadata, attr_values, value, opts)
        end
      end
      [assoc_values, filter_metadata, attr_values]
    end

    # rubocop:disable Metrics/ParameterLists
    def process_filter_assoc_param(attr, metadata, assoc_values, value, opts)
      attr_elems = attr.split('.')
      assoc_name = attr_elems[0].strip.to_sym
      assoc_metadata = metadata[assoc_name] ||
          metadata[ModelApi::Utils.ext_query_attr(assoc_name, opts)] || {}
      key = assoc_metadata[:key]
      return unless key.present? && ModelApi::Utils.eval_bool(assoc_metadata[:filter], opts)
      assoc_filter_params = (assoc_values[key] ||= {})
      assoc_filter_params[attr_elems[1..-1].join('.')] = value
    end

    def process_filter_attr_param(attr, metadata, filter_metadata, attr_values, value, opts)
      attr = attr.strip.to_sym
      attr_metadata = metadata[attr] ||
          metadata[ModelApi::Utils.ext_query_attr(attr, opts)] || {}
      key = attr_metadata[:key]
      return unless key.present? && ModelApi::Utils.eval_bool(attr_metadata[:filter], opts)
      filter_metadata[key] = attr_metadata
      attr_values[key] = value
    end

    # rubocop:enable Metrics/ParameterLists

    def apply_filter_param(attr_metadata, collection, opts = {})
      raw_value = (opts[:attr_values] || params)[attr_metadata[:key]]
      filter_table = opts[:filter_table]
      klass = opts[:class] || ModelApi::Utils.find_class(collection, opts)
      if raw_value.is_a?(Hash) && raw_value.include?('0')
        operator_value_pairs = filter_process_param_array(params_array(raw_value), attr_metadata,
            opts)
      else
        operator_value_pairs = filter_process_param(raw_value, attr_metadata, opts)
      end
      if (column = resolve_key_to_column(klass, attr_metadata)).present?
        operator_value_pairs.each do |operator, value|
          if operator == '=' && filter_table.blank?
            collection = collection.where(column => value)
          else
            table_name = (filter_table || klass.table_name).to_s.delete('`')
            column = column.to_s.delete('`')
            if value.is_a?(Array)
              operator = 'IN'
              value = value.map { |_v| format_value_for_query(column, value, klass) }
              value = "(#{value.map { |v| "'#{v.to_s.gsub("'", "''")}'" }.join(',')})"
            else
              value = "'#{value.gsub("'", "''")}'"
            end
            collection = collection.where("`#{table_name}`.`#{column}` #{operator} #{value}")
          end
        end
      elsif (key = attr_metadata[:key]).present?
        opts[:result_filters][key] = operator_value_pairs if opts.include?(:result_filters)
      end
      collection
    end

    def sort_collection(collection, sort_params, opts = {})
      return [collection, {}] if sort_params.blank? # Don't filter if no filter params
      klass = opts[:class] || ModelApi::Utils.find_class(collection, opts)
      assoc_sorts, attr_sorts, result_sorts = process_sort_params(sort_params, klass,
          opts.merge(result_sorts: result_sorts))
      sort_table = opts[:sort_table]
      sort_table = sort_table.to_s.delete('`') if sort_table.present?
      attr_sorts.each do |key, sort_order|
        if sort_table.present?
          collection = collection.order("`#{sort_table}`.`#{key.to_s.delete('`')}` " \
                "#{sort_order.to_s.upcase}")
        else
          collection = collection.order(key => sort_order)
        end
      end
      assoc_sorts.each do |assoc, assoc_sort_params|
        ar_assoc = klass.reflect_on_association(assoc)
        next unless ar_assoc.present?
        collection = collection.joins(assoc) unless collection.joins_values.include?(assoc)
        collection, assoc_result_sorts = sort_collection(collection, assoc_sort_params,
            opts.merge(class: ar_assoc.klass, sort_table: ar_assoc.table_name))
        result_sorts[assoc] = assoc_result_sorts if assoc_result_sorts.present?
      end
      [collection, result_sorts]
    end

    private

    def apply_context(query, opts = {})
      context = opts[:context]
      return query if context.nil?
      if context.respond_to?(:call)
        query = context.send(*([:call, query, opts][0..context.parameters.size]))
      elsif context.is_a?(Hash)
        context.each { |attr, value| query = query.where(attr => value) }
      end
      query
    end

    def process_sort_params(sort_params, klass, opts)
      metadata = ModelApi::Utils.filtered_ext_attrs(klass, :sort, opts)
      assoc_sorts = {}
      attr_sorts = {}
      result_sorts = {}
      sort_params.each do |attr, sort_order|
        if attr.include?('.')
          process_sort_param_assoc(attr, metadata, sort_order, assoc_sorts, opts)
        else
          attr = attr.strip.to_sym
          attr_metadata = metadata[attr] || {}
          next unless ModelApi::Utils.eval_bool(attr_metadata[:sort], opts)
          sort_order = sort_order.to_sym
          sort_order = :default unless [:asc, :desc].include?(sort_order)
          if sort_order == :default
            sort_order = (attr_metadata[:default_sort_order] || :asc).to_sym
            sort_order = :asc unless [:asc, :desc].include?(sort_order)
          end
          if (column = resolve_key_to_column(klass, attr_metadata)).present?
            attr_sorts[column] = sort_order
          elsif (key = attr_metadata[:key]).present?
            result_sorts[key] = sort_order
          end
        end
      end
      [assoc_sorts, attr_sorts, result_sorts]
    end

    # Intentionally disabling parameter list length check for private / internal method
    # rubocop:disable Metrics/ParameterLists
    def process_sort_param_assoc(attr, metadata, sort_order, assoc_sorts, opts)
      attr_elems = attr.split('.')
      assoc_name = attr_elems[0].strip.to_sym
      assoc_metadata = metadata[assoc_name] || {}
      key = assoc_metadata[:key]
      return unless key.present? && ModelApi::Utils.eval_bool(assoc_metadata[:sort], opts)
      assoc_sort_params = (assoc_sorts[key] ||= {})
      assoc_sort_params[attr_elems[1..-1].join('.')] = sort_order
    end

    # rubocop:enable Metrics/ParameterLists

    def filter_process_param(raw_value, attr_metadata, opts)
      raw_value = raw_value.to_s.strip
      array = nil
      if raw_value.starts_with?('[') && raw_value.ends_with?(']')
        array = JSON.parse(raw_value) rescue nil
        array = array.is_a?(Array) ? array.map(&:to_s) : nil
      end
      if array.nil?
        if attr_metadata.include?(:filter_delimiter)
          delimiter = attr_metadata[:filter_delimiter]
        else
          delimiter = ','
        end
        array = raw_value.split(delimiter) if raw_value.include?(delimiter)
      end
      return filter_process_param_array(array, attr_metadata, opts) unless array.nil?
      operator, value = parse_filter_operator(raw_value)
      [[operator, ModelApi::Utils.transform_value(value, attr_metadata[:parse], opts)]]
    end

    def filter_process_param_array(array, attr_metadata, opts)
      operator_value_pairs = []
      equals_values = []
      array.map(&:strip).reject(&:blank?).each do |value|
        operator, value = parse_filter_operator(value)
        value = ModelApi::Utils.transform_value(value.to_s, attr_metadata[:parse], opts)
        if operator == '='
          equals_values << value
        else
          operator_value_pairs << [operator, value]
        end
      end
      operator_value_pairs << ['=', equals_values.uniq] if equals_values.present?
      operator_value_pairs
    end

    def parse_filter_operator(value)
      value = value.to_s.strip
      if (operator = value.scan(/\A(>=|<=|!=|<>)[[:space:]]*\w/).flatten.first).present?
        return (operator == '<>' ? '!=' : operator), value[2..-1].strip
      elsif (operator = value.scan(/\A(>|<|=)[[:space:]]*\w/).flatten.first).present?
        return operator, value[1..-1].strip
      end
      ['=', value]
    end

    def format_value_for_query(column, value, klass)
      return value.map { |v| format_value_for_query(column, v, klass) } if value.is_a?(Array)
      column_metadata = klass.columns_hash[column.to_s]
      case column_metadata.try(:type)
      when :date, :datetime, :time, :timestamp
        user = current_user
        if user.respond_to?(:time_zone) && (user_time_zone = user.time_zone).present?
          time_zone = ActiveSupport::TimeZone.new(user_time_zone)
        end
        time_zone ||= ActiveSupport::TimeZone.new('Eastern Time (US & Canada)')
        return time_zone.parse(value.to_s).try(:to_s, :db)
      when :float, :decimal
        return value.to_d.to_s
      when :integer, :primary_key
        return value.to_d.to_s.sub(/\.0\Z/, '')
      when :boolean
        return value ? 'true' : 'false'
      end
      value.to_s
    end

    def params_array(raw_value)
      index = 0
      array = []
      while raw_value.include?(index.to_s)
        array << raw_value[index.to_s]
        index += 1
      end
      array
    end

    def resolve_key_to_column(klass, attr_metadata)
      return nil unless klass.respond_to?(:columns_hash)
      columns_hash = klass.columns_hash
      key = attr_metadata[:key]
      return key if columns_hash.include?(key.to_s)
      render_method = attr_metadata[:render_method]
      render_method = render_method.to_s if render_method.is_a?(Symbol)
      return nil unless render_method.is_a?(String)
      columns_hash.include?(render_method) ? render_method : nil
    end

    def class_or_sti_subclass(klass, req_body, operation, opts = {})
      metadata = ModelApi::Utils.filtered_attrs(klass, :create, opts)
      if operation == :create && (attr_metadata = metadata[:type]).is_a?(Hash) &&
          req_body.is_a?(Hash)
        external_attr = ModelApi::Utils.ext_attr(:type, attr_metadata)
        type = req_body[external_attr.to_s]
        begin
          type = ModelApi::Utils.transform_value(type, attr_metadata[:parse], opts.dup)
        rescue Exception => e
          Rails.logger.warn 'Error encountered parsing API input for attribute ' \
                  "\"#{external_attr}\" (\"#{e.message}\"): \"#{type.to_s.first(1000)}\" ... " \
                  'using raw value instead.'
        end
        if type.present? && (type = type.camelize) != klass.name
          Rails.application.eager_load!
          klass.subclasses.each do |subclass|
            return subclass if subclass.name == type
          end
        end
      end
      klass
    end

    def object_from_req_body(root_elem, req_body, format)
      if format == :json
        request_obj = req_body
      else
        request_obj = req_body[root_elem]
        if request_obj.blank?
          request_obj = req_body['obj']
          if request_obj.blank? && req_body.size == 1
            request_obj = req_body.values.first
          end
        end
      end
      fail 'Invalid request format' unless request_obj.present?
      request_obj
    end

    def verify_update_request_body(request_body, format, opts = {})
      if request_body.is_a?(Array)
        fail 'Expected object, but collection provided'
      elsif !request_body.is_a?(Hash)
        fail 'Expected object'
      end
    end
  end
end
