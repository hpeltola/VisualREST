class AddXmppnameToDevice < ActiveRecord::Migration
  def self.up
    add_column :devices, :xmppname, :string
  end

  def self.down
    remove_column :devices, :xmppname
  end
end
