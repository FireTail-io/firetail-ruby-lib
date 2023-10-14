require "firetail/version"
require "rack"
require 'objspace'
require 'yaml'
require 'json'
require 'net/http'
require 'case_sensitive_headers' # a hack because firetail API headers is case-sensitive
require "async"
require 'digest/sha1'
require 'jwt'
require 'logger'
require 'background_tasks'
require 'committee'

# If the library detects rails, it will load rail's methods
if defined?(Rails)
  require 'action_dispatch'
  require 'action_pack'
  require 'railtie'
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
      @url                = config['url'] ? config['url'] : "https://api.logging.eu-west-1.prod.firetail.app" # default goes to europe
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
	#Firetail.logger.debug "res: #{resource}"
	# sample hash of the above resource:
	# example url: /posts/1/comments/2/options/3
	# hash = {:controller=>"options", :action=>"show", :comment_id => 3, :post_id=>"1", :id=>"1"}
	# take the resource hash above, get keys, conver to string, split "_" to get name at first index, together
	# with the key, to string and camelcase route id name and keys that only include "id", compact (remove nil) and add "s" to the key
	rmap = resource.map {|k,v| [k.to_s.split("_")[0], "{#{k.to_s.camelize(:lower)}}"] if k.to_s.include? "id" }
	.compact.map {|k,v| [k.to_s + "s", v] if k != "id" }

	if resource.key? :id 
	    # It will appear like: [["comments", "commentId"], ["posts", "postId"], ["id", "id"]], 
	    # but we want post to be first in order, so we reverse sort, and drop "id", which will be first in array
	    # after being sorted
	    reverse_resource = rmap.reverse.drop(1)
            resource_path = "/" + reverse_resource * "/" + "/" + resource[:controller] + "/" + "{id}"
	    # rebuild the resource path
	    # reverse_resource * "/" will loop the array and add "/"
	    #resource_path = "/" + reverse_resource * "/" + "/" + resource[:controller] + "/" + "{id}"
	    # end result is /posts/{postId}/comments/{commentId}/options/{id}
	else
	  if rmap.empty?
	    # if resoruce is empty, means we are at the first level of the url path, so no need extra paths
	    resource_path = "/" + rmap * "/" + resource[:controller]
	  else
	    # resource path from rmap above without the [:id] key (which is the last parameter in URL)
            # only used for index, create which does not have id
  	    resource_path = "/" + rmap * "/" + "/" + resource[:controller]
	  end
	end
      else
	resource_path = nil
      end

      #Firetail.logger.debug("resource path: #{resource_path}")
      # select those with "HTTP_" prefix, these are request headers
      request_headers = env.select {|key,val| key.start_with? 'HTTP_' } # find HTTP_ prefixes, these are requests only
	                .collect {|key, val| { "#{key.sub(/^HTTP_/, '')}": [val] }} # remove HTTP_ prefix
	                .reduce({}, :merge)  # reduce from [{key:val},{key2: val2}] to {key: val, key2: val2}

      # do the inverse of the above and get rack specific keys
      response_headers = env.select {|key,val| !key.start_with? 'HTTP_' } # only keys with no HTTP_ prefix
	                 .select {|key, val| key =~ /^[A-Z._]*$/} # select keys with uppercase and underline
                         .map {|key, val| { "#{key}": [val] }} # map to firetail api format
                         .reduce({}, :merge) # reduce from [{key:val},{key2: val2}] to {key: val, key2: val2}

      # get the jwt "sub" information
      if request_headers[:AUTHORIZATION]
        subject = self.jwt_decoder(request_headers[:AUTHORIZATION])
      else
	subject = nil
      end

      # default time spent in ruby is in seconds, so multiple by 1000 to ms
      time_spent_in_ms = time_spent * 1000
      #Firetail.logger.debug "request params: #{@request.params.inspect}"
      # add the request and response data 
      # to array of data for batching up
      @request.body.rewind
      if body.is_a? Array
        body = body[0]
      else
        body = body.body
      end
      @reqres.push({
	version: "1.0.0-alpha",
	dateCreated: Time.now.utc.to_i,
	executionTime: time_spent_in_ms,
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
	  body: body,
          headers: response_headers,
	},
	oauth: {
          subject: subject ? sha1_hash(subject) :  nil,
	}
      })
      @request.body.rewind
      #Firetail.logger.debug "Request: #{body}"

      # the time we calculate if request that is
      # buffered max is 120 seconds
      current_time = Time.now
      # duration in millseconds
      duration = (current_time - @init_time)

      #Firetail.logger.debug "size in bytes #{ObjectSpace.memsize_of(@request_data.to_s)}"
      #request data size in bytes
      request_data_size = ObjectSpace.memsize_of(@request_data)
      # It is difficult to calculate the object size in bytes, 
      # seems to not return the accurate values

      # This will send the data we need in batches of 5 requests or when it is more than 120 seconds
      # if there are more than 5 requests or is more than
      # 2 minutes, then send to backend - this is for testing
      if @reqres.length >= 5 || duration > 120
        #Firetail.logger.debug "request data #{@reqres}"
	# we parse the data hash into json-nl (json-newlines)
	payload = @reqres.map { |data| JSON.generate(data) }.join("\n")

	# send the data to backend API
	# This is an async task
	BackgroundTasks.http_task(@url,
			@network_timeout,
			@api_key,
			@number_of_tries,
		        payload)

	# reset back to the initial conditions
	payload = nil
	@reqres = []
	@init_time = Time.now
      end
    rescue Exception => exception
      Firetail.logger.error(exception.message)
    end

    def sha1_hash(value)
      encode_utf8 = value.encode(Encoding::UTF_8)
      hash = Digest::SHA1.hexdigest(encode_utf8)
      sha1 = "sha1: #{hash}"
    end

    def jwt_decoder(value)
      bearer_string = value
      # if authorization exists, get the value at index
      # split the values which has a space (example: "Bearer 123") and 
      # get the value at index 1
      token = bearer_string.split(" ")[1]
      # decode the token
      jwt_value = JWT.decode token, nil, false
      # get the subject value
      subject = jwt_value[0]["sub"]
      #Firetail.logger.debug("subject value: #{subject}")
    end
  end

  def self.logger
    @@logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @@logger = logger
  end

  # custom error message
  # https://blog.frankel.ch/structured-errors-http-apis/
  # https://www.rfc-editor.org/rfc/rfc7807
  class Committee::ValidationError
    def error_body
      {
        errors: [
          {
            type: "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['REQUEST_URI']}",
            title: id,
            detail: message,
            status: status
          }
        ]
      }
    end

    def render
      [
        status,
        { "Content-Type" => "application/json" },
        [JSON.generate(error_body)]
      ]
    end
  end
end
