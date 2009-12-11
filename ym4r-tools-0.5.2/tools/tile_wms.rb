require 'open-uri'
require 'optparse'
require 'ostruct'

#Structure that contains configuration data for the WMS tiler
class FurthestZoom < Struct.new(:ul_corner, :zoom, :tile_size)
end

#Contains LatLon coordinates
class LatLng < Struct.new(:lat,:lng)
end

#Contain projected coordinates (in pixel or meter)
class Point < Struct.new(:x,:y)
end   

OptionParser.accept(Range, /(\d+)\.\.(\d+)/) do |range,start,finish|
  Range.new(start.to_i,finish.to_i)
end

OptionParser.accept(FurthestZoom, /(\d+),(\d+),(\d+),(\d+),(\d+)/) do |setting,l_corner, u_corner, zoom, width, height|
  FurthestZoom.new(Point.new(l_corner.to_i,u_corner.to_i),zoom.to_i,Point.new(width.to_i,height.to_i))
end

options = OpenStruct.new
#set some defaults
options.format = "png"
options.zoom_range = 0..17
options.styles = ""
options.srs = 54004
options.geographic = false

opts = OptionParser.new do |opts|
  opts.banner = "WMS Tiler for Google Maps\nUsage: tile_wms.rb [options]\nExample: tile_wms.rb -o ./tiles -u http://localhost:8080/geoserver/wms -l \"topp:states\" -z 11..12 -g 602,768,11,3,3"
  opts.separator "" 
  opts.on("-o","--output OUTPUT_DIR","Directory where the tiles will be created") do |dir| 
    options.output_dir = dir
  end
  opts.on("-u","--url WMS_SERVICE","URL to the WMS server") do |url|
    options.url = url
  end
  opts.on("-l","--layers LAYERS","String of comma-separated layer names") do |layers|
    options.layers = layers
  end
  opts.on("-s","--styles STYLES","String of comma-separated style names. Is empty by default") do |styles|
    options.styles = styles
  end
  opts.on("-f","--format FORMAT","Image format in which to get the file (gif, jpeg, png...). Is png by default") do |format|
    options.format = format
  end
  opts.on("-z","--zooms ZOOM_RANGE",Range,"Range of zoom values at which the tiles must be generated. Is 0..17 by default") do |range|
    options.zoom_range = range
  end
  opts.on("-g","--gmap-setting SETTING",FurthestZoom,"Corner coordinates, furthest zoom level, tile width and height") do |fz|
    options.furthest_zoom = fz
  end
  opts.on("-w","--[no-]geographic","Query the WMS server with LatLon coordinates instead of using the Mercator projection") do |g|
    options.geographic = g
  end
  opts.on("-e", "--epsg SRS","SRS to query the WMS server. Should be a the SRS id of a Simple Mercator projection. Can vary between WMS servers. Is 54004 (Simple Mercator for Mapserver) by default. For GeoServer use 41001.") do |srs|
    options.srs = srs
                    
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
error << "No WMS URL defined (-u,--url)" if options.url.nil?
error << "No Google Maps setting defined (-g,--gmap-setting)" if options.furthest_zoom.nil?
error << "No WMS layer defined (-l,--layers)" if options.layers.nil?

unless error.empty?
  puts error * "\n" + "\n\n"
  puts opts
  exit
end    

#The size of a Google Maps tile. There are square so only one size.
TILE_SIZE = 256

