class ChangeLocationColumnsToMetadata < ActiveRecord::Migration
  def self.up
    remove_column :contexts, :location_country
    remove_column :contexts, :location_name
    remove_column :contexts, :location_lat
    remove_column :contexts, :location_lon
    
    add_column :contexts, :location_string, :string
    
  end

  def self.down
  end
end
