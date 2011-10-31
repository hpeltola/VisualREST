ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.root :controller => "site"
  
  # Uncomment this, to be able to add backup_recovery_path to all files in the system
  #map.connect 'addBackupRecoveryPathToAll', :action => 'temp', :controller => 'devfile'
  
  
  map.connect 'testi', :action => 'testi', :controller => 'user'
  
  map.connect 'ajax/test', :action => 'test', :controller => 'user'
  
  map.connect 'ajax/update/blob', :action => 'changeFileOnView', :controller => 'query'
  map.connect '/ajax/groupsettings', :action => 'groupsettings', :controller => 'user'
  map.connect '/ajax/addnews', :action => 'addnews', :controller => 'site'
  #map.connect '/ajax/observersettings', :action => 'observerSettings', :controller => 'user'
  
  map.connect 'ajax/add/notification', :action => 'addNotificationView', :controller => 'query'
  
  map.connect '/ajax/update/deviceLocationMap', :action => 'updateDeviceLocationsMap', :controller => 'user'
  
  map.connect 'doc/app/*filepath', :action => 'doc', :controller => 'user'

  map.connect 'createnode/*nodename', :action => 'RESTCreateNode', :controller => 'context'
  
  map.connect 'publishtonode/*nodename', :action => 'RESTPublishToNode', :controller => 'context'
  
  # Linking with flickr account
  map.connect 'flickrAuthentication', :action => 'flickrAuthentication', :controller => 'user'
  
  # Used by backup service
  map.connect 'authenticateUser', :action => 'authenticateUser', :controller => 'user', :condition => {:method => :get}
  
  # basic stuff
  map.connect 'hub', :controller => 'user', :action => 'index', :conditions => {:method => :get}
  map.connect 'logout', :controller => 'user', :action => 'logout', :conditions => {:method => :get}
  map.connect 'login', :controller => 'user', :action => 'login', :conditions => {:method => :get}
  map.connect 'login', :controller => 'user', :action => 'login', :conditions => {:method => :post}
  map.connect 'register', :controller => 'user', :action => 'register', :conditions => {:method => :put}
  map.connect 'register', :controller => 'user', :action => 'register', :conditions => {:method => :get}
  
  map.connect 'news.:format', :controller => 'site', :action => 'index'
  map.connect 'createNews', :controller => 'site', :action => 'createNews', :conditions => {:method => :put}
  
  
  # REST adds/registers new device for user /user/{username}/device/{devicename}
  map.connect 'user/:username/device/:devicename', :action => 'register', :controller => 'device', :conditions => {:method => :put}

  # REST removes device from user /user/{username}/device/{devicename}
  map.connect 'user/:username/device/:devicename', :action => 'deleteDevice', :controller => 'user', :conditions => {:method => :delete}
  
  # REST removes all user devices and their files: /user/{username}/devices
  map.connect 'user/:username/devices', :action => 'deleteDevices', :controller => 'user', :conditions => {:method => :delete}
  

  # REST context stuff

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

  map.connect 'test', :action => 'foo', :controller => 'user'
  

  # REST context stuff ends
  

  # REST marks that device is online /user/{username}/device/{devicename}/online
  map.connect 'user/:username/device/:devicename/online', :action => 'online', :controller => 'device', :conditions => {:method => :post}
  
  # REST gets time when device was last online /user/{username}/device/{devicename}/online
  map.connect 'user/:username/device/:devicename/online', :action => 'getLastSeen', :controller => 'device', :conditions => {:method => :get}

  # REST adds new observed file for users device /user/{username}/device/{devicename}/observers
  map.connect 'user/:username/observer', :action => 'addObserver', :controller => 'user', :conditions => {:method => :put}


  # Gives device informations
  map.connect 'user/:username/device/:devicename/', :controller => 'user', :action => 'deviceSettings'
  
  # Upload a file to a virtual container
  map.connect 'user/:username/device/:devicename/upload', :controller => 'user', :action => 'uploadInWebUI', :conditions => {:method => :post}

  # REST removes files from device: /user/{username}/device/{devicename}/files
  map.connect 'user/:username/device/:devicename/files', :controller => 'user', :action => 'deleteDeviceFiles', :conditions => {:method => :delete}

  # updates the online status of every device on the web page (ajax-stuff)
  map.connect 'device/checkDeviceStatus', :controller => 'query', :action => 'checkDeviceStatus'

  # device-specific filelist
  map.connect 'device/:deviceid/files.:format', :controller => 'query', :action => 'get', :what_to_get => 'files',
                                        :requirements => {:deviceid => /\d+/}
  map.connect 'user/:username/device/:devicename/:what_to_get.:format', :controller => 'query', :action => 'get',
                                                                 :conditions => {:method => :get},
                                                                 :requirements => {:what_to_get => /files/}


  # REST registers new user: /user/{username}
  map.connect 'user/:username/', :controller => 'user', :action => 'register', :conditions => {:method => :put}
  
  # Edit user information
  map.connect 'user/:username/', :controller => 'user', :action => 'modifyUser', :conditions => {:method => :post}

  # REST deletes user: /user/{username}
  map.connect 'user/:username/', :controller => 'user', :action => 'deleteUser', :conditions => {:method => :delete}
  
  # Get user info
  map.connect '/user/:username.:format/', :controller => 'user', :action => 'getUser', :conditions => {:method => :get}

  
  # REST add new group
  #map.connect 'user/:username/addGroup', :controller => 'user', :action => 'addGroup', :conditions => {:method => :put}
  
  # user's setting group adding or user groups save

  map.connect 'fb_login', :controller => 'user', :action => 'fb_login'
  map.connect 'fb_login2', :controller => 'user', :action => 'fb_login2'

  map.connect 'user/:username/dbDeletePoller/:ud_id', :controller => 'user', :action => 'dbDeletePoller'

  map.connect 'user/:username/:action', :controller => 'user', :requirements => {:action => /(settings|addGroup|deleteGroup|saveUsersGroups|nodeSettings|addXMPPAccount|editXMPPAccount|addNode|deleteNode|emailSettings|contextSettings|virtualContainerSettings|fbDeleteToken|fbSettings|fbImportFromAlbums|fbRedirectToAuthentication|importContentFromFlickr|importContentFromFB|dropboxSettings|getDropboxToken|dbCreateDirPoller|dbDeleteToken|testi|)/}
  
  map.connect 'user/:username/observed', :controller => 'user', :action => 'modifyObserversForFile', :conditions => {:method => :get}

  map.connect 'user/:username/observed/files', :controller => 'user', :action => 'saveObserversForFile', :conditions => {:method => :put}
  
  # REST add group: /user/{username}/group/{groupname}
  map.connect 'user/:username/group/:groupname', :controller => 'user', :action => 'addGroup', :conditions => {:method => :put}

  # REST deletes group: /user/{username}/group/{groupname}
  map.connect 'user/:username/group/:groupname', :controller => 'user', :action => 'deleteGroup', :conditions => {:method => :delete}
    
  # REST adds user to group /group/{groupname}/member/{membername}  
  map.connect 'user/:username/group/:groupname/member/:membername', :controller => 'group', :action => 'addUserToGroup', :conditions => {:method => :put}

  # REST removes user from group /group/{groupname}/member/{membername}
  map.connect 'user/:username/group/:groupname/member/:membername', :controller => 'group', :action => 'removeUserFromGroup', :conditions => {:method => :delete}
  
  # REST edits file rights: /user/{username}/device/{devicename}/filerights/{*filepath}
  map.connect 'user/:username/device/:devicename/filerights/*filepath', :controller => 'devfile', :action => 'editRights', :conditions => {:method => :post}
 
  map.connect 'user/:username/device/:devicename/filerights/*filepath', :controller => 'devfile', :action => 'viewFileRights', :conditions => {:method => :get}
 

  # REST send device filelist to server: /user/{username}/device/{devicename}/files
