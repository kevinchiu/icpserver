class TargetController < ApplicationController
  def create
    target = Target.new params[:target]
    clean(target)
    Target.delete_all
    target.save!
    redirect_to :controller => 'home', :action => 'index'
  end
  
  def index
    @targets = Target.all
  end
  
  private
  
  def clean(target)
    target.lat = 0 unless target.lat != nil
    target.lng = 0 unless target.lng != nil
    target.theta = 0 unless target.theta != nil
    target.phi = 0 unless target.phi != nil
    target.psi = 0 unless target.psi != nil
  end
  
end
