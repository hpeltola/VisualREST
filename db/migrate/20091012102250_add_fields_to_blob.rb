class AddFieldsToBlob < ActiveRecord::Migration
  def self.up
    add_column :blobs, :blob_id, :string
    add_column :blobs, :predecessor_id, :string
    add_column :blobs, :size, :integer
    add_column :blobs, :filedate, :datetime
    add_column :blobs, :uploaded, :boolean
    add_column :blobs, :upload_requested, :boolean
    add_column :blobs, :thumbnail_name, :string
  end

  def self.down
    remove_column :blobs, :thumbnail_name
    remove_column :blobs, :upload_requested
    remove_column :blobs, :uploaded
    remove_column :blobs, :filedate
    remove_column :blobs, :size
    remove_column :blobs, :predecessor_id
    remove_column :blobs, :blob_id
  end
end
