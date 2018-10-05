require 'model-api/api_context'

module ModelApi
  module BaseController
    module ClassMethods
      def model_class
        nil
      end

      def base_api_options
        {}
      end

      def base_admin_api_options
        base_api_options.merge(admin_only: true)
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)

        base.send(:before_action, :common_headers)

        base.send(:rescue_from, Exception, with: :unhandled_exception)
        base.send(:respond_to, :json, :xml)
      end
    end

    module InstanceMethods
      SIMPLE_ID_REGEX = /\A[0-9]+\Z/
      UUID_REGEX = /\A[0-9A-Za-z]{8}-?[0-9A-Za-z]{4}-?[0-9A-Za-z]{4}-?[0-9A-Za-z]{4}-?[0-9A-Za-z]\
          {12}\Z/x
      DEFAULT_PAGE_SIZE = 100

      protected

      def model_class
        self.class.model_class
      end

      def api_context
        @api_context ||= ModelApi::ApiContext.new(self)
      end

      def render_collection(collection, opts = {})
        return unless ensure_admin_if_admin_only(opts)
        opts = api_context.prepare_options(opts)
        opts[:operation] ||= :index
        return unless api_context.validate_read_operation(collection, opts[:operation], opts)

        coll_route = opts[:collection_route] || self
        collection_links = { self: coll_route }
        collection = ModelApi::Utils.process_collection_includes(collection,
            opts.merge(model_metadata: opts[:api_model_metadata] || opts[:model_metadata]))
        collection, _result_filters = api_context.filter_collection(collection, find_filter_params,
            opts)
        collection, _result_sorts = api_context.sort_collection(collection, find_sort_params, opts)
        collection, collection_links, opts = paginate_collection(collection, collection_links, opts,
            coll_route)

        opts[:collection_links] = collection_links.merge(opts[:collection_links] || {})
            .reverse_merge(common_response_links(opts))
        add_collection_object_route(opts)
        ModelApi::Renderer.render(self, collection, opts)
      end

      def render_object(obj, opts = {})
        return unless ensure_admin_if_admin_only(opts)
        opts = api_context.prepare_options(opts)
        klass = ModelApi::Utils.find_class(obj, opts)
        object_route = opts[:object_route] || self

        opts[:object_links] = { self: object_route }
        if obj.is_a?(ActiveRecord::Base)
          return unless api_context.validate_read_operation(obj, opts[:operation], opts)
          unless obj.present?
            return not_found(opts.merge(class: klass, field: :id))
          end
          opts[:object_links].merge!(opts[:object_links] || {})
        else
          return not_found(opts) if obj.nil?
          obj = ModelApi::Utils.ext_value(obj, opts) unless opts[:raw_output]
          opts[:object_links].merge!(opts[:links] || {})
        end

        opts[:operation] ||= :show
        opts[:object_links].reverse_merge!(common_response_links(opts))
        ModelApi::Renderer.render(self, obj, opts)
      end

      def do_create(opts = {})
        klass = opts[:model_class] || model_class
        return unless ensure_admin_if_admin_only(opts)
        unless klass.is_a?(Class) && klass < ActiveRecord::Base
          fail 'Unable to process object creation; Missing or invalid model class'
        end
        obj, opts = prepare_object_for_create(klass, opts)
        return bad_payload(class: klass) if opts[:bad_payload]
        create_and_render_object(obj, opts)
      end

      def prepare_object_for_create(klass, opts = {})
        opts = api_context.prepare_options(opts)
        req_body, format = parse_request_body
        api_context.get_updated_object(klass, get_operation(:create, opts), req_body,
            opts.merge(format: format))

      end

      def create_and_render_object(obj, opts = {})
        opts = api_context.prepare_options(opts)
        object_link_options = opts[:object_link_options]
        object_link_options[:action] = :show
        save_and_render_object(obj, get_operation(:create, opts), opts.merge(location_header: true))
      end

      def do_update(obj, opts = {})
        return unless ensure_admin_if_admin_only(opts)
        obj, opts = prepare_object_for_update(obj, opts)
        return bad_payload(class: (self.try(:klass) || obj.try(:class))) if opts[:bad_payload]
        unless obj.present?
          return not_found(opts.merge(class: ModelApi::Utils.find_class(obj, opts), field: :id))
        end
        update_and_render_object(obj, opts)
      end

      def prepare_object_for_update(obj, opts = {})
        opts = api_context.prepare_options(opts)
        req_body, format = parse_request_body
        api_context.get_updated_object(obj, get_operation(:update, opts), req_body,
            opts.merge(format: format))
      end

      def update_and_render_object(obj, opts = {})
        opts = api_context.prepare_options(opts)
        save_and_render_object(obj, get_operation(:update, opts), opts)
      end

      def save_and_render_object(obj, operation, opts = {})
        opts = api_context.prepare_options(opts)
        status, msgs = Utils.process_updated_model_save(obj, operation, opts)
        successful = ModelApi::Utils.response_successful?(status)
        ModelApi::Renderer.render(self, successful ? obj : opts[:request_obj],
            opts.merge(status: status, operation: :show, messages: msgs))
      end

      def do_destroy(obj, opts = {})
        return unless ensure_admin_if_admin_only(opts)
        opts = prepare_options(opts)
        obj = obj.first if obj.is_a?(ActiveRecord::Relation)

        unless obj.present?
          return not_found(opts.merge(class: klass, field: :id))
        end

        operation = opts[:operation] = get_operation(:destroy, opts)
        ModelApi::Utils.validate_operation(obj, operation,
            opts.merge(model_metadata: opts[:api_model_metadata] || opts[:model_metadata]))
        response_status, errs_or_msgs =
          ModelApi::BaseController::Utils.process_object_destroy(obj, operation, opts)

        klass = ModelApi::Utils.find_class(obj, opts)
        root = opts[:root] || ModelApi::Utils.model_name(klass).singular
        ModelApi::Renderer.render(self, obj, opts.merge(status: response_status,
            root: root.to_s, messages: errs_or_msgs))
      end

      def common_response_links(_opts = {})
        {}
      end

      def initialize_options(opts)
        return opts if opts[:options_initialized]
        opts = opts.symbolize_keys
        opts[:api_context] ||= @api_context
        opts[:model_class] ||= model_class
        opts[:user] ||= filter_by_user
        opts[:user_id] ||= opts[:user].try(:id)
        opts[:admin_user] ||= admin_user?(opts)
        opts[:admin] ||= admin?(opts)
        unless opts.include?(:collection_link_options) && opts.include?(:object_link_options)
          default_link_options = request.params.to_h.symbolize_keys
          opts[:collection_link_options] ||= default_link_options
          opts[:object_link_options] ||= default_link_options
          if default_link_options[:exclude_associations].present?
            opts[:exclude_associations] ||= default_link_options[:exclude_associations]
          end
        end
        opts[:options_initialized] ||= true
        opts
      end

      # Default implementation, can be hidden by API controller classes to include any
      # application-specific options
      def prepare_options(opts)
        return opts if opts[:options_initialized]
        initialize_options(opts)
      end

      def id_info(opts = {})
        id_info = {}
        id_info[:id_attribute] = (opts[:id_attribute] || :id).to_sym
        id_info[:id_param] = (opts[:id_param] || :id).to_sym
        id_info[:id_value] = (opts[:id_value] || params[id_info[:id_param]]).to_s
        id_info
      end

      def common_object_query(opts = {})
        opts = api_context.prepare_options(opts)
        id_info = opts[:id_info] || id_info(opts)
        api_context.common_object_query(id_info[:id_attribute], id_info[:id_value],
            opts.merge(id_param: id_info[:id_param]))
      end

      def collection_query(opts = {})
        opts = api_context.prepare_options(base_api_options.merge(opts))
        klass = opts[:model_class] || model_class
        query = api_context.api_query(klass, opts)
        unless (opts.include?(:user_filter) && !opts[:user_filter]) ||
            (admin? || filtered_by_foreign_key?(query)) || !opts[:user]
          query = api_context.user_query(query, opts[:user], opts.merge(model_class: klass))
        end
        query
      end

      def object_query(opts = {})
        common_object_query(api_context.prepare_options(base_api_options.merge(opts)))
      end

      def base_api_options
        self.class.base_api_options
      end

      def base_admin_api_options
        base_api_options.merge(admin: true, admin_only: true)
      end

      def ensure_admin
        return true if admin_user?

        # Mask presence of endpoint if user is not authorized to access it
        not_found
        false
      end

      def unhandled_exception(err)
        return if handle_api_exceptions(err)
        return if performed?
        error_details = {}
        if Rails.env == 'development'
          error_details[:message] = "Exception: #{err.message}"
          error_details[:backtrace] = err.backtrace
        else
          error_details[:message] = 'An internal server error has occurred ' \
              'while processing your request.'
        end
        ModelApi::Renderer.render(self, error_details, root: :error_details,
            status: :internal_server_error)
      end

      def handle_api_exceptions(err)
        if err.is_a?(ModelApi::NotFoundException)
          not_found(field: err.field, message: err.message)
        elsif err.is_a?(ModelApi::UnauthorizedException)
          unauthorized
        else
          return false
        end
        true
      end

      def doorkeeper_unauthorized_render_options(error: nil)
        { json: unauthorized(error: 'Not authorized to access resource', message: error.description,
            format: :json, generate_body_only: true) }
      end

      # Indicates whether user has access to data they do not own.
      def admin_user?(opts = {})
        return opts[:admin_user] if opts.include?(:admin_user)
        user = current_user
        return nil if user.nil?
        [:admin_api_user?, :admin_user?, :admin?].each do |method|
          next unless user.respond_to?(method)
          opts[:admin_user] = user.send(method) rescue next
          break
        end
        opts[:admin_user] ||= false
      end

      # Indicates whether API should render administrator-only content in API responses
      def admin?(opts = {})
        return opts[:admin] if opts.include?(:admin)
        param = request.params[:admin]
        param.present? && admin_user?(opts) &&
            (param.to_i != 0 && params.to_s.strip.downcase != 'false')
      end

      # Deprecated
      def admin_content?(opts = {})
        admin?(opts)
      end

      def resource_parent_id(parent_model_class, opts = {})
        opts = api_context.prepare_options(opts)
        id_info = id_info(opts.reverse_merge(id_param: "#{parent_model_class.name.underscore}_id"))
        model_name = parent_model_class.model_name.human
        if id_info[:id_value].blank?
          unless opts[:optional]
            fail ModelApi::NotFoundException.new(id_info[:id_param], "#{model_name} not found")
          end
          return nil
        end
        query = common_object_query(opts.merge(model_class: parent_model_class, id_info: id_info))
        parent_id = query.pluck(:id).first
        if parent_id.blank?
          unless opts[:optional]
            fail ModelApi::NotFoundException.new(id_info[:id_param],
                "#{model_name} '#{id_info[:id_value]}' not found")
          end
          return nil
        end
        parent_id
      end

      def simple_error(status, error, opts = {})
        opts = opts.dup
        klass = opts[:class]
        opts[:root] = ModelApi::Utils.model_name(klass).singular if klass.present?
        if error.is_a?(Array)
          errs_or_msgs = error.map do |e|
            if e.is_a?(Hash)
              next e if e.include?(:error) && e.include?(:message)
              next e.reverse_merge(
                  error: e[:error] || 'Unspecified error',
                  message: e[:message] || e[:error] || 'Unspecified error')
            end
            { error: e.to_s, message: e.to_s }
          end
        elsif error.is_a?(Hash)
          errs_or_msgs = [error]
        else
          errs_or_msgs = [{ error: error, message: opts[:message] || error }]
        end
        errs_or_msgs[0][:field] = opts[:field] if opts.include?(:field)
        ModelApi::Renderer.render(self, opts[:request_obj], opts.merge(status: status,
            messages: errs_or_msgs))
      end

      def not_found(opts = {})
        opts = opts.dup
        opts[:message] ||= 'No resource found at the path provided or matching the criteria ' \
            'specified'
        simple_error(:not_found, opts.delete(:error) || 'No resource found', opts)
      end

      def bad_payload(opts = {})
        opts = opts.dup
        format = opts[:format] || identify_format
        opts[:message] ||= "A properly-formatted #{format.to_s.upcase} " \
            'payload was expected in the HTTP request body but not found'
        simple_error(:bad_request, opts.delete(:error) || 'Missing/invalid request body (payload)',
            opts)
      end

      def bad_request(error, message, opts = {})
        opts[:message] = message || 'This request is invalid for the resource in its present state'
        simple_error(:bad_request, error || 'Invalid API request', opts)
      end

      def unauthorized(opts = {})
        opts = opts.dup
        opts[:message] ||= 'Missing one or more privileges required to complete request'
        simple_error(:unauthorized, opts.delete(:error) || 'Not authorized', opts)
      end

      def not_implemented(opts = {})
        opts = opts.dup
        opts[:message] ||= 'This API feature is presently unavailable'
        simple_error(:not_implemented, opts.delete(:error) || 'Not implemented', opts)
      end

      def filter_by_user
        current_user
      end

      def current_user
        nil
      end

      def common_headers
        ModelApi::Utils.common_http_headers.each do |k, v|
          response.headers[k] = v
        end
      end

      def identify_format
        format = self.request.format.symbol rescue :json
        format == :xml ? :xml : :json
      end

      def ensure_admin_if_admin_only(opts = {})
        return true unless opts[:admin_only]
        ensure_admin
      end

      def get_operation(default_operation, opts = {})
        if opts.key?(:operation)
          return opts[:operation]
        elsif action_name.start_with?('create')
          return :create
        elsif action_name.start_with?('update')
          return :update
        elsif action_name.start_with?('patch')
          return :patch
        elsif action_name.start_with?('destroy')
          return :destroy
        else
          return default_operation
        end
      end

      def parse_request_body
        unless instance_variable_defined?(:@request_body)
          @req_body, @format = ModelApi::Utils.parse_request_body(request)
        end
        [@req_body, @format]
      end

      private

      def find_filter_params
        request.params.reject { |p, _v| %w(access_token sort_by admin).include?(p) }
      end

      def find_sort_params
        sort_by = params[:sort_by]
        return {} if sort_by.blank?
        sort_by = sort_by.to_s.strip
        if sort_by.starts_with?('{') || sort_by.starts_with?('[')
          process_json_sort_params(sort_by)
        else
          process_simple_sort_params(sort_by)
        end
      end

      def process_json_sort_params(sort_by)
        sort_params = {}
        sort_json_obj = (JSON.parse(sort_by) rescue {})
        sort_json_obj = Hash[sort_json_obj.map { |v| [v, nil] }] if sort_json_obj.is_a?(Array)
        sort_json_obj.each do |key, value|
          next if key.blank?
          value_lc = value.to_s.downcase
          if %w(a asc ascending).include?(value_lc)
            order = :asc
          elsif %w(d desc descending).include?(value_lc)
            order = :desc
          else
            order = :default
          end
          sort_params[key] = order
        end
        sort_params
      end

      def process_simple_sort_params(sort_by)
        sort_params = {}
        sort_by.split(',').each do |key|
          key = key.to_s.strip
          key_lc = key.downcase
          if key_lc.ends_with?('_a') || key_lc.ends_with?(' a')
            key = sort_by[key[0..-3]]
            order = :asc
          elsif key_lc.ends_with?('_asc') || key_lc.ends_with?(' asc')
            key = sort_by[key[0..-5]]
            order = :asc
          elsif key_lc.ends_with?('_ascending') || key_lc.ends_with?(' ascending')
            key = sort_by[key[0..-11]]
            order = :asc
          elsif key_lc.ends_with?('_d') || key_lc.ends_with?(' d')
            key = sort_by[key[0..-3]]
            order = :desc
          elsif key_lc.ends_with?('_desc') || key_lc.ends_with?(' desc')
            key = sort_by[key[0..-6]]
            order = :desc
          elsif key_lc.ends_with?('_descending') || key_lc.ends_with?(' descending')
            key = sort_by[key[0..-12]]
            order = :desc
          else
            order = :default
          end
          next if key.blank?
          sort_params[key] = order
        end
        sort_params
      end

      def paginate_collection(collection, collection_links, opts, coll_route)
        collection_size = collection.count
        page_size = (params[:page_size] || DEFAULT_PAGE_SIZE).to_i
        page = [params[:page].to_i, 1].max
        page_count = [(collection_size + page_size - 1) / page_size, 1].max
        page = page_count if page > page_count
        offset = (page - 1) * page_size

        opts = opts.dup
        opts[:count] ||= collection_size
        opts[:page] ||= page
        opts[:page_size] ||= page_size
        opts[:page_count] ||= page_count

        response.headers['X-Total-Count'] = collection_size.to_s

        opts[:collection_link_options] = (opts[:collection_link_options] || {})
            .reject { |k, _v| [:page].include?(k.to_sym) }
        opts[:object_link_options] = (opts[:object_link_options] || {})
            .reject { |k, _v| [:page, :page_size].include?(k.to_sym) }

        if collection_size > page_size
          opts[:collection_link_options][:page] = page
          add_pagination_links(collection_links, coll_route, page, page_count)
          collection = collection.limit(page_size).offset(offset)
        end

        [collection, collection_links, opts]
      end

      def add_pagination_links(collection_links, coll_route, page, last_page)
        if page < last_page
          collection_links[:next] = [coll_route, { page: (page + 1) }]
        end
        collection_links[:prev] = [coll_route, { page: (page - 1) }] if page > 1
        collection_links[:first] = [coll_route, { page: 1 }]
        collection_links[:last] = [coll_route, { page: last_page }]
      end

      def add_collection_object_route(opts)
        object_route = opts[:object_route]
        unless object_route.present?
          route_name = ModelApi::Utils.route_name(request)
          if route_name.present?
            if (singular_route_name = route_name.singularize) != route_name
              object_route = singular_route_name
            end
          end
        end
        if object_route.present? && (object_route.is_a?(String) || object_route.is_a?(Symbol))
          object_route = nil unless self.respond_to?("#{object_route}_url")
        end
        object_route = opts[:default_object_route] if object_route.blank?
        return if object_route.blank?
        opts[:object_links] = (opts[:object_links] || {}).merge(self: object_route)
      end

      def filtered_by_foreign_key?(query)
        fk_cache = self.class.instance_variable_get(:@foreign_key_cache)
        self.class.instance_variable_set(:@foreign_key_cache, fk_cache = {}) if fk_cache.nil?
        klass = query.klass
        foreign_keys = (fk_cache[klass] ||= query.klass.reflections.values
            .select { |a| a.macro == :belongs_to }.map { |a| a.foreign_key.to_s })
        (query.values[:where] || []).to_h.select { |v| v.is_a?(Arel::Nodes::Equality) }
            .map { |v| v.left.name }.each do |key|
          return true if foreign_keys.include?(key)
        end
        false
      rescue Exception => e
        Rails.logger.warn "Exception encounterd determining if query is filtered: #{e.message}\n" \
            "#{e.backtrace.join("\n")}"
      end
    end

    class Utils
      class << self
        def process_updated_model_save(obj, operation, opts = {})
          opts = opts.dup
          opts[:operation] = operation
          successful = ModelApi::Utils.save_obj(obj,
              opts.merge(model_metadata: opts[:api_model_metadata]))
          if successful
            suggested_response_status = :ok
            object_errors = []
          else
            suggested_response_status = :bad_request
            attr_metadata = opts.delete(:api_attr_metadata) ||
                ModelApi::Utils.filtered_attrs(obj, operation, opts)
            object_errors = ModelApi::Utils.extract_error_msgs(obj,
                opts.merge(api_attr_metadata: attr_metadata))
            unless object_errors.present?
              object_errors << {
                  error: 'Unspecified error',
                  message: "Unspecified error processing #{operation}: " \
                      'Please contact customer service for further assistance.'
              }
            end
          end
          [suggested_response_status, object_errors]
        end

        def process_object_destroy(obj, operation, opts)
          soft_delete = obj.errors.present? ? false : object_destroy(obj, opts)

          if obj.errors.blank? && (soft_delete || obj.destroyed?)
            response_status = :ok
            object_errors = []
          else
            object_errors = ModelApi::Utils.extract_error_msgs(obj, opts)
            if object_errors.present?
              response_status = :bad_request
            else
              response_status = :internal_server_error
              object_errors << {
                  error: 'Unspecified error',
                  message: "Unspecified error processing #{operation}: " \
                      'Please contact customer service for further assistance.'
              }
            end
          end

          [response_status, object_errors]
        end

        def object_destroy(obj, opts = {})
          klass = ModelApi::Utils.find_class(obj)
          object_id = obj.send(opts[:id_attribute] || :id)
          obj.instance_variable_set(:@readonly, false) if obj.instance_variable_get(:@readonly)
          if (deleted_col = klass.columns_hash['deleted']).present?
            case deleted_col.type
            when :boolean
              obj.update_attribute(:deleted, true)
              return true
            when :integer, :decimal
              obj.update_attribute(:deleted, 1)
              return true
            else
              obj.destroy
            end
          else
            obj.destroy
          end
          false
        rescue Exception => e
          Rails.logger.warn "Error destroying #{klass.name} \"#{object_id}\": \"#{e.message}\")."
          false
        end
      end
    end
  end
end
