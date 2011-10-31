class CreateServiceInformations < ActiveRecord::Migration
  def self.up
    create_table :service_informations do |t|
      t.string :service_type
      t.integer :user_id
      t.integer :s_username
      t.string :s_id
      t.string :s_token
      t.string :extra_1
      t.string :extra_2

      
    end
  end

  def self.down
    drop_table :service_informations
  end
end
