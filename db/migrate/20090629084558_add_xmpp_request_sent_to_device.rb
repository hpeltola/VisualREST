class AddXmppRequestSentToDevice < ActiveRecord::Migration
  def self.up
    add_column :devices, :xmpp_request_sent, :datetime
  end

  def self.down
    remove_column :devices, :xmpp_request_sent
  end
end
