class AddVersionToBlob < ActiveRecord::Migration
  def self.up
    add_column :blobs, :version, :integer
  end

  def self.down
    remove_column :blobs, :version
  end
end
