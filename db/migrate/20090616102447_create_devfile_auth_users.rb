class CreateDevfileAuthUsers < ActiveRecord::Migration
  def self.up
    create_table :devfile_auth_users, :id => false do |t|
      t.integer :devfile_id
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :devfile_auth_users
  end
end
