class AddUploadRequestedToDevfile < ActiveRecord::Migration
  def self.up
    add_column :devfiles, :upload_requested, :boolean
  end

  def self.down
    remove_column :devfiles, :upload_requested
  end
end