#  map.connect 'user/:username/device/:devicename/files', :controller => 'device', :action => 'updateFilelist', :conditions => {:method => :put}
  map.connect 'user/:username/device/:devicename/files', :controller => 'device', :action => 'updateFilelist', :conditions => {:method => :put}

  # REST send only changed files to the server: /user/{username}/device/{devicename}/files
  map.connect 'user/:username/device/:devicename/files', :controller => 'device', :action => 'updateFilelist', :conditions => {:method => :post}

  # is used to edit single users' groups
  map.connect 'user/:username/editUserGroups/:user_id', :controller => 'user', :action => 'editUserGroups'
  map.connect 'user/:username/saveUserGroups/:user_id', :controller => 'user', :action => 'saveUserGroups'
  
  # Has search feature included and user can edit multiple users in same GUI
  map.connect 'user/:username/editUsersGroups/', :controller => 'user', :action => 'editUsersGroups'  
  map.connect 'user/:username/saveUsersGroups/:user_id', :controller => 'user', :action => 'saveUsersGroups'

  
  # REST deletes all files from user: /user/{username}/files
  map.connect 'user/:username/files', :controller => 'user', :action => 'deleteAllUserFiles', :conditions => {:method => :delete}

  
  # all certain user's devices or files (from all his devices)
  map.connect 'user/:username/:what_to_get.:format', :controller => 'query', :action => 'get',
                                                     :requirements => {:what_to_get => /(files|devices)/},
                                                     :conditions => {:method => :get}
  
  # search for users
  map.connect 'users.:format', :controller => 'query', :action => 'searchUsers'
  
  # Get user's thumbnail
  map.connect 'user/:username/metadatas/thumbnail', :controller => 'user', :action => 'getThumbnail'
  map.connect 'user/:username/metadata/thumbnail', :controller => 'user', :action => 'getThumbnail'
  
  # REST
  # versionlist
  map.connect 'user/:username/device/:devicename/fileversions/*filepath', :controller => 'query', :action => 'getVersionlist',
                                                                   :conditions => {:method => :get}
  map.connect 'device/:deviceid/fileversions/*filepath', :controller => 'query',
                                            :action => 'getVersionlist',
                                            :requirements => {:deviceid => /\d+/}
  
  # get metadatas of a certain file
  map.connect 'user/:username/device/:devicename/metadatas/*filepath', :controller => 'devfile', :action => 'getMetadatas', :conditions => {:method => :get}
  map.connect 'user/:username/device/:devicename/metadata/*filepath', :controller => 'devfile', :action => 'getMetadatas', :conditions => {:method => :get}
  # get essence of a certain file
  map.connect 'user/:username/device/:devicename/essence/*filepath', :controller => 'devfile', :action => 'getfile', :conditions => {:method => :get}
  
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', :action => 'getfile', :conditions => {:method => :get}
  
  map.connect 'device/:deviceid/files/*filepath', :controller => 'devfile',
                                            :action => 'getfile',
                                            :requirements => {:deviceid => /\d+/}
  # REST
  # change(/create) metadata
  map.connect 'user/:username/device/:devicename/metadata/*filepath', :controller => 'devfile', :action => 'changeMetadata', :conditions => {:method => :post}

  # REST
  # delete metadata
  map.connect 'user/:username/device/:devicename/metadata/*filepath', :controller => 'devfile', :action => 'deleteMetadata', :conditions => {:method => :delete}

  # REST
  # create new metadatatype
  map.connect 'metadatatype/*metadatatypename', :controller => 'application', :action => 'addMetadataType', :conditions => {:method => :put}

  # REST
  # change metadatatype
  map.connect 'metadatatype/*metadatatypename', :controller => 'application', :action => 'changeMetadataType', :conditions => {:method => :post}

  # delete metadata type and all metadata of that type
  # Remove from comments to make available
  #map.connect 'metadatatype/*metadatatypename', :controller => 'application', :action => 'deleteMetadataType', :conditions => {:method => :delete}

  # REST
  # Get list of metadatatypes
  map.connect 'metadatatypes.:format', :controller => 'query', :action => 'getMetadatatypes',
                                                               :conditions => {:method => :get}
  
    
  
  # edit file rights
