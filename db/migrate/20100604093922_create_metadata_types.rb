class CreateMetadataTypes < ActiveRecord::Migration
  def self.up
    create_table :metadata_types do |t|
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :metadata_types
  end
end
