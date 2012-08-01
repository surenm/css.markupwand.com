require "rubygems"
require "multimap"
require "rest-client"
require "pp"

class Mailer
  # Template would be absolute path of the .txt file /Users/alagu/Code/Goyaka/web/<somemore>/campaign.txt
  def self.mailgun_send(template)
    data = Multimap.new
    data[:from] = "Raj Natarajan<raj@markupwand.com>"
    data[:'reply-to'] = "Raj Natarajan<support@markupwand.com>"
  # Replace this for testing with required id and DO NOT commit
    data[:to] =  "users_with_morethan_1_design@markupwand.mailgun.org"
    data[:'h:Reply-To'] = "Raj Natarajan<support@markupwand.com>"
    data[:subject] = "Could we have a chat about Markupwand?"
    data[:text]  = File.open(template).read
    puts "Sending to test@markupwand.mailgun.org"
    begin
     response = RestClient.post "https://api:key-3k01b6wme8-hzvhyowno9r0gccep7e17"\
     "@api.mailgun.net/v2/markupwand.mailgun.org/messages", data
     puts response.body
    rescue Exception => e
     puts e.inspect
    end
  end
end