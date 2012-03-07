class ContextController < ApplicationController
  
    # Protection from cross site request forgery
  protect_from_forgery :except => [ :createContext, :modifyContext, :changeContextName, :deleteContext, :deleteContexts]
  
  

  

  
  
  
  # Modifying the context
  #
  # Examples:
  #  Adding file to context:
  #   curl -X POST http://localhost:8443/user/ollipolli/contexts/humaljarvi -F file_uri=http://localhost:8443/user/ollipolli/device/my_x3/files/11277729_25ff58e1f2.jpg?version=0
  #
  #ds
  # Adding tags:
  #    curl -X POST http://localhost:8443/user/ollipolli/contexts/hervanta -F metadata=tag/jotain
  #
  # Changing location of the context
  #    curl -X POST http://localhost:8443/user/ollipolli/contexts/hervanta -F location=Stockholm
  # Changing metadata and location details:
  #    curl -X POST http://localhost:8443/user/ollipolli/contexts/hervanta -F metadata=context_location_country/Finland
  #
  # Icon can be changed with:
  #    curl -X POST http://localhost:8443/user/ollipolli/contexts/humaljarvi -F icon_data=@/home/niko/testikuvia/house.jpg
  #
  # Tags and some other metadatas can be deleted (notice that context_location_* metadata cannot be deleted, only changed):
  #    curl -X POST http://localhost:8443/user/ollipolli/contexts/humaljarvi -F delete_metadata=tag/cloud+tag/cloud
  #
  def modifyContext

    begin

    #  @context_owner = params[:username] ? User.find_by_username(params[:username]) : nil
    #  @context = @context_owner ? @context_owner.contexts.find(:first, :conditions => ['name = ?', params[:contextname]]) : nil
    #  if not @context_owner or not @context
    #    render :text => "Context: #{params[:contextname]} not found! \n", :status => 404
    #    return
    #  end
      
      if params[:contexthash] && params[:contexthash] != nil
        
        @context = Context.find_by_context_hash(params[:contexthash])

      elsif params[:username] && params[:contextname] && params[:username] != nil && params[:contextname] != nil

        ctx_name = ContextName.find_by_username_and_name(params[:username].downcase, params[:contextname].downcase)
        if ctx_name == nil
          render :text => "Context:not found! \n", :status => 404
          return
        end
        
        @context_id = ctx_name.context_id
  
        # Get context with context_hash
        @context = Context.find_by_id(@context_id)
        
      else
        render :text => "Context: not found! \n", :status => 404
        return
        
      end
      
      if @context == nil
        render :text => "Context: not found! \n", :status => 404
        return
      end

      @context_id = @context.id

      # user-object who is signed in, if not signed in has nil
      @user = whoIsSignedIn

      # Checks that user is authorized to modify context
      if not authorizedToContext(@context.context_hash)
        render :text => "Not authorized to modify this context", :status => 409
        return
      end
      
      
      
      # If uri for file is given -> adds file to context
      if params[:file_uri]
        addFileToContext(@context)
        puts "file was added to context!"
      end
      
      # Modifying other stuff   
      modifyContextInformations
      

    rescue Exception => ex
      putsE(ex)
      render :text => "Error in modifying context! \n", :status => 409
      return
    end


      render :text => "Context: #{params[:contextname]} modified successfully! \n", :status => 200
      return
  end
  

  
  def modifyContextInformations
    begin
    
      # Context's own data
      if params[:description]
        value = params[:description].strip.downcase
        @context.update_attribute(:description, value)
      end
      
      if params[:begin_time]
        value = params[:begin_time] ? QueryController::transform_date(params[:begin_time]) : ""
        @context.update_attribute(:begin_time, value)
      end
      
      if params[:end_time]
        value = params[:end_time] ? QueryController::transform_date(params[:end_time]) : ""
        @context.update_attribute(:end_time, value)
      end
      
      
      #if params[:new_name]
      #  value = params[:new_name].strip.downcase
      #  @context.update_attribute(:name, value)
      #end
      
      if params[:public] and params[:public] == "true"
        @context.update_attribute(:private, false)
      elsif params[:public] and params[:public] == "false"
        @context.update_attribute(:private, true)
      end
      
      
      # Icon stuff
      if params[:icon_data]
        icon_uri = "/thumbnails/vR_context_1.png"
        icon_name = "#{@context.context_hash}.png"
        icon_path = "public/thumbnails/context_thumbnails/"
        if createIcon(params[:icon_data].read, icon_name, icon_path)
          icon_uri = "/thumbnails/context_thumbnails/#{@context.context_hash}.png"
        else
          icon_uri = "/thumbnails/vR_context_1.png"
        end
        @context.update_attribute(:icon_url, icon_uri)
      end
      
    
      # Metadata

      # Deletes first the given metadata
      if params[:delete_metadata]
        # Deletes tags that are wanted to be deleted
        del_metadatas = params[:delete_metadata] ? params[:delete_metadata].split('+') : []
        del_metadatas.each do |delete_md|
          type, value = delete_md.split('/')
          if type and MetadataType.find_by_name(type) #and not @@unremovable_context_metadata.include?(type)
            @context.context_metadatas.each do |md|
              if type == md.metadata_type.name
                # If type is multimetadata, also value must match so that it can be removed
                if @@multi_metadata_types_for_context.include?(type) and value != nil and md.value == value  
                  md.delete
  
                # Otherwise deleting metadata that matches to the type
                elsif not @@multi_metadata_types_for_context.include?(type)
                  md.delete
                end
              end
            end
          end
        end
      end
      
      # Context must be re-fetched, so that rails realizes the changes
      @context = Context.find_by_id(@context_id)

      # Parsing the metadata from the uri parameters
      metadatas = []
      query_part = ""
      metadata = params[:metadata] ? params[:metadata].split('+') : []
      metadata.each_index do |i|
        md = metadata[i]
        type, value = md.split('/')
        if type and value
          metadatas.push({type => value})
        end
      end
      
      # Parsing the locations details from uri parameter -> adds to metadata
      if params[:location]
        # Gets the location details of the given location string
        #details = getLocationDetails(params[:location])
        details = getLocationDetailsFromOSM(params[:location])
        # Generate metadata from the location details
        details.each do |type, value|
          metadatas.push({type.to_s => value})
        end
      end

      # If metadata or location details was given, needs to update those and re-generate query_uri
      if not metadatas.empty? or params[:delete_metadata]

        # Updates the given metadatas for the context
        metadatas.each_index do |i|
          md = metadatas[i]
          md.each do |type,value|
            metadata_type = MetadataType.find_by_name(type)
            if metadata_type
              puts @context.id
              puts metadata_type
              u_mdata = nil
              if @@multi_metadata_types_for_context.include?(type)
              
                u_mdata = ContextMetadata.find_or_create_by_context_id_and_metadata_type_id_and_value(
                                                   :context_id => @context.id, 
                                                   :metadata_type_id => metadata_type.id,
                                                   :value => value)
              else
                u_mdata = ContextMetadata.find(:first, :conditions => ['metadata_type_id = ? and context_id = ?', 
                                                                        metadata_type.id, @context.id])
                                                                        
                if u_mdata != nil
                  u_mdata.update_attribute(:value, value.downcase)
                else
                  ContextMetadata.create(:value => value.downcase,
                                         :context_id => @context.id,
                                         :metadata_type_id => metadata_type.id)
                end                                                                                                                                
              end                       
            end
          end
        end
 
        # Create query uri
        query_part = ""
        tags = ""
        ctxMetadata = ContextMetadata.find_all_by_context_id(@context.id)
        if ctxMetadata != nil
          ctxMetadata.each do |x|
            if x.metadata_type.name == "tag"
              tags += '+' if tags != ""
              tags += x.value
            elsif not @@uninclude_from_context_query.include?(x.metadata_type.name)
              query_part += '&' if query_part != ""
              query_part += 'q[' + x.metadata_type.name + ']=' +x.value
            end
          end
          
          if tags != ""
            query_part += '&' if query_part != ""
            query_part += "q[tag]=" + tags
          end
          
        end
 
        query_uri = "/files.atom?#{query_part}"
        #query_uri += "&sparse=false"
        query_uri += "&q[context_hash]=#{@context.context_hash}"
        #puts "Query: #{query_uri}"
        @context.update_attribute(:query_uri, query_uri)
      end
      
      # Group
      
      # If new group rights are added to context
      if params[:group]
        groups = params[:group] ? params[:group].split('+') : []
        
        # Go through each group
        groups.each do |x|
          gr = Group.find_by_name(x)
          if gr
            # If the group is found, give it authorization to context
            ContextGroupPermission.find_or_create_by_group_id_and_context_id(:group_id => gr.id,
                                                                             :context_id => @context.id)
          end          
        end
      end
      

      # If group rights are removed from context
      if params[:remove_group]
        groups = params[:remove_group] ? params[:remove_group].split('+') : []
        
        # Go through each group
        groups.each do |x|
          rm_gr = Group.find_by_name(x)
          
          # If the group can be found
          if rm_gr
            rm_gr_perm = ContextGroupPermission.find_by_group_id_and_context_id(rm_gr.id, @context.id)
            # And if the group permission to context can be found 
            if rm_gr_perm
              # Remove permission
              rm_gr_perm.delete
            end                                                                                
          end          
        end
      end
      
      # If new user rights are added to context -> add users to group created for the context
      if params["user"]
        users = params["user"] ? params["user"].split('+') : []
        
        # Find the group created for this context
        ctx_group = Group.find_by_name("context_#{@context.name}")
        if ctx_group
                  
          # Go through each user
          users.each do |x|
            usr = User.find_by_username(x)
            if usr
              Usersingroup.find_or_create_by_user_id_and_group_id(usr.id, ctx_group.id)
              begin
                XmppHelper::pushToUserNode_invited_or_uninvaited_from_context(usr, @context, true)
              rescue Exception => e
                putsE(e)
              end
            end
          end
        
          begin
            puts "Sends notification to node!"
            XmppHelper::publishToContextGeneralNode(@context, "Context Members Modified!", "context-modified")
            puts "Notification sent!"
          rescue Exception => ee
            putsE(ee)
          end
        
        # If group was not found
        else
          puts "Problem adding users to context: #{@context.name}! Couldn't find group created for this context!'"
        end
      end
      
      
      # If user rights are removed from context
      if params["remove_user"]
        users = params["remove_user"] ? params["remove_user"].split('+') : []
        
        # Find the group created for this context
        ctx_group = Group.find_by_name("context_#{@context.name}")
        if ctx_group
          
          # Go through each user
          users.each do |x|
            usr = User.find_by_username(x)
            if usr
              # Find the user in group and delete it
              Usersingroup.delete_all(["user_id = ? and group_id = ?", usr.id, ctx_group.id])
              
              # Tässä käytetään XmppHelpperii... ja lähetetään käyttäjän nodeen viesti..
              XmppHelper::pushToUserNode_invited_or_uninvaited_from_context(usr, @context, false)
              
            end
          end
          
        # If group was not found
        else
          puts "Problem removing users from context: #{@context.name}! Couldn't find group created for this context!'"
        end
      end
     
     
    rescue Exception => exp
      putsE(exp)
      raise Exception.new("Error in modifying context metadatas! \n")
    end
  end
  
  
  # Adds metadata of the context for file given in file_uri
  #
  #
  def addFileToContext(context, devfile = nil)
    begin  
      
      if not devfile
        devfile = getDevfileFromURI(params[:file_uri])
      end
      
      if not devfile
        raise Exception.new("File not found!")
      end
      
      
      # Checks that user is authorized to file
      if not authorizedToFile(devfile)
        raise Exception.new("Not authorized to devfile")
      end

      # Find metadatatype context_hash
      metadatatype = MetadataType.find_by_name("context_hash")
      if metadatatype == nil
        raise Exception.new("couldn't find context_hash metadatatype, when adding file to context!'")
      end
      
      # Add context_hash metadata for the devfile. With this metadata you can find what contexts devfile is part of.
      Metadata.find_or_create_by_devfile_id_and_metadata_type_id_and_value(devfile.id, metadatatype.id,
                                                                           @context.context_hash)
      

      # Adds same group rights to the devfile as context has
      groups = ContextGroupPermission.find_all_by_context_id(@context.id)
            
      if groups
        groups.each do |cgp|
          DevfileAuthGroup.find_or_create_by_devfile_id_and_group_id(:devfile_id => devfile.id,
                                                                     :group_id => cgp.group_id)
        end
      end
      begin
        m = "Content (#{devfile.name}) added to #{@context.user.username}'s #{@context.name} context"
        XmppHelper::notificationToContextNode(devfile, @context, m, "content-added-to-context")
      rescue Exception => err
        putsE(err)
      end
    rescue Exception => e
      putsE(e)
      raise Exception.new("Error in adding file to context! \n")
    end
    
    return
  end
  
  
  

  
  
  
  
  # Creates new context 
  #
  #
  # Examples: 
  #   plain: curl -X PUT http://localhost:8443/contexts/humaljarvi
  #   curl -X PUT -F metadata=tag/rest+tag/cloud+kuvaus/tekstii -F begin_time=2010-01-01 -F end_time=2010-01-03 -F icon_data=@/home/niko/testi.png -F location=humaljarvi http://localhost:8443/user/ollipolli/contexts/humaljarvi
  #  (User needs to be signed in, or send client authentication parameters with the request)
  def createContext

    begin
    
      # Get context name
      if not params[:contextname]
        render :text => "Error in creating context, contextname needed! \n", :status => 409
        return
      end
      contextname = params[:contextname].downcase
      
      if params[:i_am_client]
        username = authenticateClient
      elsif session[:username]
        username = session[:username]
      end
      
      # Make sure user is signed in as the user who context will be created to
      if username == nil
        render :text => "Not authorized to create context! \n", :status => 409
        return
      end
      
      
      @user = User.find_by_username(username)
      
      #puts "username: #{@user.id.to_s}"
      #puts "contextname: #{contextname.to_s}"
      #puts "location: #{location.to_s}"
      
                                      # Location name is optional?
      if not contextname or not @user #or not location 
        render :text => "Not all the details that are needed was given! \n", :status => 300
        return
      end
      
          
      # Checks that user doesn't already have group with same name as context
      group_contextname = "context_"+contextname
      if Group.find_by_user_id_and_name(@user.id, group_contextname) != nil
        render :text => "Group with context name already exist, use another context name! \n", :status => 409
        return        
      end
      
      # Checks that user doesn't already have context saved with same name
      if ContextName.find_by_user_id_and_name(@user.id, contextname) != nil
        render :text => "Context name already in use for this user! \n", :status => 409
        return  
      end

      # Create unique hash for context
      context_hash = Digest::SHA1.hexdigest(@user.username+"."+contextname+Time.now.tv_sec.to_s)

      if params[:icon_data]
        icon_name = "#{context_hash}.png"
        icon_path = "public/thumbnails/context_thumbnails/"
        puts "icon created!" if createIcon(params[:icon_data].read, icon_name, icon_path)
        
      end
    
    
      metadatas = []
      query_part = ""
      
      metadata = params[:metadata] ? params[:metadata].split('+') : []
      tags = ""
      metadata.each_index do |i|
        md = metadata[i]
        type, value = md.split('/')
        if type and value
          metadatas.push({type => value})
          # There can be multiple values for tag -> they are all collected to tags
          if type == "tag"
            tags += '+' if tags != ""
            tags += value
          else
            query_part += '&' if query_part != ""
            query_part += "q[#{type}]=#{value}"
          end
        end
      end
      
      # If tags were found, add them to query url
      if tags != ""
        query_part += '&' if query_part != ""
        query_part += "q[tag]=#{tags}"
      end
      
      private_context = params[:private] ? params[:private] : true 
      
      
      #puts "query_part #{query_part}"
      query_uri = "/files.atom?#{query_part}"
      
      
      icon_uri = params[:icon_data] ? "/thumbnails/context_thumbnails/#{context_hash}.png" : "/thumbnails/vR_context_1.png"
      
      description = params[:description] ? params[:description] : ""
      
      begin_time = params[:begin_time] ? QueryController::transform_date(params[:begin_time]) : ""
      end_time = params[:end_time] ? QueryController::transform_date(params[:end_time]) : ""
      
      
      location = nil
      
      if params[:location]
          
        location = params[:location].strip.downcase
        
        # To see if geonames search didn't throw exception
        geonames_success = false
   #### Geonames has been down from time to time. uncomment the below to take geonames back to use.
