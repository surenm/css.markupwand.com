require "pp"

class Analyzer
  def self.get_dom_map(layers)
    bounding_rectangles = layers.collect do |layer|
      PhotoshopItem::Layer.new layer
    end
    
    bounding_rectangles.sort!
    
    # Find a grid map of enclosing rectangles
    # grid[i][j] is true if i-th rectangle encloses j-th rectangle
    layers_count = bounding_rectangles.size
    grid = Array.new(layers_count) { Array.new }
    for i in 0..(layers_count-1)
      for j in 0..(layers_count-1)
        first = bounding_rectangles[i]
        second = bounding_rectangles[j]
        if i != j and first.encloses? second
          grid[i].push j
        end
      end
    end
    
    # Build a tree adjancecy list out of the grid map
    # grid[i][j] is true if j-th rectangle is a direct child of i-th rectangle
    for i in 0..(layers_count-1)
      items_to_delete = []
      grid[i].each do |child|
        grid[child].each do |grand_child|
          items_to_delete.push grand_child
        end
      end
      
      items_to_delete.each do |item|
        grid[i].delete item
      end
    end

    for i in 0..(layers_count-1)
      bounding_rectangles[i].children = grid[i]
    end
    
    return bounding_rectangles
  end
  
  def self.get_root_layer(dom_map)
    root = nil
    dom_map.each do |layer|
      flag = true
      
      dom_map.each do |inner_layer|
        if not layer.encloses? inner_layer
          flag = false
          break
        end
      end
      
      if flag
        root = layer
        break
      end

    end    
    return root
  end
  
  def self.generate_html(dom_map)
    root_node = self.get_root_layer dom_map
    html = root_node.render_to_html dom_map, true
    return html
  end
  
  def self.analyze(psd_json_data)
    layers = JSON.parse psd_json_data, :symbolize_names => true
    dom_map = self.get_dom_map layers
    args = {}
    layers.each do |layer|

      if layer[:name][:value] == "mailgun"
        css = Converter::parse_text layer
        args[:color1] = css[:color]
      elsif layer[:name][:value] == "features"
        css = Converter::parse_box layer
        args[:color2] = css[:background]
      end
    end

    html = self.html 
    html_fptr = File.new '/tmp/result.html', 'w+'
    html_fptr.write html args
    html_fptr.close
    return true
  end
  
  def self.html(args = {})
    str = <<STR
    <!DOCTYPE html>
    <html lang="en"><head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <meta charset="utf-8">
        <title>Twitter Bootstrap</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="description" content="">
        <meta name="author" content="">

        <!-- Le styles -->
        <link href="./bootstrap/assets/css/bootstrap.css" rel="stylesheet">
        <style>
          body {
            background: #e1e1e3; 
            margin: 0 auto; 
          }

          ul {
            float: right;
          }

          ul li {
            float: left;
            list-style-type: none;
            padding: 0px 10px;
          }

          .header {
            margin-top: 20px;
            padding: 20px;
          }
        </style>

        <!-- Le HTML5 shim, for IE6-8 support of HTML5 elements -->
        <!--[if lt IE 9]>
          <script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
        <![endif]-->

        <!-- Le fav and touch icons -->
        <link rel="shortcut icon" href="./bootstrap/assets/ico/favicon.ico">
        <link rel="apple-touch-icon-precomposed" sizes="114x114" href="./bootstrap/assets/ico/apple-touch-icon-114-precomposed.png">
        <link rel="apple-touch-icon-precomposed" sizes="72x72" href="./bootstrap/assets/ico/apple-touch-icon-72-precomposed.png">
        <link rel="apple-touch-icon-precomposed" href="./bootstrap/assets/ico/apple-touch-icon-57-precomposed.png">
      </head>

      <body class="container"> 
        <div class="header" style="background: #ffffff">
          <div class="row" style="padding-bottom: 60px">
            <div class="span5" style="font-family: Signika; font-size: 50px; color: #{args[:color1]}; ">mailgun</div> 
            <div class="span6">
              <ul style="float:right">
                <li style="font-family: Tahoma; font-size: 15px; font-weight: bold; color: #2f85cb;">Login</li> 
                <li style="font-family: Tahoma; font-size: 15px; color: #2f85cb;">Blog</li>
                <li style="font-family: Tahoma; font-size: 15px; color: #2f85cb;">Pricing & plans</li> 
                <li style="font-family: Tahoma; font-size: 15px; color: #2f85cb;">Documentation</li> 
              </ul>
            </div>
          </div>
          <div style="clear:both"> </div>
          <div class="row">
            <div class="span4" style="padding-top: 30px">
              <div style="font-family: Tahoma; font-size: 28px; color: #4f5d65; ">Email for developers</div> 
              <div style="font-family: Tahoma; font-size: 16px; color: #4f5d65; padding-top: 30px; line-height: 30px ">Mailgun is a set of powerful APIs that allow you to send, receive, track and store email effortlessly.</div>
            </div>
            <div class="span7"> <img src='/tmp/mg-factory.png'> </div>      
          </div>
        </div>

        <div class="row" style="margin-top: 30px;">
          <div class="span7" style="min-height:275px; background: #{args[:color2]}; padding: 20px; line-height: 30px">
              <div style="font-family: Tahoma; font-size: 24px; color: #4f5d65; ">Optimized Deliverability</div> 
              <div class="row" style="padding-top: 20px">
                <div class="span3"> <img src='/tmp/mg-pistol.png'>  </div>
                <div class="span4">  

                  <div style="font-family: Tahoma; font-size: 16px; color: #000; ">Get emails delivered to inbox</div> 
                  <div style="font-family: Tahoma; font-size: 16px; color: #000; ">Clean IP addresses and whitelist registrations.</div>
                  <div style="font-family: Tahoma; font-size: 16px; color: #000; ">Automated bounce, unsubscribe and complaint handling</div>
                </div>

              </div>

          </div> 

          <div class="span4" style="min-height: 275px; background: #ffffff; padding: 20px; text-align: center">
            <div style="font-family: Tahoma; font-size: 24px; color: #000; line-height: 30px; ">Your App with Email in Minutes</div> 
            <br> <br> <br>
            <center>
            <div style="width: 200px; background: #3ba5e7; vertical-align: middle; color: #ffffff; padding: 10px 0px;">
              <div style="font-family: Tahoma; font-size: 24px; font-weight: bold; color: #ffffff; ">Sign Up Free</div>
            </div> 
            </center>
            <div style="font-family: Tahoma; font-size: 20px; color: #000; padding-top: 40px ">Our API makes integrating real  Email quick & easy.  </div>

          </div>

          </div>
          <div class="span4">
          </div>
        </div>
      </body>
    </html>
STR
    return str
  end
end