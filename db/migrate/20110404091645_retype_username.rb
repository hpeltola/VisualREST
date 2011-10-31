class RetypeUsername < ActiveRecord::Migration
  def self.up
    
    remove_column :service_informations, :s_username
    
    add_column :service_informations, :s_username, :string
    
  end

  def self.down
  end
end
