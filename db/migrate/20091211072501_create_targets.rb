class CreateTargets < ActiveRecord::Migration
  def self.up
    create_table :targets do |t|
      
      t.timestamps
      t.float :lat
      t.float :lng
      t.float :theta #compass direction
      t.float :phi #elevation from horizon
      
    end
  end

  def self.down
    drop_table :targets
  end
end
