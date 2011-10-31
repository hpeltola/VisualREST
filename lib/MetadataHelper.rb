class MetadataHelper
  
  def initialize()
    
    
    # Näitä voi lisätä ja tässä voi olla turhiakin..
    @@devfile_metadata_value_types = {
      "tag" => :tag,
      "created_at" => :date,
      "modified_at" => :date,
      "device_id" => :float,
      "username" => :string,
      "dev_name" => :string,
      "name" => :string,
      "path" => :string,
      "thumbnail_name" => :string,
      "description" => :string,
      "version" => :float,
      "filetype" => :string,
      "size" => :float,
      "rank" => :float,
      "last_seen" => :date,
      "uploaded" => :float,
      "devfile_id" => :float,
      "fullpath" => :string,
      "blob_hash" => :string  
    }
    
    
    
    
    
  end
  
  
  
  
  #
  # returns float, string or data according to the given type
  #
  def get_metadata_value_type(metadata_type)
    type = MetadataType.find_by_name(metadata_type)
    if type
      return type.value_type.to_sym
    
    else
      return @@devfile_metadata_value_types[metadata_type]
    end
  end
  
  
  
  
  def numeric?(object)
    true if Float(object) rescue false
  end
  
  
  
end