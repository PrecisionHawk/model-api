module ModelApi
  class HashMetadata
    class << self
      def process_metadata(type, obj, args)
        type = type.to_sym
        instance_var = :"@api_#{type}_metadata"
        metadata = obj.instance_variable_get(instance_var) || {}
        if args.present?
          if args.size == 1 && args[0].is_a?(Hash)
            new_metadata = args[0].symbolize_keys
          elsif args.size == 1 && args[0].is_a?(Array)
            new_metadata = Hash[args[0].map { |key| [key.to_sym, {}] }]
          else
            new_metadata = Hash[args.map { |key| [key.to_sym, {}] }]
          end
          new_metadata.symbolize_keys.each do |key, item_metadata|
            if (existing_item_metadata = metadata[key]).is_a?(Hash)
              existing_item_metadata.merge!(item_metadata)
            else
              item_metadata[:key] = key
              metadata[key] = item_metadata
            end
          end
          obj.instance_variable_set(instance_var, metadata)
        end
        metadata.dup
      end

      def merge_superclass_metadata(type, sc, metadata)
        metadata_method = :"api_#{type}"
        return metadata if sc == ActiveRecord::Base || !sc.respond_to?(metadata_method)
        superclass_metadata = sc.send(metadata_method)
        merged_metadata = {}
        superclass_metadata.each do |item, item_metadata|
          merged_metadata[item] = item_metadata.dup
        end
        metadata.each do |key, item_metadata|
          if (existing_item_metadata = merged_metadata[key]).is_a?(Hash)
            existing_item_metadata.merge!(item_metadata)
          else
            merged_metadata[key] = item_metadata
          end
        end
        merged_metadata
      end
    end
  end
end
