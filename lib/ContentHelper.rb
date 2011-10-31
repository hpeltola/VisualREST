class ContentHelper
  
  def initialize(devile_id, blob_id = nil)
    
    
    @df = Devfile.find_by_id(devfile_id)
    
    # If no blob id was given, uses the newest one
    if blob_id
      @bl = @df.blobs.find_by_id(blob_id)
    else
      @bl = @df.blob
    end
    
    
  end
  
  
  def addMetadata(metadatatype, metadatavalue)
    if metadatatype == nil or metadatavalue == nil or @df_id == nil
      return false
    end
    
    type = MetadataType.find_by_name(metadatatype)
    if type == nil
      return false
    end
    
    Metadata.find_or_create_by_value_and_blob_id_and_devfile_id_and_metadata_type_id(metadatavalue, nil, @df_id, type.id)
    return true
  end
  
  
  
  
end