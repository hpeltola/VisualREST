class AddMailEncryptionToUserEmail < ActiveRecord::Migration
  def self.up
    add_column :user_emails, :mail_tls_encryption, :boolean
    add_column :user_emails, :device_id, :integer    
  end

  def self.down
    remove_column :user_emails, :mail_tls_encryption
    remove_column :user_emails, :device_id
  end
end
