class ChangeFloatToDoubleInDeviceLocations < ActiveRecord::Migration
  def self.up
    remove_column :device_locations, :latitude
    add_column :device_locations, :latitude, :double
    remove_column :device_locations, :longitude
    add_column :device_locations, :longitude, :double
  end

  def self.down
  end
end
