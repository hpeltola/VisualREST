class CreateFileObservers < ActiveRecord::Migration
  def self.up
    create_table :file_observers do |t|
      t.integer :devfile_id
      t.integer :user_id
      t.integer :device_id
    end
  end

  def self.down
    drop_table :file_observers
  end
end
