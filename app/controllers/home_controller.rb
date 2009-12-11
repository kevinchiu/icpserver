class HomeController < ApplicationController
  def index
    targets = Target.all
    @map = GMap.new("map_div")
    @map.control_init(:large_map => true,:map_type => true)
    
    if targets.size > 0
      lat = targets.last.lat
      lng = targets.last.lng
    else
      lat = 42.360799
      lng = -71.08768
    end
    
    @map.center_zoom_init([lat, lng], 15)
    
    for target in targets do
      add_to_map(target)
    end
    
    @target = Target.new #probably don't need this
  end
  
  private
  
  def add_to_map(target)
    lat = target.lat
    lng = target.lng
    message = target_info(lat, lng, target.theta, target.phi, target.psi) 
    marker = GMarker.new([lat, lng],:title => "Target", :info_window => message)
    @map.overlay_init(marker)
  end
  
  def target_info(lat, lng, theta, phi, psi)
    "lat: "   + lat.to_s   + '<br>' +
    "lng: "   + lng.to_s   + '<br>' + 
    "theta: " + theta.to_s + '<br>' +
    "phi: "   + phi.to_s   + '<br>' +
    "psi: "   + psi.to_s   + '<br>'
  end
end

# Get Lat / Lon from Google Maps
# javascript:void(prompt('',gApplication.getMap().getCenter()));