#  map.connect 'user/:username/device/:devicename/editfile/*filepath', :controller => 'devfile',
#                                              :action => 'editFileRights'
                                              
  map.connect 'user/:username/device/:devicename/makeFilePublic/*filepath', :controller => 'devfile',
                                            :action => 'makePub'
                                            
  map.connect 'user/:username/device/:devicename/makeFilePrivate/*filepath', :controller => 'devfile',
                                            :action => 'makePriv',
                                            :conditions => {:method => :post}
  
  # send upload request
  map.connect 'user/:username/device/:devicename/requestUpload/*filepath', :controller => 'devfile',
                                            :action => 'sendUploadRequest'
  
  # upload file
  #map.connect 'user/:username/device/:devicename/upload', :controller => 'devfile', :action => 'upload', :conditions => {:method => :post}
  
  # REST upload file: /user/{username}/device/{devicename}/files/{*filepath}
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', 
                                            :action => 'upload', :conditions => {:method => :put}
  
  # REST delete file: /user/{username}/device/{devicename}/files/{*filepath}
  map.connect 'user/:username/device/:devicename/files/*filepath', :controller => 'devfile', :action => 'deleteFile', :conditions => {:method => :delete}
  
  
  # declare upload beginning
  map.connect 'user/:username/device/:devicename/beginUpload/*filepath', :controller => 'devfile', :action => 'beginUpload'

  # get either files or devices (used for a query without defined context)
  map.connect ':what_to_get.:format', :controller => 'query', :action => 'get',
                                      :requirements => {:what_to_get => /(files|devices)/}
                                      
  # Search
  map.connect 'search', :controller => 'query', :action => 'search'
                                      
  # get site stuff
  map.connect 'site/help/queryInstructions', :controller => 'query', :action => 'doInstructions'
  map.connect 'site/help/fileQueryInstructions', :controller => 'query', :action => 'fileQueryInstructions'
  map.connect 'site/help/contextInstructions', :controller => 'query', :action => 'contextInstructions'
  map.connect 'site/help/authenticationInstructions', :controller => 'query', :action => 'authenticationInstructions'
  map.connect 'site/help/virtualDeviceInstructions', :controller => 'query', :action => 'virtualDeviceInstructions'
  map.connect 'site/help/emailInstructions', :controller => 'query', :action => 'emailInstructions'
  map.connect 'site/help/flickrInstructions', :controller => 'query', :action => 'flickrInstructions'
  map.connect 'site/help/userInstructions', :controller => 'query', :action => 'userInstructions'
  
  map.connect 'site/:action', :controller => 'site'
  
#  map.connect ':controller/:action/:id'
#  map.connect ':controller/:action/:id.:format'
end
