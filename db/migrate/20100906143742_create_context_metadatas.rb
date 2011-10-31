class CreateContextMetadatas < ActiveRecord::Migration
  def self.up
    create_table :context_metadatas do |t|
      t.string :value
      t.integer :context_id
      t.integer :metadata_type_id
    end
  end

  def self.down
    drop_table :context_metadatas
  end
end
