class ContextGroupPermission < ActiveRecord::Base
  
  belongs_to :context
  belongs_to :group
  
end
