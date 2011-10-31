class ChangeDevfileidToBlobidInFileuploads < ActiveRecord::Migration
  def self.up
    remove_column :fileuploads, :devfile_id
    add_column :fileuploads, :blob_id, :integer
  end

  def self.down
  end
end
