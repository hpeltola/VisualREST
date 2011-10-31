class ChangeBlobIdToBlob < ActiveRecord::Migration
  def self.up
    remove_column :blobs, :blob_id
    add_column :blobs, :blob_hash, :string
  end

  def self.down
  end
end
