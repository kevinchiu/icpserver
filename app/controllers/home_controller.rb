class HomeController < ApplicationController
  def index
    @map = GMap.new("map_div")
    @map.control_init(:large_map => true,:map_type => true)
    @map.center_zoom_init([42.360799, -71.08768],15)
  end
end

# Get Lat / Lon from Google Maps
# javascript:void(prompt('',gApplication.getMap().getCenter()));