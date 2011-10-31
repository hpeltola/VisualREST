class ChangeFileObserver < ActiveRecord::Migration
  def self.up
    #remove_column :file_observers, :device_id
    remove_column :file_observers, :node_id
    add_column :file_observers, :node_path, :string
    add_column :file_observers, :node_service, :string
  end

  def self.down
  end
end
