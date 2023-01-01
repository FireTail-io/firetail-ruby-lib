require 'committee'
require 'rails'

class Error < StandardError; end

class Railtie < Rails::Railtie

  initializer "commitee.insert_middleware" do |app|
    schema_path = File.join(Rails.root, "config/schema.json")
    app.config.middleware.use Committee::Middleware::RequestValidation,
      schema_path: schema_path,
      coerce_date_times: true,
      params_key: 'action_dispatch.request.request_parameters',
      query_hash_key: 'action_dispatch.request.query_parameters'

    app.config.middleware.use Committee::Middleware::ResponseValidation, schema_path: schema_path
  end
end
