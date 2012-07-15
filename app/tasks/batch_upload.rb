require 'open-uri'
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
    markupwand_url = (target == 'prod') ? 'http://www.markupwand.com/upload_danger' : 'http://beta.markupwand.com/upload_danger' 

    files.each do |file|
      print "Uploading #{file} to filepicker"
      contents = open(file, "rb") {|io| io.read }
      data = RestClient.post url.to_s, {:fileUpload => File.new(file)}, {"Content-Type" => "application/octet-stream"}
      data_obj = JSON.parse(data)
      file_url = data_obj['data']['url']
      file_name = data_obj['data']['filename']

      puts "    done (#{url}"

      markupwand_post_data =  {
        :"design[file_url]" => file_url,
        :"design[name]" => file_name,
        :email  => email,
        :secret => secret
      }

      puts "Markupwand post data"

      markupwand_response_data = RestClient.post markupwand_url, markupwand_post_data

      puts markupwand_response_data

      break
    end
  end
end