# Class controls users in certain group.
class GroupController < ApplicationController
  
  # Protection from cross site request forgery
  protect_from_forgery :except => [:addUserToGroup, :removeUserFromGroup]
  
  # These methods needs authentication:
  before_filter :authenticate, :only => [:addUserToGroup, :removeUserFromGroup]
  
  
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
      render :text => "User or Group not found - 404", :status => 404
      return
    end

    # Creates new user in group
    begin
      Usersingroup.create(:user_id => member.id, :group_id => group.id, :created_at => DateTime.now, :updated_at => DateTime.now)
    rescue => e
      puts e
      render :text => "409 Conflict", :status => 409
      return
    end
    render :text => "OK - 200", :status => 200
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
      render :text => "OK - 200 ", :status => 200
      return
    end
      
    begin
      # Tries to delete user from the group
      member.groups.delete(authgroup)  
    rescue => e
      puts "EXCEPTION: " + e
      render :text => "409 Conflict", :status => 409
      return
    end
    
    render :text => "OK - 200 ", :status => 200
    return
  

  end
  
end
