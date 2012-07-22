module Shape
  class Path
    attr_accessor :path_points

    def initialize(path_point_list)
      self.path_points = path_point_list.collect do |path_point|
        Shape::PathPoint.new(path_point)
      end
      num_path_points = self.path_points.size
      self.path_points.each_with_index do |path_point, i|
        path_point.next = self.path_points[(i+1)%(num_path_points)]
        path_point.prev = self.path_points[(i+num_path_points-1)%(num_path_points)]
      end
    end
  end
end