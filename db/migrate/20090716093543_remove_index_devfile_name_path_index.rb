class RemoveIndexDevfileNamePathIndex < ActiveRecord::Migration
  def self.up
    remove_index :devfiles, :column => [:name, :path]
  end
end
