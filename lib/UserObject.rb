class UserObject

  
  def initialize(user, format="json", groups=nil, own_groups=nil, friends=nil)

    @format = format
    if @format != "html" && @format != "atom" && @format != "json" && @format != "yaml"
      raise Exception.new("Problem with format in UserObject!")
    end
    
    @groups = groups
    @own_groups = own_groups
    @friends = friends
    
    @user = user
    if not @user
      raise Exception.new("Error finding owner of the device!")
    end
    
  end



  def get_uri()
    uri = "#{@@http_host}/user/#{@user.username}.#{@format}"
    return uri
  end




  def to_yaml
    
    res = {}
    
    begin
      
      res.merge!({"name" => @user.real_name})
      res.merge!({"username" => @user.username})
      res.merge!({"thumbnail_uri" => "#{@@http_host}/user/#{@user.username}/metadatas/thumbnail"})

      if @own_groups != nil
        res.merge!({"own_groups" => @own_groups})        
      end
 
      if @groups != nil
        res.merge!({"member_in_groups" => @groups})        
      end     
      
      if @friends != nil
         res.merge!({"users_in_same_groups_with_you" => @friends})
      end
      
      #puts res.to_s

      return res
      
    rescue Exception => e
      puts "Error: #{e.to_s}"
      puts "  -- line: #{e.backtrace[0].to_s}"
      return {}
    end
  end


end