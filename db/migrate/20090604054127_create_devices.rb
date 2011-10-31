class CreateDevices < ActiveRecord::Migration
  def self.up
    create_table :devices do |t|
      t.integer :user_id
      t.string :id_digest
      t.string :dev_name
      t.string :dev_type
      t.datetime :last_seen
      t.boolean :direct_access
      t.string :address

      t.timestamps
    end
  end

  def self.down
    drop_table :devices
  end
end
