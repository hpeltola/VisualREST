class Commit < ActiveRecord::Base

  # Previous commit
  has_one :commit
  belongs_to :device
  has_many :blobs_in_commits
  has_many :blobs, :through => :blobs_in_commits

end
