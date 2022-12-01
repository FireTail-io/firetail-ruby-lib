require_relative '../lib/firetail'

RSpec.describe Firetail do
  before do
    @app = Firetail::Run.new(nil)
  end

  it "has a version number" do
    expect(Firetail::VERSION).not_to be nil
  end

#  it "does something useful" do
#    expect(false).to eq(true)
#  end
 
   context "call target web application GET request" do
     it "should have a correct request body" do
       env = {"HTTP_VERSION"=>"HTTP/1.1", "HTTP_HOST"=>"localhost:3000", "HTTP_CONNECTION"=>"keep-alive", "HTTP_PRAGMA"=>"no-cache", "HTTP_CACHE_CONTROL"=>"no-cache", "HTTP_SEC_CH_UA"=>"\"Google Chrome\";v=\"107\", \"Chromium\";v=\"107\", \"Not=A?Brand\";v=\"24\"", "HTTP_SEC_CH_UA_MOBILE"=>"?0", "HTTP_SEC_CH_UA_PLATFORM"=>"\"macOS\"", "HTTP_DNT"=>"1", "HTTP_UPGRADE_INSECURE_REQUESTS"=>"1", "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/107.0.0.0 Safari/537.36", "HTTP_ACCEPT"=>"text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9", "HTTP_SEC_FETCH_SITE"=>"none", "HTTP_SEC_FETCH_MODE"=>"navigate", "HTTP_SEC_FETCH_USER"=>"?1", "HTTP_SEC_FETCH_DEST"=>"document", "HTTP_ACCEPT_ENCODING"=>"gzip, deflate, br", "HTTP_ACCEPT_LANGUAGE"=>"en-GB,en;q=0.9,ms-MY;q=0.8,ms;q=0.7,en-US;q=0.6,zh-CN;q=0.5,zh;q=0.4", "HTTP_COOKIE"=>"_ga=GA1.1.1113729272.1635246362; intercom-id-ordh8mos=c5cc5a30-13b5-4869-a44f-ac645129e1c1; _ga_WT0V13SBWL=GS1.1.1662219522.5.1.1662220215.0.0.0; csrftoken=gk9Px9m28gi6XuIGBQaDaRgN9W19TadFhCvHPSwC3MYGH1QvnAK7EPpIidKVHLNa; _gcl_au=1.1.642239831.1666221572"}
       response = @app.call(env)
       body = response
       expect(body).to eq "abc"
     end
   end
end
