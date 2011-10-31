# Thison builds atomfeed
atom_feed do |feed|
  title = "List of all added metadatatypes"
  feed.title title
  feed.updated Time.now.utc

  link = @host + "/metadatatypes.atom"
  
  @results.each do |type|
    feed.entry(type, :id => link, :url => link) do |entry|
      entry.title type.name
      entry.value_type type.value_type
      entry.created_at type.created_at
      entry.updated_at type.updated_at
      
      entry.content "<p>Name: #{type.name}</p><p>Type: #{type.value_type}</p>", :type => 'html'
      
      entry.author do |author|
        author.name "admin"
      end 
    end
  end

  
end