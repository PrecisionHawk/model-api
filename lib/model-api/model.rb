module ModelApi
  module Model
    module ClassMethods
      def api_model(*args)
        metadata = ModelApi::SimpleMetadata.process_metadata(:model, self, args,
            post_process: (lambda do |metadata|
              if args.present? && metadata.include?(:id_attributes)
                metadata[:id_attributes] = metadata[:id_attributes]
                    .map { |v| (v.is_a?(Array) ? v.flatten : [v]).map(&:to_sym) }
              end
            end))
        ModelApi::SimpleMetadata.merge_superclass_metadata(:model, superclass, metadata,
            exclude_keys: [:alias])
      end

      def api_model_post_process_metadata(klass, metadata)

      end

      def api_attributes(*args)
        metadata = ModelApi::HashMetadata.process_metadata(:attributes, self, args)
        metadata = ModelApi::HashMetadata.merge_superclass_metadata(:attributes, superclass, metadata)
        if args.present?
          id_attrs = []
          metadata.each { |attr, attr_metadata| id_attrs << attr if attr_metadata[:id] }
          if id_attrs.present?
            id_attr_sets = id_attrs.map { |v| (v.is_a?(Array) ? v.flatten : [v]).map(&:to_sym) }
            existing_id_attr_sets = (api_model[:id_attributes] || [])
                .map { |v| (v.is_a?(Array) ? v.flatten : [v]).map(&:to_sym) }
            if (id_attr_sets - existing_id_attr_sets).present?
              api_model id_attributes: (id_attr_sets - existing_id_attr_sets).uniq
            end
          end
        end
        if self < ActiveRecord::Base && (args.present? ||
            !self.instance_variable_get(:@api_attrs_characterized))
          metadata.each do |attr, attr_metadata|
            if (assoc = self.reflect_on_association(attr)).present?
              attr_metadata[:type] = :association
              attr_metadata[:association] = assoc
            else
              attr_metadata[:type] = :attribute
            end
          end
          self.instance_variable_set(:@api_attrs_characterized, true)
        end
        metadata
      end

      def api_links(*args)
        metadata = ModelApi::HashMetadata.process_metadata(:links, self, args)
        ModelApi::HashMetadata.merge_superclass_metadata(:links, superclass, metadata)
      end
    end

    class << self
      def included(base)
        base.extend(ClassMethods)
      end
    end
  end
end
