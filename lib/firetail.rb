require "firetail/version"
require "rack"
require 'objspace'
require 'yaml'
require 'json'
require 'net/http'
require 'case_sensitive_headers' # a hack because firetail API headers is case-sensitive
require "async"
if defined?(Rails)
  require 'rails'
  require 'action_pack'
end

module Firetail
  class Error < StandardError; end

  class Run
    MAX_BULK_SIZE_IN_BYTES = 1 * 1024 * 1024  # 1 MB

    def initialize app
      @app = app
      @reqres ||= [] # request data in stored in array memory
      @init_time ||= Time.now # initialize time
    end
 
    def call(env)
      # This block initialises the configuration and checks
      # sets the values for certain necessary configuration
      # If it is Rails
      if defined?(Rails)
        begin
          default_location = File.join(Rails.root, "config/firetail.yml")
          config = YAML.load_file(default_location)
        rescue Errno::ENOENT
          # error message if firetail is not installed
          puts ""
          puts "Please run 'rails generate firetail:install' first"
          puts ""
        end
      else # other frameworks
        config = YAML.load_file("firetail.yml")
      end

      raise Error.new "Please run 'rails generate firetail:install' first" if config.nil?
      raise Error.new "API Key is missing from firetail.yml configuration"  if config['api_key'].nil?

      @api_key            = config['api_key']
      @url                = config['url'] ? config['url'] : "https://api.logging.eu-west-1.sandbox.firetail.app/logs/bulk" # default goes to dev
      @log_drains_timeout = config['log_drains_timeout'] ? config['log_drains_timeout'] : 5
      @network_timeout    = config['network_timeout'] ? config['network_timeout'] : 10
      @number_of_retries  = config['number_of_retries'] ? config['number_of_retries'] : 4
      @retry_timeout      = config['retry_timeout'] ? config['retry_timeout'] : 2
      # End of configuration initialization

      # Gets the rack middleware requests
      @request = Rack::Request.new(env)
      started_on = Time.now
      begin
        status, client_headers, body = response = @app.call(env)
	log(env, status, body, started_on, Time.now)
      rescue Exception => exception
	      log(env, status, body, started_on, Time.now, exception)
        raise exception
      end

      response
    end

    def log(env,
	    status,
	    body,
            started_on,
	    ended_on,
            exception = nil)

      # request values
      time_spent                = ended_on - started_on
      request_ip                = defined?(Rails) ? env['action_dispatch.remote_ip'].calculate_ip : env['REMOTE_ADDR']
      request_method            = env['REQUEST_METHOD']
      request_path              = env['REQUEST_PATH']
      request_http_version      = env['HTTP_VERSION']
 
      # get the resource parameters if it is rails
      if defined?(Rails)
        resource = Rails.application.routes.recognize_path(request_path)
	# sample hash of the above resource:
	# example url: /posts/1/comments/2/options/3
	# hash = {:controller=>"options", :action=>"show", :comment_id => 3, :post_id=>"1", :id=>"1"}
	# take the resource hash above, get keys, split "_" to get name at first index, together
	# with a camelcase route id name and keys that only include "id", compact (remove nil) and add "s" to the key
	rmap = resource.map {|k,v| [k.to_s.split("_")[0], "{#{k.to_s.camelize(:lower)}}"] if k.to_s.include? "id" }
	.compact.map {|k,v| [k.to_s + "s", v] if k != "id" }

	# It will appear like: [["comments", "commentId"], ["posts", "postId"], ["id", "id"]], 
	# but we want post to be first in order, so we reverse sort, and drop "id", which will be first in array
	# after being sorted
	reverse_resource = rmap.reverse.drop(1)
	# rebuild the resource path
	# reverse_resource * "/" will loop the array and add "/"
	resource_path = "/" + reverse_resource * "/" + "/" + resource[:controller] + "/" + "{id}"
	# end result is /posts/{postId}/comments/{commentId}/options/{id}
      else
	resource_path = nil
      end

      Firetail.logger.debug("resource path: #{resource_path}")
      # select those with "HTTP_" prefix, these are request headers
      request_headers = env.select {|key,val| key.start_with? 'HTTP_' } # find HTTP_ prefixes, these are requests only
	                .collect {|key, val| { "#{key.sub(/^HTTP_/, '')}": [val] }} # remove HTTP_ prefix
	                .reduce({}, :merge)  # reduce from [{key:val},{key2: val2}] to {key: val, key2: val2}

      # do the inverse of the above and get rack specific keys
      response_headers = env.select {|key,val| !key.start_with? 'HTTP_' } # only keys with no HTTP_ prefix
	                 .select {|key, val| key =~ /^[A-Z._]*$/} # select keys with uppercase and underline
                         .map {|key, val| { "#{key}": [val] }} # map to firetail api format
                         .reduce({}, :merge) # reduce from [{key:val},{key2: val2}] to {key: val, key2: val2}

      #Firetail.logger.debug "request params: #{@request.params.inspect}"
      # add the request and response data 
      # to array of data for batching up
      @reqres.push({
	version: "1.0.0-alpha",
	dateCreated: Time.now.utc.to_i,
	executionTime: time_spent,
        request: {
 	  httpProtocol: request_http_version,
	  headers: request_headers, # headers must be in: headers: {"key": ["value"]}, array in object
	  method: request_method,
	  body: @request.body.read,
	  ip: request_ip,
	  resource: resource_path,
	  uri: @request.url
	},
	response: {
  	  statusCode: status,
	  body: body ? body.body : body[0],
          headers: response_headers,
	},
	oauth: {
          subject: "ThisIsAWorkInProgress",
	}
      })

      # the time we calculate if request that is
      # buffered max is 120 seconds
      current_time = Time.now
      # duration in millseconds
      duration = (current_time - @init_time) * 1000.0

      #Firetail.logger.debug "size in bytes #{ObjectSpace.memsize_of(@request_data.to_s)}"
      #request data size in bytes
      #request_data_size = ObjectSpace.memsize_of(@request_data.to_s)
      # It is difficult to calculate the object size in bytes, 
      # seems to not return the accurate values

      # This will send the data we need in batches of 5 requests or when it is more than 120 seconds
      # if there are more than 5 requests or is more than
      # 2 minutes, then send to backend - this is for testing
      if @reqres.length >= 5 || duration > 120
        #Firetail.logger.debug "request data #{@reqres}"
	# we parse the data hash into json-nl (json-newlines)
	payload = @reqres.map { |data| JSON.generate(data) }.join("\n")

	#puts "Our data: #{payload}"
	# send the data to backend API
	# This is an async task
	Async do |task|
          task.async do
            send_to_backend(payload)
          end
	end

	# reset back to the initial conditions
	payload = nil
	@reqres = []
	@init_time = Time.now
      end
    rescue Exception => exception
      Firetail.logger.error(exception.message)
    end

    def send_to_backend(payload)
      #Firetail.logger.debug datas.to_json
      # Parse it as URI
      uri = URI(@url)

      # Create a new request
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.set_debug_output($stdout)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      # Create a new request
      req = CustomPost.new(uri.path,
      {
        'content-type': 'application/nd-json',
        'x-ft-api-key': @api_key
      })

      req.body = payload
      # Send the request
      res = http.request(req)
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
