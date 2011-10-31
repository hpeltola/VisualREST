class ClusterObject

  include Magick


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
  

  
  #
  #  If the cluster is based on string, it needs to be defined with stringCluster-parameter
  #
  #
  #
  def initialize(cluster_by_key, uri_base, maxRange = nil, content_objects = nil, previous_range_string = "", previous_uri_params = "")
    
    if not cluster_by_key
      raise Exception.new("cluster_by_key parameter must be given!")
    else
      @cluster_by = cluster_by_key
    end
    
    # set whether the clustering is done by string, float, or date
    @cluster_by_value_type = MetadataHelper.new.get_metadata_value_type(@cluster_by)
    
    
    if not uri_base
      raise Exception.new("uri_base parameter must be given!")
    else
      @uri_base = uri_base
    end
    
    @content_objects = []
    @biggest_value = nil
    
    if content_objects
      @content_objects = content_objects
    end

    if maxRange
      @maxRange = maxRange
    end
    
    @previous_range_string = previous_range_string
    @previous_uri_params = previous_uri_params
    
  end
  
  
  
  
  
  

  def <<(o)
    
    if not o.instance_of? ContentObject
      raise Exception.new("Object was not an instance of ContentObject!")
    end
    
    if not @biggest_value or o.get_value(@cluster_by) > @biggest_value
      @biggest_value = o.get_value(@cluster_by)
    end
    @content_objects << o
  end


#  def get_biggest_value
#    return @biggest_value
#  end

  def get_comparison_value
    return @biggest_value
  end

  def get_content_objects
    return @content_objects
  end


  def get_surrogate
    
    if @content_objects.count > 0
      return @content_objects[0]
    else
      return nil
    end
    
    
  end


  

  def generate_thumbnail(force_thumbs = false)

    if force_thumbs
      @force_thumbs = true
    end

    thumb_path = "public/thumbnails/clusters/"
    
    # Lasketaan hash
    s = ""
    thumbnail_paths = Array.new
    
    @content_objects.each do |content_obj|
      #if thumbnail_paths.count > 50 then
      #  break
      #end
      s << content_obj.get_value("blob_hash")
      thumbnail_paths << "public/thumbnails/#{content_obj.get_value("device_id")}/#{content_obj.get_value("thumbnail_name")}"
    end
    cluster_thumbnail_name = Digest::SHA1.hexdigest(s)
    cluster_thumbnail_name += ".png"
    
    
    
    full_path = "#{thumb_path}#{cluster_thumbnail_name}"
    
    # If no thumbnail with the same name already exists, creates a new one
    if (File.exists?(full_path)) and not @force_thumbs
      @thumbnail_uri = full_path
      return @thumbnail_uri

    else   # Creates collage
      
      @thumbnail_uri = CollageHelper.new(thumbnail_paths, full_path).get_thumbnail_path
      return @thumbnail_uri

    end

    
  end


  def get_contents_parameter
    
    devfile_ids =  Array.new
    @content_objects.each do |c_obj|
      devfile_ids << c_obj.devfile_id
    end
    
    return devfile_ids
  end



  # returns human readable string describing the range from the smallest value to the biggest one of the cluster
  def get_range_string
  
    if not @previous_range_string.empty?
      prefix = @previous_range_string + "; "
    else
      prefix = ""
    end
  
  
    if @cluster_by_value_type == :string
      return prefix + stringString
  
    elsif @cluster_by_value_type == :float
      return prefix + floatString
  
    elsif @cluster_by_value_type == :date
      return prefix + dateString
  
    else
      return ""
    end
  end


  def get_range_string_with_type
    
    if not @previous_range_string.empty?
      prefix = @previous_range_string + " <br />"
    else
      prefix = ""
    end
  
  
    if @cluster_by_value_type == :string
      return prefix + " Range (string): " + stringString
  
    elsif @cluster_by_value_type == :float
      return prefix + " Range (float): " + floatString
  
    elsif @cluster_by_value_type == :date
      return prefix + " Range (date): " + dateString
  
    else
      return ""
    end    
  end


  def get_uri
    
    return "#{@uri_base}&#{get_uri_params}" 
=begin
    if @cluster_by_value_type == :string
      return "#{@uri_base}&q[#{@cluster_by}]=#{@content_objects.first.get_value(@cluster_by)}"
    elsif @cluster_by_value_type == :date
      
      format = "%Y-%m-%d %H:%M:%S"
      
      min = @content_objects.first.get_value(@cluster_by).strftime(format)
      max = @content_objects.last.get_value(@cluster_by).strftime(format)

      return "#{@uri_base}&qmin[#{@cluster_by}]=#{min}&qmax[#{@cluster_by}]=#{max}"
    else
      return "#{@uri_base}&qmin[#{@cluster_by}]=#{@content_objects.first.get_value(@cluster_by)}&qmax[#{@cluster_by}]=#{@content_objects.last.get_value(@cluster_by)}"
    end
