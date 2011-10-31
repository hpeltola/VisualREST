# Methods added to this helper will be available to all templates in the application.
# Methods for creating links.
module ApplicationHelper
  # Return a link for use in layout navigation
  def nav_link(text, controller, action="index")
    link_to_unless_current text, :controller => controller, :action => action
  end
  
  def nav_link_devices(text, username)
    link_to_unless_current text, :controller => "query", :username => username, :action => "get", :what_to_get => 'devices'
  end
  
  def nav_link_devices_atom(text, username)
    link_to_unless_current text, :controller => "query", :username => username, :action => "get", :what_to_get => 'devices',
    :format=>"atom", :type=>"application/atom+xml", :title=>"Atom", :rel=>"alternate"
  end
  
  def nav_link_to_user_settings (text, username)
    link_to_unless_current text, :controller => "user", :action => "settings", :username => username
  end
  
  
end
