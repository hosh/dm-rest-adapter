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

    attr_reader :environment, :connection_options, :auth_token 
    class_inheritable_accessor :default_connection

    def initialize(options = {})
      @environment = options[:environment] || Rails.env
      @connection_options = ACCESS_CREDENTIALS[@environment].merge(options)
    end

    # Replace this with the URI library?
    def base_url
      @base_url ||= [
        (ssl? ? 'https://' : 'http://' ), 
        connection_options[:host],
        ':' + (connection_options[:port].to_s || (ssl? ? '443' : '80'))].join
    end

    def ssl?
      connection_options[:ssl]
    end

    def authenticate!
      true
    end

    # TODO: Add :payload that intelligently figure out GET or POST requests
    # TODO: Add auto-reauthenticate, probably have to put it in a thread-safe queue or something
    def request(method, path, options = {})
      authenticate! unless self.auth_token
      request = {
        :headers => { 
        'X-Auth-Token' => self.auth_token ,
        # TODO: Fix this hard-coded JSON mime-type
        'Content-Type' => Mime::JSON.to_s,}.merge(options[:headers] || {}), 
        :method  => method }

        # See O'Reilly The Ruby Programming Language, p 126
        case method
        when :post, :put
          request.merge!(:body => options[:payload])
        else
        end

        handle_response(Typhoeus::Request.run("#{self.base_url}/#{path}", request))
    end

    [:head, :get, :post, :put, :delete].each do |method|
      define_method("http_#{method}") do |path, options|
        self.request(method, path, options || {})
      end
    end

    # Convenience methods
    def self.set_default_connection(connection)
      Connection.default_connection = connection
    end

    def self.connection
      Connection.default_connection
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
