require "rubygems"
require "multimap"
require "rest-client"
require "pp"

def mailgun_send 
  data = Multimap.new
  data[:from] = "Raj <raj@markupwand.com>"
  data[:'reply-to'] = "Hackers <hackers@markupwand.com>"
# Replace this for testing with required id and DO NOT commit
  data[:to] =  "test@markupwand.mailgun.org"
  data[:'h:Reply-To'] = "Hackers <hackers@markupwand.com>"
  data[:subject] = "Status of your upload at Markupwand"
  data[:text]  = File.open('failed.txt').read
  puts "Sending to test@markupwand.mailgun.org"
  begin
   response = RestClient.post "https://api:key-3k01b6wme8-hzvhyowno9r0gccep7e17"\
   "@api.mailgun.net/v2/markupwand.mailgun.org/messages", data
   puts response.body
  rescue Exception => e
   puts e.inspect
  end
end

mailgun_send
