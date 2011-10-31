class ChangeDeviceIdToNodeIdToFileObservrs < ActiveRecord::Migration
  def self.up
    remove_column :file_observers, :device_id
    add_column :file_observers, :node_id, :integer
  end

  def self.down
  end
end
