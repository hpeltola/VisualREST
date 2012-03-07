class DeviceObject

  
  def initialize(device, format="json")

    @format = format
    if @format != "html" && @format != "atom" && @format != "json" && @format != "yaml"
      raise Exception.new("Problem with format in DeviceObject!")
    end

    @device = device
    if not @device
      raise Exception.new("Device Cannot be nil!")
    end
    
    @user = User.find_by_id(@device.user_id)
    if not @user
      raise Exception.new("Error finding owner of the device!")
    end
    
  end



  def get_uri()
    uri = "#{@@http_host}/user/#{@user.username}/device/#{@device.dev_name}/files.#{@format}"
    return uri
  end




  def to_yaml
    
    res = {}
    
    begin
      
      res.merge!({"device_name" => @device.dev_name})
      res.merge!({"device_type" => @device.dev_type})
      res.merge!({"last_seen" => @device.last_seen})
      res.merge!({"owner_name" => @user.username})
      
      #puts res.to_s

      return res
      
    rescue Exception => e
      puts "Error: #{e.to_s}"
      puts "  -- line: #{e.backtrace[0].to_s}"
      return {}
    end
  end


end