require 'open-uri'
#
# Usage:
# open up rails console in your dev machine
#
# [1] pry(main)> BatchUpload.upload('/Users/alagu/Dropbox/markupwand/psd_sources/Test cases/unit tests/font-text','allagappan@gmail.com')
#
# pass second param as 'beta' to upload to beta machine
# 
class BatchUpload
  def self.upload(folder, email, target = 'prod')
    upload_data = {:mimetypes => ["*/*"],
     :app => {
        :apiKey => "ZOFGmR9AQeWSYvsehp6W"
      },
      :id => (Time.now.to_f * 1000).to_i.to_s
    }

    files = Dir.glob(folder + "/*.psd")
    url = URI.parse "https://www.filepicker.io/api/path/computer/"
    url.query = "js_session=" + URI.encode(upload_data.to_json)
    secret = '02b0c8ad8a141b04693e923b3d56a918'
    markupwand_url = (target == 'prod') ? 'http://www.markupwand.com/design/upload_danger' : 'http://beta.markupwand.com/design/upload_danger' 
    puts markupwand_url

    files.each do |file|
      contents = open(file, "rb") {|io| io.read }
      data = RestClient.post url.to_s, {:fileUpload => File.new(file)}, {"Content-Type" => "application/octet-stream"}
      data_obj = JSON.parse(data)
      file_url = data_obj['data']['url']
      file_name = data_obj['data']['filename']

      puts "Uploaded #{file_name} to filepicker"

      markupwand_post_data =  {
        :"design[file_url]" => file_url,
        :"design[name]" => file_name,
        :email  => email,
        :secret => secret
      }

      puts "Uploading to markupwand"

      markupwand_response_data = RestClient.post markupwand_url, markupwand_post_data

      puts markupwand_response_data
    end
  end
end