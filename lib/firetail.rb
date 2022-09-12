require "firetail/version"
require "rack"

module Firetail
  class Error < StandardError; end

  class RequestLogger
    def initialize app
      @app = app
      @request_data ||= [] # request data in stored in array memory
      @init_time ||= Time.now # initialize time
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
      url = env['REQUEST_URI']
      path = env['PATH_INFO']
      time_spent = ended_on - started_on
      user_agent = env['HTTP_USER_AGENT']
      ip = defined?(Rails) ? env['action_dispatch.remote_ip'].calculate_ip : ""
      request_method = env['REQUEST_METHOD']
      http_host = env['HTTP_HOST']
 
      #request_data = []
      @request_data.push({
        status: status,
        url: url,
        path: path,
        time_spent: time_spent,
        user_agent: user_agent,
        ip: ip,
        request_method: request_method,
        http_host: http_host,
        error_type: exception&.class&.name,
        error_message: exception&.message
      })

      # the time we calculate if request that is
      # buffered max is 120 seconds
      current_time = Time.now
      duration = current_time - @init_time
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
      Firetail.logger.debug duration
    rescue Exception => exception
      Firetail.logger.error(exception.message)
    end

    def send_to_backend(datas)
      datas.each do |data|
        # TODO 
	Firetail.logger.debug datas
      end
    end
  end

  def self.logger
    @@logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
  end

  def self.logger=(logger)
    @@logger = logger
  end
end
