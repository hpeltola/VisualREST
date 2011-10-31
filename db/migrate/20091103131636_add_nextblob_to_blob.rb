class AddNextblobToBlob < ActiveRecord::Migration
  def self.up
    add_column :blobs, :follower_id, :integer
  end

  def self.down
  end
end
