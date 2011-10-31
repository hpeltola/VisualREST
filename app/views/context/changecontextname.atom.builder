# Thison builds atomfeed
atom_feed do |feed|
  title = "Contextname Changed"
  feed.title title
  feed.updated Time.now.utc

  feed.nameChanged "true"
  
  
end