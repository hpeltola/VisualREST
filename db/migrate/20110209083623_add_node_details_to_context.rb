class AddNodeDetailsToContext < ActiveRecord::Migration
  def self.up
    add_column :contexts, :node_path, :string
    add_column :contexts, :node_service, :string
  end

  def self.down
    remove_column :contexts, :node_service
    remove_column :contexts, :node_path
  end
end
