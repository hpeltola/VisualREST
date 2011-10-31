class AddDeviceToCommit < ActiveRecord::Migration
  def self.up
    add_column :commits, :device_id, :integer
  end

  def self.down
    remove_column :commits, :device_id
  end
end
