ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.


  map.root :controller => "site"
  
  
  
  map.connect 'testi', :action => 'testi', :controller => 'user'
  
  
  ## basic stuff
  map.connect 'hub', :controller => 'user', :action => 'index', :conditions => {:method => :get}
  map.connect 'logout', :controller => 'user', :action => 'logout', :conditions => {:method => :get}
  map.connect 'login', :controller => 'user', :action => 'login', :conditions => {:method => :get}
  map.connect 'login', :controller => 'user', :action => 'login', :conditions => {:method => :post}
  map.connect 'register', :controller => 'user', :action => 'register', :conditions => {:method => :put}
  map.connect 'register', :controller => 'user', :action => 'register', :conditions => {:method => :get}
  
  # News on the front page
  map.connect 'news.:format', :controller => 'site', :action => 'index'
  map.connect 'createNews', :controller => 'site', :action => 'createNews', :conditions => {:method => :put}
  map.connect '/ajax/addnews', :action => 'addnews', :controller => 'site'
  
  

  

  ## context stuff ##

  # POST: Create context, as a parameter contextname
  map.connect 'contexts/', :action => 'createContext', :controller => 'context', :conditions => {:method => :post}

  # POST: Modify context.
  map.connect 'user/:username/contexts/:contextname/', :action => 'modifyContext', :controller => 'context', :conditions => {:method => :post}
  map.connect 'contexts/:contexthash', :action => 'modifyContext', :controller => 'context', :conditions => {:method => :post}

  # DELETE: delete context
  map.connect 'user/:username/contexts/:contextname/', :action => 'deleteContext', :controller => 'context', :conditions => {:method => :delete}

  # This is really helpful for testing purposes
  # DELETE: delete all contexts from user
  map.connect 'user/:username/contexts/', :action => 'deleteContexts', :controller => 'context', :conditions => {:method => :delete}

  # PUT: Change context name for this user. Needed parameter 'context_hash' or 'old_name' (username_personalCtxname)
  map.connect 'user/:username/contexts/:contextname/', :action => 'changeContextName', :controller => 'context', :conditions => {:method => :put}

  # GET: Query contexts added to certain user
  map.connect 'user/:username/contexts.:format/', :action => 'getContexts', :controller => 'query', :conditions => {:method => :get}  
  
  # GET: Context info. contextname is the name set for this user.
  map.connect 'user/:username/contexts/:contextname.:format/', :action => 'getContext', :controller => 'context', :conditions => {:method => :get}

  # GET: Context info by contexthash.
  map.connect 'contexts/:contexthash.:format/', :action => 'getContext', :controller => 'context', :conditions => {:method => :get}

  # GET: Query for available contexts. 
  map.connect 'contexts.:format/', :action => 'getContexts', :controller => 'query', :conditions => {:method => :get}
  

  # Get suggestions for location. Parameter 'location' needed.
  map.connect 'location/tags.:format', :action => 'suggestLocation', :controller => 'query', :conditions => {:method => :get} 
  ## context stuff ends ##


  
  ## Device ##
  # REST adds/registers new device for user /user/{username}/device/{devicename}
  map.connect 'user/:username/device/:devicename', :action => 'register', :controller => 'device', :conditions => {:method => :put}
  map.connect 'user/:username/device/:devicename', :action => 'preRegister', :controller => 'device', :conditions => {:method => :options}

  # Removes device from user /user/{username}/device/{devicename}
  map.connect 'user/:username/device/:devicename', :action => 'deleteDevice', :controller => 'user', :conditions => {:method => :delete}
  
  # REST removes all user devices and their files: /user/{username}/devices
  #map.connect 'user/:username/devices', :action => 'deleteDevices', :controller => 'user', :conditions => {:method => :delete}

  # REST marks that device is online /user/{username}/device/{devicename}/online
  map.connect 'user/:username/device/:devicename/online', :action => 'online', :controller => 'device', :conditions => {:method => :post}
  
  # REST gets time when device was last online /user/{username}/device/{devicename}/online
  map.connect 'user/:username/device/:devicename/online', :action => 'getLastSeen', :controller => 'device', :conditions => {:method => :get}

  # REST adds new observed file for users device /user/{username}/device/{devicename}/observers
  map.connect 'user/:username/observer', :action => 'addObserver', :controller => 'user', :conditions => {:method => :put}

  # Give device informations
  map.connect 'user/:username/device/:devicename/', :controller => 'user', :action => 'deviceSettings'
  
  # Upload a file to a virtual container
  map.connect 'user/:username/device/:devicename/upload', :controller => 'user', :action => 'uploadInWebUI', :conditions => {:method => :post}

  # Upload a file to a virtual container with javascript
  map.connect 'user/:username/device/:devicename/uploadFromBrowser', :controller => 'user', :action => 'uploadFromBrowser', :conditions => {:method => :post}


  # Remove files from device
  map.connect 'user/:username/device/:devicename/files', :controller => 'user', :action => 'deleteDeviceFiles', :conditions => {:method => :delete}

  # update the online status of every device on the web page (ajax-stuff)
  map.connect 'device/checkDeviceStatus', :controller => 'query', :action => 'checkDeviceStatus'

  # device-specific filelist
  map.connect 'device/:deviceid/files.:format', :controller => 'query', :action => 'get', :what_to_get => 'files',
                                        :requirements => {:deviceid => /\d+/}
                                        
  # GET files on the device
  map.connect 'user/:username/device/:devicename/:what_to_get.:format', :controller => 'query', :action => 'get',
                                                                 :conditions => {:method => :get},
                                                                 :requirements => {:what_to_get => /files/}

  # REST send device filelist to server: /user/{username}/device/{devicename}/files
  map.connect 'user/:username/device/:devicename/files', :controller => 'device', :action => 'updateFilelist', :conditions => {:method => :put}

  # REST send only changed files to the server: /user/{username}/device/{devicename}/files
  map.connect 'user/:username/device/:devicename/files', :controller => 'device', :action => 'updateFilelist', :conditions => {:method => :post}

  # Update device location on map
  map.connect '/ajax/update/deviceLocationMap', :action => 'updateDeviceLocationsMap', :controller => 'user'




  ## USER ##
  # Get user info
  map.connect '/user/:username.:format/', :controller => 'user', :action => 'getUser', :conditions => {:method => :get}

  # Get user's thumbnail
  map.connect 'user/:username/metadatas/thumbnail', :controller => 'user', :action => 'getThumbnail'
  map.connect 'user/:username/metadata/thumbnail', :controller => 'user', :action => 'getThumbnail'

  # REST registers new user: /user/{username}
  map.connect 'user/:username/', :controller => 'user', :action => 'register', :conditions => {:method => :put}
  
  # Edit user information
  map.connect 'user/:username/', :controller => 'user', :action => 'modifyUser', :conditions => {:method => :post}

  # Delete user
 # map.connect 'user/:username/', :controller => 'user', :action => 'deleteUser', :conditions => {:method => :delete}
  
  # Search users
  map.connect 'users.:format', :controller => 'query', :action => 'searchUsers'
  



  ## Group ##
  # Create new group
  map.connect 'user/:username/group/:groupname', :controller => 'user', :action => 'addGroup', :conditions => {:method => :put}

  ## Delete group
  map.connect 'user/:username/deleteGroup', :controller => 'user', :action => 'deleteGroup', :conditions => {:method => :delete}
  map.connect 'user/:username/group/:groupname', :controller => 'user', :action => 'deleteGroup', :conditions => {:method => :delete}

  # Add/Remove user to/from group  
  map.connect 'user/:username/group/:groupname/member/:membername', :controller => 'group', :action => 'addUserToGroup', :conditions => {:method => :put}
  map.connect 'user/:username/group/:groupname/member/:membername', :controller => 'group', :action => 'removeUserFromGroup', :conditions => {:method => :delete}

  # Add/Remove device to/from group
  map.connect 'user/:username/group/:groupname/device/:devicename', :controller => 'group', :action => 'addDeviceToGroup', :conditions => {:method => :put}
  map.connect 'user/:username/group/:groupname/device/:devicename', :controller => 'group', :action => 'removeDeviceFromGroup', :conditions => {:method => :delete}
    
  # Edit single users' groups. edit shows the groups and save is used to save changes.
  map.connect 'user/:username/editUserGroups/:user_id', :controller => 'user', :action => 'editUserGroups'
  map.connect 'user/:username/saveUserGroups/:user_id', :controller => 'user', :action => 'saveUserGroups'
  # Edit groups for multiple users at once. edit shows the groups and save is used to save changes.
  map.connect 'user/:username/editUsersGroups', :controller => 'user', :action => 'editUsersGroups'  
  map.connect 'user/:username/saveUsersGroups', :controller => 'user', :action => 'saveUsersGroups'
  
  # Get info about a group
  map.connect '/user/:username/group/:groupname.:format', :controller => 'group', :action => 'getGroup', :conditions => {:method => :get}

  # Get group settings - Used in web-ui
  map.connect '/user/:username/groupSettings', :action => 'groupsettings', :controller => 'user', :conditions => {:method => :get}




  ## Settings in web-ui ##
  map.connect '/user/:username/settings', :action => 'settings', :controller => 'user'
  map.connect '/user/:username/emailSettings', :action => 'emailSettings', :controller => 'user'
  map.connect '/user/:username/contextSettings', :action => 'contextSettings', :controller => 'user'
  map.connect '/user/:username/virtualContainerSettings', :action => 'virtualContainerSettings', :controller => 'user'

  # Node settings
  map.connect '/user/:username/nodeSettings', :action => 'nodeSettings', :controller => 'user'
  map.connect '/user/:username/addXMPPAccount', :action => 'addXMPPAccount', :controller => 'user'
  map.connect '/user/:username/editXMPPAccount', :action => 'editXMPPAccount', :controller => 'user'
  map.connect '/user/:username/addNode', :action => 'addNode', :controller => 'user'
  map.connect '/user/:username/deleteNode', :action => 'deleteNode', :controller => 'user'

  # Create node and publish to node (Not sure if these are used anywhere or by any client, or are these old)
  map.connect 'createnode/*nodename', :action => 'RESTCreateNode', :controller => 'context'
  map.connect 'publishtonode/*nodename', :action => 'RESTPublishToNode', :controller => 'context'



  ## FACEBOOK ##
  map.connect 'user/:username/facebookSettings', :controller => 'user', :action => 'facebookSettings'
  map.connect '/facebook_callback', :controller => 'user', :action => 'facebook_callback'
  map.connect 'user/:username/facebookPublishPhoto', :controller => 'user', :action => 'facebookPublishPhoto'
  map.connect 'user/:username/facebookWriteOnWall', :controller => 'user', :action => 'facebookWriteOnWall', :conditions => {:method => :post}
  map.connect 'user/:username/facebookDeleteToken', :controller => 'user', :action => 'facebookDeleteToken', :conditions => {:method => :delete}
  map.connect 'user/:username/facebookConnected', :controller => 'user', :action => 'facebookConnected', :conditions => {:method => :get}
  map.connect 'user/:username/facebookImportAlbum', :controller => 'user', :action => 'facebookImportAlbum'
  # Facebook authorization for client programs
  map.connect 'user/:username/facebook_authorization', :controller => 'user', :action => 'facebook_client_authorization'
  map.connect 'user/:username/facebook_client_callback', :controller => 'user', :action => 'facebook_client_callback'

  map.connect 'user/:username/fbTestingStuff', :controller => 'user', :action => 'fbTestingStuff', :conditions => {:method => :get}
  map.connect 'user/:username/fbTestingStuff2', :controller => 'user', :action => 'fbTestingStuff2', :conditions => {:method => :get}


  ## DROPBOX ##
  map.connect 'user/:username/dropboxSettings', :controller => 'user', :action => 'dropboxSettings'
  map.connect '/dropbox_callback', :controller => 'user', :action => 'dropbox_callback', :conditions => {:method => :get}
  map.connect 'user/:username/dropboxDeleteToken', :controller => 'user', :action => 'dropboxDeleteToken', :conditions => {:method => :delete}
  map.connect 'user/:username/dropboxConnected', :controller => 'user', :action => 'dropboxConnected', :conditions => {:method => :get}
  map.connect 'user/:username/dbCreateDirPoller', :controller => 'user', :action => 'dbCreateDirPoller'
  map.connect 'user/:username/dbDeletePoller/:ud_id', :controller => 'user', :action => 'dbDeletePoller'
  map.connect 'user/:username/dropboxUpload', :controller => 'user', :action => 'dropboxUpload', :conditions => {:method => :put}
  # Dropbox authorization for client programs
  map.connect 'user/:username/dropbox_authorization', :controller => 'user', :action => 'dropbox_client_authorization'
  map.connect 'user/:username/dropbox_client_callback', :controller => 'user', :action => 'dropbox_client_callback'


  ## TWITTER ##
  map.connect 'user/:username/twitterSettings', :controller => 'user', :action => 'twitterSettings'
  map.connect '/twitter_callback', :controller => 'user', :action => 'twitter_callback', :conditions => {:method => :get}
  map.connect 'user/:username/twitterDeleteToken', :controller => 'user', :action => 'twitterDeleteToken', :conditions => {:method => :delete}
  map.connect 'user/:username/twitterPublish', :controller => 'user', :action => 'twitterPublish', :conditions => {:nethod => :post}
  map.connect 'user/:username/twitterConnected', :controller => 'user', :action => 'twitterConnected', :conditions => {:method => :get}
  # Twitter authorization for client programs
  map.connect 'user/:username/twitter_authorization', :controller => 'user', :action => 'twitter_client_authorization'
  map.connect 'user/:username/twitter_client_callback', :controller => 'user', :action => 'twitter_client_callback'

  
  ## FLICKR ##
  map.connect 'user/:username/flickrSettings', :controller => 'user', :action => 'flickrSettings'
  map.connect '/flickr_callback', :action => 'flickr_callback', :controller => 'user'
  map.connect 'user/:username/flickrConnected', :controller => 'user', :action => 'flickrConnected', :conditions => {:method => :get} 
  map.connect 'user/:username/flickrDeleteToken', :controller => 'user', :action => 'flickrDeleteToken', :conditions => {:method => :delete}
  map.connect 'user/:username/flickrImportPhotos', :controller => 'user', :action => 'flickrImportPhotos'
  map.connect 'user/:username/flickrPublishPhoto', :controller => 'user', :action => 'flickrPublishPhoto'
  # Flickr authorization for client programs
  map.connect 'user/:username/flickr_authorization', :controller => 'user', :action => 'flickr_client_authorization'
  map.connect 'user/:username/flickr_client_callback', :controller => 'user', :action => 'flickr_client_callback'
 
 
  # Observers for files
  map.connect 'user/:username/observed', :controller => 'user', :action => 'modifyObserversForFile', :conditions => {:method => :get}
  map.connect 'user/:username/observed/files', :controller => 'user', :action => 'saveObserversForFile', :conditions => {:method => :put}
  

  
  
  
  
  ## Metadata
  # change(/create) metadata
  map.connect 'user/:username/device/:devicename/metadata/*filepath', :controller => 'devfile', :action => 'changeMetadata', :conditions => {:method => :post}

  # delete metadata
  map.connect 'user/:username/device/:devicename/metadata/*filepath', :controller => 'devfile', :action => 'deleteMetadata', :conditions => {:method => :delete}

  # create new metadatatype
  map.connect 'metadatatype/*metadatatypename', :controller => 'application', :action => 'addMetadataType', :conditions => {:method => :put}

  # Get list of metadatatypes
  map.connect 'metadatatypes.:format', :controller => 'query', :action => 'getMetadatatypes',
                                                               :conditions => {:method => :get}
  # change metadatatype
  #map.connect 'metadatatype/*metadatatypename', :controller => 'application', :action => 'changeMetadataType', :conditions => {:method => :post}

  # delete metadata type and all metadata of that type
  # Remove from comments to make available
  #map.connect 'metadatatype/*metadatatypename', :controller => 'application', :action => 'deleteMetadataType', :conditions => {:method => :delete}

  



  
  
  ## FILE ##
  # Filerights - Edit groups the file belongs to.
  map.connect 'user/:username/device/:devicename/filerights/*filepath', :controller => 'devfile', :action => 'viewFileRights', :conditions => {:method => :get}
  map.connect 'user/:username/device/:devicename/filerights/*filepath', :controller => 'devfile', :action => 'editRights', :conditions => {:method => :post}
  #  Make file public/private   
  map.connect 'user/:username/device/:devicename/makeFilePublic/*filepath', :controller => 'devfile', :action => 'makePub'               
  map.connect 'user/:username/device/:devicename/makeFilePrivate/*filepath', :controller => 'devfile', :action => 'makePriv', :conditions => {:method => :post}  
  
  # GET versionlist of a file
  map.connect 'user/:username/device/:devicename/fileversions/*filepath', :controller => 'query', :action => 'getVersionlist', :conditions => {:method => :get}
  map.connect 'device/:deviceid/fileversions/*filepath', :controller => 'query', :action => 'getVersionlist', :requirements => {:deviceid => /\d+/}
    
  # GET metadatas of a certain file
  map.connect 'user/:username/device/:devicename/metadatas/*filepath', :controller => 'devfile', :action => 'getMetadatas', :conditions => {:method => :get}
  map.connect 'user/:username/device/:devicename/metadata/*filepath', :controller => 'devfile', :action => 'getMetadatas', :conditions => {:method => :get}
  
  # GET essence of a certain file
  map.connect 'user/:username/device/:devicename/essence/*filepath', :controller => 'devfile', :action => 'getfile', :conditions => {:method => :get}
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', :action => 'getfile', :conditions => {:method => :get} 
  map.connect 'device/:deviceid/files/*filepath', :controller => 'devfile',
                                            :action => 'getfile',
                                            :requirements => {:deviceid => /\d+/}
                                            
  # GET thumbnail
  map.connect 'allowthumbnails/:deviceid/:thumbname.png', :controller => 'devfile', :action => 'getThumbnail', :conditions => {:method => :get}#,
                                            #    :requirements => {:deviceid => /\d+/}
  
                                            
  # DELETE essence from server, all metadata is preserved
  map.connect 'user/:username/device/:devicename/essence/*filepath', :controller => 'devfile', :action => 'deleteEssence', :conditions => {:method => :delete}

  # REST deletes all files from user: /user/{username}/files
 # map.connect 'user/:username/files', :controller => 'user', :action => 'deleteAllUserFiles', :conditions => {:method => :delete}

  # Mark the file deleted
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', :action => 'deleteFile', :conditions => {:method => :delete}


  # send upload request to device
  map.connect 'user/:username/device/:devicename/requestUpload/*filepath', :controller => 'devfile',
                                            :action => 'sendUploadRequest'
  
  # declare upload beginning
  map.connect 'user/:username/device/:devicename/beginUpload/*filepath', :controller => 'devfile', :action => 'beginUpload'

  # REST upload file: /user/{username}/device/{devicename}/files/{*filepath}
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', 
                                            :action => 'upload', :conditions => {:method => :put}
                                            
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', 
                                            :action => 'preUpload', :conditions => {:method => :options}
  
  
  



  ## SEARCH
  # GET all devices or files of a user
  map.connect 'user/:username/:what_to_get.:format', :controller => 'query', :action => 'get',
                                                     :requirements => {:what_to_get => /(files|devices)/},
                                                     :conditions => {:method => :get}

  # get either files or devices (used for a query without defined context)
  map.connect ':what_to_get.:format', :controller => 'query', :action => 'get',
                                      :requirements => {:what_to_get => /(files|devices)/}
                                      
  # Search - files/users/contexts
  map.connect 'search', :controller => 'query', :action => 'search'
  
  # Change shown blob (aka. version of file) in file search
  map.connect 'ajax/update/blob', :action => 'changeFileOnView', :controller => 'query'
             
  # Get possible values for certain metadata type
  map.connect 'metadatatype/:metadatatype.:format', :action =>'getPossibleMetadataValues', :controller => 'query', :conditions => {:method => :get}
             
             
             
  # Used by backup service
  map.connect 'authenticateUser', :action => 'authenticateUser', :controller => 'user', :conditions => {:method => :get}
  # Uncomment this, to be able to add backup_recovery_path to all files in the system
  #map.connect 'addBackupRecoveryPathToAll', :action => 'temp', :controller => 'devfile'
             
             
                                      
  ## Help pages
  map.connect 'site/help/queryInstructions', :controller => 'query', :action => 'doInstructions'
  map.connect 'site/help/fileQueryInstructions', :controller => 'query', :action => 'fileQueryInstructions'
  map.connect 'site/help/contextInstructions', :controller => 'query', :action => 'contextInstructions'
  map.connect 'site/help/authenticationInstructions', :controller => 'query', :action => 'authenticationInstructions'
  map.connect 'site/help/virtualDeviceInstructions', :controller => 'query', :action => 'virtualDeviceInstructions'
  map.connect 'site/help/emailInstructions', :controller => 'query', :action => 'emailInstructions'
  map.connect 'site/help/flickrInstructions', :controller => 'query', :action => 'flickrInstructions'
  map.connect 'site/help/facebookInstructions', :controller => 'query', :action => 'facebookInstructions'
  map.connect 'site/help/dropboxInstructions', :controller => 'query', :action => 'dropboxInstructions'
  map.connect 'site/help/twitterInstructions', :controller => 'query', :action => 'twitterInstructions'
  map.connect 'site/help/userInstructions', :controller => 'query', :action => 'userInstructions'
  map.connect 'site/help/groupInstructions', :controller => 'query', :action => 'groupInstructions'
  map.connect 'site/help/containerInstructions', :controller => 'query', :action => 'containerInstructions'
  map.connect 'site/help/rubyContainer', :controller => 'query', :action => 'rubyContainer'
  map.connect 'site/help/androidContainer', :controller => 'query', :action => 'androidContainer'
  
  
  # The old documentation
  map.connect 'doc/app/*filepath', :action => 'doc', :controller => 'user'
  
  map.connect 'site/:action', :controller => 'site'
  

end
