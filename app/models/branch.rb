class Branch < ActiveRecord::Base
  
  # Branch has only one parent blob
  belongs_to :blob
  
  # Blob can have many different blobs as a branch
  has_many :blobs
  
  
end
