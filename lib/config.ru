require 'committee'

puts "FUCK FUCK FUCK!"

SCHEMA_PATH = "config/schema.json"

# The request validator verifies that the required input parameters (and no
# unknown input parameters) are included with the request and that they are
# of the right types.
use Committee::Middleware::RequestValidation, schema_path: SCHEMA_PATH

# The response validator checks that responses from within the stack are
# compliant with the JSON schema. It's normally used for verification in
# tests, but here we can use it to check that our changes to the stub's
# responses are still compliant with our schema.
use Committee::Middleware::ResponseValidation, schema_path: SCHEMA_PATH