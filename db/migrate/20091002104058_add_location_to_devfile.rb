class AddLocationToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :longitude, :float
    add_column :devfiles, :latitude, :float
  end

  def self.down
    remove_column :devfiles, :latitude
    remove_column :devfiles, :longitude
  end
end
