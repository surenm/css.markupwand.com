class SifBuilder
  def self.build_from_extracted_file(design, file_path)
    fptr = File.read file_path
    psd_data = JSON.parse fptr, :symbolize_names => true, :max_nesting => false
    SifBuilder.build_from_psd_data design, psd_data
  end
  
  def self.build_from_psd_data(design, psd_data)
    design_metadata = {
      :id     => design.id,
      :name   => design.name,
      :height => psd_data[:header][:height],
      :width  => psd_data[:header][:width],
      :mode   => psd_data[:header][:modename],
    }
    
    user_metadata = {
      :user => design.user.email
    }
    
    raw_layers = psd_data[:layerMask][:layers]
    layers = raw_layers.collect do |raw_layer|
      SifBuilder.build_layer_from_psd_data design, raw_layer
    end
    
    sif_data = {
      :header => { :design_metadata => design_metadata, :user_metadata => user_metadata },
      :layers => layers,
      :grids => nil,
    }

    Sif::write(design, sif_data)
  end
  
  def self.build_layer_from_psd_data(design, raw_layer_data)
    raw_bounds = raw_layer_data[:bounds]
    bounds     = BoundingBox.new raw_bounds[:top], raw_bounds[:left], raw_bounds[:bottom], raw_bounds[:right]

    layer = {
      :design    => design,
      :name      => raw_layer_data[:name],
      :type      => raw_layer_data[:type],
      :uid       => raw_layer_data[:uid],
      :zindex    => raw_layer_data[:zindex],
      :bounds    => bounds.attribute_data,
      :opacity   => raw_layer_data[:opacity],
      :height    => raw_layer_data[:height],
      :width     => raw_layer_data[:width],
      :text      => raw_layer_data[:text],
      :shape     => raw_layer_data[:shape],
      :styles    => raw_layer_data[:styles],
      :image_name => raw_layer_data[:image_name]
    }
  end
end