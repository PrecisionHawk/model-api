module Api
  module V1
    class GenresController < BaseController
      class << self

        # Default model class to use for API endpoints in this controller
        def model_class
          Genre
        end

        # Default options for model-api helper methods used to process requests to endpoints
        def base_api_options
          super.merge(id_param: :genre_id)
        end
      end

      # OpenAPI metadata describing the collective set of endpoints defined in this controller
      open_api_controller \
            tag: {
          name: 'Genres',
          description: 'Comprehensive list of available genres'
      }

      # GET /api/v1/genres endpoint OpenAPI doc metadata and implementation
      add_open_api_action :index, :index, base_api_options.merge(
          description: 'Retrieve list of available genres')

      def index
        render_collection collection_query, base_api_options
      end

      # GET /api/v1/genres/:genre_id endpoint OpenAPI doc metadata and implementation
      add_open_api_action :show, :show, base_api_options.merge(
          description: 'Retrieve details for a specific genre')

      def show
        render_object object_query.first, base_api_options
      end

      # POST /api/v1/genres endpoint OpenAPI doc metadata and implementation
      add_open_api_action :create, :create, base_api_options.merge(
          description: 'Create a new genre')

      def create
        do_create base_api_options
      end

      # PATCH/PUT api/v1/genres/:genre_id endpoint OpenAPI doc metadata and implementation
      add_open_api_action :update, :update, base_api_options.merge(
          description: 'Update an existing genre')

      def update
        do_update object_query, base_api_options
      end

      # DELETE /api/v1/genres/:genre_id endpoint OpenAPI doc metadata and implementation
      add_open_api_action :destroy, :destroy, base_api_options.merge(
          description: 'Delete an existing genre')

      def destroy
        do_destroy object_query, base_api_options
      end

      def object_query(opts = {})
        super(opts.merge(not_found_error: true))
      end
    end
  end
end
