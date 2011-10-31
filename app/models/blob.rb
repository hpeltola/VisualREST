class Blob < ActiveRecord::Base

  belongs_to :devfile

  has_many :fileuploads

  # Previous blob
  has_one :blob
  
  has_many :blobs_in_commits
  
  # One blob can belong in many commits
  has_many :commits, :through => :blobs_in_commits

  
  # One blob can have many braches
  has_many :branches

  has_many :metadata

end
