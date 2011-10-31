class CreateDeviceLocations < ActiveRecord::Migration
  def self.up
    create_table :device_locations do |t|
      t.integer :device_id
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end

  def self.down
    drop_table :device_locations
  end
end
