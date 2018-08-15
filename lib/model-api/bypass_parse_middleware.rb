module ModelApi
  class BypassParseMiddleware
    def initialize(app)
      @app = app
      @api_roots = nil
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      unless @api_roots.present?
        options = Rails.application.config.class.class_variable_get(:@@options)
        options ||= {}
        @api_roots = options[:api_middleware_root_paths] || ['api']
        @api_roots = [@api_roots] unless @api_roots.is_a?(Array)
        @api_roots = @api_roots.map { |path| path.starts_with?('/') ? path : "/#{path}" }
      end
      @api_roots.each do |path|
        next unless env['REQUEST_PATH'].to_s.starts_with?(path)
        api_format = nil
        if request.content_type.to_s.downcase.ends_with?('json')
          api_format = :json
        elsif request.content_type.to_s.downcase.ends_with?('xml')
          api_format = :xml
        end
        #env['action_dispatch.request.content_type'] = 'application/x-api'
        env['API_CONTENT_TYPE'] = api_format
        break
      end
      @app.call(env)
    end
  end
end
