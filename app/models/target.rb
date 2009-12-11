class Target < ActiveRecord::Base
  acts_as_mappable
  
  def pretty_print
    p = self.lat.to_s
    p << ', '
    p << self.lng.to_s
    p << ', '
    p << self.theta.to_s
    p << ', '
    p << self.phi.to_s
    p << ', '
    p << self.psi.to_s
  end
end
