require 'rexml/document'

module ModelApi
  module Renderer
    class << self
      def render(controller, response_obj, opts = {})
        opts = opts.symbolize_keys
        format = (opts[:format] ||= get_format(controller))
        opts[:action] ||= controller.action_name.to_sym
        if format == :xml
          render_xml_response(response_obj, controller, opts)
        else
          render_json_response(response_obj, controller, opts)
        end
      end

      private

      def serializable_object(obj, opts = {})
        obj = obj.first if obj.is_a?(ActiveRecord::Relation)
        opts = opts.symbolize_keys
        return nil if obj.nil?
        operation = opts[:operation] || :show
        metadata_opts = opts.merge(ModelApi::Utils.contextual_metadata_opts(opts))
        metadata = ModelApi::Utils.filtered_attrs(obj, operation, metadata_opts)
        render_values, render_assoc = attrs_by_type(obj, metadata)
        hash = {}
        serialize_values(hash, obj, render_values, opts)
        serialize_associations(hash, obj, render_assoc, opts)
        process_serializable_hash(metadata, hash, opts)
      end

      def attrs_by_type(obj, metadata)
        render_values = []
        render_assoc = []
        metadata.each do |attr, attr_metadata|
          if (value = attr_metadata[:value]).present?
            render_values << [attr, value, attr_metadata]
          elsif obj.respond_to?(attr.to_s)
            render_values << [attr, obj.send(attr.to_sym), attr_metadata]
          elsif (assoc = obj.class.reflect_on_association(attr)).present?
            render_assoc << [assoc, attr_metadata]
          elsif obj.is_a?(ActiveRecord::Base)
            fail "Invalid API attribute for #{obj.class.model_name.human} instance: #{attr}"
          else
            fail "Invalid API attribute for #{obj.class.name} instance: #{attr}"
          end
        end
        [render_values, render_assoc]
      end

      def serialize_values(hash, obj, value_procs, opts = {})
        value_procs.each do |attr, value, attr_metadata|
          if value.respond_to?(:call) && value.respond_to?(:parameters)
            proc_opts = opts.merge(attr: attr, attr_metadata: attr_metadata)
            value = value.send(*([:call, obj, proc_opts][0..value.parameters.size]))
          end
          hash[attr] = serialize_value(value, attr_metadata, opts)
        end
      end

      def serialize_associations(hash, obj, associations, opts = {})
        associations.each do |assoc, attr_metadata|
          return nil if assoc.nil?
          assoc_opts = ModelApi::Utils.assoc_opts(assoc, attr_metadata, opts)
          next if assoc_opts.nil?
          attr = assoc.name
          assoc = assoc_opts[:association]
          render_proc ||= ->(o) { serialize_value(o, attr_metadata, assoc_opts) }
          if !assoc.nil? && assoc.collection?
            value = obj.send(attr).map { |o| render_proc.call(o) }
          else
            value = render_proc.call(obj.send(attr))
          end
          hash[attr] = value
        end
      end

      def serialize_value(value, attr_metadata, opts)
        if (render_method = attr_metadata[:render_method]).present?
          if render_method.respond_to?(:call)
            value = serialize_value_proc(render_method, value)
          else
            value = serialize_value_obj_attr(render_method, value)
          end
        end
        opts = ModelApi::Utils.contextual_metadata_opts(attr_metadata, opts)
        opts[:operation] = :show
        if value.respond_to?(:map)
          return value.map do |elem|
            elem.is_a?(ActiveRecord::Base) ? serializable_object(elem, opts) : elem
          end
        elsif value.is_a?(ActiveRecord::Base)
          return serializable_object(value, opts)
        end
        value
      end

      def serialize_value_proc(render_method, value)
        if render_method.parameters.count > 1
          render_method.call(value, opts)
        else
          render_method.call(value)
        end
      end

      def serialize_value_obj_attr(render_method, value)
        render_method = render_method.to_s.to_sym
        if value.is_a?(ActiveRecord::Associations::CollectionProxy) || value.is_a?(Array)
          (value.map do |obj|
            obj.respond_to?(render_method) ? obj.send(render_method) : nil
          end).compact
        elsif value.respond_to?(render_method)
          value.send(render_method)
        end
      end

      def process_serializable_hash(api_attrs_metadata, hash, opts)
        updated_hash_array = (hash.map do |key, value|
          attr_metadata = api_attrs_metadata[key.to_sym] || {}
          value = ModelApi::Utils.format_value(value, attr_metadata, opts)
          next nil if value.nil? && attr_metadata[:hide_when_nil]
          [ModelApi::Utils.ext_attr(key, attr_metadata).to_sym, value]
        end).compact
        api_attrs = api_attrs_metadata.map { |k, m| ModelApi::Utils.ext_attr(k, m).to_sym }
        updated_hash_array.sort_by! do |key, _value|
          api_attrs.find_index(key.to_s.to_sym) || api_attrs.size
        end
        Hash[updated_hash_array]
      end

      def get_format(controller)
        format = controller.request.format.symbol rescue :json
        format == :xml ? :xml : :json
      end

      def get_object_root_elem(obj, opts)
        if (root_elem = opts[:root]).present?
          return root_elem
        end
        if obj.respond_to?(:klass)
          item_class = obj.klass
        elsif obj.nil?
          item_class = Object
        else
          item_class = obj.class
        end
        return 'response' if item_class == Hash
        ModelApi::Utils.model_name(item_class).singular
      end

      def get_collection_root_elem(collection, opts)
        if (root_elem = opts[:root]).present?
          return root_elem
        end
        if collection.respond_to?(:klass)
          item_class = collection.klass
        elsif collection.respond_to?(:first) && (first_obj = collection.first).present?
          item_class = first_obj.class
        else
          item_class = Object
        end
        ModelApi::Utils.model_name(item_class).plural
      end

      def hateoas_link_xml(links, _opts = {})
        '<_links>' +
            links.map do |link|
              '<link' + link.map { |k, v| " #{k}=\"#{CGI.escapeHTML(v)}\"" }.join + ' />'
            end.join +
            '</_links>'
      end

      def hateoas_pagination_values_json(count, page, page_count, page_size)
        json = []
        if count.present?
          json << ",\"#{ModelApi::Utils.ext_attr(:count)}\":#{[count.to_i, 0].max}"
        end
        json << ",\"#{ModelApi::Utils.ext_attr(:page)}\":#{[page.to_i, 0].max}" if page.present?
        if page_count.present?
          json << ",\"#{ModelApi::Utils.ext_attr(:page_count)}\":#{[page_count.to_i, 0].max}"
        end
        if page_size.present?
          json << ",\"#{ModelApi::Utils.ext_attr(:page_size)}\":#{[page_size.to_i, 0].max}"
        end
        json.join
      end

      def hateoas_pagination_values_xml(count, page, page_count, page_size)
        xml = []
        count_attr = ModelApi::Utils.ext_attr(:count)
        page_attr = ModelApi::Utils.ext_attr(:page)
        page_count_attr = ModelApi::Utils.ext_attr(:page_count)
        page_size_attr = ModelApi::Utils.ext_attr(:page_size)
        xml << "<#{count_attr}>#{[count.to_i, 0].max}</#{count_attr}>" if count.present?
        xml << "<#{page_attr}>#{[page.to_i, 0].max}</#{page_attr}>" if page.present?
        if page_count.present?
          xml << "<#{page_count_attr}>#{[page_count.to_i, 0].max}</#{page_count_attr}>"
        end
        if page_size.present?
          xml << "<#{page_size_attr}>#{[page_size.to_i, 0].max}</#{page_size_attr}>"
        end
        xml.join
      end

      def object_hateoas_links(object_links, obj, controller, opts = {})
        return {} if obj.blank?
        custom_links = ModelApi::Utils.filtered_links(obj, opts[:operation], opts)
        links = (object_links || {}).merge(custom_links).map do |rel, route|
          next { rel: rel.to_s, href: route.to_s } if route.is_a?(URI)
          if route.is_a?(Hash)
            link_opts = opts.merge(route)
            route = link_opts.delete(:route)
            next nil if route.blank?
          else
            link_opts = opts
          end
          next { rel: rel.to_s, href: route.to_s } if route.is_a?(URI)
          route_args = build_object_hateoas_route_args(obj, controller, route, link_opts)
          if route_args[0].respond_to?(:url_for)
            next { rel: rel.to_s, href: route_args[0].url_for(*route_args.slice(1..-1)) }
          elsif !controller.respond_to?(route_args[0].to_s.to_sym)
            route_args[0] = :"#{route_args[0]}_url"
            next nil unless controller.respond_to?(route_args[0])
          end
          begin
            param_count = controller.method(route_args[0]).parameters.size
            { rel: rel.to_s, href: controller.send(*(route_args[0..param_count])) }
          rescue Exception => e
            Rails.logger.warn "Error encountered generating \"#{rel}\" " \
                "link (\"#{e.message}\") for #{obj.class.name}: " \
                "#{(obj.respond_to?(:guid) ? obj.guid : obj.id)}"
            nil
          end
        end
        links.compact
      end

      def build_object_hateoas_route_args(obj, controller, route, opts = {})
        id_attr = opts[:id_attribute] || :id
        link_opts = (opts[:object_link_options] || {}).dup
        format = controller.request.format.symbol rescue nil
        link_opts[:format] ||= format if format.present?
        if route.is_a?(Array)
          if route.size > 1 && (route_opts = route.last).is_a?(Hash)
            route.first(route.size - 1).append(link_opts.merge(route_opts))
          else
            route + [object.send(id_attr), link_opts]
          end
        else
          id = obj.is_a?(Hash) ? obj[id_attr] : obj.send(id_attr)
          [route, { (opts[:id_param] || :id) => id }.merge(link_opts)]
        end
      end

      def hateoas_links(links, common_link_opts, controller, opts = {})
        links = (links || {}).map do |rel, route|
          if route.is_a?(Hash)
            link_opts = route.merge(common_link_opts)
            route = link_opts.delete(:route)
          else
            link_opts = common_link_opts
          end
          next { rel: rel.to_s, href: route.to_s } if route.is_a?(URI)
          route_args = build_hateoas_route_args(controller, route, link_opts, opts)
          if route_args[0].respond_to?(:url_for)
            next { rel: rel.to_s, href: route_args[0].url_for(*route_args.slice(1..-1)) }
          elsif !controller.respond_to?(route_args[0])
            route_args[0] = :"#{route_args[0]}_url"
            next nil unless controller.respond_to?(route_args[0])
          end
          begin
            { rel: rel.to_s, href: controller.send(*route_args) }
          rescue Exception => e
            Rails.logger.warn "Error encountered generating \"#{rel}\" link " \
                "(\"#{e.message}\") for collection."
            nil
          end
        end
        links.compact
      end

      def build_hateoas_route_args(controller, route, link_opts, _opts = {})
        link_opts ||= {}
        format = controller.request.format.symbol rescue nil
        link_opts[:format] ||= format if format.present?
        if route.is_a?(Array)
          if route.size > 1 && (route_opts = route.last).is_a?(Hash)
            route.first(route.size - 1).append(link_opts.merge(route_opts))
          else
            route.append(link_opts)
          end
        else
          [route, link_opts]
        end
      end

      def hateoas_object(obj, controller, format, opts = {})
        object_links = object_hateoas_links(opts[:object_links], obj, controller, opts)
        hash = serializable_object(obj, opts)
        if format == :xml
          root_tag = ModelApi::Utils.ext_attr(opts[:root] || get_object_root_elem(obj, opts) || :obj)
          end_tag = "</#{root_tag}>"
          if object_links.present?
            pretty_xml(hash
                .to_xml(opts.merge(root: root_tag, skip_instruct: true))
                .sub(Regexp.new('(' + Regexp.escape(end_tag) + ')\\w*\\Z'),
                    hateoas_link_xml(object_links, opts) + end_tag))
          else
            pretty_xml(hash.to_xml(opts.merge(root: root_tag, skip_instruct: true)))
          end
        else
          hash[:_links] = object_links
          hash.to_json(opts)
        end
      end

      def hateoas_collection(collection, controller, format, opts = {})
        opts = (opts || {}).symbolize_keys
        count = opts[:count]
        page = opts[:page]
        page_count = opts[:page_count]
        page_size = opts[:page_size]
        root_tag = ModelApi::Utils.ext_attr(opts[:root] || get_collection_root_elem(collection, opts) ||
            :objects)
        if format == :xml
          children_tag = opts.delete(:children) || root_tag.to_s.singularize
          response_xml = []
          response_xml << "<#{root_tag}>"
          collection.each do |obj|
            response_xml << hateoas_object(obj, controller, format, opts.merge(root: children_tag))
          end
          response_xml << "</#{root_tag}>"
          response_xml << hateoas_pagination_values_xml(count, page, page_count, page_size)
          pretty_xml(response_xml.join)
        else
          "\"#{root_tag}\":[" + collection.map do |obj|
            hateoas_object(obj, controller, format, opts)
          end.join(',') + ']' +
              hateoas_pagination_values_json(count, page, page_count, page_size)
        end
      end

      def render_xml_response(response_obj, controller, opts = {})
        http_status, http_status_code = http_status_and_status_code(controller, opts)
        successful = ModelApi::Utils.response_successful?(http_status_code)
        response_xml = render_xml_response_heading(http_status, opts)
        render_xml_response_body(response_xml, response_obj, controller, opts)
        response_xml << "</#{ModelApi::Utils.ext_attr(:response)}>"
        return pretty_xml(response_xml.join) if opts[:generate_body_only]
        set_location_header(response_obj, controller, successful, opts)
        controller.render status: http_status, xml: pretty_xml(response_xml.join)
        successful
      end

      def render_xml_response_heading(status, opts = {})
        http_status_code = ModelApi::Utils.http_status_code(status)
        successful = ModelApi::Utils.response_successful?(http_status_code)
        successful_tag = ModelApi::Utils.ext_attr(:successful)
        status_tag = ModelApi::Utils.ext_attr(:status)
        status_code_tag = ModelApi::Utils.ext_attr(:status_code)
        response_xml = []
        response_xml << "<#{ModelApi::Utils.ext_attr(:response)}>"
        response_xml << "<#{successful_tag}>#{successful ? 'true' : 'false'}</#{successful_tag}>"
        response_xml << "<#{status_tag}>#{status}</#{status_tag}>"
        response_xml << "<#{status_code_tag}>#{http_status_code}</#{status_code_tag}>"
        if opts[:messages].present?
          response_xml << xml_collection_elem_tags_with_attrs(
              ModelApi::Utils.ext_attr(successful ? :messages : :errors), opts[:messages])
        end
        response_xml
      end

      def render_xml_response_body(response_xml, response_obj, controller,
          opts = {})
        collection = false
        if response_obj.is_a?(ActiveRecord::Base)
          response_xml << hateoas_object(response_obj, controller, opts[:format] || :xml, opts)
        elsif !response_obj.is_a?(Hash) && response_obj.respond_to?(:map)
          response_xml << hateoas_collection(response_obj, controller, opts[:format] || :xml, opts)
          collection = true
        elsif response_obj.present?
          root = ModelApi::Utils.ext_attr(opts[:root] || get_object_root_elem(response_obj, opts) ||
              :response)
          response_xml << response_obj.to_xml(opts.merge(skip_instruct: true, root: root)).rstrip
        end
        if opts[:ignored_fields].present?
          response_xml << xml_collection_elem_tags_with_attrs(
              ModelApi::Utils.ext_attr(:ignored_fields), opts[:ignored_fields])
        end
        if collection
          if (links = hateoas_links(opts[:collection_links],
              opts[:collection_link_options], controller, opts)).present?
            response_xml << hateoas_link_xml(links, opts)
          end
        elsif (links = hateoas_links(opts[:links], opts[:link_opts], controller, opts)).present?
          response_xml << hateoas_link_xml(links, opts)
        end
        response_xml
      end

      def http_status_and_status_code(controller, opts = {})
        if opts[:status].present?
          return [opts[:status].to_sym, ModelApi::Utils.http_status_code(opts[:status].to_sym)]
        elsif opts[:status_code].present?
          return [ModelApi::Utils.http_status(opts[:status_code].to_i), opts[:status_code].to_i]
        elsif controller.response.status.present? && controller.response.status > 0
          return [ModelApi::Utils.http_status(controller.response.status), controller.response.status]
        else
          return [:ok, ModelApi::Utils.http_status_code(:ok)]
        end
      end

      def render_json_response(response_obj, controller, opts = {})
        http_status, http_status_code = http_status_and_status_code(controller, opts)
        successful = ModelApi::Utils.response_successful?(http_status_code)
        response_json = "\"#{ModelApi::Utils.ext_attr(:successful)}\":#{successful ? 'true' : 'false'},"
        response_json += "\"#{ModelApi::Utils.ext_attr(:status)}\":\"#{http_status}\","
        response_json += "\"#{ModelApi::Utils.ext_attr(:status_code)}\":#{http_status_code}"
        if opts[:messages].present?
          response_json += ",\"#{ModelApi::Utils.ext_attr(successful ? :messages : :errors)}\":" +
              opts[:messages].to_json(opts)
        end
        response_json += build_response_obj_json(response_obj, controller, opts)
        if opts[:ignored_fields].present?
          response_json += ",\"#{ModelApi::Utils.ext_attr(:ignored_fields)}\":" +
              opts[:ignored_fields].to_json(opts)
        end
        return "{#{response_json}}" if opts[:generate_body_only]
        set_location_header(response_obj, controller, successful, opts)
        controller.render status: http_status, json: "{#{response_json}}"
        successful
      end

      def build_response_obj_json(response_obj, controller, opts = {})
        if !response_obj.nil?
          if response_obj.is_a?(ActiveRecord::Base)
            root_elem_json = ModelApi::Utils.ext_attr(get_object_root_elem(response_obj, opts)).to_json
            response_json = ",#{root_elem_json}:" +
                hateoas_object(response_obj, controller, opts[:format] || :json, opts)
            links = hateoas_links(opts[:links], opts[:link_opts], controller, opts)
          elsif !response_obj.is_a?(Hash) && response_obj.respond_to?(:map)
            response_json = ',' + hateoas_collection(response_obj, controller,
                opts[:format] || :json, opts)
            links = hateoas_links(opts[:collection_links],
                opts[:collection_link_options], controller, opts)
          else
            root_elem_json = ModelApi::Utils.ext_attr(get_object_root_elem(response_obj, opts)).to_json
            response_json = ",#{root_elem_json}:" + response_obj.to_json(opts)
            links = hateoas_links(opts[:links], opts[:link_opts], controller, opts)
          end
          if links.present?
            response_json += ",\"_links\":" + links.to_json(opts)
          end
          response_json
        else
          ''
        end
      end

      def xml_elem_tags_with_attrs(element, hash)
        tags = hash.map do |attr, value|
          " #{attr}=\"#{CGI.escapeHTML(value.to_s)}\""
        end
        "<#{element}#{tags.join} />"
      end

      def xml_collection_elem_tags_with_attrs(element, array, opts = {})
        child_element = opts[:children] || element.to_s.singularize
        tags = array.map do |hash|
          xml_elem_tags_with_attrs(child_element, hash)
        end
        "<#{element}>#{tags.join}</#{element}>"
      end

      def pretty_xml(xml, _indent = 2)
        xml_doc = REXML::Document.new(xml) rescue nil
        return xml unless xml_doc.present?
        formatter = REXML::Formatters::Pretty.new
        formatter.compact = true
        out = ''
        formatter.write(xml_doc, out)
        out || xml
      end

      def set_location_header(response_obj, controller, successful, opts = {})
        return unless successful && opts[:location_header] &&
            response_obj.is_a?(ActiveRecord::Base)
        links = opts[:object_links]
        return unless links.is_a?(Hash) && links.include?(:self)
        link = object_hateoas_links({ self: links[:self] }, response_obj, controller,
            opts.merge(exclude_api_links: true)).find { |l| l[:rel].to_s == 'self' }
        controller.response.header['Location'] = link[:href] if link.include?(:href)
      end
    end
  end
end
