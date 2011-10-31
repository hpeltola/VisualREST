
class ContentObject

include Comparable

  # getter and setter
  attr_reader :device_id, :username, 
              :dev_name, :name, 
              :thumbnail_name, :description, 
              :version, :path, :filetype, 
              :size, :rank, :blob_hash, 
              :longitude, :latitude, 
              :last_seen, :uploaded,
              :updated_at, :date,
              :devfile_id, :metadata

  
  def initialize(result, mdata)
    
    begin
      @@sort_by = nil
      
      if not result
        raise Exception.new("Result was nil!")
      end
      
      # blob
      @thumbnail_name = result.thumbnail_name
      @size = result.size
      
      @modified_at = Time.parse(result.blobs_updated_at)
      @created_at = Time.parse(result.devfiles_created_at)
      
      @version = result.version
      @blob_hash = result.blob_hash
      @latitude = result.latitude
      @longitude = result.longitude
      @uploaded = result.uploaded
  #puts "1"
      # devfile
      #@devfile = @blob.devfile
      @devfile_id = result.devfile_file_id
      @name = result.name
      @path = result.path
      @description = result.description
      @filetype = result.filetype
      @rank = result.rank
  #puts "2"
      # device
      #@device = @devfile.device
      @device_id = result.device_id
      @dev_name = result.dev_name
      @last_seen = result.last_seen 
      
  #puts "3"
      # user
      #@user = @device.user
      @username = result.username
  #puts "4"
  
  
      metadata = {}
      mds = mdata[@devfile_id.to_i]
      
      if mds != nil
        mds.each do |k,v|
          mdvalue = v
          if mdvalue == nil
            mdvalue = v
          else
            mdvalue = v
          end
          metadata.merge!({k.to_s => mdvalue})
        end
      end    
      @metadata = metadata
    rescue Exception => e
      puts e.to_s
      raise e
    end
  end
  
  
  
  def get_value(key)
      case key
        when "device_id"
          return @device_id
        when "username"
          return @username
        when "dev_name"
          return @dev_name
        when "name"
          return @name
        when "path"
          return @path
        when "thumbnail_name"
          return @thumbnail_name
        when "description"
          return @description
        when "version"
          return @version
        when "filetype"
          return @filetype
        when "size"
          return @size.to_f
        when "rank"
          return @rank
        when "blob_hash"
          return @blob_hash 
        when "longitude"
          return @longitude
        when "latitude"
          return @latirude
        when "last_seen"
          return @last_seen
        when "uploaded"
          return @uploaded
        when "modified_at"
          return @modified_at
        when "created_at"
          return @created_at
        when "devfile_id"
          return @devfile_id
        when "fullpath"
          return @path + @name
        else
          return @metadata[key]
        end
  end
  
  
  
  
  
  
  def self.setSortBy(value)
    
    
    
    
    @@sort_by = value
    
    puts "sortting by: #{@@sort_by}"
    
    
  end
  
  
  
  
  def <=>(o)
    
    if not @@sort_by
      return 0
    end
    
    if not self.get_value(@@sort_by) and o.get_value(@@sort_by)
      return 1
    elsif not o.get_value(@@sort_by) and self.get_value(@@sort_by)
      return -1
    elsif not self.get_value(@@sort_by) and not o.get_value(@@sort_by)
      return 0
    else
      
      if self.get_value(@@sort_by).instance_of? String and o.get_value(@@sort_by).instance_of? String 
        return self.get_value(@@sort_by).downcase <=> o.get_value(@@sort_by).downcase
      else
        return self.get_value(@@sort_by) <=> o.get_value(@@sort_by)
      end      
    end
    
  end
  
  
  def get_uri(format = :html)
    
    if format == :atom
      return "#{@@http_host}/user/#{@username}/device/#{@dev_name}/metadatas#{@path}#{@name}?format=atom"
    else
      return "#{@@http_host}/user/#{@username}/device/#{@dev_name}/metadatas#{@path}#{@name}"
    end

  end
  
  
  def get_thumb_uri
    
    uri = ""
    if self.get_value("thumbnail_name")
      uri = "/thumbnails/" + self.get_value("device_id").to_s + "/" + self.get_value("thumbnail_name").to_s
    end
    return uri
  end
  
  
  
  
  def to_yaml(host="")
    
    file_status = "not cached"
    if @uploaded == "1" or @uploaded == "true" then file_status = "cached" end
    device_status = "offline"
    if Time.parse(@last_seen) > 2.minutes.ago then device_status = "online" end
        res = {"#{@path}#{name}" => {
      "thumbnail" => "#{@@http_host}/thumbnails/#{@device_id}/#{@blob_hash}.png",
      "description" => @description,
      "file_user" => @username,
      "file_version" => @version,
      "filename" => @name,
      "filepath" => @path,
      "filetype" => @filetype,
      "filesize" => @size,
      "rank_value" => @rank,
      "file_device" => @dev_name,
      "file_status" => file_status,
      "device_status" => device_status,
      "file_versionlist_url" => "#{@@http_host}/user/#{@username}/device/#{@dev_name}/fileversions#{@path}#{@name}?format=atom",
      "updated" => @updated_at,
      "version_hash" => @blob_hash,
      "metadata" => @metadata
    }}
  end
  
  
  def to_yaml1
    
    res = {"#{@path}#{name}" => {
      "name" => @name,
      "path" => @path,
      "modified_at" => @modified_at,
      "created_at" => @created_at,
      "blob_hash" => @blob_hash,
      "size" => @size,
      "metadata" => @metadata
    }}

    return res
  end
  
  
 
  
end