=end
  end


  def get_uri_params
    
    prefix = ""
    if @previous_uri_params and not @previous_uri_params.empty?
      prefix = @previous_uri_params + "&"
    end
    
    if @cluster_by and not @cluster_by.empty?
    
      if @cluster_by_value_type == :string
        
        puts "JIIJIIIII:: " + "#{prefix}q[#{@cluster_by}]=#{@content_objects.first.get_value(@cluster_by)}"
        
        return "#{prefix}q[#{@cluster_by}]=#{@content_objects.first.get_value(@cluster_by)}"
      elsif @cluster_by_value_type == :date
        
        format = "%Y-%m-%d %H:%M:%S"
        
        min = @content_objects.first.get_value(@cluster_by).strftime(format)
        max = @content_objects.last.get_value(@cluster_by).strftime(format)

  
        if min > max
          t_min = max
          max = min
          min = t_min
        end

  
        return "#{prefix}qmin[#{@cluster_by}]=#{min}&qmax[#{@cluster_by}]=#{max}"
      else
        return "#{prefix}qmin[#{@cluster_by}]=#{@content_objects.first.get_value(@cluster_by)}&qmax[#{@cluster_by}]=#{@content_objects.last.get_value(@cluster_by)}"
      end
    else
      return ""    
    end
  end



  #
  #  Returns URI for the cluster icon.
  #  If no collage icon has yet been made, uses default icon
  #
  def get_icon_uri
    
    if @thumbnail_uri
      return @thumbnail_uri.gsub("public","")
    else
      return "/thumbnails/clusters/no_thumb_many.png"
    end
    
    if @content_objects.count > 1 and @content_objects.first.get_value("thumbnail_name")
      uri = "/thumbnails/" + @content_objects.first.get_value("device_id").to_s + "/" + @content_objects.first.get_value("thumbnail_name").to_s
    end


    return uri
  end
  
  
  #
  # NOTICE! the difference between this one and get_cluster_by_type_for_range_string method
  # value is the metadata key by which the clustering has been done!
  #
  def get_cluster_by_key
    return @cluster_by
  end
  
  #
  #  What is the maximum range between content objects according to the 
  #  cluster_by_key
  #
  def get_max_range
    return @maxRange
  end
  
  #
  # How many contetent objects there are in the cluster
  #
  def get_size
    return @content_objects.count
  end



  #
  # NOTICE! the difference between this one and get_cluster_by_key method
  # values are: float, string and date
  #
  def get_cluster_by_type_for_range_string
    
    
    return @cluster_by_value_type.to_s
  end

  



private



  def stringString
    begin
     t1 = nil
     t2 = nil
     
     prefix = ""
     
      s = prefix
      if @content_objects.count >= 1
        t1 = @content_objects.first.get_value(@cluster_by).to_s
        if not t1
          return false
        end
      end  
      
      if @content_objects.count > 1
        t2 = @content_objects.last.get_value(@cluster_by).to_s
        if not t2
          return false
        end
      end
      
      #puts "string"
      
      if t1 and not t2
        return "#{prefix}#{t1.to_s}"
      elsif t1 and t2
        if t1.to_s == t2.to_s
          return "#{prefix}#{t1.to_s}"
        else
          return "#{prefix}#{t1.to_s} - #{t2.to_s}"
        end
      else
        return ""
      end
      
    rescue Exception => ee
      return ""
    end
    
  end



  def floatString
    begin
     t1 = nil
     t2 = nil
     
     
     prefix = ""
     
      s = prefix
      if @content_objects.count >= 1
        t1 = @content_objects.first.get_value(@cluster_by)
        if not numeric?(t1)
          return ""
        end
      end  
      
      if @content_objects.count > 1
        t2 = @content_objects.last.get_value(@cluster_by)
        if not numeric?(t2)
          
          return ""
        end
      end
      
      #puts "float"
      
      if t1 and not t2
        return "#{prefix}#{t1.to_s}"
      elsif t1 and t2
        if t1.to_s == t2.to_s
          return "#{prefix}#{t1.to_s}"
        else
          return "#{prefix}#{t1.to_s} - #{t2.to_s}"
        end
      else
        return false
      end
      
    rescue Exception => ee
      return false
    end
    
  end



  def dateString
   
   begin
     t1 = nil
     t2 = nil
     
     prefix = ""

      s = prefix

      
      
      if @content_objects.count >= 1
        # Tests if the value is valid timedate
        t1 = Time.parse(@content_objects.first.get_value(@cluster_by).to_s)
        if not t1
          return ""
        end
      end
      if @content_objects.count > 1
        t2 = Time.parse(@content_objects.last.get_value(@cluster_by).to_s)
        if not t2
          return ""
        end
      end
      
      #puts "date"
      
      format = "%d/%m/%Y %I:%M:%S"
      if t1 and not t2
        
        return "#{prefix}#{t1.strftime(format).to_s}"
      
      elsif t1 and t2

       
       # If the dates between first and last are the same
       if t1.strftime(format).to_s == t2.strftime(format).to_s

          return "#{prefix}#{t1.strftime(format).to_s}"
       
       # If difference is less than a day => time - time (date)
       elsif (t1 - t2).abs < 60 * 60 * 24 # and (t1 - t2).abs > 60 * 60
          format = "%H:%M:%S"
          format2 = "%d/%m/%Y"
          return "#{prefix}#{t1.strftime(format).to_s} - #{t2.strftime(format).to_s}  (#{t2.strftime(format2).to_s})"
       
       # If difference is more than a day (no time) => date - date 
       elsif (t1 - t2).abs > 60 * 60 * 24

          format = "%d/%m/%Y"
          return "#{prefix}#{t1.strftime(format).to_s} - #{t2.strftime(format).to_s}"
       else
puts "muuten"
          return "#{prefix}#{t1.strftime(format).to_s} - #{t2.strftime(format).to_s}"
       end
      else

        return ""
      end
    rescue Exception => ee
      puts ee.to_s
      return ""
    end
  end







  def numeric?(object)
    true if Float(object) rescue false
  end

  def date?(object)
    if object.instance_of? Date
      return true
    end
    
    return false
  end


  

  





end





