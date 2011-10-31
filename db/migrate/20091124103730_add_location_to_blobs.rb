class AddLocationToBlobs < ActiveRecord::Migration
  def self.up
        add_column :blobs, :latitude, :float
        add_column :blobs, :longitude, :float
  end

  def self.down
  end
end
