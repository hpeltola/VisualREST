class ContextObject

include Comparable

  # getter and setter
#  attr_reader :device_id, :username, 
#              :dev_name, :name, 
#              :thumbnail_name, :description, 
#              :version, :path, :filetype, 
#              :size, :rank, :blob_hash, 
#              :longitude, :latitude, 
#              :last_seen, :uploaded,
#              :updated_at, :date,
#              :devfile_id, :metadata

  
  def initialize(context, metadata, members, context_info)
    @context = context
    if not @context
      raise Exception.new("Context Cannot be nil!")
    end
    
    @members = members ? members : []
    @metadata = metadata ? metadata : []
    
    @user_named = context_info["user_named"]
    @owner_name = context_info["owner_name"]
    
  end


  def get_uri()
    uri = "#{@@http_host}/contexts/#{@context.context_hash}"
    return uri
  end




  def to_yaml
    
    res = {}
    
    begin
      
      mem = []
      @members.each do |m|
        mem << m.username
      end
      
      
      
      mdata = {}
      
      c = ""
      tags = Array.new
      country = nil
      place = nil
      lat = nil
      lon = nil
      
      puts @metadata.to_s
      
      if not @metadata.empty?
        @metadata.each do |md|
          if md.type_name == "context_location_country" and md.value != nil and md.value != ""
            country = md.value
          elsif md.type_name == "context_location_name" and md.value != nil and md.value != ""
            place = md.value
          elsif md.type_name == "context_location_lat" and md.value != nil and md.value != ""
            lat = md.value
          elsif md.type_name == "context_location_lon" and md.value != nil and md.value != ""
            lon = md.value
          elsif md.type_name == "tag" and md.value != nil and md.value != ""
            tags << md.value
          end
          
          if md.type_name != "tag"
            mdata.merge!({md.type_name => md.value})
          end
        end
      end
      
      mdata.merge!({"tags" => tags})
      
      
      location = {}
      if country
        location.merge!("country" => country)
      end
      if place
        location.merge!("place" => place)
      end
      if lat
        location.merge!("latitude" => lat)
      end
      if lon
        location.merge!("longitude" => lon)
      end

      
      
      
      res.merge!({"user_named" => @user_named})
      res.merge!({"context_owner" => @owner_name})
      res.merge!({"title" => @user_named})
      
      res.merge!({"description" => @context.description})
      res.merge!({"icon_uri" => @@http_host+@context.icon_url})
      res.merge!({"query_uri" => @@http_host+@context.query_uri})
      res.merge!({"private_context" => @context.private.to_s})
      res.merge!({"context_hash" => @context.context_hash})
      
      res.merge!({"context_owner_named" => @context.name})
      
      
      res.merge!({"members" => mem})
      
      res.merge!({"metadata" => mdata})
      
      
      res.merge!({"context_xmpp_node" => @context.node_path})
      res.merge!({"context_xmpp_node_service" => @context.node_service})
      
      
      res.merge!({"rank_value" => @context.rank.to_s})
      res.merge!({"begin_time" => @context.begin_time.to_s})
      res.merge!({"end_time" => @context.end_time.to_s})
      
      
      if not location.empty?
        res.merge!({"location" => location})
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