module ModelApi
  class SimpleMetadata
    class << self
      def process_metadata(type, obj, args)
        instance_var = :"@api_#{type}_metadata"
        metadata = obj.instance_variable_get(instance_var) || {}
        if args.present?
          if args.size == 1 && args[0].is_a?(Hash)
            metadata.merge!(args[0].symbolize_keys)
          elsif args.size == 1 && args[0].is_a?(Array)
            metadata.merge!(Hash[args[0].map { |key| [key.to_sym, {}] }])
          else
            metadata.merge!(Hash[args.map { |key| [key.to_sym, {}] }])
          end
          obj.instance_variable_set(instance_var, metadata)
        end
        metadata.dup
      end

      def merge_superclass_metadata(type, sc, metadata, opts = {})
        metadata_def_method = :"api_#{type}"
        if sc == ActiveRecord::Base || !sc.respond_to?(:"api_#{type}")
          metadata
        elsif (exclude_keys = opts[:exclude_keys]).is_a?(Array)
          (sc.send(metadata_def_method) || {}).reject { |k, _v| exclude_keys.include?(k) }
              .merge(metadata)
        else
          (sc.send(metadata_def_method) || {}).merge(metadata)
        end
      end
    end
  end
end
