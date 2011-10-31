class CreateDeviceAuthUsers < ActiveRecord::Migration
  def self.up
    create_table :device_auth_users, :id => false do |t|
      t.integer :device_id
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :device_auth_users
  end
end
