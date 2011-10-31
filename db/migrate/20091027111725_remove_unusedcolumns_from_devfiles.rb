class RemoveUnusedcolumnsFromDevfiles < ActiveRecord::Migration
  def self.up
    remove_column :devfiles, :size
    remove_column :devfiles, :uploaded
    remove_column :devfiles, :filedate
    remove_column :devfiles, :upload_requested
    remove_column :devfiles, :thumbnail_name
  end

  def self.down
  end
end
