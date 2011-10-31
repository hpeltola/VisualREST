# This builds atomfeed
atom_feed do |feed|
  title = "User Created"
  feed.title title
  feed.updated Time.now.utc
   
    feed.entry(type, :id => @request_url, :url => @request_url) do |entry|
      content = "Username: " + @user.username.to_s() + "<br/>"
      content << "Real name: " << @user.real_name.to_s() << "<br/>"
      
      entry.title @user.real_name    
      entry.username @user.username
      entry.updated Time.now.xmlschema
 
      entry.content @content, :type=>"html"
      
      entry.author do |author|
        author.name "admin"
      end 
    end

  
end