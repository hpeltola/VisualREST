class ContextMetadata < ActiveRecord::Base
  belongs_to :context
  belongs_to :metadata_type
  
  
end
