require_relative '../lib/firetail'
require 'spec_helper'
require 'digest'

RSpec.describe Firetail do
  before do
    @app = Firetail::Run.new(nil)
  end

  let(:app) { Firetail::Run.new }
  subject { described_class.new(app) }

  it "has a version number" do
    expect(Firetail::VERSION).not_to be nil
  end
  
  context "basic configuration settings" do

    it "should be able to load configuration file with api key" do
      firetail_config = <<-EOF
        api_key: abc123
      EOF
      firetail_yaml = YAML.load(firetail_config)
      firetail_filepath = "firetail.yml"
      expect(allow(YAML).to receive(:load_file).with(firetail_filepath).and_return(firetail_yaml))
    end

    it "should give an error when configuration file is empty" do
      firetail_config = <<-EOF
      EOF
      firetail_yaml = YAML.load(firetail_config)
      firetail_filepath = "missing_config.yml"
      allow(YAML).to receive(:load_file).with(firetail_filepath).and_return(firetail_yaml)
      expect { File.open("firetail.yml") }.to raise_error(Errno::ENOENT)
    end

    it "should be able to load json schema" do
      json_schema = <<-EOF
	{
          "api_key": "abc123"
	}
      EOF
      schema = JSON.load(json_schema)
      schema_filepath = "schema.json"
      expect(allow(JSON).to receive(:load_file).with(schema_filepath).and_return(schema))
    end

    it "should give an error when schema.json is empty" do
      json_schema = <<-EOF
      EOF

      schema = JSON.load(json_schema)
      schema_filepath = "missing_schema.json"
      allow(JSON).to receive(:load_file).with(schema_filepath).and_return(schema)
      expect { File.open("schema.json") }.to raise_error(Errno::ENOENT)
    end
  end

  context "request to backend" do
    it "should have a correct request body" do
      url = "https://api.logging.eu-west-1.prod.firetail.app/logs/bulk"
      api_key = "Abc123"
      payload = {"HTTP_ACCEPT"=>"text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", "HTTP_ACCEPT_ENCODING"=>"gzip, deflate, br", "HTTP_ACCEPT_LANGUAGE"=>"en-GB,en;q=0.9,ms-MY;q=0.8,ms;q=0.7,en-US;q=0.6,zh-CN;q=0.5,zh;q=0.4", "HTTP_CACHE_CONTROL"=>"no-cache", "HTTP_CONNECTION"=>"keep-alive", "HTTP_COOKIE"=>"_ga=GA1.1.1113729272.1635246362; intercom-id-ordh8mos=c5cc5a30-13b5-4869-a44f-ac645129e1c1; _ga_WT0V13SBWL=GS1.1.1662219522.5.1.1662220215.0.0.0; csrftoken=gk9Px9m28gi6XuIGBQaDaRgN9W19TadFhCvHPSwC3MYGH1QvnAK7EPpIidKVHLNa; _gcl_au=1.1.642239831.1666221572", "HTTP_DNT"=>"1", "HTTP_HOST"=>"localhost:3000", "HTTP_PRAGMA"=>"no-cache", "HTTP_SEC_CH_UA"=>"\"Google Chrome\";v=\"107\", \"Chromium\";v=\"107\", \"Not=A?Brand\";v=\"24\"", "HTTP_SEC_CH_UA_MOBILE"=>"?0", "HTTP_SEC_CH_UA_PLATFORM"=>"\"macOS\"", "HTTP_SEC_FETCH_DEST"=>"document", "HTTP_SEC_FETCH_MODE"=>"navigate", "HTTP_SEC_FETCH_SITE"=>"none", "HTTP_SEC_FETCH_USER"=>"?1", "HTTP_UPGRADE_INSECURE_REQUESTS"=>"1", "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36", "HTTP_VERSION"=>"HTTP/1.1"}.to_json
      headers = {
      	  'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
	  'Content-Type'=>'application/nd-json',
	  'User-Agent'=>'Ruby',
	  'X-Ft-Api-Key'=> api_key
      }

      stub_request(:post, url)
      .with(body: payload,
            headers: headers)
      .to_return(status: 200, body: {"status":"success"}.to_json, headers: {})

      options = {url: url, api_key: "Abc123"}
      request = Backend.send_now(payload, options)
    end

    it "should not be successful without the correct request body" do
      url = "https://api.logging.eu-west-1.prod.firetail.app/logs/bulk"
      api_key = "Abc123"
      payload = {abc: 123}.to_json
      headers = {
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/nd-json',
          'User-Agent'=>'Ruby',
          'X-Ft-Api-Key'=> api_key
      }

      stub_request(:post, url)
      .with(body: payload,
	    headers: headers)
      .to_return(status: 400, body: {status: "failed"}.to_json)

      options = {url: url, api_key: "Abc123"}
      request = Backend.send_now(payload, options)
    end
  end

  context "backend logic" do

    it "should be able to correctly run backoff strategy for failure from retries" do
      url = "https://api.logging.eu-west-1.prod.firetail.app/logs/bulk"
      api_key = "Abc123"
      payload = {abc: 123}.to_json
      headers = {
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/nd-json',
          'User-Agent'=>'Ruby',
          'X-Ft-Api-Key'=> api_key
      }
      timeout = 5
      retries = 1

      stub_request(:post, url)
      .with(body: payload,
            headers: headers)
      .to_raise(StandardError)

      BackgroundTasks.http_task(url,
                                timeout,
                                api_key,
                                retries,
            	                payload)
    end

    it "should be able to correctly run backoff strategy for failure from timeouts" do
      url = "https://api.logging.eu-west-1.prod.firetail.app/logs/bulk"
      api_key = "Abc123"
      payload = {abc: 123}.to_json
      headers = {
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/nd-json',
          'User-Agent'=>'Ruby',
          'X-Ft-Api-Key'=> api_key
      }
      timeout = 5
      retries = 1

      stub_request(:post, url)
      .with(body: payload,
            headers: headers)
      .to_timeout
      .then
      .to_raise(StandardError)

      BackgroundTasks.http_task(url,
                                timeout,
                                api_key,
                                retries,
                                payload)
    end

    it "should give an error for invalid or malformed JWT token" do
      expect do
        @app.jwt_decoder("Bearer abc")
      end.to raise_error JWT::DecodeError
    end

    it "should be able to decode a valid JWT token" do
      expect(@app.jwt_decoder("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IlphaWhhbiBGbGl0bmV0aWNzIiwiaWF0IjoxNTE2MjM5MDIyfQ.EhMjmGt76Mf2VMO10nL5LzrRnmLA_pbpgRH3iv-aU4Q"))
      .to eq("1234567890")
    end
  end
end
