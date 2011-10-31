class AddLatestLocationIdToDevice < ActiveRecord::Migration
  def self.up
    add_column :devices, :latest_location_id, :integer
  end

  def self.down
  end
end
