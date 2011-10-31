class CreateMetadatas < ActiveRecord::Migration
  def self.up
    create_table :metadatas do |t|
      t.string :value
      t.integer :devfile_id
      t.integer :blob_id

      t.timestamps
    end
  end

  def self.down
    drop_table :metadatas
  end
end
