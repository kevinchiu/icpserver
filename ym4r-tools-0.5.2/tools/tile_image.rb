require 'RMagick'
require 'optparse'
require 'ostruct'

#Structure that contains configuration data for the Image tiler
class TileParam < Struct.new(:ul_corner,:zoom,:padding,:scale)
end

class Point < Struct.new(:x,:y)
  def -(point)
    Point.new(x - point.x , y - point.y)
  end
  def +(point)
    Point.new(x + point.x , y + point.y)
  end
  def *(scale)
    Point.new(scale * x,scale * y)
  end
  def to_s
    "Point #{x} #{y}"
  end
end

OptionParser.accept(Range, /(\d+)\.\.(\d+)/) do |range,start,finish|
  Range.new(start.to_i,finish.to_i)
end

OptionParser.accept(TileParam, /(\d+),(\d+),(\d+),(\d+),(\d+),([\d.]+)/) do |setting,l_corner, u_corner, zoom, padding_x, padding_y, scale|
  TileParam.new(Point.new(l_corner.to_i,u_corner.to_i),zoom.to_i,Point.new(padding_x.to_i,padding_y.to_i),scale.to_f)
end

OptionParser.accept(Magick::Pixel,/(\d+),(\d+),(\d+),(\d+)/) do |pixel, r,g,b,a|
  Magick::Pixel.new(r.to_f,g.to_f,b.to_f,a.to_f)
end

options = OpenStruct.new
#set some defaults
options.format = "png"
options.zoom_range = 0..17
options.bg_color = Magick::Pixel.new(255,255,255,255)

opts = OptionParser.new do |opts|
  opts.banner = "Image Tiler for Google Maps\nUsage: tile_image.rb [options]\nExample: tile_image.rb -o ./tiles -z 11..12 -p 602,768,11,78,112,1.91827348 ./input_files/*.jpg"
  opts.separator "" 
  opts.on("-o","--output OUTPUT_DIR","Directory where the tiles will be created") do |dir| 
    options.output_dir = dir
  end
  opts.on("-f","--format FORMAT","Image format in which to get the file (gif, jpeg, png...). Is png by default") do |format|
    options.format = format
  end
  opts.on("-z","--zooms ZOOM_RANGE",Range,"Range of zoom values at which the tiles must be generated. Is 0..17 by default") do |range|
    options.zoom_range = range
  end
  opts.on("-p","--tile-param PARAM",TileParam,"Corner coordinates, furthest zoom level, padding in X and Y, scale") do |tp|
    options.tile_param = tp
  end
  opts.on("-b","--background COLOR",Magick::Pixel,"Background color components. Is fully transparent par default") do |bg|
    options.bg_color = bg
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

opts.parse!(ARGV)

#test the presence of all the options and exit with an error message
error = []
error << "No output directory defined (-o,--output)" if options.output_dir.nil?
error << "No tile parameter defined (-p,--tile-param)" if options.tile_param.nil?
error << "No input files defined" if ARGV.empty?

unless error.empty?
  puts error * "\n" + "\n\n"
  puts opts
  exit
end

#The interesting part starts here
TILE_SIZE = 256
        
def get_tiles(output_dir, input_files, tile_param, zooms, bg_color = Magick::Pixel.new(255,255,255,0), format = "png")
  #order the input files: string order.
  sorted_input_files = input_files.sort
  
  #Whatever the zoom level, the tiles must cover the same surface : we get the surface of the furthest zoom. 
  furthest_dimension_tiles = get_dimension_tiles(sorted_input_files[0],tile_param)
    
  zooms.each do |zoom|
    next if zoom < tile_param.zoom
    return if (input_file = sorted_input_files.shift).nil?
    
    image = Magick::ImageList::new(input_file)
    image.scale!(tile_param.scale)
    image_size = Point.new(image.columns , image.rows)
    
    factor = 2 ** (zoom - tile_param.zoom)
    
    #index of the upper left corner for the current zoom
    start = tile_param.ul_corner * factor
    dimension_tiles = furthest_dimension_tiles * factor
    dimension_tiles_pixel = dimension_tiles * TILE_SIZE
    padding = tile_param.padding * factor
     
    #create an image at dimension_tiles_pixel ; copy the current image there  (a bit inefficient memory wise even if it simplifies )
    image_with_padding = Magick::Image.new(dimension_tiles_pixel.x, dimension_tiles_pixel.y) do 
      self.background_color = bg_color
    end
    
    image_with_padding.import_pixels(padding.x,padding.y,image_size.x,image_size.y,"RGBA",image.export_pixels(0,0,image_size.x,image_size.y,"RGBA"))
    
    image_with_padding.write(output_dir + "/tile_glob_#{zoom}.png")
    
    total_tiles = dimension_tiles.x * dimension_tiles.y
    
    counter = Point.new(0,0)
    
    cur_tile = Point.new(start.x,start.y)
    
    1.upto(total_tiles) do |tile|
      #progress column by column
      if counter.y == dimension_tiles.y
        counter.x += 1
        counter.y = 0
        cur_tile.x += 1
        cur_tile.y = start.y
      end
      
      pt_nw = counter * TILE_SIZE
      
      tile_image = Magick::Image.new(TILE_SIZE,TILE_SIZE)
      tile_image.import_pixels(0,0,TILE_SIZE,TILE_SIZE,"RGBA",image_with_padding.export_pixels(pt_nw.x,pt_nw.y,TILE_SIZE,TILE_SIZE,"RGBA"))
      tile_image.write("#{output_dir}/tile_#{zoom}_#{cur_tile.x}_#{cur_tile.y}.#{format}")
      
      counter.y += 1
      cur_tile.y += 1
      
    end
  end
end

def get_dimension_tiles(file,tile_param)
  #Get the size of the first input_file
  image = Magick::ImageList::new(file)
  image.scale!(tile_param.scale)
  image_size = Point.new(image.columns , image.rows)
  ending = tile_param.padding + image_size
  Point.new((ending.x / TILE_SIZE.to_f).ceil,(ending.y / TILE_SIZE.to_f).ceil)
end

get_tiles(options.output_dir,ARGV,options.tile_param,options.zoom_range,options.bg_color,options.format)

                      
