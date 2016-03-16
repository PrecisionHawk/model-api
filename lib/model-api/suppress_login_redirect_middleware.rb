module ModelApi
  class SuppressLoginRedirectMiddleware
    def initialize(app)
      @app = app
      @api_root = nil
    end

    def call(env)
      unless @api_roots.present?
        options = Rails.application.config.class.class_variable_get(:@@options)
        options ||= {}
        @api_roots = options[:api_middleware_root_paths] || ['api']
        @api_roots = [@api_roots] unless @api_roots.is_a?(Array)
        @api_roots = @api_roots.map { |path| path.starts_with?('/') ? path : "/#{path}" }
      end
      response = @app.call(env)
      if response[0].to_i == 302
        @api_roots.each do |path|
          next unless env['REQUEST_PATH'].to_s.starts_with?(path) &&
              (loc = response[1].find { |a| a[0] == 'Location' }).present? &&
              loc[1].to_s.ends_with?('/users/sign_in')

          # Mimic headers returned from API endpoint 404's for security reasons.
          response_headers = ModelApi::Utils.common_http_headers.merge(
              'Content-Type' => 'application/json',
              'X-Content-Type-Options' => 'nosniff',
              'X-Frame-Options' => 'SAMEORIGIN',
              'X-Request-Id' => SecureRandom.uuid,
              'X-UA-Compatible' => 'chrome=1',
              'X-XSS-Protection' => '1; mode=block'
          )
          return [404, response_headers, [ModelApi::Utils.not_found_response_body]]
        end
      end
      response
    end
  end
end
