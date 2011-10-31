class AddBlobIdToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :blob_id, :integer
  
  end

  def self.down
    remove_column :devfiles, :blob_id
  end
end
