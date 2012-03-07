# Class controls users in certain group.
class GroupController < ApplicationController
  
  # Protection from cross site request forgery
  protect_from_forgery :except => [:addUserToGroup, :removeUserFromGroup, :getGroup, :addDeviceToGroup, 
                                   :removeDeviceFromGroup]
  
  # These methods needs authentication:
  before_filter :authenticate, :only => [:addUserToGroup, :removeUserFromGroup, :getGroup, :addDeviceToGroup, 
                                         :removeDeviceFromGroup]



  # '/user/:username/group/:groupname'
  def getGroup
    
    query_processing_time_begin = Time.now

    # Authentication
    begin

      if session[:username]
        username = session[:username]
      elsif params[:i_am_client]
        username = authenticateClient
      else
        flash[:notice] = "You must login first"
        redirect_to :action => "login", :controller => "user"
        return
      end
      
      if username == nil
        raise Exception.new("Problem authenticating")
      end

      # User making the request
      @user = User.find_by_username(username)
      
      if @user == nil
        raise Exception.new("Problem authenticating")
      end
          
      # Owner of the group
      @owner = User.find_by_username(params[:username])

      if not @owner
        raise Exception.new("Could not find  owner of the group")
      end

      # The group
      @group = Group.find_by_user_id_and_name(@owner.id, params[:groupname])

      if not @group
        raise Exception.new("Could not find group: #{params[:groupname]}")
      end

      # Check that the user is owner or member in the group
      memberInGroup(@user, @owner, @group)
      
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 401
      return
    end
    
    
    begin
      
      @members = Array.new
      @devices = Array.new
      @files = Array.new
      
      
      ug = Usersingroup.find(:all, :conditions => ["group_id = ?", @group.id])
      ug.each do |x|
        @members.push(x.user)
      end
  
      devicesAuth = DeviceAuthGroup.find(:all, :conditions => ["group_id = ?", @group.id])
      devicesAuth.each do |x|
        device = x.device
        device["username"] = x.device.user.username
        @devices.push(device)
      end
      
      
      filesAuth = DevfileAuthGroup.find(:all, :conditions => ["group_id = ?", @group.id])
      filesAuth.each do |x|
        devfile = x.devfile
        devfile["dev_name"] = x.devfile.device.dev_name
        devfile["username"] = x.devfile.device.user.username
        @files.push(devfile)
      end
      


    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end

    # Processing time of this function
    query_processing_time_end = Time.now
    @query_processing_time = query_processing_time_end - query_processing_time_begin
    puts "Time used for processing query: #{@query_processing_time}"

    @host = @@http_host
    respond_to do |format|
      if params[:format] == nil
        format.html {render :getGroup, :layout=>true }
      else
        format.html {render :getGroup, :layout=>true }
        format.atom {render :getGroup, :layout=>false }
      end
    end
    
  end

  # Returns: True  - If user is owner or member of the group
  #          False - If user is not member or owner of the group
  def memberInGroup(user, owner, group)

    begin
      
      # If user is the owner
      if user.username == owner.username
        return true
      end

      # Is the user member in the group
      users = Usersingroup.find_by_group_id(group.id)
      users.each do |x|
        if x.user_id == user.id
          return true
        end
      end

    rescue Exception => e
      return false
    end
    
    return false
  end
  
  
  
  # Method to add user in certain group.
  # Renders text and http code which tell that whether everething went ok or errors occoured
  # Requires authentication.
  # Usage:
  #   Send PUT to /user/{username}/group/{groupname}/member/{membername}
  def addUserToGroup
    
    user = User.find_by_username(params[:username])
    member = User.find_by_username(params[:membername])
    group = Group.find(:first, :conditions => ["name = ? and user_id = ?", params[:groupname], user.id])
    
    if user == nil or member == nil or group == nil
      render :text => "Error: User or Group not found", :status => 404
      return
    end

    begin
      # Creates new user in group
      Usersingroup.find_or_create_by_user_id_and_group_id(:user_id => member.id, :group_id => group.id)

    rescue => e
      puts e
      render :text => "Error adding user to the group", :status => 409
      return
    end
    render :text => "Added user: #{params[:membername]} to group: #{params[:groupname]}", :status => 200
    return
    
  end
  
  
  
  
  
  # Method to remove user in certain group.
  # Renders text and http code which tell that whether everething went ok or errors occoured
  # Requires authentication.
  # Usage: 
  #   Send DELETE to /user/{username}/group/{groupname}/member/{membername}
  def removeUserFromGroup
    
    
    groupowner = User.find_by_username(params[:username])
    member = User.find_by_username(params[:membername])
    group = Group.find(:first, :conditions => ["name = ? and user_id = ?", params[:groupname], groupowner.id])
    
    if groupowner == nil or member == nil or group == nil
      render :text => "User or Group not found - 404", :status => 404
      return
    end
    
    authgroup = member.groups.find(:first, :conditions => ["group_id = ?", group.id])        
    
    # if user is not in the group return: 200
    if authgroup == nil
      render :text => "User was not in the group", :status => 200
      return
    end
      
    begin
      # Tries to delete user from the group
      member.groups.delete(authgroup)  
    rescue => e
      puts "EXCEPTION: " + e
      render :text => "Error removing user from group", :status => 409
      return
    end
    
    render :text => "Removed user: #{params[:membername]} from group: #{params[:groupname]}", :status => 200
    return
  

  end
  
  # 'user/:username/group/:groupname/device/:devicename'
  # Returns: 200 - Device added to group
  #          401 - Unauthorized
  #          409 - Error 
  def addDeviceToGroup
    begin
      puts "addDeviceToGroup..."
      if session[:username]
        username = session[:username]
      elsif params[:i_am_client]
        username = authenticateClient
      else
        flash[:notice] = "You must login first"
        redirect_to :action => "login", :controller => "user"
        return
      end
      
      # User making the request
      @user = User.find_by_username(username)
      
      if @user == nil
        raise Exception.new("Problem authenticating")
      end
          
      # Owner of the group
      @owner = User.find_by_username(params[:username])

      if not @owner
        raise Exception.new("Could not find  owner of the group")
      end
      
      if @user.id != @owner.id
        raise Exception.new("User is not the owner of the group")
      end
      
      @group = Group.find_by_user_id_and_name(@owner.id, params[:groupname])
      @device = Device.find_by_user_id_and_dev_name(@user.id, params[:devicename])
      
      if not @group
        raise Exception.new("Group: #{params[:groupname]} not found")
      end
      
      if not @device
        raise Exception.new("Device: #{params[:devicename]} not found")
      end
      
      authDev = DeviceAuthGroup.find_or_create_by_device_id_and_group_id(:device_id => @device.id, :group_id => @group.id)
      
      if authDev == nil
        raise Exception.new("Could not add device: #{params[:devicename]} to group: #{params[:groupname]}")
      end
      
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
    
    render :text => "Device added to the group", :status => 200
    return
  end


  # 'user/:username/group/:groupname/device/:devicename'
  # Returns: 200 - Device added to group
  #          401 - Unauthorized
  #          409 - Error
  def removeDeviceFromGroup
    begin
      puts "removeDeviceFromGroup..."
      if session[:username]
        username = session[:username]
      elsif params[:i_am_client]
        username = authenticateClient
      else
        flash[:notice] = "You must login first"
        redirect_to :action => "login", :controller => "user"
        return
      end
      
      # User making the request
      @user = User.find_by_username(username)
      
      if @user == nil
        raise Exception.new("Problem authenticating")
      end
          
      # Owner of the group
      @owner = User.find_by_username(params[:username])

      if not @owner
        raise Exception.new("Could not find  owner of the group")
      end
      
      if @user.id != @owner.id
        raise Exception.new("User is not the owner of the group")
      end
      
      @group = Group.find_by_user_id_and_name(@user.id, params[:groupname])
      @device = Device.find_by_user_id_and_dev_name(@user.id, params[:devicename])
      
      if not @group
        raise Exception.new("Group: #{params[:groupname]} not found")
      end
      
      if not @device
        raise Exception.new("Device: #{params[:devicename]} not found")
      end
      
      DeviceAuthGroup.delete_all(:device_id => @device.id, :group_id => @group.id)
      
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
    
    render :text => "Device removed from the group", :status => 200
    return
  end
  
  
end
