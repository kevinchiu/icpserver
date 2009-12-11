class AddPsiToTarget < ActiveRecord::Migration
  def self.up
    add_column :targets, :psi, :float
  end

  def self.down
    remove_column :targets, :psi
  end
end
