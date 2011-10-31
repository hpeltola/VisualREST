class ChangeFloatToDoubleInBlobs < ActiveRecord::Migration
  def self.up
    remove_column :blobs, :latitude
    add_column :blobs, :latitude, :double
    remove_column :blobs, :longitude
    add_column :blobs, :longitude, :double
  end

  def self.down
  end
end
