class AddIndexDevfileNamePathIndex < ActiveRecord::Migration
  def self.up
    add_index(:devfiles, [:name, :path], :unique => true)
  end

  def self.down
    remove_index :devfiles, :column => [:name, :path]
  end
end
