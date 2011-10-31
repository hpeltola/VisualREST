class AddIndexDevfilePathNameDeviceIdIndex < ActiveRecord::Migration
  def self.up
    add_index(:devfiles, [:path, :name, :device_id], :unique => true)
  end

  def self.down
    remove_index :devfiles, :column => [:path, :name, :device_id]
  end
end
