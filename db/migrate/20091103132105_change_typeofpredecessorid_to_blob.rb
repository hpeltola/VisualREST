class ChangeTypeofpredecessoridToBlob < ActiveRecord::Migration
  def self.up
    remove_column :blobs, :predecessor_id
    add_column :blobs, :predecessor_id, :integer
    
  end

  def self.down
  end
end
