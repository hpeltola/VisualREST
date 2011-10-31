class AddXmpppasswdToDevice < ActiveRecord::Migration
  def self.up
    add_column :devices, :xmpppasswd, :string
  end

  def self.down
    remove_column :devices, :xmpppasswd
  end
end
