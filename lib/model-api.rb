require 'model-api/base_controller.rb'
require 'model-api/bypass_parse_middleware.rb'
require 'model-api/hash_metadata.rb'
require 'model-api/model.rb'
require 'model-api/not_found_exception.rb'
require 'model-api/open_api_extensions.rb'
require 'model-api/renderer.rb'
require 'model-api/simple_metadata.rb'
require 'model-api/suppress_login_redirect_middleware.rb'
require 'model-api/unauthorized_exception.rb'
require 'model-api/utils.rb'

module ModelApi
  class << self
    def configure(metadata = nil, &block)
      return unless metadata.is_a?(Hash) || block_given?
      global_metadata = @model_api_global_metadata || default_global_metadata
      if metadata.is_a?(Hash)
        global_metadata = OpenApi::Utils.merge_hash(global_metadata, metadata)
      end
      if block_given?
        config = OpenStruct.new(global_metadata)
        block.call(config)
        global_metadata = OpenApi::Utils.merge_hash(global_metadata, config.to_h.symbolize_keys)
      end
      @model_api_global_metadata = global_metadata
    end

    def global_metadata
      @model_api_global_metadata || default_global_metadata
    end

    def default_global_metadata
      {
      }
    end
  end
end
