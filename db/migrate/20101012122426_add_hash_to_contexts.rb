class AddHashToContexts < ActiveRecord::Migration
  def self.up
    add_column :contexts, :context_hash, :string
  end

  def self.down
    remove_column :contexts, :context_hash
  end
end
