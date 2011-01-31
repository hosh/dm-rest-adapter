require 'typhoeus'

begin
  require 'active_support/inflector'
rescue LoadError
  require 'extlib/inflection'
  module ActiveSupport
    Inflector = Extlib::Inflection unless defined?(Inflector)
  end
end

module DataMapperRest
  # Extracted from private code
  class Connection
    attr_accessor :connection_options

    def initialize(_connection_options)
      self.connection_options = _connection_options
    end

    def site_uri
      @site_uri ||= connection_options[:site_uri]
    end

    # TODO: Add auto-reauthenticate, probably have to put it in a thread-safe queue or something
    def request(method, path, options = {})
      request = {
        :headers => { 
          # TODO: Fix this hard-coded JSON mime-type
          'Accept' => 'application/json',
          'Content-Type' => 'application/json'}.merge(options[:headers] || {}), 
        :method  => method }
      request.merge!(:params => options[:params]) if options[:params]

      # See O'Reilly The Ruby Programming Language, p 126
      case method
      when :post, :put, :delete
        request.merge!(:body => options[:payload])
      else
      end
      #{ :site_uri => site_uri, :path => path, :request_uri => (site_uri + path).to_s, :request => request, 
      #  :stubs => Typhoeus::Hydra.hydra.instance_variable_get(:@stubs) }.tap { |h| ap h }

      handle_response(Typhoeus::Request.run((site_uri + path).to_s, request))
    end

    [:head, :get, :post, :put, :delete].each do |method|
      define_method("http_#{method}") do |*args|
        path = args.shift
        self.request(method, path, *args)
      end
    end

    # Handles response and error codes from remote service.
    def handle_response(response)
      case response.code.to_i
      when 301,302
        raise(Redirection.new(response))
      when 200...400
        response
      when 400
        raise(BadRequest.new(response))
      when 401
        raise(UnauthorizedAccess.new(response))
      when 403
        raise(ForbiddenAccess.new(response))
      when 404
        raise(ResourceNotFound.new(response))
      when 405
        raise(MethodNotAllowed.new(response))
      when 409
        raise(ResourceConflict.new(response))
      when 422
        raise(ResourceInvalid.new(response))
      when 401...500
        raise(ClientError.new(response))
      when 500...600
        raise(ServerError.new(response))
      else
        raise(ConnectionError.new(response, "Unknown response code: #{response.code}"))
      end
    end

  end
end
