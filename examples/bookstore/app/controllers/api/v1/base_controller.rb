module Api
  module V1
    class BaseController < ActionController::Base
      include ModelApi::BaseController
      include ModelApi::OpenApiExtensions
      include OpenApi::Controller

      # OpenAPI documentation metadata shared by all endpoints, including common query string
      #  parameters, HTTP headers, and HTTP response codes.
      open_api_controller \
          query_string: {
          access_token: {
              type: :string,
              description: 'OAuth 2 access token query parameter',
              required: false
          }
      },
          headers: {
              'Authorization' => {
                  type: :string,
                  description: 'Authorization header (format: "Bearer &lt;current user id&gt;")',
                  required: false
              }
          },
          responses: {
              200 => { description: 'Successful' },
              400 => { description: 'Not found' },
              401 => { description: 'Invalid request' },
              403 => { description: 'Not authorized (typically missing / invalid access token)' }
          }

      # OpenAPI documentation for common API endpoint path parameters
      open_api_path_param :book_id, description: 'Book identifier'

      # HATEOAS links common to all responses (e.g. a common terms-of-service link)
      def common_response_links(_opts = {})
        { 'terms-of-service' => URI(url_for(controller: '/home', action: :terms_of_service)) }
      end

      def current_user
        return @current_user if instance_variable_defined?(:@current_user)
        if request.authorization.try(:starts_with?, 'Bearer ')
          @current_user = User.where(id: request.authorization[7..-1].to_i).first
        else
          @current_user = nil
        end
      end

      def admin_user?(_opts = {})
        return @admin_user if instance_variable_defined?(:@admin_user)
        @admin_user = @current_user.try(:admin?)
      end

      def admin_content?(_opts = {})
        return @admin_content if instance_variable_defined?(:@admin_content)
        @admin_content = params.include?(:admin) && params[:admin].to_i != 0
      end
    end
  end
end
