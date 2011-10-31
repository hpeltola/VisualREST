class CreateUsersingroups < ActiveRecord::Migration
  def self.up
    create_table :usersingroups, :id => false do |t|
      t.integer :user_id
      t.integer :group_id

      t.timestamps
    end
  end

  def self.down
    drop_table :usersingroups
  end
end
