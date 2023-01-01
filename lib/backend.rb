class Backend

  def self.send_now(payload, options)
    #Firetail.logger.debug "running backend"
    # Parse it as URI
    uri = URI(options[:url])

    # Create a new request
    http = Net::HTTP.new(uri.hostname, uri.port)
    #http.set_debug_output($stdout) # Use this is you want to see the data output
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.read_timeout = options[:network_timeout]

    begin
      # Create a new request
      req = CustomPost.new(uri.path,
      {
        'content-type': 'application/nd-json',
        'x-ft-api-key': options[:api_key]
      })

      req.body = payload
      # Send the request
      res = http.request(req)
      #Firetail.logger.debug "response from firetail: #{res}"
    rescue StandardError => e
      Firetail.logger.info "Firetail HTTP Request failed (#{e.message})"
    end
  end
end
