require 'rainbow'

# Class that controls searches for files, devices and users.
class QueryController < ApplicationController
  
  
  
  # devfile_keywords1 contains keywords which accept 1..n values separated by '+',
  # devfile_keywords2 contains keywords which accept exactly 1 value
  # NOTE: "user" and "device" are also allowed (depending on the context) though they aren't on the list
  @@devfile_keywords1 = ["type", "filename", "path", "search", "group"]
  @@devfile_keywords2 = ["state", "maxsize", "minsize", "filedateafter", "filedatebefore", "addedafter",
                 "addedbefore", "updatedafter", "updatedbefore", "lat", "lon", "distance", "maxlat", "minlat", "maxlon", "minlon"]
  # Types added later
  @@devfile_keywords3 = ["rank", "size", "modified_at", "created_at", "blob_hash"]

  
  # values that can be given to parameter "sort_by". Table is used to map these search terms to database columns.
  @@devfile_sort_by = {"user" => "users.username",
               "device" => "devices.dev_name",
               "path" => "devfiles.path",
               "filename" => "devfiles.name",
               "date_added" => "devfiles.created_at",
               "date_updated" => "devfiles.updated_at",
               "modified_at" => "blobs.updated_at",
               "created_at" => "devfiles.created_at",
               "size" => "blobs.size",
               "location" => "devfiles.latitude, devfiles.longitude",
               "rank" => "devfiles.rank"}
  
  # default sorting order
  @@devfile_sorting = ["LOWER(devfiles.created_at)", "LOWER(users.username)",
                       "LOWER(devices.dev_name)", "LOWER(devfiles.name)"]


  # versionlist sorting order
  @@versions_sorting = "blobs.version"
                       
                       
  # condition_rules: rules to make sql condition
  @@devfile_condition_rules = {"type" => "devfiles.filetype like ? or devfiles.name like ?",
                  "maxsize" => "blobs.size <= ?",
                  "minsize" => "blobs.size >= ?",
                  "filedateafter" => "blobs.filedate > ?",
                  "filedatebefore" => "blobs.filedate < ?",
                  "addedafter" => "devfiles.created_at > ?",
                  "addedbefore" => "devfiles.created_at < ?",
                  "updatedafter" => "devfiles.updated_at > ?",
                  "updatedbefore" => "devfiles.updated_at < ?",
                  "search" => "devfiles.name like ? or devfiles.path like ?",
                  "filename" => "devfiles.name like ?",
                  "path" => "devfiles.path like ?",
                  "distance" => "((devfiles.latitude - ?) * (devfiles.latitude - ?) + (devfiles.longitude - ?) * (devfiles.longitude - ?)) <= ?",
                  "maxlat" => "devfiles.latitude <= ?",
                  "minlat" => "devfiles.latitude >= ?",
                  "maxlon" => "devfiles.longitude <= ?",
                  "minlon" => "devfiles.longitude >= ?",
                  "state" => "blobs_in_commits.commit_id = ?",
                  "rank" => "devfiles.rank = ?", "rankmin" => "devfiles.rank >= ?", "rankmax" => "devfiles.rank <= ?", 
                  "ranksmaller" => "devfiles.rank < ?","rankbigger" => "devfiles.rank > ?",
                  "size" => "blobs.size = ?", "sizemin" => "blobs.size >= ?", "sizemax" => "blobs.size <= ?",
                  "sizesmaller" => "blobs.size < ?", "sizebigger" => "blobs.size > ?",
                  
                  "modified_at" => "blobs.updated_at = ?", "modified_atmin" => "blobs.updated_at >= ?", "modified_atmax" => "blobs.updated_at <= ?",
                  "modified_atsmaller" => "blobs.updated_at < ?", "modified_atbigger" => "blobs.updated_at > ?",
                  "modified_atdate" => "CONVERT(blobs.updated_at, DATE) = ?", "modified_atmindate" => "CONVERT(blobs.updated_at, DATE) >= ?", "modified_atmaxdate" => "CONVERT(blobs.updated_at, DATE) <= ?",
                  "modified_atsmallerdate" => "CONVERT(blobs.updated_at, DATE) < ?", "modified_atbiggerdate" => "CONVERT(blobs.updated_at, DATE) > ?",                  
                  "modified_atyear" => "YEAR(blobs.updated_at) = ?", "modified_atminyear" => "YEAR(blobs.updated_at) >= ?", "modified_atmaxyear" => "YEAR(blobs.updated_at) <= ?",
                  "modified_atsmalleryear" => "YEAR(blobs.updated_at) < ?", "modified_atbiggeryear" => "YEAR(blobs.updated_at) > ?",

                  "created_at" => "devfiles.created_at = ?", "created_atmin" => "devfiles.created_at >= ?", "created_atmax" => "devfiles.created_at <= ?",
                  "created_atsmaller" => "devfiles.created_at < ?", "created_atbigger" => "devfiles.created_at > ?",
                  "created_atdate" => "CONVERT(devfiles.created_at, DATE) = ?", "created_atmindate" => "CONVERT(devfiles.created_at, DATE) >= ?", "created_atmaxdate" => "CONVERT(devfiles.created_at, DATE) <= ?",
                  "created_atsmallerdate" => "CONVERT(devfiles.created_at, DATE) < ?", "created_atbiggerdate" => "CONVERT(devfiles.created_at, DATE) > ?",
                  "created_atyear" => "YEAR(devfiles.created_at) = ?", "created_atminyear" => "YEAR(devfiles.created_at) >= ?", "created_atmaxyear" => "YEAR(devfiles.created_at) <= ?",
                  "created_atsmalleryear" => "YEAR(devfiles.created_at) < ?", "created_atbiggeryear" => "YEAR(devfiles.created_at) > ?",
                  "blob_hash" => "blobs.blob_hash = ?"}

                  
  
  # sql-strings -- Devfiles
  @@devfile_select_part1 = "SELECT devfiles.id as devfile_file_id, devfiles.created_at as devfiles_created_at, devfiles.*, blobs.updated_at as blobs_updated_at, blobs.*, users.username, devices.dev_name, devices.last_seen"
  @@devfile_select_part2 =                "from devfiles, devices, users, blobs, blobs_in_commits WHERE"
  @@devfile_select_part2_without_commit = "from devfiles, devices, users, blobs WHERE"
  
  @@devfile_default_id_conditions =        "AND devfiles.device_id = devices.id AND devices.user_id = users.id AND blobs.devfile_id = devfiles.id AND blobs_in_commits.blob_id = blobs.id AND blobs_in_commits.commit_id = devices.commit_id"  
  @@devfile_id_conditions_without_commit = "AND devfiles.device_id = devices.id AND devices.user_id = users.id AND blobs.devfile_id = devfiles.id AND blobs_in_commits.blob_id = blobs.id"
  @@devfile_id_conditions_all_commits =    "AND devfiles.device_id = devices.id AND devices.user_id = users.id AND devfiles.blob_id = blobs.id"
  
  # sql-strings -- metadata
  @@metadata_select_part1 = "SELECT metadatas.devfile_id as devfile_id, devfiles.blob_id as devfile_blob_id, metadatas.value as metadata_value, metadata_types.name as metadatatype, metadatas.blob_id as metadata_blob_id"
  @@metadata_select_part2 = " FROM devfiles, metadatas, metadata_types WHERE"
  @@metadata_conditions = " metadatas.metadata_type_id = metadata_types.id AND devfiles.id = metadatas.devfile_id"


  
  # device_keywords1 contains keywords which accept 1..n values separated by '+',
  # device_keywords2 contains keywords which accept exactly 1 value
  # NOTE: "user" and "device" are also allowed (depending on the context) though they aren't on the list
  @@device_keywords1 = ["type"]
  @@device_keywords2 = ["addedafter", "addedbefore", "updatedafter", "updatedbefore", "lastseenafter", "lastseenbefore"]
  @@device_keywords3 = []
  
  # values that can be given to parameter "sort_by"
  @@device_sort_by = {"user" => "users.username",
               "device" => "devices.dev_name",
               "type" => "devices.dev_type",
               "date_added" => "devfiles.created_at",
               "date_updated" => "devfiles.updated_at",
               "last_seen" => "devices.last_seen"}
  
  # default sorting order
  @@device_sorting = ["LOWER(users.username)", "LOWER(devices.dev_name)"]
  
  # condition_rules: rules to make sql condition
  @@device_condition_rules = {"type" => "devices.dev_type like ?",
                              "addedafter" => "devices.created_at > ?",
                              "addedbefore" => "devices.created_at < ?",
                              "updatedafter" => "devices.updated_at > ?",
                              "updatedbefore" => "devices.updated_at < ?",
                              "lastseenafter" => "devices.last_seen > ?",
                              "lastseenbefore" => "devices.last_seen < ?" }
  
  # sql-strings -- Devices
  @@device_select_part1 = "SELECT devices.*, users.username"
  @@device_select_part2 = "from devices, users WHERE"
  @@device_default_id_conditions = "AND devices.user_id = users.id"
  

  # Constants that are used to calculate distances between gps-locations
  @@radius_miles = 3956
  @@radius_km = 6371
  @@radius_feet =  @@radius_miles * 5282
  @@radius_meters = @@radius_km * 1000
  @@rad_per_deg = 0.017453293  #  PI/180
  @@kms_per_latitude_degree = 111.2
  @@kms_per_degree = 102
  @@latitude_degrees = @@radius_km / @@kms_per_latitude_degree


  def device_online_timeout 
    return 90.seconds.ago
  end

  # Return possible values for certain metadatatype
  #
  # Usage:
  #   Send GET to /metadatatype/{metadatatype}
  #
  def getPossibleMetadataValues
    begin
      
      if params[:qoption] && params[:qoption][:json_callback]
        @json_callback = params[qoption][:json_callback]
      end
      
      if params[:qoption] && params[:qoption]["format"]
       params[:format] = params[:qoption]["format"]
     end
      
      # Find username who is signed in
      if params[:i_am_client]
        username = authenticateClient
      elsif session[:username]
        username = session[:username]  
      else
        username = nil
      end
  
      if username != nil
        @user = User.find_by_username(username)
      end  
          
      # Get all values of the requested type
      @metadatatype = MetadataType.find_by_name(params[:metadatatype])
      
      if not @metadatatype
        raise Exception.new("Metadatatype #{params[:metadatatype]} not found")
      end
      
      # Find all values
      values = Metadata.find_all_by_metadata_type_id(@metadatatype.id)
      
      # Here will be the results returned to user
      @results = Hash.new
      
      
      # Make sure the user is authorized to access the content with these values
      values.each do |x|
        # Find the devfile the metadata is related to
        devfile = x.devfile
        
        if devfile.privatefile == true
          if username == nil || @user == nil
            next
          end
          
          
          
        end
        
        # OK, add the file to results
        if @results.has_key?(x.value)
          @results[x.value] = @results[x.value] + 1
        else
          @results[x.value] = 1
        end
        
      end
          
      # host parameter, needed when creating atom-feed
      if request.ssl?
        @host = "https://#{request.host}"
      else
        @host = "http://#{request.host}"
      end
  
      if request.port != nil and request.port != 80
        @host += ":#{request.port}"
      end    
        
        
    rescue Exception => e
      putsE(e)
      render :text => "Error: #{e.to_s}", :status => 409
      return
    end
        
        
    # Create atom feed
    @host = @@http_host
    respond_to do |format|
      if params[:format] == nil
        format.html {render :getpossiblemetadatavalues, :layout=>true }
      else
        format.html {render :getpossiblemetadatavalues, :layout=>true }
        format.atom {render :getpossiblemetadatavalues, :layout=>false }
        format.yaml {render :text => @results.to_yaml, :layout=>false }
        if @json_callback == nil
          format.json {render :text => @results.to_json, :layout=>false }
        else
          format.json {render :text => @json_callback + '(' + @results.to_json + ')', :layout=>false }
        end
      end
    end
  end




  # Return atom feed of all metadatatypes
  #
  # Usage:
  #   Send GET to /metadatatypes.atom
  #
  def getMetadatatypes
    
    @queryparams = params
    
    # Get all metadatatypes
    @results = MetadataType.find(:all, :order => "updated_at ASC" )
        
    if params[:format] && params[:format]== "json" || params[:format] == "yaml"
      @yaml_results = {}
      @results.each do |result|
        @yaml_results.merge!({result.name => result.value_type})
      end
      
    end
        
    # host parameter, needed when creating atom-feed
    if request.ssl?
      @host = "https://#{request.host}"
    else
      @host = "http://#{request.host}"
    end

    if request.port != nil and request.port != 80
      @host += ":#{request.port}"
    end    
        
    # Create atom feed
    @host = @@http_host
    respond_to do |format|
      if @queryparams[:format] == nil
        format.html {render :getmetadatatypes, :layout=>true }
      else
        format.html {render :getmetadatatypes, :layout=>true }
        format.atom {render :getmetadatatypes, :layout=>false }
        format.yaml {render :text => YAML.dump(@yaml_results), :layout=>false }
        format.json {render :text => JSON.dump(@yaml_results), :layout=>false }
      end
    end
  end



  # Get the informations about the context
  #
  #
  def getContexts
  
    query_processing_time_begin = Time.now
    # In web-ui query processing time is only shown if asked. In atom-feed, it is always shown.
    if params["query_processing_time"] && params["query_processing_time"].downcase == "true"
      @query_processing = true
    end
    if params[:qoption] && params[:qoption]["query_processing_time"] == "true"
      @query_processing = true
    end
  
    @queryparams = params
  
    if request.url.to_s.include?("?")
      @querystring = request.url.to_s.gsub(/http\:\/\/[\w\.\:\/]+\?/, "").gsub("%2A", "*")
      @querystring_for_feed = @querystring.gsub(/\&?perpage\=\d+/i, "").gsub(/\&?page\=\d+/i, "").gsub(/^\&/, "")
    end
    if @querystring_for_feed == "" or @querystring_for_feed == nil then @querystring_for_feed = "No parameters given. Use name parameter for querying contexts by name." end
  
    
    # Find username who is signed in
    if params[:i_am_client]
      username = authenticateClient
    elsif session[:username]
      username = session[:username]  
    end
    @user = User.find_by_username(username)

    # host parameter, needed when creating atom-feed
    if request.ssl?
      @host = "https://#{request.host}"
    else
      @host = "http://#{request.host}"
    end

    if request.port != nil and request.port != 80
      @host += ":#{request.port}"
    end    
    
    sql = "SELECT contexts.id as c_id, contexts.user_id as user_id, contexts.name as name, query_uri, icon_url,
                  contexts.node_path as node_path, contexts.node_service as node_service,
                  description, begin_time, end_time, contexts.email as email, private, location_string, username, 
                  users.id, contexts.updated_at as updated_at, contexts.created_at as created_at, context_hash,
                  contexts.rank as rank
                  FROM contexts, users "
    sql_conditions = nil
    
    if @queryparams[:name]  
      sql_names = searchtermForSql(@queryparams[:name], "name")
      sql_conditions = sql_conditions ? sql_conditions + " AND " + sql_names : sql_names
    end
    
    if @queryparams[:username]  
      # Find user_id
      owner = User.find_by_username(@queryparams[:username])
      if owner == nil
        render :text => "Owner of queried context not found", :status => 409
        return
      end 
      sql_conditions = sql_conditions ? sql_conditions + " AND user_id = #{owner.id} " : "user_id = #{owner.id} "
    end
    
    if @queryparams[:sort_by]
      # You can sort by created_at/updated_at/name/rank
      if @queryparams[:sort_by].downcase == "date_added"
        sort_by = "created_at"
      elsif @queryparams[:sort_by].downcase == "date_updated"
        sort_by = "updated_at"
      elsif @queryparams[:sort_by].downcase == "name"
        sort_by = "name"
      elsif @queryparams[:sort_by].downcase == "rank"
        sort_by = "rank"
      end
      
    else
      sort_by = "updated_at"
    end
    
    # If searching contexts by name, also take into account context_names given by the user
    if @queryparams[:name] && @user != nil
      tmp_also_these_ctx = Context.find_by_sql("SELECT context_names.* FROM context_names WHERE #{sql_conditions} AND context_names.user_id = #{@user.id}")
                                      
      if tmp_also_these_ctx != nil && tmp_also_these_ctx.size != 0
        
        add_contexts = "contexts.id IN ("

        tmp_also_these_ctx.each_with_index do |x, i|
          if i != 0
            add_contexts += ", "
          end
          add_contexts += x.context_id
        end
        add_contexts += " ) "
        
        sql_conditions = " ( "+ add_contexts + " OR " + sql_conditions  +" ) "
      end
                                                      
    end
    
    
    if @queryparams[:order] && @queryparams[:order].downcase == "asc"
      order = "ASC" 
    else
      order = "DESC"
    end
    
    if sql_conditions
      sql += " WHERE " + sql_conditions + " AND user_id = users.id "
    else
      sql += " WHERE contexts.user_id = users.id "
    end
    
    sql += " ORDER BY #{sort_by} #{order} "
    puts "Context search SQL: #{sql}"
    
    # Get contexts, user authorization is not yet checked for these
    contexts_unlimited = Context.find_by_sql( sql )
    
    # Move contexts here, that user is authorized to see
    @contexts = Array.new
    # Show the name owner has given, as well as the name the user has given
    @context_info = {}
    
    # Find contexts that user is authorized to see
    contexts_unlimited.each do |cx|
      if authorizedToContext(cx.context_hash)
        
        tmp_owner = User.find_by_id(cx.user_id)
        if tmp_owner == nil
          render :text => "Couldn't find owner info for context: #{cx.name}", :status => 409
          return
        end

        if @user != nil
          temp_ctx_name = ContextName.find_by_user_id_and_context_id(@user.id, cx.c_id)
        else
          temp_ctx_name = nil
        end
        
        if temp_ctx_name != nil
          
          @context_info.merge!({cx.c_id => { "owner_name" => tmp_owner.username, "user_named" => temp_ctx_name.name}})          
        else   
          @context_info.merge!({cx.c_id => { "owner_name" => tmp_owner.username, "user_named" => cx.name}})
        end
        @contexts.push(cx)
        next
      end
    end
    
    puts @contexts.to_s
    
    # If user doesn't have access to any context
    if @contexts.empty?
      render :text => "Nothing found!", :status => 404
      return
    end
    
    sql = "SELECT context_metadatas.context_id as id, 
                  context_metadatas.value as value, 
                  metadata_types.name as type_name,
                  metadata_types.value_type as value_type
                  FROM context_metadatas, metadata_types"

    metadata_where_part = " WHERE context_metadatas.metadata_type_id = metadata_types.id AND 
                                  context_metadatas.context_id in ("
    @contexts.each_index do |i|
      c = @contexts[i]
      metadata_where_part += "#{c.c_id.to_s}"
      metadata_where_part += ',' if @contexts.count > 1 and i != @contexts.count - 1
    end
    metadata_where_part += ')'
    
    sql += metadata_where_part
    
    @metadatas = {}
    mdatas = ContextMetadata.find_by_sql(sql)
    mdatas.each do |md|
      temp = @metadatas[md.id]
      if not temp
        # Wasn't found => new array for the mds
        temp = []
      end
      temp.push(md)
      @metadatas.merge!({md.id => temp})
    end
   
   

    @members = {}
    @contexts.each do |x|
 
      sql = "SELECT users.* 
             FROM context_group_permissions, groups, usersingroups, users 
             WHERE context_group_permissions.context_id=#{x.c_id} AND 
                   context_group_permissions.group_id = groups.id AND 
                   groups.id=usersingroups.group_id AND usersingroups.user_id=users.id;"
      
      m_temp = User.find_by_sql(sql)
      if not m_temp
        m_temp = []
      end
      @members.merge!({x.c_id => m_temp})     
    end

    # Create atom feed
    @host = @@http_host
    
    
    if @queryparams[:format] == "yaml" or @queryparams[:format] == "json" 
        puts "YAMLII"
        @yaml_results = {}
        
        @contexts.each do |context|
          context_metadatas = @metadatas[context.c_id.to_i]
          context_members = @members[context.c_id]
          co = ContextObject.new(context, context_metadatas, context_members, @context_info[context.c_id])
          @yaml_results.merge!({co.get_uri => co.to_yaml})
        end
    end
    
    
    if query_processing_time_begin != nil
      query_processing_time_end = Time.now
      @query_processing_time = query_processing_time_end - query_processing_time_begin
      puts "Time used for processing query: #{@query_processing_time}"
    end
    
    
    
    # Rendering
    respond_to do |format|
      if @queryparams[:format] == nil
        format.html {render :getcontexts, :layout=>true }
      else
        format.html {render :getcontexts, :layout=>true }
        format.atom {render :getcontexts, :layout=>false }
        format.yaml {render :text => YAML.dump(@yaml_results), :layout=>false }
        format.json {render :text => JSON.dump(@yaml_results), :layout=>false }
      end
    end 
  end




  



  # Get list of files or devices
  #
  # Parameters: what_to_get - must be either "files" or "devices"
  #             Depending on the wanted context url can include:
  #               username OR username+devicename OR deviceid
  #             Additionally a query can be defined (see accepted query-parameters ("keywords") above).
  #             List of files/devices can be either in the web-UI or as a feed (.atom must be specified)
  #
  # Method searches for files or devices in the given context (using query parameters if any given). If
  # the context is empty ("/files" or "/devices") a query must be defined.
  #
  # Usage:
  #   Files:
  #    Send GET to /user/{username}/device/{devicename}/files[.atom][?query]
  #      or GET to /device/{deviceid}/files[.atom][?query]
  #      or GET to /user/files[.atom][?query]
  #      or GET to /files[.atom]{?query}
  #   Devices:
  #    Send GET to /user/{username}/devices[.atom][?query]
  #      or GET to /devices[.atom]{?query}
  #
  def get
    
      @queryparams = params
    
puts "qp: "
@queryparams.each do |k,v|
  puts "k: #{k.to_s}    v: #{v.to_s}"
  
end

    # In web-ui query processing time is only shown if asked. In atom-feed, it is always shown.
    if params["query_processing_time"] && params["query_processing_time"].downcase == "true"
      @query_processing = true
    end
    if params[:qoption] && params[:qoption]["query_processing_time"] == "true"
      @query_processing = true
    end
    
    
    query_processing_time_begin = Time.now
   
        
    # get the query-part of the request-url (strip away page- and perpage-params for feeds) --  just for the views
    if request.url.to_s.include?("?")
      @querystring = request.url.to_s.gsub(/http\:\/\/[\w\.\:\/]+\?/, "").gsub("%2A", "*")
      @querystring_for_feed = @querystring.gsub(/\&?perpage\=\d+/i, "").gsub(/\&?page\=\d+/i, "").gsub(/^\&/, "")
      if @querystring_for_feed == "" then @querystring_for_feed = nil end
    end
 
    
    

    # set default string depending on if the search is for devfiles or devices
    setDefaultStrings
    
    # will include everything that is needed to do the search
    @device_ids = Array.new
    @conditions = Hash.new
    @locationdata = Hash.new
    
    # info about the context
    @context = Hash.new
    
    # get context (device and/or user)
    if not getSearchContext
      if @queryparams[:format] && @queryparams[:format] != "html"
        render :text => "Nothing found", :status => 404
        return
      end

      # nothing found
      @nothingfound = true
      render @render
      return
    end
puts "S C: #{@context.to_s}"
    # check for searchterms
    metadata_search_terms = {}
    @context_hash = nil

    searchparams = {}
    @sparseAllParams = nil
    @qSparse = nil
    @availableFilesOnly = false
    @showDeletedFiles = false
    @newQueryInterfaceUsed = false
    @only_these_users = nil
    @json_callback = nil

    ### Query parameters should be in form: q[city]=tampere&q[tag]=testi
    if params[:q] &&  params[:q] != nil
      @newQueryInterfaceUsed = true
      # Parse query parameters from params[:q]
      puts
      puts "Query parameters"
      params[:q].each do |key, value|
        if key == nil || value == nil
          next
        end
        puts "Key: #{key} Value: #{value}"
        if key == "user"
          addUsersToSearchContext(value)
          @only_these_users = value
        else
          searchparams.merge!({key => value})
        end
      end
    end
    
    begin
      ## Comparison operators ##
      if params[:qequal] && params[:qequal] != nil
        @newQueryInterfaceUsed = true
        params[:qequal].each do |key, value|
          if key == nil || value == nil
            next
          end
          searchparams.merge!({key => value})
        end
      end
      
      if params[:qmax] && params[:qmax] != nil
        @newQueryInterfaceUsed = true
        params[:qmax].each do |key, value|
          if key == nil || value == nil
            next
          end
          if validateKeyAsFloatOrDateOrDatetimeType(key)
            searchparams.merge!({key+'<=' => value})
          else
            raise Exception.new("Comparison operator can only be used with float, date or datetime")
          end
        end
      end
      
      if params[:qmin] && params[:qmin] != nil
        @newQueryInterfaceUsed = true
        params[:qmin].each do |key, value|
          if key == nil || value == nil
            next
          end
          if validateKeyAsFloatOrDateOrDatetimeType(key)
            searchparams.merge!({key+'>=' => value})
          else
            raise Exception.new("Comparison operator can only be used with float, date or datetime")
          end
        end
      end
      
      if params[:qsmaller] && params[:qsmaller] != nil
        @newQueryInterfaceUsed = true
        params[:qsmaller].each do |key, value|
          if key == nil || value == nil
            next
          end
          if validateKeyAsFloatOrDateOrDatetimeType(key)
            searchparams.merge!({key+'<' => value})
          else
            raise Exception.new("Comparison operator can only be used with float, date or datetime")
          end
        end
      end
      
      if params[:qbigger] && params[:qbigger] != nil
        @newQueryInterfaceUsed = true
        params[:qbigger].each do |key, value|
          if key == nil || value == nil
            next
          end
          if validateKeyAsFloatOrDateOrDatetimeType(key)
            searchparams.merge!({key+'>' => value})
            puts 'bigger >'
          else
            raise Exception.new("Comparison operator can only be used with float, date or datetime")
          end
        end
      end
      ## end comparison operators ##
      
      if params[:qgroup] && params[:qgroup] != nil
        @newQueryInterfaceUsed = true
        puts
        puts "Querying for groups"
        params[:qgroup].each do |key, value|
          if key== nil || value == nil
            next
          end
          addGroupsToSearchContext(key, value)
          puts "User: #{key} Groups: #{value}"
        end
      end
            
      if params[:qoption] && params[:qoption] != nil
        @newQueryInterfaceUsed = true
        # This is query option that is relevant with all parameters
        puts
        puts "Query option for all parameters"
        params[:qoption].each do |key, value|
          if key == nil || value == nil
            next
          end
          
          # Using sparse for all files?
          if key.downcase == "sparse" && value.downcase == "false"
            @sparseAllParams = false
          elsif key.downcase == "sparse" && value.downcase == "true"
            @sparseAllParams = true
          
          # Only available files?
          elsif key == "available_files_only" && value == "true"
            @availableFilesOnly = true
          
          # Set sorting order?
          elsif key == "sort_by"
            @queryparams.merge!({key => value})
          
          elsif key == "order"
            @queryparams.merge!({key => value})
            
          elsif key == "format"
            params[:format] = value
            
          elsif key == "json_callback"
            @json_callback = value
            
          # Show deleted files?
          elsif key == "show_deleted_files" && value == "true"
            @showDeletedFiles = true
          end
          
          puts "Qoption Key: #{key} Value: #{value}"
        end
      end
        
      if params[:qsparse] && params[:qsparse] != nil
        @newQueryInterfaceUsed = true
        @qSparse = params[:qsparse]
        # Sparse value given for each parameter separately
        puts
        puts "Query sparse parameters"
        params[:qsparse].each do |key, value|
          if key == nil || value == nil
            next
          end
          puts "Sparse Key: #{key} Value: #{value}"
        end
      end
        
      if params[:qweight] && params[:qweight] != nil
        @newQueryInterfaceUsed = true
        # Weight value given separately given for each parameter
        puts
        puts "Weight parameters"
        params[:qweight].each do |key, value|
          if key == nil || value == nil
            next
          end
          puts "Weight Key: #{key} Value: #{value}"
        end
      end
        
      if @newQueryInterfaceUsed == false
        # This is the old way of handling parameters, and it will also be supported.
        searchparams = params
      end
    rescue Exception => e
      puts "Error querying. #{e.to_s}"
      render :text => "Error querying. Problem with float, date or datetime -type? E:#{e.to_s}", :status => 404
      return        
    end
    
    # Because of this, without search parameters returns everything and with errorenous paremeters returns nothing
    @queryNotEmpty = false
    @queryHasCorrectParameter = false

    searchparams.each do |param, value|

      # Move the comparison operator from param to the value
      if param[-2..-1] == '<='
        param = param[0..-3]
        value += '<='
      elsif param[-2..-1] == '>='
        param = param[0..-3]
        value += '>='
      elsif param[-1..-1] == '<'
        param = param[0..-2]
        value += '<'
      elsif param[-1..-1] == '>'
        param = param[0..-2]
        value += '>'
      end
      
      # skip other than search-params
      if param != "what_to_get" && param != "action" && param != "controller"
        @queryNotEmpty = true
      end
      # if parameter is user added metadatatype, it will be processed later
      metadatatypeAndValueType = MetadataType.find_by_name(param.downcase)
      if metadatatypeAndValueType != nil
        if value != ""
          # If context_hash as parameter, put it to @context_hash for later processing
          if param.downcase == "context_hash"
            @context_hash = value
            
            # Also increase context rank-value
            tmp_context = Context.find_by_context_hash(@context_hash)
            if tmp_context != nil
              tmp_context.update_attribute(:rank, tmp_context.rank+1)
            end
            
            next
          end
          
          # If context_name as parameter, convert it to context_hash and put it to @context_hash for later processing
          if param.downcase == "context_name"
            # Find owner of context
            ctx_splitted = value.split('.')
            if ctx_splitted.length == 2
              ctx_name = ContextName.find_by_username_and_name(ctx_splitted[0], ctx_splitted[1])
              if ctx_name != nil
                @context_hash = ctx_name.context_hash
              end
            end
            
            # Also increase context rank-value
            tmp_context = Context.find_by_context_hash(@context_hash)
            if tmp_context != nil
              tmp_context.update_attribute(:rank, tmp_context.rank+1)
            end
            
            next
          end
          @queryHasCorrectParameter = true
          
          # Add search params to metadata_search_terms and process them later
          temp = [metadatatypeAndValueType.value_type, value.downcase]
          metadata_search_terms.merge!({param.downcase => temp})         
        end
        next
      end
      
      # Parameter wasn't found on metadatatype-list, go through keyword list
      #next if not @keywords1.include?(param.downcase) and not @keywords2.include?(param.downcase) and not @keywords3.include?(param.downcase)
      if not @keywords1.include?(param.downcase) and not @keywords2.include?(param.downcase) and not @keywords3.include?(param.downcase)
        if param.downcase == "what_to_get" || param.downcase == "action" || param.downcase == "username" || param.downcase == "controller" ||
           param.downcase == "devicename" || param.downcase == "format" || param.downcase == "sparse" || param.downcase == "page"
          next
        end
        render :text => "Problem with metadatatype: #{param.downcase}, it is not found on the system.", :status => 404
        return
      end

      # if parameter is a keyword, validate value and process it
      
      if @keywords3.include?(param.downcase)
        p = processLaterAddedParamTypes(param.downcase, value)
        if p == true
          next
        else
          render :text => "Problem with search parameter: rank, size or date", :status => 404
          return
        end
      end
      
      multi = nil
      if @keywords1.include?(param.downcase)
        multi = true
      elsif @keywords2.include?(param.downcase)
        multi = false
      end
      p = processParam(param.downcase, value, multi)
      if not p
        render :text => "bad value for keyword"
        return
      elsif p == :nothingfound
        render :text => "Nothing found", :status => 404
        return
      end
    end
    
    # If no search parameters given, returns all files as long as the following is commented out
=begin    if @context.empty? and @conditions.empty? and metadata_search_terms.empty? and @context_hash == nil
      if @queryparams[:format] != "atom"
        @nothingfound = true
        render @render
        return
      else
        render :text => "Nothing found, no search parameters given", :status => 404
        return
      end
=end    end
    
    # Because of this, without search parameters returns everything and with errorenous paremeters returns nothing
    allowSearch = false
    if @queryNotEmpty == true && @queryHasCorrectParameter == true
      allowSearch = true
    elsif @queryNotEmpty == false && @queryHasCorrectParameter == false
      allowSearch = true
    elsif @context_hash != nil
      allowSearch = true
    end

    if @context.empty? and not @@metadata_conditions.empty? and @conditions.empty? and allowSearch
      if @context_hash == nil || @queryHasCorrectParameter
        @conditions.merge!("filedateafter" => Array["1979-01-01"] )
      else
        @conditions.merge!("filedatebefore" => Array["1979-01-01"])
      end
    end
    
    # if no context and no query specified
    if @context.empty? and @conditions.empty? and @device_ids.empty?
      if @queryparams[:format] && @queryparams[:format] != "html"
        render :text => "Nothing found, problem with search parameter type?", :status => 404
        return
      end

      # nothing found
      @nothingfound = true
      render @render
      return
    end
    
    # Is availableFilesOnly set with old way of querying
    if searchparams["available_files_only"] == "true"
      @availableFilesOnly = true
    end

    # Is showDeletedContent set with old way of querying
    if searchparams["show_files_content"] == "true"
      @showDeletedFiles = true
    end

   
    # ID:s of results that will be removed
    @remove_from_results = Array.new
    
    # ID:s of files that are only allowed in the @results
    # This can be nil, then this will be ignored
    @only_allowed_in_results = Array.new
   
    # make the search
    makeSearch
   
    if @results.size == 0
      
      if @queryparams[:format] && @queryparams[:format] != "html"
               
        respond_to do |format|
          if @queryparams[:format] == "yaml"
            render :text => "", :status => 200
          elsif @queryparams[:format] == "json"
            if @json_callback == nil
              render :text => "{ }", :status => 200
            else
              render :text => @json_callback + '({ })', :status => 200
            end
          end
          
          return
        end
      end

      # nothing found
      @nothingfound = true
      render @render
      return
    end    
    
    # Is user signed in
    if params[:i_am_client]
      username = authenticateClient
    elsif session[:username]
      username = session[:username]
    end


    if username != nil
      @signed_in_user = username
      @user = User.find(:first, :conditions => ["username = ?", username])
      @node_names = Array.new
      @user.nodes.each do |n|
        @node_names.push(n.nick_name)
      end
    end    
 
    if not @queryparams[:what_to_get] =~ /devices/i
      
    begin
      # Find out 
      goThroughMetadataSearchTermsV2(metadata_search_terms)
      
      
      metadata_select = metadata_select = @@metadata_select_part1 + @@metadata_select_part2+ @@metadata_conditions  + buildFinalResultCondition + " ORDER BY metadatas.devfile_id, metadatas.updated_at"
      
      metas = Metadata.find_by_sql(metadata_select)
      
    rescue Exception => e
      puts e.to_s
      render :text => "Error querying. Problem with float or date -type? E:#{e.to_s}", :status => 404
      return        
    end
 

      # If context_hash is specified, don't remove devfiles from results that are part of the context
      if @context_hash != nil and @devfiles_in_context != nil
        @devfiles_in_context.each do |y|            
          @remove_from_results.reverse_each do |x|
            if y.to_i == x.to_i
              # The devfile is in context. Now make sure user is authorized to the file.
              # If user is authorized, devfile will be shown in @results
              if authorizedToDevfile(x.to_i)
                # Remove the file from list of to be deleted devfiles
                @remove_from_results.delete(x)
              end
            end
          end
        end
      end

     ## MAKE FINAL QUERY FOR ONLY FILES THAT WILL BE RETURNED TO USER ##
     
     @sql += buildFinalResultCondition + " ORDER BY " + @sql_sorting
    
     #puts
     #puts "SQL sorting:"
     #puts @sql_sorting
     #puts
     
     puts "Final result query: "
     puts @sql
     count = @sql.gsub(@select_part1, "SELECT COUNT(*) AS entries").gsub(/\sORDER BY.*$/, "").gsub!(/\:\w+/) do |s|
      "'" + @condition_values[s.gsub(":", "").intern].to_s + "'"
     end
     
     entries = Devfile.count_by_sql(count)
     
     if params[:qcluster]
       
       # Doesn't use will_paginate
       @condition_values.each do |cond, val|   
        @sql = @sql.gsub(":#{cond.to_s}", "'#{val.to_s}'")
       end
       @results = Devfile.find_by_sql(@sql)
       
     else
       @results = Devfile.paginate_by_sql [@sql, @condition_values],
                                          :page => @show_page,
                                          :per_page => @results_per_page,
                                          :total_entries => entries
     end
     
     
      # LINK METADATA to right devfile from @results. Save metadata to @metadatas
      @metadatas = {}
      linkMetadataToResults(metas)
    end

    
    if @queryparams[:what_to_get] =~ /devices/i
      @device_ids = Array.new
      @onlinelist = Hash.new
      @results.each do |dev|
        @device_ids.push(dev.id)
        # check status
        if dev.last_seen > device_online_timeout
          @onlinelist.merge!({dev.id => true})
        else
          @onlinelist.merge!({dev.id => false})
        end
      end
    end

    # host parameter, needed when creating atom-feed
    if request.ssl?
      @host = "https://#{request.host}"
    else
      @host = "http://#{request.host}"
    end

    if request.port != nil and request.port != 80
      @host += ":#{request.port}"
    end



    #
    # The results can now be returned as YAML also
    #
    # => When using parameter localhost_context_polling, returns only an array of devfile_id:s
    # 
    if @queryparams[:format] == "yaml" or @queryparams[:format] == "json"
      puts "Formaatti: " + @queryparams[:format].to_s
      
      if params[:localhost_context_polling] == "true"
        @yaml_results = []
      else
        @yaml_results = {}
      end
      
      @json_ordered = false
      @json_results = "{  "
      
      @results.each do |df|
        begin
          
          @json_temp = {}
          
          # For polling the contexts from localhost
          if params[:localhost_context_polling] == "true"
            #puts "localhost_context_polling"
            brp = df.devfile_id.to_s
            @yaml_results << df.devfile_id.to_s
          
          # For query results
          else
            if @queryparams[:what_to_get] =~ /devices/i
              # If requesting devices
              devObject = DeviceObject.new(df)
              @yaml_results.merge!({devObject.get_uri => devObject.to_yaml})
              if @queryparams[:json_callback]
                @json_callback = @queryparams[:json_callback]
              end

            else
              # If requesting files
              id = @host+url = "/user/" + df.username + "/device/" + df.dev_name + "/files" + df.path + df.name
              brp = BlobRepresentation.new(df.blob_id).to_yaml
              @yaml_results.merge!({id => brp})    
              
              @json_ordered = true    
              @json_temp.merge!({id => brp})
              @json_results += JSON.dump({id => brp})[1..-2]
              @json_results += "," 
              
            end
          end
          
        rescue Exception => e
          putsE(e)
        end
      end
      @json_results = @json_results[0..-2]
      @json_results += "}"
      #puts @yaml_results.to_s
    end

=begin

    # FileObservers for html interface:
    if (@user and not @queryparams[:format]) or (@user and @queryparams[:format] == "html")
      if @user.xmpp_jid != nil && @user.xmpp_pw != nil && @user.xmpp_host != nil
        client_info = {:id => @user.xmpp_jid+'@visualrest.cs.tut.fi', :psword => @user.xmpp_pw,
                       :host => @user.xmpp_host, :port => 5222, :plain_id => @user.xmpp_jid,
                       :node_service => "pubsub.#{@user.xmpp_host}"}
        @node_names = XmppHelper::getMyNodes(client_info, true)
      end
    end
=end




    if params[:qcluster]
      clusterResults
      @render = :getclusters
    end


    if query_processing_time_begin != nil
      query_processing_time_end = Time.now
      @query_processing_time = query_processing_time_end - query_processing_time_begin
      puts "Time used for processing query: #{@query_processing_time}"
    end



    #############################################
    #
    #  RENDERING
    #
    ##############################################

    @host = @@http_host
    
    
    
    respond_to do |format|
      if @queryparams[:format] == nil
        format.html {render @render}
      else
        format.html {render @render}
        format.atom { render @render, :layout=>false }
        format.yaml { render :text => YAML.dump(@yaml_results), :layout=>false }
        if @json_ordered == true
          if @json_callback == nil
            format.json { render :text => @json_results, :layout=>false }
          else
            format.json { render :text => @json_callback + '('+@json_results+ ')', :layout=>false }
          end          
        end
        if @json_callback == nil
          format.json { render :text => JSON.dump(@yaml_results), :layout=>false }
        else
          format.json { render :text => @json_callback + '('+JSON.dump(@yaml_results)+ ')', :layout=>false }
        end
      end
    end
  end

  
  
  
  def clusterResults
    
    @no_clusters_uri = request.url.to_s.gsub(/\&?qcluster\[\w+\]=\w+/i, "")
    @no_clusters_uri = @no_clusters_uri.gsub(/\&?qcluster\[\w+\]=/i, "")
    @no_clusters_uri = @no_clusters_uri.gsub(/\&?qcluster\[\w+\]/i, "")
    puts "NO CLUSTERS URI #{@no_clusters_uri}"
    puts "begin res count: #{@results.count.to_s}"
    
    
    @clustered_by = ""
    
    # Creates ContentObjects of the results
    @content_objects = []
    @results.each do |result| 
      co = ContentObject.new(result, @metadatas)
      @content_objects << co
    end
    
    
    
#    @content_objects.each do |co|
#      puts "filedate: #{co.updated_at}, name: #{co.name}"
#    end

    
    temp = ClusterObject.new("", "", nil, @content_objects)
    

    @cluster_objects = []
    @cluster_objects << temp
    
    @turn_down_content_objects = Array.new
    
    
    #
    #  Clusters by each qcluster key
    #
    params[:qcluster].each do |key, value|
      
    
      
      puts "avain: #{key.to_s}  arvo: #{value.to_s}"
      
      if key == nil #|| value == nil
        next
      end
      
      
      # Ensures that the given metadata key is valid type, and checks whether it is string, float, or date
      value_type = MetadataHelper.new.get_metadata_value_type(key)
      if not value_type
        puts "value type not found!"
        next
      end
      
      if @clustered_by.empty?
        @clustered_by = key
      else
        @clustered_by += ", #{key}"
      end
    
      # Sets the maximum range between the metadata values
      maxRange = value.to_f
    
      
      @temp_cluster_objects = Array.new
    
#puts "#####################################################"
#puts "#    cluster BY KEY: #{key}"
#puts "#####################################################"
    
      @cluster_objects.each_with_index do |cluster_obj, index|
    
#puts "*********************************************"
        
        old_range_string = cluster_obj.get_range_string_with_type
        old_uri_params = cluster_obj.get_uri_params
        
        
        
        @content_objects = cluster_obj.get_content_objects
      
        # Sorts by the clustering metadata key
        ContentObject.setSortBy(key)
        @content_objects.sort!
        
        
        # The actual clustering
        @content_objects.each_with_index do |content_obj, content_index|
          
          value = content_obj.get_value(key)
          
          if not value
            # Currently skipping, later on adds to end of the results, not to a cluster
            @turn_down_content_objects << content_obj
            #puts "value not found"
            next
          end
          
          
          
          if value_type == :string
          
            #puts "STRING value type"
          
            # Notice! this expects that the values are ordered in alphabetical order!
            if @temp_cluster_objects.last and value == @temp_cluster_objects.last.get_comparison_value and content_index != 0
              @temp_cluster_objects.last << content_obj 
            else  
              
              new_cluster_obj = ClusterObject.new(key, @no_clusters_uri, maxRange, nil, old_range_string, old_uri_params)
              new_cluster_obj << content_obj
              @temp_cluster_objects << new_cluster_obj
              
            end
          
          else  # If not string -> Comparable
            
            
           # puts "OTHER THAN STRING Comparable: #{key.to_s}   value: #{value.to_s}"
            
            if @temp_cluster_objects.last and value - maxRange < @temp_cluster_objects.last.get_comparison_value and content_index != 0
              @temp_cluster_objects.last << content_obj
              
              #puts "yks: #{content_obj.get_value("name")}"
            
            
            else
               
              new_cluster_obj = ClusterObject.new(key, @no_clusters_uri, maxRange, nil, old_range_string, old_uri_params)
              new_cluster_obj << content_obj
              @temp_cluster_objects << new_cluster_obj
              
              #puts "kaks"
              
            end
          end

          # NEXT content object
        end



        # NEXT cluster object        
        
        
        puts "index: #{index.to_s}"
        if index == @cluster_objects.count - 1
#puts "Last object in the cluster array => @cluster_objects = @temp_cluster_objects"
          
          @cluster_objects = @temp_cluster_objects
          @temp_cluster_objects = Array.new
          
        end

      
      end # @cluster_objects.each
      
      
      # NEXT cluster by key
      

      
      Thread.new{
        # Luodaan thumbnailit
        @cluster_objects.each do |cluster_obj|
          cluster_obj.generate_thumbnail  
        end
      }
      
      
      
    end
    
#    puts "################ sortattu ########################"   
#    @content_objects.each do |co|
#      puts "filedate: #{co.updated_at}, name: #{co.name}"
#    end
    

  end
  
  
  def puts_content_objects(array_of_mdtypes)
    
    puts "*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*#*"
    
    @content_objects.each do |co|
      
      array_of_mdtypes.each do |type|
        print type + " : " + co.get_value(type).to_s + ';  '
      end
      puts ' '
      
    end
  end
  
  
  

  
  
  def sortBy(metadata_key)
    @results.each do |file_metadata|
      
      dkey = "/user/#{file_metadata.username}/device/#{file_metadata.dev_name}/files#{file_metadata.path+file_metadata.name}"
      
      puts "dkey: #{dkey}"
      
      #if @res2[dkey]
        
      #else
        
      #end
    
    end
  end
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  # Get list of all versions of a single file
  #
  # Parameters: required parameters from path-variables. Optional query-parameters:
  #               versions - you can specify what versions to include in the list
  #               order - ASC|DESC, order of versions
  #               format - to get the list as atom-feed
  #
  # Method gets list of all versions of a single file.
  #
  # Usage:
  #    Send GET to /user/{username}/device/{devicename}/fileversions/{filepath}[?query]
  #      or GET to /device/{deviceid}/fileversions/{filepath}[?query]
  #
  def getVersionlist
    
    @queryparams = params
    
    @render = :versionlist
    @select_part1 = @@devfile_select_part1
    @select_part2 = "from devfiles, devices, users, blobs WHERE"
    @default_id_conditions = "AND devfiles.device_id = devices.id AND devices.user_id = users.id AND blobs.devfile_id = devfiles.id"
    @default_sorting = @@devfile_sorting
    @condition_values = Hash.new
    getPathAndFilename
    @versionlist_conditions = "devfiles.path = :path and devfiles.name = :filename"
    @condition_values[:path] = @path
    @condition_values[:filename] = @filename
    
    if @queryparams[:deviceid]
      @versionlist_conditions += " and devices.id = :devid"
      @condition_values[:devid] = @queryparams[:deviceid]
    elsif @queryparams[:devicename] and @queryparams[:username]
      @versionlist_conditions += " and devices.dev_name = :devname and users.username = :username"
      @condition_values[:devname] = @queryparams[:devicename]
      @condition_values[:username] = @queryparams[:username]
    end
puts "foo"
puts @queryparams[:versions]
puts "bar"   
    if @queryparams[:versions] =~ /^[\d ]+$/ or @queryparams[:versions] =~ /^\d+$/
      versions = @queryparams[:versions].split(" ")
      if versions.size > 0
        i = 1
        @versionlist_conditions += " and blobs.version in ("
        versions.each do |v|
          if i > 1
            @versionlist_conditions += ", :ver#{i}"
          else
            @versionlist_conditions += ":ver#{i}"
          end
          @condition_values["ver#{i}".intern] = v
          i += 1
        end
        @versionlist_conditions += ")"
      end
    end
    
    if @queryparams[:order] =~ /^asc$/i
      @versionlist_sorting = @@versions_sorting + " ASC"
    else
      @versionlist_sorting = @@versions_sorting + " DESC"
    end
    
    makeSearch
    
    if @results.size == 0
      if @queryparams[:format] != "atom"
        @nothingfound = true
        render @render
        return
      else
        render :text => "Nothing found", :status => 404
        return
      end
    end
    
    # Check that user has right to view files
    if checkFileRightstoResultsinVersionlist == false
      if @queryparams[:format] != "atom"
        @forbidden = true
        render @render
        return
      else
        render :text => "You are not permitted to access this versionlist", :status => 404
        return
      end
    end

=begin
    # Finds if file versions (blobs) has branches, and adds that information to the results
    @results.each do |r|
      puts "r: " + r.to_s
      
      
      details = Hash.new
      
      Branch.find(:all, :conditions => ["parent_blob_id = ?", r.id]).each do |branch|
        puts "meni"
        details.merge!(getBlobDetailsByBlobID(branch.child_blob_id))
      end

      r['branch_details'] = details
      puts "r.t 2: " + r.branch_details.to_s

    end
=end
    

    # Is user signed in
    if params[:i_am_client]
      username = authenticateClient
    elsif session[:username]
      username = session[:username]
    end
    
    if username != nil
      @signed_in_user = username
    end

    @host = @@http_host
    respond_to do |format|
      if @queryparams[:format] == nil
        format.html {render @render}
      else
        format.html {render @render}
        format.atom { render @render, :layout=>false }
      end
    end
  end
  
  
  def getBlobDetailsByBlobID(blob_id)
    
    @queryparams = params
    
    blob = Blob.find_by_id(blob_id)
    devfile = Devfile.find_by_id(blob.devfile_id)
    device = Device.find_by_id(devfile.device_id)
    user = User.find_by_id(device.user_id)
    r = {'blob' => blob, 'devfile' => devfile, 'device_name' => device.dev_name, 'user_name' => user.username}
    
    return r
    
  end
  
  def search
    
  end
  
  
  # Search for users
  #
  # Parameters: user - usernames to search separated by "+"
  #
  # Method searches for users with given searchterm and returns a view for web-UI.
  #
  def searchUsers
    
    
    query_processing_time_begin = Time.now
    # In web-ui query processing time is only shown if asked. In atom-feed, it is always shown.
    if params["query_processing_time"] && params["query_processing_time"].downcase == "true"
      @query_processing = true
    end
    if params[:qoption] && params[:qoption]["query_processing_time"] == "true"
      @query_processing = true
    end
    
    @json_callback = nil
    if params[:qoption] && params[:qoption]["json_callback"]
      @json_callback = params[:qoption]["json_callback"]
    end
    
    @queryparams = params

    if params[:qoption] && params[:qoption]["format"]
      @queryparams[:format] = params[:qoption]["format"]
    end
    
    if params[:q] && params[:q]["user"]
      @queryparams[:user] = params[:q]["user"]
    end
    
    
    # host parameter, needed when creating atom-feed
    if request.ssl?
      @request_url = "https://#{request.host}"
    else
      @request_url = "http://#{request.host}"
    end

    if request.port != nil and request.port != 80
      @request_url += ":#{request.port}"
    end
    
    @request_url += request.request_uri

    @query_search = ""
    if @queryparams[:user] and @queryparams[:user] !~ /[^\w\.\s\-\_\+]/
      @query_search = @queryparams[:user]
      usersstring = searchtermForSql(@queryparams[:user], "username") + " OR " + searchtermForSql(@queryparams[:user], "real_name")
      @users = User.find(:all, :conditions => usersstring)
    end 
    
    if @queryparams[:format] == "yaml" or @queryparams[:format] == "json"
      @yaml_results = {}
      @users.each do |user|
        begin

          userObject = UserObject.new(user)
          @yaml_results.merge!({userObject.get_uri => userObject.to_yaml})
        
        rescue Exception => e
          putsE(e)
        end
      end
      #puts @yaml_results.to_s
    end
    
    if query_processing_time_begin != nil
      query_processing_time_end = Time.now
      @query_processing_time = query_processing_time_end - query_processing_time_begin
      puts "Time used for processing query: #{@query_processing_time}"
    end
    
    # Renderöinti
    @host = @@http_host
    respond_to do |format|
      if @queryparams[:format] == nil
        format.html {render :searchUsers, :layout=>true }
      else
        format.html {render :searchUsers, :layout=>true }
        format.atom {render :searchUsers, :layout=>false }
        format.yaml { render :text => YAML.dump(@yaml_results), :layout=>false }
        if @json_callback == nil
          format.json { render :text => JSON.dump(@yaml_results), :layout=>false }
        else
          format.json { render :text => @json_callback + '(' + JSON.dump(@yaml_results) + ')', :layout=>false }
        end
      end
    end
    
  end

  
  
  # Show instructions in web-UI
  #
  def doInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def fileQueryInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def contextInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def authenticationInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def virtualDeviceInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def emailInstructions
    # do absolutely nothing at all... just render instructions
  end

  def flickrInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def facebookInstructions
    # do absolutely nothing at all... just render instructions
  end

  def dropboxInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def twitterInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def userInstructions
    # do absolutely nothing at all... just render instructions
  end

  def containerInstructions
    # do absolutely nothing at all... just render instructions
  end
  
  def rubyContainer
    # do absolutely nothing at all... just render instructions
  end
  
  def androidContainer
    # do absolutely nothing at all... just render instructions
  end


  # Checks and updates device status on web page, depending on the last seen values. 
  #
  # parameters: List of devices must be given. 
  def checkDeviceStatus
   
    @user = User.find(:first, :conditions => ["username = ? ", session[:username]])    
    @onlinelist = {}
    sql = "SELECT devices.*, users.username from devices, users WHERE devices.user_id = users.id AND users.id = #{@user.id.to_s} ORDER BY devices.dev_name"
    @results = Device.find_by_sql(sql)
    #@results = Device.find(:all, :conditions => ["user_id = ?", @user.id])
    @results.each do |dev|
      status = "offline"
      #puts "#{dev.last_seen.to_s} #{device_online_timeout.to_s}"
      if dev.last_seen > device_online_timeout
        @onlinelist.merge!(dev.id => true)
      else
        @onlinelist.merge!({dev.id => false})
      end
    end
    
    if @results and not @results.empty?
      render :update do |page|
        page['device_list'].replace_html :partial => 'devicelist'  
      end
    else
      return
    end
  end  





  # Changes file version in web-UI's filelist (ajax-stuff)
  def changeFileOnView
    
    @queryparams = params

    if @queryparams[:thumb_up] && @queryparams[:thumb_up] == "true"
      devfile = Devfile.find_by_id(@queryparams[:file_devfile_id])
      devfile.update_attribute(:rank, devfile.rank + 1)
    end
    
    if @queryparams[:thumb_down] && @queryparams[:thumb_down] == "true"
      devfile = Devfile.find_by_id(@queryparams[:file_devfile_id])
      value = devfile.rank - 1
      if value < 0
        value = 0
      end
      devfile.update_attribute(:rank, value)      
    end
    
    if @queryparams[:showMetadata] && @queryparams[:showMetadata] == "true"
      @showMetadata = "true"
    end
    
    
    @metadatatypes = MetadataType.find(:all, :order => "updated_at ASC" )
    
    metadata_select = metadata_select = @@metadata_select_part1 + @@metadata_select_part2+ @@metadata_conditions  + " AND devfiles.id = " + @queryparams[:file_devfile_id] + " ORDER BY metadatas.devfile_id, metadatas.updated_at"      
    metas = Metadata.find_by_sql(metadata_select)
      
    @metadatas = {}
    @results = Metadata.find_all_by_devfile_id(@queryparams[:file_devfile_id])
    linkMetadataToResults(metas)

    
    if session[:username]
      @signed_in_user = session[:username]
      @user = User.find(:first, :conditions => ["username = ?", session[:username]])
      @device_names = Array.new
      @user.devices.each do |d|
        @device_names.push(d.dev_name)
      end
    end
    
    puts "FUUUPAAR"
    @ttest = "jeps"
    
    puts "Alkaa".background(:blue)
    dev_file = Devfile.find_by_id(@queryparams[:file_devfile_id])
    puts dev_file.name.background(:blue)
    blob = Blob.find_by_id(@queryparams[:blob_update_id])

    @user_username = @queryparams[:username]
    @device_dev_name = @queryparams[:device_name]
    @device_id = @queryparams[:device_id]
    @file_path = dev_file.path
    @file_name = dev_file.name
    @file_rank = dev_file.rank

    @file_type = dev_file.filetype
    @file_devfile_id = dev_file.id
    @file_created_at = dev_file.created_at.strftime('%F %T').to_s

    @file_privatefile = dev_file.privatefile
    @blob_size = blob.size
    @blob_version = blob.version
    @blob_filedate = blob.filedate.strftime('%F %T').to_s
    @blob_modified_at = blob.updated_at.strftime('%F %T').to_s
    @blob_id = blob.id
    @blob_uploaded = blob.uploaded
    @blob_thumbnail_name = blob.thumbnail_name
    @blob_predecessor_id = blob.predecessor_id
    @blob_follower_id = blob.follower_id
    @blob_hash = blob.blob_hash
    @fullpath = (@file_path + @file_name.gsub(/[\s]/, '%20'))[1..-1]
    
    @file_uri = '/user/' + @user_username + '/device/' + @device_dev_name + '/files/' + @fullpath
    
    puts "Renderointi"
    render :update do |page|
      page[@queryparams[:file_devfile_id]].replace_html :partial => 'file'#, :locals => {:status => stat, :image => @queryparams[:image]} 
    end
    
  end
  
  
  
  # Get 3 suggestions for place names
  #
  # Parameters: location - part of location string, from which suggestions will be createdb-UI or as a feed (.atom must be specified)
  #
  # Method uses geonames to get suggestions
  #
  # Usage:
  #   Files:
  #    Send GET to /location/tags?location={location}
  def suggestLocation
    
    @queryparams = params
    
    # Check that param location is given
    if @queryparams[:location] == nil
      render :text => "No search parameter given"
      return
    end

    # url, where to get suggestions
    url = URI.parse('http://ws.geonames.org/search?country=FI&maxRows=5&style=short&name_startsWith='+@queryparams[:location].strip)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.get('/search?country=FI&maxRows=5&style=short&name_startsWith='+@queryparams[:location].strip)
    }
    
    # Parse result from geonames
    xml = res.body
    if xml != nil
      doc = XML::Document.string(xml)
      
      # Get all result elements
      geoname_elements = doc.find('//geonames/geoname')
      @suggested_names = {}
      geoname_elements.each do |element|
        sug_name = element.find_first('name')  ? element.find_first('name').content : nil
        @suggested_names.merge!({sug_name => nil})
  
      end
    end
   
    # host parameter, needed when creating atom-feed
    if request.ssl?
      @request_url = "https://#{request.host}"
    else
      @request_url = "http://#{request.host}"
    end

    if request.port != nil and request.port != 80
      @request_url += ":#{request.port}"
    end
    
    @request_url += request.request_uri
     
   @host = @@http_host
    respond_to do |format|
      if @queryparams[:format] == nil
        format.html {render :suggestlocation}
      else
        format.html {render :suggestlocation}
        format.atom { render :suggestlocation, :layout=>false }
      end
    end
  end
  
  
  
  
 
 
  
  
  
  
  #--------------------------------------------------------------------------------------------
  # ---- PRIVATE METHODS ----------------------------------------------------------------------  
  private
  
  def validateKeyAsFloatOrDateOrDatetimeType(key)
    type = MetadataType.find_by_name(key)
    if type != nil
      if type.value_type == "float" || type.value_type == "date" || type.value_type == "datetime"
        return true
      end
    end
    
    # Also possible for: rank, size, date
    if key == "rank" || key == "size" || key == "modified_at" || key == "created_at"
      return true
    end
    return false
  end
  
  def goThroughMetadataSearchTermsV2(metadata_search_terms)
    
    # Go through search terms
    metadata_search_terms.each do |key, val|
  
      # This prevents datetime in value from being splitted    
      if QueryController::check_datetime(val[1])
        values=val[1]
      else
        values = val[1].split(' ')
      end
      
      # in case search term has many values, go trough all of them
      values.each do |value|
        
        # values that match this search parameter
        tempArray = Array.new
  
        # Find the type      
        type = MetadataType.find_by_name(key)
        if type != nil
          
          # See what type of metadatatype you are comparing (string/float/date)
          ### If value type is "string" ###
          if val[0] == "string"
            metadataCompareString(type.id, value, tempArray)
    
          ### If value type is "float" ###
          elsif val[0] == "float"
            metadataCompareFloat(type.id, value, tempArray)
            
          ### If value type is "date" ###
          elsif val[0] == "date" || val[0] == "datetime"
            metadataCompareDate(type.id, value, tempArray)
          end
        end
          
        # Does the sparse thingy.
        # If sparse true -> adds to search results files that don't have the searched metadatatype
        if @sparseAllParams == true || ( @qSparse != nil && @qSparse[key] && @qSparse[key] == "true")
          # Do sparse true for 'key'
          metadataCompareSparse(key, tempArray)
        end
        
        if tempArray.size != 0
          # This will be a clause in 'where' in final sql-query for results
          @only_allowed_in_results.push(tempArray)
        end
      end # values.each end
    end #metadata_search_terms.each end
    
    # This makes sure that if parameters given and no results found, returns zero results
    if metadata_search_terms.size != 0 && @only_allowed_in_results.size == 0
      @only_allowed_in_results.push([-1])
    end
    
  end

  # Called from goThroughMetadataSearchTermsV2.
  # Finds matching metadata from database.
  # Sets @only_allowed_in_results accordingly
  def metadataCompareString(type_id, value, tempArray)
    # Find from database all matching metadata
    tmps = Metadata.find(:all, :conditions => ["metadata_type_id = ? and value like ?", type_id, "%"+value+"%"])
    
    if tmps != nil
      tmps.each do |x|
        tempArray.push(x.devfile_id)
      end
    end
  end
  
  # Called from goThroughMetadataSearchTermsV2.
  # Finds matching metadata from database.
  # Sets @only_allowed_in_results accordingly
  def metadataCompareFloat(type_id, value, tempArray)
    comparison = "="
    if value[-1..-1] == '>'                            # bigger
      value = value[0..-2]
      comparison = ">"
      puts "BIGGER"
      
    elsif value[-1..-1] == '<'                         # smaller
      value = value[0..-2]
      comparison = "<"
      puts "SMALLER"
      
    elsif value[-1..-1] == '=' && value[-2..-1] == '>=' # min
      value = value[0..-3]
      comparison = ">="
      puts "MIN"
    elsif value[-1..-1] == '=' && value[-2..-1] == '<=' # max
      value = value[0..-3]
      comparison = "<="
      puts "MAX"
    end

    # Check that param is float
    if value !~ /^\s*[+-]?((\d+_?)*\d+(\.(\d+_?)*\d+)?|\.(\d+_?)*\d+)(\s*|([eE][+-]?(\d+_?)*\d+)\s*)$/
      raise Exception.new("Invalid float value")
    end
    
    sql = "SELECT id, value, devfile_id, metadata_type_id" +
           " FROM metadatas" +
           " WHERE metadata_type_id = #{type_id} AND CONVERT(value, SIGNED)#{comparison}#{value}"
     puts sql
     tmps = Metadata.find_by_sql(sql)      
    
    if tmps != nil
      tmps.each do |x|
        tempArray.push(x.devfile_id)
      end
    end
  end
  
  
  # Called from goThroughMetadataSearchTermsV2.
  # Finds matching metadata from database.
  # Sets @only_allowed_in_results accordingly
  def metadataCompareDate(type_id, value, tempArray)
    comparison = "="
    if value[-1..-1] == '>'                            # bigger
      value = value[0..-2]
      comparison = ">"
      
    elsif value[-1..-1] == '<'                         # smaller
      value = value[0..-2]
      comparison = "<"
      
    elsif value[-1..-1] == '=' && value[-2..-1] == '>=' # min
      value = value[0..-3]
      comparison = ">="
      
    elsif value[-1..-1] == '=' && value[-2..-1] == '<=' # max
      value = value[0..-3]
      comparison = "<="
      
    end

    # If value is full datetime, use it as it is
    if QueryController::check_datetime(value)
      datetimeOrDate = "CONVERT(value, DATETIME)#{comparison}'#{value}'"
    else

      # If searching with year and month
      if value =~ /^\d{4}\-\d{1,2}$/
        # First day of month
        valueFirst = value+'-01'
        
        # Date in this exact month
        if comparison == '='
          datetimeOrDate = "CONVERT(value, DATE)>='#{valueFirst}' AND CONVERT(value, DATE)<=LAST_DAY('#{valueFirst}')"
          
        # Date bigger than this month
        elsif comparison == '>'
          datetimeOrDate = "CONVERT(value, DATE)#{comparison}LAST_DAY('#{valueFirst}')"

        # Date max this month
        elsif comparison == '<='
          datetimeOrDate = "CONVERT(value, DATE)#{comparison}LAST_DAY('#{valueFirst}')"
          
        # Date smaller than this month
        elsif comparison == '<'
          datetimeOrDate = "CONVERT(value, DATE)#{comparison}'#{valueFirst}'"
          
        # Date min this month
        elsif comparison == '>='
          datetimeOrDate = "CONVERT(value, DATE)#{comparison}'#{valueFirst}'"
        end
        

      
      # If searching with only year
      elsif value =~ /^\d{4}$/
        datetimeOrDate = "YEAR(value)#{comparison}'#{value}'"
      else

        # Check if value_number is date and convert it if needed
        valueNew = QueryController::transform_date(value)
        if valueNew == false
          raise Exception.new("Invalid date value")
        end
        datetimeOrDate = "CONVERT(value, DATE)#{comparison}'#{valueNew}'"
      end
      
      
    end

    sql = "SELECT id, value, devfile_id, metadata_type_id" +
          " FROM metadatas" +
          " WHERE metadata_type_id = #{type_id} AND #{datetimeOrDate}"
     puts sql
     tmps = Metadata.find_by_sql(sql)      
    
    if tmps != nil
      tmps.each do |x|
        tempArray.push(x.devfile_id)
      end
    end
  end
  
  # Sparse for metadata comparing
  def metadataCompareSparse(key, tempArray)
    
    # Find all files that don't have the metadatatype
    type = MetadataType.find_by_name(key)
    if type == nil
      return
    end
    
    @results.each do |x|
      tmp = Metadata.find_by_metadata_type_id_and_devfile_id(type.id, x.devfile_file_id)
      if tmp == nil
        tempArray.push(x.devfile_file_id)
      end
    end
  end

  
  
  
  # Goes through metadata from metas and puts it to
  # @metadatas, according to id:s from @results
  def linkMetadataToResults(metas)

    # Go through metadata
    # m - has all metadata combined
    m = {}       
    metas.each do |t|
      # Skip metadata from old blobs
      if t.metadata_blob_id != nil && t.devfile_blob_id != t.metadata_blob_id
        next
      end
          
      # n - has metadata of one file  
      n = {}
        
      store = m[t.devfile_id]
          
      # Is there already data for this devfile_id
      if store == nil
        # No data for this devfile yet, create it
        n.merge!({t.metadatatype => t.metadata_value})
          
        # Add metadata of this file to combined metadata
        m.merge!({t.devfile_id => n })

      else
        block = store[t.metadatatype]

        # Is there already this metadatatype
        if block == nil
          # Create the new metadatatype for this file
          store.merge!({t.metadatatype => t.metadata_value})
        elsif t.metadatatype == "tag" or t.metadatatype == "context_hash"
          # Add new metadatatype for this file
          store.merge!({t.metadatatype => block + ", " + t.metadata_value})
        end
            
        # Add metadata of this file to combined metadata
        m.merge!({t.devfile_id => store })   
      end
    end  
      
          
      
      
    # link metadata to right result, with hash
    @results.each do |r|
      mdata = m[r.devfile_id.to_i]
      if mdata != nil
        #puts "r: #{r.devfile_file_id.to_s}"
        @metadatas.merge!({r.devfile_id.to_i => mdata})
      end
    end
    
    

    
      
  end
  
  
  
  
  
  # Set default strings
  #
  # Method sets default string depending on the "what_to_get"-parameter (files/devices).
  #
  def setDefaultStrings #:doc:
    # get either devfiles or devices
    if @queryparams[:what_to_get] =~ /files/i
      @render = :getfiles
      @keywords1 = @@devfile_keywords1
      @keywords2 = @@devfile_keywords2
      @keywords3 = @@devfile_keywords3
      @sort_by = @@devfile_sort_by
      @condition_rules = @@devfile_condition_rules
      @select_part1 = @@devfile_select_part1
      @select_part2 = @@devfile_select_part2
      @default_id_conditions = @@devfile_default_id_conditions
      @default_sorting = @@devfile_sorting
    elsif @queryparams[:what_to_get] =~ /devices/i
      @render = :getdevices
      @keywords1 = @@device_keywords1
      @keywords2 = @@device_keywords2
      @keywords3 = @@device_keywords3
      @sort_by = @@device_sort_by
      @condition_rules = @@device_condition_rules
      @select_part1 = @@device_select_part1
      @select_part2 = @@device_select_part2
      @default_id_conditions = @@device_default_id_conditions
      @default_sorting = @@device_sorting
    end
  end
 
  # This is used for processing params listed in @@devfile_keywords3
  def processLaterAddedParamTypes(keyword, value) 
    key, val = processValuesV2(keyword, value)
    puts
    puts key
    puts val
    puts
    if @condition_rules.has_key?(key)

      if val == "FALSE"
        return false
      end  
      
      puts "KEY #{key}.... val:#{val}"
      @conditions.merge!({key, val})
    else
      return false
    end
    return true
  end

  # Processing of certain values, such as rank, size, date
  def processValuesV2(keyword, value)
    key_orig = keyword
    comp = ""

    if value[-1..-1] == '>'                            # bigger
      value = value[0..-2]
      keyword = keyword + "bigger"
      comp = "bigger"
      
    elsif value[-1..-1] == '<'                         # smaller
      value = value[0..-2]
      keyword = keyword + "smaller"
      comp = "smaller"
      
    elsif value[-1..-1] == '=' && value[-2..-1] == '>=' # min
      value = value[0..-3]
      keyword = keyword + "min"
      comp = "min"
      
    elsif value[-1..-1] == '=' && value[-2..-1] == '<=' # max
      value = value[0..-3]
      keyword = keyword + "max"
      comp = "max"
    end

    if key_orig == "modified_at" || key_orig == "created_at"
      if value =~ /^\d{4}$/
        keyword += "year"
      
      elsif value =~ /^\d{4}\-\d{1,2}$/
        if comp == "bigger" || comp == "max"
          value += '-31'
        elsif comp == ""
          # This is a piece of jenkki-purukumi, When searching for files in a month.
          # This is the first search and from 'value' and 'keyword' will be generated another one
          @conditions.merge!({keyword+'mindate', value+'-01'})
          value += '-31'
          keyword += 'max'
        else
          value += '-01'
        end
        keyword += "date"
       # keyword += "month"
      elsif value =~ /^\d{4}\-\d{1,2}\-\d{1,2}$/
        keyword += "date"
      elsif QueryController::check_datetime(value)
        puts "datetime: true"
      else
        keyword = "FALSE"
      end
    end


    return keyword, value
  end 
  
  # Process given query parameter
  #
  # Parameters: keyword - query keyword
  #             value - given value to the parameter
  #             allow_many_values - true if value can include many separate values separated by " "
  #
  # Method validates value, does transformations for sizes and dates and adds keyword-value-pair
  # to @conditions
  # 
  # Returns false if error.
  #  
  def processParam(keyword, value, allow_many_values) #:doc:
    # validate value(s) and if many values, separate terms
    values = nil
    regexp = /[^\w\_\-\.]/
    if allow_many_values
      regexp = /[^\w\s\_\-\.]/
    end
    if not value =~ regexp
      values = value.split(" ")
    else
      return false
    end
    
    # do transformations into correct form for sizes, dates and states
    if keyword =~ /^.+size$/ or keyword =~ /.+before$/ or keyword =~ /^.+after$/ or (keyword =~ /state/i and @context[:user] and @context[:device])
      if keyword =~ /^.+size$/
        values = transform_size(values.first)
      elsif keyword =~ /.+before$/ or keyword =~ /^.+after$/
        values = QueryController::transform_date(values.first)
      elsif keyword =~ /state/i and @context[:user] and @context[:device]
        values = processState(value)
      end
      if values == false
        return false
      elsif values == :nothingfound
        return values
      elsif values == :combined or values == :default
        return true
      else
        values = [values]
      end
    end
    
    # get location parameters ONLY if the context is defined
    if keyword == "lat" or keyword == "lon" or keyword == "distance"
      if (@context.empty? and @device_ids.empty?)
        return true
      end
      if keyword == "distance" and value[-1, 1].downcase == "m"
        @locationdata.merge!({keyword => value.to_f * 1000})
        return true
      end
      @locationdata.merge!({keyword => value})
      return true
    end
  
    # add to search conditions
    if @condition_rules.has_key?(keyword)
      processed_values = processValues(keyword, values)
      @conditions.merge!({keyword => processed_values})
    end
  end
  
   
  # Process values of a parameter
  # 
  # Helper method for processParam
  def processValues(keyword, values) #:doc:
    new_values = []
    if keyword == "type" or keyword == "search" or keyword == "filename" or keyword == "path"
      values.each do |value|
        new_values.push("%" + value + "%")
      end
      return new_values
    end
    return values
  end


  # Process value of parameter 'state'
  #
  # Helper method for processParam
  def processState(value) #:doc:
    if value =~ /^\d+$/ or value =~ /^-\d+$/ or value =~ /original/i
      order = "ASC"
      if value =~ /^-\d+$/
        order = "DESC"
        value = value[1..-1]
      end
      if value =~ /original/i
        value = "1"
      elsif value == "0"
        return false
      end
      commits = Commit.find(:all, :conditions => ["device_id = ?", @context[:device].id],
                            :order => "previous_commit_id " + order, :limit => value.to_i)
      if value.to_i > 0 and commits.size == value.to_i
        @default_id_conditions = @@devfile_id_conditions_without_commit
        return commits.last.id
      else
        return :nothingfound
      end
    elsif value =~ /current/i
      # default
      return :default
    elsif value =~ /combined/i
      @select_part2 = @@devfile_select_part2_without_commit
      @default_id_conditions = @@devfile_id_conditions_all_commits
      return :combined
    elsif value =~ /^\d{4}\-\d{1,2}\-\d{1,2}$/ or value =~ /^\d{1,2}\-\d{1,2}\-\d{4}$/ or value =~ /^\d{8}$/
      value = QueryController::transform_date(value)
      if value == false
        return false
      end
      commits = Commit.find(:all, :conditions => ["device_id = ? and (created_at like ? or created_at < ?)", @context[:device].id, value + "%", value],
                            :order => "created_at DESC", :limit => 1)
      if commits.size > 0
        @default_id_conditions = @@devfile_id_conditions_without_commit
        return commits.first.id
      else
        return :nothingfound
      end
    else
      return false
    end
  end
  
  
  # Get context of the search
  #
  # Method finds out where to look for files/devices from. Method looks for the context in the
  # URL (see method get). Possible query parameters "device" and "user" are also parsed.
  # @context and @device_ids are set accordingly. Returns false if nothing found and true
  # if found something.
  #  
  def getSearchContext #:doc:
    # try get context from the url parameters
    if @queryparams[:deviceid] and @queryparams[:what_to_get] =~ /files/i
      device = Device.find(@queryparams[:deviceid].to_i)
      if device == nil
        # device not found
        return false
      else
        @context.merge!({:device => device, :user => device.user})
        @device_ids.push(@queryparams[:deviceid])
        return true
      end
    elsif @queryparams[:username]
      user = User.find_by_username(@queryparams[:username])
      if user == nil
        # user not found
        return false
      end
      @context.merge!({:user=> user})
      
      if @queryparams[:devicename] and @queryparams[:what_to_get] =~ /files/i
        device = user.devices.find_by_dev_name(@queryparams[:devicename])
        if device != nil
          @device_ids.push(device.id)
          @context.merge!({:device => device})
          return true
        else
          # device not found
          return false
        end
      else
        # check if devicenames specified
        device_names = Hash.new
        device_names_string = ""
        if params["device"]
          if not params["device"] =~ /[^\w\s\_\-\.\*]/
            given_devices = params["device"].gsub("*", "%").split(" ")
            given_devices.each_index do |i|
              device_names.merge!({"dev#{i}".intern => given_devices[i]})
            end
            device_names_string += "dev_name like :dev0"
            device_names.size.times do |i|
              next if i == 0
              device_names_string += " or dev_name like :dev#{i}"
            end
          end
        end
        
        # let's get all devices of the user (or just the specified devices)
        user_devices = nil
        if device_names.size > 0
          user_devices = user.devices.find(:all, :conditions => [device_names_string, device_names])
        else
          user_devices = user.devices
        end
        user_devices.each do |d|
          @device_ids.push(d.id)
        end
        if @device_ids.size > 0
          return true
        else
          # no devices
          return false
        end
      end
    end
    
    # no context and no user/device in search params
    if not (params["user"] or params["device"])
      @query_path = "/files"
      return true
    end
    
    # detect user/device in search params
    users_string = ""
    if params["user"]
      users = nil
      if not params["user"] =~ /[^\w\s\_\-\.\*]/
        users = params["user"].gsub("*", "%").split(" ")
      end
      if users.size > 0
        users_string = "(users.username like '" + users.join("' OR users.username like '") + "')"
      end
    end
    
    devices_string = ""
    if params["device"]
      given_devices = nil
      if not params["device"] =~ /[^\w\s\_\-\.\*]/
        given_devices = params["device"].gsub("*", "%").split(" ")
      end
      if given_devices.size > 0
        devices_string = "(devices.dev_name like '" + given_devices.join("' OR devices.dev_name like '") + "')"
      end
    end
    
    where = ""
    if users_string != "" and devices_string != ""
      where = users_string + " AND " + devices_string
    elsif users_string != ""
      where = users_string
    elsif devices_string != ""
      where = devices_string
    else
      # nothing found
    end
      return false
    
    user_devices = Device.find_by_sql("SELECT devices.id FROM devices, users WHERE #{where} AND devices.user_id = users.id;")
    user_devices.each do |d|
      @device_ids.push(d.id)
    end
    if @device_ids.size > 0
      return true
    else
      # no devices found
      return false
    end
  end

  
  
  # In func 'get', this is used to add groups to search context
  def addGroupsToSearchContext(key, value)
    begin
      owner = User.find_by_username(key)
      if owner == nil
        puts "Couldn't find owner of the group"
        return
      end
      # Split the value, if multiple values
      values = value.split(' ')
      values.each do |x|
        
        # Find the group and users in it
        group = Group.find_by_name(x)
        if group != nil
          group.users.each do |u|
            addUsersToSearchContext(u.username)
          end
          addUsersToSearchContext(owner.username)
        end      
      end
    rescue => e
      puts "Problem adding group to search context. E: #{e}"
    end
  end
  
  # In func 'get', this is used to add users to search context.
  # @context and @device_ids are set accordingly.
  def addUsersToSearchContext(value)
    begin
      values = value.split(' ')
      values.each do |x|
        
        # Find each user and add its information to the search context
        user = User.find_by_username(x)
        if user != nil
          @context.merge!({:user=> user})
          puts "Added user: #{user.username} to the search context"
          user.devices.each do |d|
            @device_ids.push(d.id)
          end
        end
      end
    rescue => e
      puts "Problem adding user to search context. E: #{e}"
    end
  end
  
  
  
  
  # Transform size-related parameter's value to correct form
  #
  # Parameters: size - ( {number} | {number}kb | {number}mb | {number}gb )
  #
  # Method transforms given size to correct form and returns it.
  #    
  def transform_size(size) #:doc:
    multi = 1
    ind = -3
    # get multiplier
    if size[-2..-1].upcase == "KB" or size[-2..-1].upcase == "KT"
      multi = 1024
    elsif size[-2..-1].upcase == "MB" or size[-2..-1].upcase == "MT"
      multi = 1024 * 1024
    elsif size[-2..-1].upcase == "GB" or size[-2..-1].upcase == "GT"
      multi = 1024 * 1024 * 1024
    else
      ind = -1
    end
    
    # get numbers
    if size[0..ind] =~ /^\d{0,}\.{0,1}\d{1,}$/
      temp = size[0..ind].to_i * multi
      return temp.to_s
    else
      return false
    end
  end

  
  
  
  

  # Transform date-related parameter's value to correct form
  #
  # Parameters: date - ( {mm-dd-yyyy} | {yyyy-mm-dd} | {mmddyyyy} | {yyyy} )
  #
  # Method transforms given date to correct form and returns it.
  #    
  def self.transform_date(date) #:doc:
    # check the structure of given date
    if date =~ /^\d{4}\-\d{2}\-\d{2}$/
      return date
