require 'committee'
require 'rails'

class Error < StandardError; end

class Railtie < Rails::Railtie

    initializer "commitee.insert_middleware" do |app|
      begin
        schema_path = File.join(Rails.root, "config/schema.json")

	# check if schema file exists in config/
	if File.exists?(schema_path)
          app.config.middleware.use Committee::Middleware::RequestValidation,
            schema_path: schema_path,
            coerce_date_times: true,
            params_key: 'action_dispatch.request.request_parameters',
            query_hash_key: 'action_dispatch.request.query_parameters'

          app.config.middleware.use Committee::Middleware::ResponseValidation, schema_path: schema_path
	else 
          puts "Need schema.json in \"config/\" directory"
          puts "Try re-running \"rails g firetail:install\" again"
        end
      rescue
        puts "Need schema.json in \"config/\" directory"
	puts "Try re-running \"rails g firetail:install\" again"
      end
    end
end
