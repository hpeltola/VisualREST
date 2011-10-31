class CreateContextUserPermissions < ActiveRecord::Migration
  def self.up
    create_table :context_user_permissions do |t|
      t.integer :user_id
      t.integer :context_id

      
    end
  end

  def self.down
    drop_table :context_user_permissions
  end
end