#    elsif date =~ /^\d{1,2}\-\d{1,2}\-\d{4}$/
#      return date[-4..-1] + "-" + date[0..4]
#    elsif date =~ /^\d{8}$/
#      return date[-4..-1] + "-" + date[0..1] + "-" + date[2..3]
    elsif date =~ /^\d{4}\-\d{2}$/
      return date + "-01"
    elsif date =~ /^\d{4}$/
      return date + "-01-01"
    else
      return false
    end
  end
  
  # Checks if given time is datetime, if not returns false
  def self.check_datetime(datetime)
    begin
      if datetime =~ /(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/
        DateTime.civil(datetime[0..3].to_i, datetime[5..6].to_i, datetime[8..9].to_i, datetime[11..12].to_i, datetime[14..15].to_i, datetime[17..18].to_i, 0 )
      else
        return false
      end
    rescue
      return false
    end
    if datetime =~ /(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/
      return true
    end
    return false
  end
  
  # Get all devfile_id:s from @result and return them
  def idsFromResults  
    resp = ""
    if @results == nil or @results.size == 0
      return ""
    end

    resp = " devfile_id IN ("
    
    @results.each_with_index do |x, i|
      if i == 0
        resp += x.devfile_file_id.to_s
      else
        resp += ", "+ x.devfile_file_id.to_s
      end
      
    end 
    resp += ") AND"

    return resp
  end
  
  
  def buildFinalResultCondition
    resp = ""
    
    # This is used for showing only files user is authorized to see
    if @remove_from_results != nil and @remove_from_results.size != 0            
      resp = " AND devfile_id NOT IN("
      
      @remove_from_results.each_with_index do |x,i|
        if i == 0
          resp += x.to_s
        else
          resp += ", "+x.to_s
        end
      end
      
      resp += ") "
      
    end
    
    if @only_allowed_in_results != nil and @only_allowed_in_results.size != 0
      resp = " AND (("
      
      @only_allowed_in_results.each_with_index do |x,i|
      
        if i != 0
          resp += ' AND'
        end  
        resp += " devfile_id IN("
        
        x.each_with_index do |y,j|
          if j != 0
            resp += ', '
          end
          resp += y.to_s
          
        end
        resp += ')'
      end
      resp += ')'
      
      # If context_hash is specified, this keeps files with specified context_hash, in the @results
      if @hash_in_where != nil && @hash_in_where != ""
        resp += @hash_in_where
      end
      
      resp += ") "
      
    elsif @hash_in_where != nil && @hash_in_where != ""
       resp += " AND " + @hash_in_where[3..-1]
    end
    
    return resp
  end
  
  
  
  # Make the sql-search
  #
  # Prerequisites: Context and query must be parsed before making the search.
  #
  # Method makes the sql-query and performs the search. @results will
  # include the results of the search.
  #
  def makeSearch #:doc:
    # beginning of sql query string
    sql = @select_part1 + " " + @select_part2

    begin
        @hash_in_where = ""
        
        if @context_hash != nil
          
          # If 'user' parameter given, only files owned by 'user' can be in search results.
          only_these_users_in_where = ""
          if @only_these_users != nil
            only_these_users_in_where = " users.username IN ("
            users = @only_these_users.split(' ')
            users.each_with_index do |x, i|
              if i == 0
                only_these_users_in_where += "'" + x + "'"
              else
                only_these_users_in_where += ', ' + "'" + x + "'"
              end
            end
            
            only_these_users_in_where += ") AND "
          end
          
          
          # Find devfiles that have queried context_hash
          devfiles = Devfile.find_by_sql("SELECT devfiles.id as devfile_id, devfiles.device_id, metadatas.devfile_id, metadatas.metadata_type_id,
                                                 metadatas.value, metadata_types.id, metadata_types.name,
                                                 devices.id, devices.user_id, users.id, users.username 
                                          FROM devfiles, metadatas, metadata_types, devices, users
                                          WHERE metadatas.value = '"+@context_hash+"' AND
                                                metadata_types.name = 'context_hash' AND
                                                devfiles.id = metadatas.devfile_id AND
                                                devices.id = devfiles.device_id AND
                                                devices.user_id = users.id AND #{only_these_users_in_where}
                                                metadatas.metadata_type_id = metadata_types.id")
          
          if devfiles != nil && devfiles.size > 0
            # Add id:s of devfiles that will be included into results, because these devfiles belong to queried context
            @hash_in_where = " OR devfiles.id IN ( "
          
            @devfiles_in_context = Array.new
          
            devfiles.each_with_index do |x, i|
              @devfiles_in_context.push(x.devfile_id)
              if i == 0
                @hash_in_where += x.devfile_id.to_s
              else
               @hash_in_where += ", " + x.devfile_id.to_s
              end              
            end
            @hash_in_where += " )"
          end
        end
        puts @hash_in_where
        available_files_only_in_where = ""
        
        if @availableFilesOnly == true
          available_files_only_in_where = " AND ( blobs.uploaded = 1 OR devices.last_seen >= '#{device_online_timeout.to_s(:db)}' ) "
        end
        
        show_deleted_files_in_where = ""
        
        if @showDeletedFiles == false && @queryparams[:what_to_get] =~ /files/i
          show_deleted_files_in_where = " AND devfiles.deleted = 0 "
        end
              
        # make the where-part of the sql query
        if not @versionlist_conditions
          makeConditions
          if @condition_string != "" || @hash_in_where != ""
            sql += " ( " + @condition_string + @hash_in_where + " ) "
          else
            sql += " false "
          end
          sql += show_deleted_files_in_where + available_files_only_in_where + @default_id_conditions
        else
          sql += " " + @versionlist_conditions + " " + @default_id_conditions
        end
    rescue => exp
      putsE(exp)
      raise exp
    end

    @sql = sql
 
    # sorting order
    @sql_sorting = ""
    if not @versionlist_sorting
      @sql_sorting = getSortingOrder
    else
      @sql_sorting = @versionlist_sorting
    end
    
    sql += " ORDER BY " + @sql_sorting
    puts "Initial SQL: #{sql}"
    
    @results_per_page = 100 # default
    @show_page = 1 # default
    if @queryparams[:format] == "atom"
      @results_per_page = 100 #default maxresults for atom-feed
      if @queryparams[:maxresults] and @queryparams[:maxresults] =~ /^\d{1,}$/
        @results_per_page = @queryparams[:maxresults]
      end
    else
      if @queryparams[:perpage]
        @results_per_page = @queryparams[:perpage].to_i
      end
      if @queryparams[:page] and @queryparams[:page] =~ /^\d{1,}$/
        @show_page = @queryparams[:page]
      end
    end

    # will_paginate uses sql-subqueries to get COUNT of rows. Subqueries are NOT
    # supported by Mysql versions < 4.1. So we have to do the counting by ourselves...
    count = sql.gsub(@select_part1, "SELECT COUNT(*) AS entries").gsub(/\sORDER BY.*$/, "").gsub!(/\:\w+/) do |s|
      "'" + @condition_values[s.gsub(":", "").intern].to_s + "'"
    end
    
    
    
    if @queryparams[:what_to_get] =~ /files/i
    #  entries = Devfile.count_by_sql(count)

                 # Pagination will be made later, with new sql query
      @results = Devfile.find_by_sql [sql, @condition_values]#,
#                                        :page => @show_page,
#                                        :per_page => @results_per_page,
#                                        :total_entries => entries
    # Remove files from results that user is not allowed to access
    checkFileRightstoResults                                        
    elsif @queryparams[:what_to_get] =~ /devices/i
      entries = Device.count_by_sql(count)
      @results = Device.paginate_by_sql [sql, @condition_values],
                                        :page => @show_page,
                                        :per_page => @results_per_page,
                                        :total_entries => entries
      # SHOULD EVERYONE BE ALLOWED TO SEE ALL DEVICES?
      
    elsif @versionlist_conditions
      entries = Blob.count_by_sql(count)
      @results = Blob.paginate_by_sql [sql, @condition_values],
                                        :page => @show_page,
                                        :per_page => @results_per_page,
                                        :total_entries => entries
    end
  end
  

  # Removes from @results all files that user doesn't have rights to view
  #
  # Parameters: @results
  def checkFileRightstoResults
    
    # If user is client, see if it is signed in
    if params[:i_am_client]
      username = authenticateClient
      
    # If user is signed in
    elsif session[:username]
      username = session[:username].to_s
    end

    if username != nil    
      user = User.find_by_username(username)
      # Groups that user is in 
      if user != nil
        user_groups = user.groups
      end
    end
        

    # Go through all results
    @results.reverse_each do |x|
      # If the file is private, check if user has right to access it
      if x.privatefile == true
        
        # If user is not logged in, remove private file from @results
        if user == nil
          @results.delete(x)
          @remove_from_results.push(x.devfile_id)
          next
        end
        
        # If user owns the file, he can access it
        if username == x.device.user.username
          next
        end
        
        
        # Check if user is in same group as the file
        fileinGroups = DevfileAuthGroup.find_all_by_devfile_id(x.devfile_id)
        hasRight = false
        # Go through the groups the file is in
        fileinGroups.each do |g|
          # Check if user is in the same group
          if user_groups.find_by_id(g.group_id) != nil
            hasRight = true
            break
          end
        end

        if hasRight == true
          next
        end
                
        # Find device the file is in. Is user authorized to access files of the device.
        deviceinGroups = DeviceAuthGroup.find_all_by_device_id(x.device.id)
        deviceinGroups.each do |d|
          if user_groups.find_by_id(d.group_id) != nil
            hasRight = true
            break
          end
        end
        
        if hasRight == true
          next
        end
        
        # Couldn't find access rights to this privatefile
        @results.delete(x)
        @remove_from_results.push(x.devfile_id)
      end
    end
  end
  
  # Check that file is public or user has right to access it
  def checkFileRightstoResultsinVersionlist
    # Get first blob and check if it is a private file
    if first = @results.first()
      if first.devfile.privatefile == true
        # Check that user has signed in
        # If user is client, see if it is signed in
        if params[:i_am_client]
          username = authenticateClient
      
        # If user is signed in
        elsif session[:username]
          username = session[:username].to_s
        end
              
        # If username was not found, return false
        if username == nil
          return false
        end
        
        user = User.find_by_username(username)
        
        # If user was not found, return false
        if user == nil
          return false
        end
        
        # If user owns the file, he can access it
        if username == first.devfile.device.user.username
          return true
        end
        
        # Groups user is in
        user_groups = user.groups
        
        # Groups file is in
        fileinGroups = DevfileAuthGroup.find_all_by_devfile_id(first.devfile_id)
        
        # Check if file is in one of those groups
        fileinGroups.each do |x|
          if user_groups.find_by_id(x.group_id) != nil
            return true
          end
        end
        
        # Find device the file is in. Is user authorized to access files of the device.
        deviceinGroups = DeviceAuthGroup.find_all_by_device_id(first.devfile.device.id)
        deviceinGroups.each do |d|
          if user_groups.find_by_id(d.group_id) != nil
            return true
          end
        end
        
        return false
      end
    else
      return false
    end
    # User is allowed to access versionlist
    return true
  end
  
  
  
  # Get sorting order of the sql-query
  #
  # Parameters: sort_by and order can be defined as parameters in the query.
  #
  # Method finds out if ordering wanted and constructs the "ORDER BY"-part of the sql-query
  # and returns it. If no ordering specified, default ordering is returned.
  # 
  def getSortingOrder #:doc:
    sorting = @default_sorting.dup
    ordering = ["DESC", "ASC", "ASC", "ASC"] # default ordering
    
    if @queryparams[:sort_by]
      # get given sort_by-values
      sorts = @queryparams[:sort_by].split(" ")
      # get given order-values and make sure sorts.size == orders.size
      orders = Array.new(sorts.size, "DESC")
      if @queryparams[:order]
        orders = @queryparams[:order].split(" ")
        if orders.size < sorts.size
          orders += Array.new(sorts.size - orders.size, "DESC")
        elsif orders.size > sorts.size
          orders = orders.slice(0, sorts.size)
        end
        orders.each do |o|
          if not (o.upcase == "ASC" or o.upcase == "DESC") then o = "ASC" end
        end  
      end
      
      # first sort_by-value has to be processed last (so it gets first on the list)
      sorts = sorts.reverse
      orders = orders.reverse
      
      # check sort_by-values
      sorts.each_index do |i|
        if @sort_by.has_key?(sorts[i])
          # move the sort-attribute to first
          sort_value = @sort_by[sorts[i]]
          ind = sorting.index("LOWER(" + @sort_by[sorts[i]] + ")")
          if ind != nil
            sorting.delete_at(ind)
            ordering.delete_at(ind)
            sort_value = "LOWER(" + sort_value + ")"
          end
          sorting.unshift(sort_value)
          ordering.unshift(orders[i].upcase)
        end
      end
    end
    
    #combine everything together
    returnable = sorting[0] + " " + ordering[0]
    sorting.each_index do |i|
      next if i == 0
      returnable += ", " + sorting[i] + " " + ordering[i]
    end
    return returnable
  end

  
  
  
  
  
  
  
  # Make the WHERE-part of the sql-query
  #
  # Prerequisites: Something from which to construct the condition required. Either
  # @device_ids or @conditions or both (see methods processParam and getSearchContext). 
  #
  # Method constructs the where-part of the sql-query and sets it to @condition_string.
  # 
  def makeConditions #:doc:
    @condition_string = ""
    @condition_values = Hash.new
    i = 0
    
    # if search is from spesific devices
    if @device_ids.size > 0
      @device_ids.uniq!
      firstdevid = true
      @device_ids.each do |id|
        if firstdevid
          @condition_string += "(devices.id in ("
          firstdevid = false
        else
          @condition_string += ", "
        end
        @condition_string += ":cond#{i}"
        @condition_values.merge!({"cond#{i}".intern => id})
        i += 1
      end
      @condition_string += "))"
      if not @conditions.empty? or @locationdata.size == 3
        @condition_string += " AND "
      end
    end
    
    # take each condition and combine them
    firstcond = true
    @conditions.each do |keyword, values|
      condition = "("
      statement = @condition_rules[keyword]
      
      # combine values
      firstvalue = true
      values.each do |value|
        condition_part = statement.gsub("?") do |s|
          new = ":cond#{i}"
          # bind the value
          @condition_values.merge!({"cond#{i}".intern => value})
          
          # do some special processing if the keyword is type and there's 2 "?"'s in the statement
          if keyword == "type" and statement.count("?") == 2
            value = value[0..-2].insert(1, ".")
          end
          i += 1
          new
        end
        
        if not firstvalue
          condition += " OR "
        end
        condition += condition_part
        
        firstvalue = false
      end
      
      condition += ")"
      
      # append condition_string with the condition
      if not firstcond
        @condition_string += " AND "
      end
      @condition_string += condition
      firstcond = false
    end
    
    # add distance-search to conditions
    if @locationdata.size == 3
      statement = "(" + @condition_rules["distance"] + ")"
      j = 0
      statement.gsub!("?") do |s|
        j += 1
        new = ":cond#{i}"
        # bind the value
        if j == 1
          @condition_values.merge!({"cond#{i}".intern => @locationdata["lat"]})
        elsif j == 3
          @condition_values.merge!({"cond#{i}".intern => @locationdata["lon"]})
        elsif j == 5
          @condition_values.merge!({"cond#{i}".intern => (@locationdata["distance"].to_f / @@kms_per_degree) **2})
        else
          i += 1
        end
        new
      end
      
      if not @conditions.empty?
        @condition_string += " AND "
      end
      @condition_string += statement
    end
  end
  
  
  def countDistance( lat1, lon1, lat2, lon2 )
    dlon = lon2 - lon1
    dlat = lat2 - lat1

    dlon_rad = dlon * @@rad_per_deg 
    dlat_rad = dlat * @@rad_per_deg

    lat1_rad = lat1 * @@rad_per_deg
    lon1_rad = lon1 * @@rad_per_deg

    lat2_rad = lat2 * @@rad_per_deg
    lon2_rad = lon2 * @@rad_per_deg
    
    a = (Math.sin(dlat_rad/2))**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad/2))**2
    c = 2 * Math.atan2( Math.sqrt(a), Math.sqrt(1-a))

    delta_miles = @@radius_miles * c       # delta between the two points in miles
    delta_km = @@radius_km * c             # delta in kilometers
    delta_feet = @@radius_feet * c         # delta in feet
    delta_meters = @@radius_meters * c     # delta in meters

    distances = Hash.new
    distances.merge!({"mi" => delta_miles})
    distances.merge!({"km" => delta_km})
    distances.merge!({"ft" => delta_feet})
    distances.merge!({"m" => delta_meters})
    return distances
  end
  

    

end