#Defines a Simple Mercator projection for one level of Google Maps zoom.
class MercatorProjection
  DEG_2_RAD = Math::PI / 180
  WGS84_SEMI_MAJOR_AXIS = 6378137.0
  WGS84_ECCENTRICITY = 0.0818191913108718138
  
  attr_reader :zoom, :size, :pixel_per_degree, :pixel_per_radian, :origin
  
  def initialize(zoom)
    @zoom = zoom
    @size = TILE_SIZE * (2 ** zoom)
    @pixel_per_degree = @size / 360.0
    @pixel_per_radian = @size / (2 * Math::PI)
    @origin = Point.new(@size / 2 , @size / 2)
  end
  
  def borne(number, inf, sup)
    if(number < inf)
      inf
    elsif(number > sup)
      sup
    else
      number
    end
  end
  
  #Transforms LatLon coordinate into pixel coordinates in the Google Maps sense
  #See http://www.math.ubc.ca/~israel/m103/mercator/mercator.html for details
  def latlng_to_pixel(latlng)
    answer = Point.new
    answer.x = (@origin.x + latlng.lng * @pixel_per_degree).round
    sin = borne(Math.sin(latlng.lat * DEG_2_RAD),-0.9999,0.9999)
    answer.y = (@origin.y + 0.5 * Math.log((1 + sin) / (1 - sin)) * -@pixel_per_radian).round
    answer
  end
  
  #Transforms pixel coordinates in the Google Maps sense to LatLon coordinates
  def pixel_to_latlng(point)
    answer = LatLng.new
    lng = (point.x - @origin.x) / @pixel_per_degree;
    answer.lng = lng - (((lng + 180)/360).round * 360)
    lat = (2 * Math.atan(Math.exp((point.y - @origin.y) / -@pixel_per_radian))- Math::PI / 2) / DEG_2_RAD
    answer.lat = borne(lat,-90,90)
    answer
  end
  
  #Projects LatLon coordinates in the WGS84 datum to meter coordinates using the Simple Mercator projection
  def self.latlng_to_meters(latlng)
    answer = Point.new
    answer.x = WGS84_SEMI_MAJOR_AXIS * latlng.lng * DEG_2_RAD
    lat_rad = latlng.lat * DEG_2_RAD
    answer.y = WGS84_SEMI_MAJOR_AXIS * Math.log(Math.tan((lat_rad + Math::PI / 2) / 2) * ( (1 - WGS84_ECCENTRICITY * Math.sin(lat_rad)) / (1 + WGS84_ECCENTRICITY * Math.sin(lat_rad))) ** (WGS84_ECCENTRICITY/2)) 
    answer
  end
end

#Get tiles from a WMS server 
def get_tiles(output_dir, url, furthest_zoom, zooms, layers, geographic = false, epsg = 54004, styles = "", format = "png")
  
  unless geographic
    srs_str = epsg
  else
    srs_str = 4326 #Geographic WGS84
  end
  
  base_url = url << "?REQUEST=GetMap&SERVICE=WMS&VERSION=1.1&LAYERS=#{layers}&STYLES=#{styles}&BGCOLOR=0xFFFFFF&FORMAT=image/#{format}&TRANSPARENT=TRUE&WIDTH=#{TILE_SIZE}&HEIGHT=#{TILE_SIZE}&SRS=EPSG:#{srs_str}&reaspect=false"
  
  zooms.each do |zoom|
    next if zoom < furthest_zoom.zoom
    
    proj = MercatorProjection.new(zoom)
    
    #from mapki.com
    factor = 2 ** (zoom - furthest_zoom.zoom)
    
    #index of the upper left corner
    x_start = furthest_zoom.ul_corner.x * factor
    y_start = furthest_zoom.ul_corner.y * factor
    
    x_tiles = furthest_zoom.tile_size.x * factor
    y_tiles = furthest_zoom.tile_size.y * factor
    
    total_tiles = x_tiles * y_tiles
    
    x_counter = 0
    y_counter = 0
    
    x_tile = x_start
    y_tile = y_start
    
    1.upto(total_tiles) do |tile|
      #progress column by column
      if y_counter == y_tiles
        x_counter += 1
        y_counter = 0
        x_tile += 1
        y_tile = y_start
      end
      
      pt_sw = Point.new( (x_start + x_counter) * TILE_SIZE, (y_start + (y_counter + 1)) * TILE_SIZE) #y grows southbound
      pt_ne = Point.new((x_start + (x_counter + 1)) * TILE_SIZE, (y_start + y_counter) * TILE_SIZE)
      
      ll_sw = proj.pixel_to_latlng(pt_sw)
      ll_ne = proj.pixel_to_latlng(pt_ne)
      
      unless geographic
        pt_sw = MercatorProjection.latlng_to_meters(ll_sw)
        pt_ne = MercatorProjection.latlng_to_meters(ll_ne)
        bbox_str = "#{pt_sw.x},#{pt_sw.y},#{pt_ne.x},#{pt_ne.y}"
      else
        bbox_str = "#{ll_sw.lon},#{ll_sw.lat},#{ll_ne.lon},#{ll_ne.lat}"
      end
      
      request_url = "#{base_url}&BBOX=#{bbox_str}"
      
      begin
        open("#{output_dir}/tile_#{zoom}_#{x_tile}_#{y_tile}.#{format}","wb") do |f|
          f.write open(request_url).read
        end
      rescue Exception => e
        puts e
        raise
      end
      
      y_counter += 1
      y_tile += 1
      
    end
  end
end

get_tiles(options.output_dir,options.url,options.furthest_zoom,options.zoom_range,options.layers,options.geographic,options.srs,options.styles,options.format)

                      
