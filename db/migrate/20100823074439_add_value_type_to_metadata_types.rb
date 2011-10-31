class AddValueTypeToMetadataTypes < ActiveRecord::Migration
  def self.up
    add_column :metadata_types, :value_type, :string, :default => "string"
  end

  def self.down
    remove_column :metadata_types, :value_type
  end
end
