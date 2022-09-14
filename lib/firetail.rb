require "firetail/version"
require "rack"
require 'objspace'
require 'yaml'
require 'json'

module Firetail
  class Error < StandardError; end

  class Run
    def initialize app
      @app = app
      @request_data ||= [] # request data in stored in array memory
      @init_time ||= Time.now # initialize time

      # Rails
      if defined?(Rails)
	default_location = File.join(Rails.root, "config/firetail.yml")
        config = YAML.load_file(default_location)
      else # other frameworks
        config = YAML.load_file("firetail.yml")
      end
      raise Error.new "Token is missing from configuration" if config['token'].nil?
      raise Error.new "API Key is missing from configuration"  if config['api_key'].nil?
      raise Error.new "URL is missing from configuration"  if config['url'].nil?

      @token              = config['token']
      @api_key            = config['api_key']
      @url                = config['url']
      @log_drains_timeout = config['log_drains_timeout'] ? config['log_drains_timeout'] : 5
      @network_timeout    = config['network_timeout'] ? config['network_timeout'] : 10
      @number_of_retries  = config['number_of_retries'] ? config['number_of_retries'] : 4
      @retry_timeout      = config['retry_timeout'] ? config['retry_timeout'] : 2
    end
 
    def call(env)
      request = Rack::Request.new(env)
      started_on = Time.now
      begin
        status, _, _ = response = @app.call(env)
        log(env, status, started_on, Time.now)
      rescue Exception => exception
        log(env, status, started_on, Time.now, exception)
        raise exception
      end

      response
    end

    def log(env, status, started_on, ended_on, exception = nil)
      url               = env['REQUEST_URI']
      path              = env['PATH_INFO']
      time_spent        = ended_on - started_on
      user_agent        = env['HTTP_USER_AGENT']
      ip                = defined?(Rails) ? env['action_dispatch.remote_ip'].calculate_ip : env['REMOTE_ADDR']
      request_method    = env['REQUEST_METHOD']
      http_host         = env['HTTP_HOST']
      http_version      = env['HTTP_VERSION']
      http_encoding     = env['HTTP_ACCEPT_ENCODING']
      http_accept       = env['HTTP_ACCEPT']
      query_string      = env['QUERY_STRING']
      request_path      = env['REQUEST_PATH']
      request_uri       = env['REQUEST_URI']
      server_software   = env['SERVER_SOFTWARE']
      server_port       = env['SERVER_PORT']
      gateway_interface = env['GATEWAY_INTERFACE']
      http_connection   = env['HTTP_CONNECTION']

      headers = env.select {|k,v| k.start_with? 'HTTP_'}
    .collect {|key, val| [key.sub(/^HTTP_/, ''), val]}
    .collect {|key, val| "#{key}: #{val}<br>"}
    .sort

      Firetail.logger.debug headers
 
      @request_data.push({
	version: "1.1",
	dateCreated: Time.now.utc.to_i,
	execution_time: time_spent,
	req: {
 	  httpProtocol: http_version,
	  headers: "test",
	  path: path,
	  method: request_method,
          oPath: "/test/path",
	  fPath: "/test/path",
	  args: "arguments",
	  ip: ip,
	  path_params: "params",
	  user_agent: user_agent
	},
	resp: {
          status_code: status,
	  content_len: 123,
	  content_enc: http_encoding,
	  body: "body",
          headers: "headers",
	  content_type: "application/json", 
	  error_type: exception&.class&.name,
          error_message: exception&.message
	}
      })

      # the time we calculate if request that is
      # buffered max is 120 seconds
      current_time = Time.now
      duration = current_time - @init_time
      #Firetail.logger.debug "size in MB #{ObjectSpace.memsize_of(@request_data)}"
      if @request_data.length > 5  || duration > 120
	# if there are 5 requests stored or is more than
	# 2 minutes, then 
	# send to backend
        send_to_backend(@request_data)
	# reset back the conditions
	@request_data = []
	@init_time = Time.now
      end
      Firetail.logger.debug @request_data.length
      #Firetail.logger.debug duration
    rescue Exception => exception
      Firetail.logger.error(exception.message)
    end

    def send_to_backend(datas)
      #Firetail.logger.debug datas.to_json
    end
  end

  def self.logger
    @@logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
