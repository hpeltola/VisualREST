class AddMetadataTypeIdToMetadata < ActiveRecord::Migration
  def self.up
    add_column :metadatas, :metadata_type_id, :integer
  end

  def self.down
    remove_column :metadatas, :metadata_type_id
  end
end
