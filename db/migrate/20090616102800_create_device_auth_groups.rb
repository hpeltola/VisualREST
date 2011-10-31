class CreateDeviceAuthGroups < ActiveRecord::Migration
  def self.up
    create_table :device_auth_groups, :id => false do |t|
      t.integer :device_id
      t.integer :group_id

      t.timestamps
    end
  end

  def self.down
    drop_table :device_auth_groups
  end
end
