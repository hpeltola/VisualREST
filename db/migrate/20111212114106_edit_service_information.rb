class EditServiceInformation < ActiveRecord::Migration
  def self.up
    remove_column :service_informations, :s_id
    remove_column :service_informations, :s_token
    add_column :service_informations, :s_user_id, :string
    add_column :service_informations, :auth_token, :string
    add_column :service_informations, :auth_secret, :string
  end

  def self.down
    remove_column :service_informations, :s_user_id
    remove_column :service_informations, :auth_token
    remove_column :service_informations, :auth_secret
    add_column :service_informations, :s_id, :string
    add_column :service_informations, :s_token, :string
  end
end
