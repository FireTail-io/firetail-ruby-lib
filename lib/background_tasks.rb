require 'backend'

class BackgroundTasks

    # send the data to backend API
    # This is an async task
    def self.http_task(url,
                       timeout,
                       api_key,
                       retries,
                       payload)
      Async do |task|
        task.async do
          # below code includes exponential backoff algorithm
          retries = 0
          begin
            # send to firetail backend
            # values to use for backend object
            options = {"url": url,
                       "network_timeout": timeout,
                       "api_key": api_key}

            request = Backend.send_now(payload, options)
            Firetail.logger.info "Successfully sent to Firetail"
          rescue Net::HTTPError => e
            # if request response code is an error
            # then try sending.
            # @number_of_retries is configurable in .yaml file

            if retries <= retries
              retries += 1
              max_sleep_seconds = Float(2 ** retries)
              sleep rand(0..max_sleep_seconds)
              retry
            else
              raise "Giving up on the server after #{retries} retries. Got error: #{e.message}"
            end
          end
        end
      end
    end

end
