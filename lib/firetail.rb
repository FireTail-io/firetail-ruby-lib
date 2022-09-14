require "firetail/version"
require "rack"
require 'objspace'
require 'yaml'
require 'json'
require 'net/http'

module Firetail
  class Error < StandardError; end

  class Run
    MAX_BULK_SIZE_IN_BYTES = 1 * 1024 * 1024  # 1 MB

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

      @token              = config['token']
      @api_key            = config['api_key']
      @url                = config['url'] ? config['url'] : "https://ingest.eu-west-1.dev.platform.pointsec.io/ingest/request" # default goes to dev
      @log_drains_timeout = config['log_drains_timeout'] ? config['log_drains_timeout'] : 5
      @network_timeout    = config['network_timeout'] ? config['network_timeout'] : 10
      @number_of_retries  = config['number_of_retries'] ? config['number_of_retries'] : 4
      @retry_timeout      = config['retry_timeout'] ? config['retry_timeout'] : 2
    end
 
    def call(env)
      request = Rack::Request.new(env)
      started_on = Time.now
      begin
        status, res_headers, body = response = @app.call(env)
        log(env, response, status, res_headers, body, started_on, Time.now)
      rescue Exception => exception
        log(env, response, status, res_headers, body, started_on, Time.now, exception)
        raise exception
      end

      response
    end

    def log(env,
            response,
            status,
            res_headers,
            body,
            started_on,
            ended_on,
            exception = nil)

      # request values
      req_url               = env['REQUEST_URI']
      req_path              = env['PATH_INFO']
      time_spent            = ended_on - started_on
      req_user_agent        = env['HTTP_USER_AGENT']
      req_ip                = defined?(Rails) ? env['action_dispatch.remote_ip'].calculate_ip : env['REMOTE_ADDR']
      req_method            = env['REQUEST_METHOD']
      req_http_host         = env['HTTP_HOST']
      req_http_version      = env['HTTP_VERSION']
      req_http_encoding     = env['HTTP_ACCEPT_ENCODING']
      req_http_accept       = env['HTTP_ACCEPT']
      req_query_string      = env['QUERY_STRING']
      req_path              = env['REQUEST_PATH']
      req_uri               = env['REQUEST_URI']
      req_server_software   = env['SERVER_SOFTWARE']
      req_server_port       = env['SERVER_PORT']
      req_gateway_interface = env['GATEWAY_INTERFACE']
      req_http_connection   = env['HTTP_CONNECTION']

      # get the request "HTTP_" headers
      req_headers = env.select {|k,v| k.start_with? 'HTTP_'}
       .collect {|key, val| [key.sub(/^HTTP_/, ''), val]}
       .collect {|key, val| "#{key}: #{val}<br>"}
       .sort

      # add to array of data objects for batching up
      @request_data.push({
	version: "1.1",
	dateCreated: Time.now.utc.to_i,
	execution_time: time_spent,
	req: {
 	  httpProtocol: req_http_version,
	  headers: req_headers.to_s, # headers array to string
	  path: req_path,
	  method: req_method,
          oPath: req_path,
	  fPath: req_path,
	  args: req_query_string,
	  ip: req_ip,
	  pathParams: req_query_string,
	  user_agent: req_user_agent # maybe not needed
	},
	resp: {
          status_code: status,
	  content_len: res_headers['Content-Length'] ? res_headers['Content-Length'] : "No content length",
	  content_enc: res_headers['Content-Encoding'] ? res_headers['Content-Encoding'] : "No content encoding",
	  body: body.body,
          headers: res_headers.to_s, # headers array to string
	  content_type: res_headers['Content-Type'], 
	  error_type: exception&.class&.name, # maybe not needed. Just in case
          error_message: exception&.message # maybe not need. Just in case
	}
      })

      # the time we calculate if request that is
      # buffered max is 120 seconds
      current_time = Time.now
      duration = current_time - @init_time

      #Firetail.logger.debug "size in bytes #{ObjectSpace.memsize_of(@request_data.to_s)}"
      #request data size in bytes
      #request_data_size = ObjectSpace.memsize_of(@request_data.to_s)
      # It is difficult to calculate the object size in bytes, seems to not return the accurate
      # values

      # This will send the data we need in batches of 5 requests or when it is more than 120 seconds
      # if there are more than 5 requests or is more than
      # 2 minutes, then send to backend - this is for testing
      if @request_data.length >= 5 || duration > 120
        #Firetail.logger.debug "request data #{@request_data.length}"
        # send data to backend
        send_to_backend(@request_data)

	# reset back the conditions
	@request_data = []
	@init_time = Time.now
      end
    rescue Exception => exception
      Firetail.logger.error(exception.message)
    end

    def send_to_backend(data)
      #Firetail.logger.debug datas.to_json
      # Parse it as URI
      uri = URI(@url)
      # Create a new request
      req = Net::HTTP::Post.new(uri, {
                                       'Content-Type': 'text/plain',
                                       'x-api-key': @api_key,
                                       'x-ps-api-key': @token
                               })
 
      req.body = "\n#{data.to_json}"
      # Send the request
      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end
      Firetail.logger.debug "response from firetail: #{res}"
    end
  end

  def self.logger
    @@logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
