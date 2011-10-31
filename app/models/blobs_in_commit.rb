class BlobsInCommit < ActiveRecord::Base
  belongs_to :blob
  belongs_to :commit
  
  
  #def delete_b_in_c
  #  self.delete_all(:conditions => ["commit_id = ?, blob_id = ?", this.commit_id.to_s, this.blob_id.to_s])
  #end
  
  
end
