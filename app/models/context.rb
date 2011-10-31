class Context < ActiveRecord::Base
  
  # The owner of the context
  belongs_to :user
  
  has_many :context_metadatas
  has_many :context_names
  has_many :context_group_permissions
end
