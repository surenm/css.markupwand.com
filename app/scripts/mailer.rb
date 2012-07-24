require "rubygems"
require "multimap"
require "rest-client"
require "pp"

def mailgun_send 
  data = Multimap.new
  data[:from] = "Suren <suren@markupwand.com>"
  data[:'reply-to'] = "Hackers <hackers@markupwand.com>"
# Replace this with required id and DO NOT commit
  data[:to] =  "test@markupwand.mailgun.org"
  data[:subject] = "Hello from Markupwand"
  data[:text]  = File.open('template1.txt').read
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
