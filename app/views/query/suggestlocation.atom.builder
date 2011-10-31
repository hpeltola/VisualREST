# Thison builds atomfeed
atom_feed do |feed|
  title = "Suggestions for location"
  feed.title title
  feed.updated Time.now.utc

  @suggested_names.each do |key,value|    
    feed.entry("", :id => @request_url, :url => @request_url) do |entry|
      entry.title key
      entry.updated Time.now.xmlschema
      
      entry.author do |author|
        author.name "admin"
      end 
    end
  end

  
end