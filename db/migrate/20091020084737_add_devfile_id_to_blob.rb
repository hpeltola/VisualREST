class AddDevfileIdToBlob < ActiveRecord::Migration
  def self.up
    add_column :blobs, :devfile_id, :integer
  end

  def self.down
    remove_column :blobs, :devfile_id
  end
end