=begin      begin
          # Gets the location details of the given location string
          details = getLocationDetails(location)
          # Generate metadata from the location details
          details.each do |type, value|
            metadatas.push({type.to_s => value})
            
          # Found details from geonames, no need for OpenStreetMap
          geonames_success = true
          
          end
        rescue Exception => exp
          putsE(exp)
          puts "Could not connect to GeoNames. Will try OpenStreetMap."
       #   metadatas.push({"context_location_name" => location})
=end      end
        
        # If coudn't get location details from geonames, try openStreetmap instead:
        if not geonames_success
          begin
            # Gets the location details of the given location string
            details = getLocationDetailsFromOSM(location)        
            # Generate metadata from the location details
            details.each do |type, value|
              puts "type: #{type.to_s} . Value: #{value}"
              metadatas.push({type.to_s => value})
            end
            
          rescue Exception => exp
            putsE(exp)
            puts "Could not connect to OpenStreetMap either."
            metadatas.push({"context_location_name" => location})    
          end
            
        end
      end
    
      # Creates XMPP node for the context. Node naming goes: /home/<host>/visualrestmain_node/<context_hash>
      node_path, node_service = XmppHelper::createContextNode(context_hash)
      if not node_path or not node_service
        node_path = "" 
        node_service = ""
      end
      
      #query_uri += "&sparse=false"
      
      # Add context_hash to query_uri
      query_uri += "&q[context_hash]=#{context_hash}"
      
      # Create the context
      @new_context = Context.create(:name => contextname, :user_id => @user.id, :query_uri => query_uri,
                                    :icon_url => icon_uri, :description => description,
                                    :location_string => location,
                                    :begin_time => begin_time, :end_time => end_time, :private => private_context,
                                    :context_hash => context_hash,
                                    :node_path => node_path, :node_service => node_service)
      
      if not @new_context
        raise Exception.new("Couldn't save the context!")
      end


      # Create context_name for the creator of context
      ContextName.create(:context_id => @new_context.id,
                         :name => @new_context.name,
                         :context_hash => @new_context.context_hash,
                         :user_id => @user.id,
                         :username => @user.username)

     
      # Creates a group named context_contextName and authorizes the group to context
      
      new_group = Group.create(:name => group_contextname, :user_id => @user.id)
      
      if not new_group
        puts "Error creating group for the context"
      end

      ContextGroupPermission.create(:group_id => new_group.id,
                                    :context_id => @new_context.id)
                                    
      # Adds creator of context to the group
      Usersingroup.find_or_create_by_user_id_and_group_id(:user_id => @user.id, :group_id => new_group.id)

      # Adds users given in parameters into new_group that was created     
      if params[:user]
        user = params[:user] ? params[:user].split('+') : ""
        
        # Go through every user in params
        user.each do |x|
          
          # Find the user
          u = User.find_by_username(x)
          if u
            
            # Add user to the new_group
            Usersingroup.find_or_create_by_user_id_and_group_id(:user_id => u.id, :group_id => new_group.id)
            
            # Get suggestions for contextname for this user
            sugg = suggestContextNames(u.username, contextname)
            
            ## Notifies every device of users that they were added to the context
            
            # Go through all devices of user
            u_devices = Device.find_all_by_user_id(u.id)
            if u_devices
              # Create xmpp message
              message = '<vr-xmpp-message>
                           <message>You have been authorized for a new context! You can add it to your contexts with a name that you like</message>'

              sugg.each do |x|
                message += '<suggested-transition>
                              <description>'+x+'</description>
                              <url method="put">http://visualrest.cs.tut.fi/user/'+u.username+'/contexts/'+x+'</url>
                              <parameters>
                                <context_hash>'+@new_context.context_hash+'</context_hash>
                                <i_am_client>true</i_am_client>
                                <auth_username>'+u.username+'</auth_username>
                                <auth_timestamp></auth_timestamp>
                                <auth_hash></auth_hash>
                              </parameters>
                            </suggested-transition>'  
              end
              message += '</vr-xmpp-message>'
              
              u_devices.each do |dev|  
                # Send xmpp message with link. If user goes to the link, he is added to the group
      #          XmppHelper::sendXmppMessage(dev.xmppname, message)
                #puts dev.xmppname
                #puts message
              end
            end
          end                       
        end
      end


      # Authorizes given groups to the context
      group_names = []
      
      if params[:group]
        group_names = params[:group] ? params[:group].split('+') : ""
        group_names.each do |gn|
          group = Group.find(:first, :conditions => ["name = ? and user_id = ?", gn, @user.id])
          if group != nil
            ContextGroupPermission.find_or_create_by_group_id_and_context_id(:group_id => group.id,
                                                                             :context_id => @new_context.id)
          end       
        end
      end
      
            
      # Creates the given metadatas for the context
      metadatas.each do |md|
        md.each do |type,value|
          metadata_type = MetadataType.find_by_name(type)
          if metadata_type
            if @@multi_metadata_types_for_context.include?(metadata_type.name)
            
              new_mdata = ContextMetadata.find_or_create_by_context_id_and_metadata_type_id_and_value(
                                                 :context_id => @new_context.id, 
                                                 :metadata_type_id => metadata_type.id,
                                                 :value => value.downcase)
            else
              new_mdata = ContextMetadata.find_or_create_by_context_id_and_metadata_type_id(
                                                 :context_id => @new_context.id, 
                                                 :metadata_type_id => metadata_type.id,
                                                 :value => value.downcase)
            end
          end
        end
      end
      
     
    rescue Exception => exp
      putsE(exp)
      render :text => "Error in creating context \n", :status => 409
      return
    end


   




    # atom feed needs @context and @context_metadatas
    @context = @new_context
    # get metadatas with sql, gets also metadata_type names
    @context_metadatas = ContextMetadata.find_by_sql("SELECT context_metadatas.context_id as id, 
                                                             context_metadatas.value as value, 
                                                             metadata_types.name as type_name,
                                                             metadata_types.value_type as value_type
                                                      FROM context_metadatas, metadata_types
                                                      WHERE context_metadatas.metadata_type_id = metadata_types.id AND 
                                                            context_metadatas.context_id = #{@context.id}")
                                                            
    @owner = @context.user
    @contextname = @context.name
    @context_named_by_user = @context.name

    sql = "SELECT users.* 
           FROM context_group_permissions, groups, usersingroups, users 
           WHERE context_group_permissions.context_id=#{@context.id} AND 
                 context_group_permissions.group_id = groups.id AND 
                 groups.id=usersingroups.group_id AND usersingroups.user_id=users.id;"
    @members = User.find_by_sql(sql)


    begin
      puts "Sends notification to node!"
      XmppHelper::publishToContextGeneralNode(@context)
      puts "Notification sent!"
    rescue Exception => ee
      putsE(ee)
    end



    # Create atom-feed. Returns info about the created context.                                                            
    @host = @@http_host
    respond_to do |format|
      format.atom {render :getcontext, :layout=>false }
    end
  end
  
  
  def RESTCreateNode
   puts "Creating node through REST api"
   begin
      node_name = ""
      params[:nodename].each do |n|
        node_name = "#{node_name}/#{n.strip}"
      end
      node_name = node_name[1..-1]
 puts node_name
      if not XmppHelper::createXmppNode(node_name) then raise Exception.new("Error in creating node!") end
    
      render :text => "Node was created!", :status => 202
      return
      
    rescue Exception => ex
      putsE(ex)
      render :text => "Error in creating node for context \n", :status => 409
      return
    end
  end
  
  
  
  def RESTPublishToNode
    
    puts "RESTPublishToNode"
    
    node_name = ""
    params[:nodename].each do |n|
      node_name = "#{node_name}/#{n.strip}"
    end
    node_name = node_name[1..-1]
    
    m = "Hello World!"
    if params[:message] != nil
      m = params[:message]
    end
    
    #NodeHelper.new(node_name, @@node_client_info, true).publishToNode(m)
    
    m = "<notification>" + m + "</notification>"
    
    XmppHelper::publishToContextNode(node_name, m)
    
    render :text => "Message was given for worker to send to context node!", :status => 202
    return
  end
  
  
=begin
  def publishToContextNode(context_hash, message)
    node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/#{context_hash}".strip        
    XmppHelper::publishToXmppNode(node_path, message, @@node_client_info)
  end
  
  def createContextNode(context_hash)
     # Creates node for the context
    node_path = "home/#{@@xmpp_host.strip}/#{@@node_client_info[:plain_id].strip}/#{context_hash}".strip
    return XmppHelper::createXmppNode(node_path, @@node_client_info)
  end
=end
  
  
  
  
  # Changes (or creates) contextname for the user that has signed in.
  # params[:username] (from url) and signed in user must be same.
  # Parameters: 'context_hash' or 'old_name' (username_personalContextname
  # New contextname will be params[:contextname] (from url)
  def changeContextName
   
    new_contextname = params[:contextname].downcase
   
    # To find context, use context_hash or old_name
    if params[:context_hash]
      @context = Context.find_by_context_hash(params[:context_hash])
    elsif params[:old_name]
      @context = getContextFromUsernameCtxname(params[:old_name])
    end

    if @context == nil
      render :text => "Couln't find the context!", :status => 409
      return
    end      
    
    @user = whoIsSignedIn
    
    if @user == nil
      render :text => "You need to be authenticated for this!", :status => 409
      return   
    
    elsif @user.username != params[:username]
      render :text => "You authenticated with wrong user!", :status => 409
      return   
    end
    
    # Check that user is authorized for the context
    if not authorizedToContext(@context.context_hash)
      render :text => "User is not authorized for this context!", :status => 409
      return
    end

    ### User is authenticated and right context has been found
    
    # Check that new contextname is available for this user
    if ContextName.find_by_user_id_and_name(@user.id, new_contextname) != nil
      render :text => "New contextname already in use for this user!", :status => 409
      return
    end
    
    # The old name user had for context
    old_contextname = ContextName.find(:first, :conditions => ["context_id = ? and user_id = ?", @context.id, @user.id])
    
    # If user is owner, check that new groupname is available
    if @user.id == @context.user_id
      
      new_group_name = "context_"+new_contextname
      
      # Make sure owner doesn't already have a group named context_newContextName
      if Group.find_by_user_id_and_name(new_group_name) != nil
        render :text => "Owner of the context already has a group with new contextname, use other contextname", :status => 409
        return
      end   
      
      if old_contextname != nil
        # User had a name for the context -> there should be a group with that name
        old_group = Group.find(:first, :conditions => ["user_id = ? and name = ?", @user.id, old_contextname.name])
        
        if old_group != nil
          # Change group name
          old_group.update_attribute(:name, new_group_name)
        end
      end
      
      # If old group wasn't found
      if old_contextname == nil or old_group == nil
        # Create a new group for the context and give access rights to the context
        new_group = Group.create(:name => new_group_name,
                                 :user_id => @user.id)
                     
        # Give group access right to the context
        ContextGroupPermission.find_or_create_by_group_id_and_context_id(new_group.id, @context.id)
        
      end 
    
      # If user is owner, chanege contextname also to context table
      @context.update_attribute(:name, new_contextname)
        
    end ## end group stuff
    
      
    # If context name was saved for the user, update it
    if old_contextname != nil
      # Change existing contextName
      old_contextname.update_attribute(:name, new_contextname)
      
      
    else
      # Create new contextName
      ContextName.create(:context_id => @context.id,
                         :name => new_contextname,
                         :context_hash => @context.context_hash,
                         :user_id => @user.id,
                         :username => @user.username)
      
    end   

  
    @host = @@http_host
    respond_to do |format|
      format.atom {render :changecontextname, :layout=>false }
    end

  end 
  
  
  
  
  
  
  
  
  # Remove context and links to it
  # Only creator of context can remove context permanently
  def deleteContext
    # Find the context to be removed
    ctx_name = ContextName.find_by_username_and_name(params["username"].downcase, params["contextname"].downcase)
    if ctx_name == nil
      render :text => "Context: #{params[:contextname].downcase} not found! \n", :status => 404
      return
    end
      
    @context_id = ctx_name.context_id

    # Get context with context_id
    @context = Context.find_by_id(@context_id)
    if @context == nil
      render :text => "Context: #{params[:contextname]} for User: #{params[username]} not found! \n", :status => 404
      return
    end

    # user-object who is signed in, if not signed in has nil
    @user = whoIsSignedIn
  
    if @user == nil
      render :text => "You need to be authenticated for this!", :status => 409
      return   
    
    elsif @user.username != params["username"]
      render :text => "You authenticated with wrong user!", :status => 409
      return   
    end
    
    # Is user creator of the context
    if @context.user_id != @user.id
      render :text => "You are not the creator of this context, you can't delete it!", :status => 409
      return
    end
    
    
    # Find group created for this context
    ctx_group = Group.find_by_name("context_#{params["contextname"]}")
    if ctx_group == nil
      puts "Deleting context: Could not find group created for the context!"
    else
      # Group found, remove users from this group
      Usersingroup.delete_all(["group_id = ?", ctx_group.id])
      
      # Delete group
      ctx_group.destroy
    end
    
    # Remove group access rights to context
    ContextGroupPermission.delete_all(["context_id = ?", @context.id])
        
    # Remove context_metadatas
    ContextMetadata.delete_all(["context_id = ?", @context.id])
    
    # Remove context_names
    ContextName.delete_all(["context_id = ?", @context.id])
    
    # Remove metadatas "context_hash" with this contexts hash
    metadatatype = MetadataType.find_by_name("context_hash")
    if metadatatype != nil     
      Metadata.delete_all(["value = ? and metadata_type_id = ?", @context.context_hash, metadatatype.id])
    end
    
    # Remove Context
    @context.destroy
    
    render :text => "Context has been deleted.", :status => 200
    return
    
  end
  
  
  # Remove contexts from user and links to those
  # Only creator of context can remove context permanently
  def deleteContexts
    
    # user-object who is signed in, if not signed in has nil
    @user = whoIsSignedIn
  
    if @user == nil
      render :text => "You need to be authenticated for this!", :status => 409
      return   
    
    elsif @user.username != params["username"]
      render :text => "You authenticated with wrong user!", :status => 409
      return   
    end
   
    context = Context.find_by_user_id(@user.id)
    
    while context != nil
      
      
    
      # Find group created for this context
      ctx_group = Group.find_by_name("context_#{context.name}")
      if ctx_group == nil
        puts "Deleting context: Could not find group created for the context!"
      else
        # Group found, remove users from this group
        Usersingroup.delete_all(["group_id = ?", ctx_group.id])
        
        # Delete group
        ctx_group.destroy
      end
      
      # Remove group access rights to context
      ContextGroupPermission.delete_all(["context_id = ?", context.id])
          
      # Remove context_metadatas
      ContextMetadata.delete_all(["context_id = ?", context.id])
      
      # Remove context_names
      ContextName.delete_all(["context_id = ?", context.id])
      
      # Remove metadatas "context_hash" with this contexts hash
      metadatatype = MetadataType.find_by_name("context_hash")
      if metadatatype != nil     
       Metadata.delete_all(["value = ? and metadata_type_id = ?", context.context_hash, metadatatype.id])
      end
      
      # Remove Context
      context.destroy
      
      # Find if there is next context in line for destruction
      context = Context.find_by_user_id(@user.id)
      
    end
    
    render :text => "No more contexts for user #{params["username"]}.", :status => 200
    return
    
  end
  
  
  
  
  
  # Get information about certain context
  def getContext
    
    query_processing_time_begin = Time.now
    # In web-ui query processing time is only shown if asked. In atom-feed, it is always shown.
    if params["query_processing_time"] && params["query_processing_time"].downcase == "true"
      @query_processing = true
    end
    if params[:qoption] && params[:qoption]["query_processing_time"] == "true"
      @query_processing = true
    end
    
    
    if params[:contexthash] != nil
      
      @context = Context.find_by_context_hash(params[:contexthash])
    
    else
      
      user = User.find_by_username(params[:username])
      if user == nil
        render :text => "Owner of context not found!", :status => 409
        return
      end
      
      ctxName = ContextName.find_by_user_id_and_name(user.id, params[:contextname])
      if ctxName == nil
        render :text => "Contextname was not found for this user!", :status => 404
        return
      end
      
      @context = Context.find_by_id(ctxName.context_id)   
    end
    
    # If requested context wasn't found
    if @context == nil
      render :text => "Context not found!", :status => 404
      return
    end
    
    sql = "SELECT users.* 
           FROM context_group_permissions, groups, usersingroups, users 
           WHERE context_group_permissions.context_id=#{@context.id} AND 
                 context_group_permissions.group_id = groups.id AND 
                 groups.id=usersingroups.group_id AND usersingroups.user_id=users.id;"
    @members = User.find_by_sql(sql)
    
    @owner = User.find_by_id(@context.user_id)
    if @owner == nil
      render :text => "Owner of the context could not be found", :status => 409
      return
    end
       
    # User-object who is signed in, if not signed in it's nil
    @user = whoIsSignedIn   
       
    # If user is not authorized to see context
    if not authorizedToContext(@context.context_hash)
      render :text => "You don't have permission to see this context", :status => 401
      return
    end

    ## Context is found and user is authorized to view it. We may proceed.
    
    
    @context_metadatas = ContextMetadata.find_by_sql("SELECT context_metadatas.context_id as id, 
                                                             context_metadatas.value as value, 
                                                             metadata_types.name as type_name,
                                                             metadata_types.value_type as value_type
                                                      FROM context_metadatas, metadata_types
                                                      WHERE context_metadatas.metadata_type_id = metadata_types.id AND 
                                                            context_metadatas.context_id = #{@context.id}")   
 
    @context_named_by_user = @context.name
 
    @metadatatypes = MetadataType.find(:all, :order => "name ASC" )
 
    # Find if user that is signed in, has named the context
    if @user != nil
      tmp_ctx_name = ContextName.find_by_user_id_and_context_id(@user.id, @context.id)
      if tmp_ctx_name != nil
        # Signed in user has named the context
        @context_named_by_user = tmp_ctx_name.name
      end
    end
    
    
    
    if query_processing_time_begin != nil
      query_processing_time_end = Time.now
      @query_processing_time = query_processing_time_end - query_processing_time_begin
      puts "Time used for processing query: #{@query_processing_time}"
    end
    
    
    #Create atom feed
    @host = @@http_host
    respond_to do |format|
      if params[:format] == nil
        format.html {render :getcontext, :layout=>true }
      else
        format.html {render :getcontext, :layout=>true }
        format.atom {render :getcontext, :layout=>false }
      end
    end 
  end
  
    
  
  # Parameters: - username
  #             - contextname
  # Returns: -3 suggestions for context name, in array
  #          -nil, if problems
  def suggestContextNames(username, contextname)

    # Put suggestions to resp and return it
    resp = Array.new
    
    sugg = contextname
    
    # Look for the context name for this user
    ctxName = ContextName.find_by_name_and_username(contextname, username )
    
    
    while resp.length < 3
      if ContextName.find_by_name_and_username(sugg, username) == nil
        resp.push(sugg)
      end
      sugg +="I"
    end
    
    return resp
  end
  
  
  # Parameters: contextname - username_personalContextname
  # Returns: - Context
  #          - if problems, return nil
  def getContextFromUsernameCtxname(contextname)
    if contextname == nil
      return nil
    end
    
    # If contextname includes '.', it is of form username_personalContextname
    index = contextname.index('.')
    if index != nil

      # If '.' is the last character, return nil
      if contextname[contextname.length-1..contextname.length-1] == '.'
        return nil
      end

      username = contextname[0..index-1].downcase
      personalContextname = contextname[index+1..-1].downcase

      # Find contextname
      ctx_name = ContextName.find_by_username_and_name(username, personalContextname)
      if ctx_name == nil
        return nil
      end
      
      # Find Context
      ctx = Context.find_by_id(ctx_name.context_id)  
      
      if ctx == nil
        return nil
      end
      
      # Return context
      return ctx
           
    # Context wasn't found -> return nil
    else
      return nil
    end
    return nil
  end
  
  # Returns: user-object of signed in user
  #          nil, if not signed in
  def whoIsSignedIn
    if params[:i_am_client]
        username = authenticateClient
    elsif session[:username]
        username = session[:username]
    end
    
    if username == nil
      return nil
    end
    
    user = User.find_by_username(username)
    if user == nil
      return nil
    end
    return user
  end
    

  # Returns True, if user is authorized for the devfile
  def authorizedToFile(devfile)
    
    # If file is private, everyone is authorized for it
    if devfile.privatefile == false
      return true
    end
    
    ## Check user rights to devfile
    # Is user signed in
    if params[:i_am_client]
      username = authenticateClient
    elsif session[:username]
      username = session[:username]
    end
    
    if username != nil
      
      # Find the user
      user =  User.find_by_username(username)  
      if user != nil
         
        # If user is the owner of context
        if user.id == devfile.device.user_id
          return true
          
        # Is user in a group that is authorized for the context
        elsif
          
          # Groups that user is in
          uigroups = Usersingroup.find_all_by_user_id(user.id)
          if uigroups == nil
            return false
          end
          
          # Is group autohorized for the context
          uigroups.each do |uigroup|
            
            group = DevfileAuthGroup.find_by_group_id_and_devfile_id(uigroup.group_id, devfile.id)
            
            # If group is authorized for the context, return true
            if group != nil
              return true
            end
          end
      
        end
      end
    end
    return false
    
  end

  
  
  
  
  # Gets devfile objects that matches to metadata of given context
  #
  # Returns: Arrays of devfile-objects
  # Raises: exception if any errors
  # 
  def self.getContextFiles(context)
  
    begin
      context_metadatas = context ? context.context_metadatas : []
      mdata_count = 0
      
      if context_metadatas.empty?
        puts "Context not found, or had no metadata!"
        return []
      end
      
      select_part = "SELECT devfile_id "
      from_part   = "FROM metadatas "
      where_part  = "WHERE "
  
      context_metadatas.each_index do |i|
        md = context_metadatas[i]
        if not @@uninclude_from_context_query.include?(md.metadata_type.name)
          where_part += "value = '#{md.value}' AND metadata_type_id = #{md.metadata_type_id} OR "
          mdata_count += 1
        end
      end
      where_part = where_part.chomp("OR ")
      final_select_part = "GROUP BY devfile_id HAVING count(value) = #{mdata_count.to_s}"
      metadata_sql = select_part + from_part + where_part + final_select_part  
      
      select_part = "SELECT * "
      from_part   = "FROM devfiles "
      where_part = "WHERE id in (#{metadata_sql})"
      
      devfile_sql = select_part + from_part + where_part
      res = Devfile.find_by_sql(devfile_sql)
      
      return res
    rescue Exception => ex
      putsE(ex)
      raise ex
    end
  end



 
    
  def getLocationDetails(location)
    
    details = {}
    
    begin 
      
      #osm_uri = "http://nominatim.openstreetmap.org/search?q=#{location}&format=xml&addressdetails=1"
      osm_uri = "http://ws.geonames.org:80/search"
      uri = URI.parse(osm_uri.to_s)

      params = {'q' => location}
      
      Net::HTTP.start(uri.host, 80) { |http|
        
        path_and_query = "#{uri.path}?".concat(params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&'))
        response = http.get(path_and_query)
        
        case response
          when Net::HTTPSuccess
            xml = response.body
            if xml != nil
#puts "xml: #{xml}"
              doc = XML::Document.string(xml)  
              # Fetches only the first one
              geoname_element = doc.find_first('//geonames/geoname')
              if geoname_element
                location_name = geoname_element.find_first('name') ? geoname_element.find_first('name').content : nil
                location_country = geoname_element.find_first('countryName') ? geoname_element.find_first('countryName').content : nil
                location_lat = geoname_element.find_first('lat') ? geoname_element.find_first('lat').content : nil
                location_lon = geoname_element.find_first('lng') ? geoname_element.find_first('lng').content : nil
              else
                raise Exception.new("Location: #{location} not found!")
              end
              
            if location_name and location_country and location_lat and location_lon
              details = {:context_location_name => location_name, :context_location_country => location_country, 
                         :context_location_lat => location_lat, :context_location_lon => location_lon}
            else
              puts "Found these location details:"
              puts "name: #{location_name.to_s}"
              puts "country: #{location_country.to_s}"
              puts "lat: #{location_lat.to_s}"
              puts "lon: #{location_lon.to_s}"
              raise Exception.new("Not all the details for location was found!")
            end
              
            else
              raise Exception.new("Error in requesting address details from geonames.com, no xml was found")
            end
          
        else
          raise Exception.new("Error in requesting address details from geonames.com")
        end
      }
      
    rescue => e
      putsE(e)
      raise e
    end
    
    return details
    
  end
    
    
    
  def getLocationDetailsFromOSM(location)
    
    details = {}
    
    begin 
      
      osm_uri = "http://nominatim.openstreetmap.org/search"
      #osm_uri = "http://ws.geonames.org:80/search"
      uri = URI.parse(osm_uri.to_s)

      params = {'q' => location, 'format' => 'xml', 'addressdetails' => '1', 'accept-language' => 'en'}
      
      Net::HTTP.start(uri.host, 80) { |http|
        
        path_and_query = "#{uri.path}?".concat(params.collect { |k,v| "#{k}=#{CGI::escape(v.to_s)}" }.join('&'))
        response = http.get(path_and_query)
        
        case response
          when Net::HTTPSuccess
            xml = response.body
            if xml != nil
#puts "xml: #{xml}"
              doc = XML::Document.string(xml)  
              # Fetches only the first one
              osm_element = doc.find_first('//searchresults/place')
              if osm_element
                place_type = osm_element['type'] ? osm_element['type'] : nil
                location_name = osm_element.find_first(place_type) ? osm_element.find_first(place_type).content : nil
                location_country = osm_element.find_first('country') ? osm_element.find_first('country').content : nil
                location_lat = osm_element['lat'] ? osm_element['lat'] : nil
                location_lon = osm_element['lon'] ? osm_element['lon'] : nil
              else
                raise Exception.new("Location: #{location} not found!")
              end
              
            if location_name and location_country and location_lat and location_lon
              details = {:context_location_name => location_name, :context_location_country => location_country, 
                         :context_location_lat => location_lat, :context_location_lon => location_lon}
            else
              puts "Found these location details:"
              puts "name: #{location_name.to_s}"
              puts "country: #{location_country.to_s}"
              puts "lat: #{location_lat.to_s}"
              puts "lon: #{location_lon.to_s}"
              raise Exception.new("Not all the details for location was found!")
            end
              
            else
              raise Exception.new("Error in requesting address details from OpenStreetMap, no xml was found")
            end
          
        else
          raise Exception.new("Error in requesting address details from OpenStreetMap")
        end
      }
      
    rescue => e
      putsE(e)
      raise e
    end
    
    return details      
      
  end


  # Returns context that mathes to metadata of devfile
  #
  # Returns: Arrays of context-objects
  # Raises: exception if any errors
  # 
  def self.getFileContexts(devfile)

  
    begin
      
      devfile_metadatas = devfile ? devfile.metadatas : []
      mdata_count = 0
      
      if devfile_metadatas.empty?
        puts "Devfile had no user added metadata!"
        return []
      end

      select_part = "SELECT context_id "
      from_part   = "FROM context_metadatas "
      where_part  = "WHERE "

      devfile_metadatas.each_index do |i|
        md = devfile_metadatas[i]
        if @@devfile_context_metadata.include?(md.metadata_type.name) and not @@uninclude_from_context_query.include?(md.metadata_type.name)
          where_part += "metadata_type_id = #{md.metadata_type_id} OR "
          mdata_count += 1
        end
      end
      where_part = where_part.chomp("OR ")
      final_select_part = " GROUP BY context_id"
      metadata_sql = select_part + from_part + where_part + final_select_part
      context_sql = "SELECT * FROM contexts WHERE id in (#{metadata_sql})"
      
      contexts = []
      res = Context.find_by_sql(context_sql)
      res.each do |cxt|
        dfiles = getContextFiles(cxt)
        dfiles.each do |dfile|
          if dfile.id == devfile.id
            contexts.push(cxt)
          end
        end
      end
            
      return contexts
      
    rescue Exception => ex
      putsE(ex)
      raise ex
    end
  end


  def testi
    
    devfile = Devfile.find_by_id(3160)
    puts "devfilename: #{devfile.name}"
    
    puts "foo"
    temp = []
    temp << devfile
    ContextController::notifyObservers(temp, "Testiiii!")
    
    puts "bar"
    
    render :text => "ok", :status => 200
    return
  end






 # Parametrina saadaan taulukko, joka sisältää commitissa olleiden devfilejen id:t
 #
 # Palautettava tietorakenne: {commit_id => [devfile_id, devfile_id, devfile_id...]}
 #
 # Käydään kaikki contextstit läpi yksitellen ja tutkitaan onko queryjen hakutuloksissa parametrina saatuja ideitä
 # => jos on, lisätään se context_id -riville: {commit_id => [devfile_id, devfile_id, devfile_id...]}
 #
  def self.foobar(commit_devfiles, contexts_case1)
    
  end











  #
  #   Notifies nodes of the context with this method
  #
  # Notification should only be transferred once per context
  #
  def self.notifyObservers(commit_devfiles, msg = "Content updated!")
    begin
      
      # {commit_id => [devfile_id, devfile_id, devfile_id...]}
      res = {}

      #
      #  Makes query to localhost and to which context the devfiles of the commit belongs to
      #
      params = {"localhost_context_polling" => "true"}
      Context.find(:all).each do |context|
        begin
          path = context.query_uri.sub("atom", "yaml")
          r = HttpRequest.new(:get, path, params).send(@@http_host)  
          context_devfile_ids = YAML.load(r.body.to_s)     
          devfile_id_row = []
          if res and res[context.id.to_s] and not res[context.id.to_s].empty? 
            devfile_id_row = res[context.id.to_s]  
          end
          commit_devfiles.each do |c_devfile|
            if context_devfile_ids.include?(c_devfile.id.to_s)
              devfile_id_row << c_devfile.id.to_s
            end
          end
          devfile_id_row.uniq!
          # {commit_id => [devfile_id, devfile_id, devfile_id...]}
          res.merge!({context.id.to_s => devfile_id_row})
          
        rescue Exception => e
          #puts e.to_s  # This one causes harm in dropbox_wrker (virtual_container, CommitManager)
        end
      end
      
      #
      # Sends the notifications:
      #
      res.each do |k, v|
        puts "context_id: #{k}: "
        cxt = Context.find_by_id(k)
        v.each do |did|
          df = Devfile.find_by_id(did)
          puts "devfile_id: #{did}"         
          XmppHelper::notificationToContextNode(df, cxt, "Context content updated!", "content-added-to-context")
        end
      end
    rescue Exception => exp
      puts "Error: #{exp.to_s}"
      puts "  -- line: #{exp.backtrace[0].to_s}"
    end    
    return
  end
  
   
  

end
