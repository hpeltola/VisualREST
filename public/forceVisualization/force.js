var GetUsers = function(){
  console.log("getting users");

  var path = "/users";
  var params = {};
  params = authParams(path);
  params["user"] = "";
  params["qoption[format]"] = "json";

	$.ajax({
		url: base_url + path, 
		data: params, 
		dataType: 'jsonp',
		jsonp: "qoption[json_callback]",
  	jsonpCallback: 'handleUsers',
    error: function(){alert("Problem getting users list")}
  });
}

var GetUserDevices = function(username){
  console.log("getting devices");

  var path = "/user/" + username + "/devices";
  var params = {};
  params = authParams(path);
  params["qoption[format]"] = "json";

  $.ajax({
	  url: base_url + path, 
	  data: params, 
	  dataType: 'jsonp',
  	jsonp: "qoption[json_callback]",
	  jsonpCallback: 'handleDevices',
    error: function(){alert("This user does not have any devices!")}
  });
}

var GetDeviceFiles = function(username, devicename){
  console.log("getting device files");

  var path = "/user/" + username + "/device/" + devicename + "/files";
  var params = {};
  params = authParams(path);
  params["qoption[format]"] = "json";

  $.ajax({
	  url: base_url + path, 
	  data: params, 
	  dataType: 'jsonp',
  	jsonp: "qoption[json_callback]",
	  jsonpCallback: 'handleDeviceFiles',
    error: function(){alert("Problem getting device files")}
  });
}

var GetGroup = function(user, group){
  console.log("getting group");

  var path = "/user/" + user + "/group/" + group
  var params = {};
  params = authParams(path);
  params["qoption[format]"] = "json";

  document.getElementById("path").innerHTML = "<b>Path:</b> /user/" + user + "/group/" + group;

  $.ajax({
	  url: base_url + path, 
	  data: params, 
	  dataType: 'jsonp',
  	jsonp: "qoption[json_callback]",
	  jsonpCallback: 'handleGroupInfo',
    error: function(){alert("Problem getting group info")}
  });

}

handleGroupInfo = function(data){

			var nodes = [];
			var links = [];
			var labelAnchors = [];
			var labelAnchorLinks = [];

      // Create the center node
      var node = { link: "users", thumb: "./img/user-group-2.png" };
      nodes.push(node);
	    labelAnchors.push({
  	    node : node
	    });
	    labelAnchors.push({
  	    node : node
	    });
    
      // Create all file nodes
      for( var i in data["files"] ){
        if( data["files"].hasOwnProperty(i) ){

         //     console.log(data["files"][i].username);
         //     console.log(data["files"][i].devicename);
         //     console.log(data["files"][i].filename);

				      node = {
					      label : data["files"][i].filename,
                link : "file",
                username : data["files"][i].username,
                devicename : data["files"][i].devicename,
                link_file : data["files"][i].essence_uri,
                thumb : data["files"][i].thumbnail
				      };
				      nodes.push(node);
				      labelAnchors.push({
					      node : node
				      });
				      labelAnchors.push({
					      node : node
				      });
        }   
      }

      // Create device nodes with files
  console.log(data["devices"]);
      for( var i in data["devices"] ){
        if( data["devices"].hasOwnProperty(i) ){

          console.log(data["devices"][i].username);
          console.log(data["devices"][i].devicename);


     //     AddDeviceFilesToNode(data["devices"][i].username, data["devices"][i].devicename, nodes, links, labelAnchors);


            

				      node = {
					      label : data["devices"][i].username + " / " + data["devices"][i].devicename,
                link : "files",
                username : data["devices"][i].username,
                devicename : data["devices"][i].devicename,
                thumb : "./img/Computer-icon.png"
				      };
				      nodes.push(node);
				      labelAnchors.push({
					      node : node
				      });
				      labelAnchors.push({
					      node : node
				      });
        }   
      }


			for(var i = 1; i < nodes.length; i++) {
      // Create links between center node and all other
				links.push({
					source : 0,
					target : i,
					weight : 1
        });
				
        // This is for label anchoring
				labelAnchorLinks.push({
					source : i * 2,
					target : i * 2 + 1,
					weight : 1
				});
			};
  
      createForceGraph(nodes, links, labelAnchors, labelAnchorLinks);
  

}

AddDeviceFilesToNode = function(usrname, devname, nodes, links, labelAnchors){
  console.log("TODO: add username: " + usrname + ", devicename: " + devname);
}

handleDeviceFiles = function(data){
			var nodes = [];
			var links = [];
			var labelAnchors = [];
			var labelAnchorLinks = [];

      // Create the center node
      var node = { link: "devices", label: current_user, thumb: current_dev_thumb};
      nodes.push(node);
	    labelAnchors.push({
  	    node : node
	    });
	    labelAnchors.push({
  	    node : node
	    });
    
      // Create all file nodes
      for( var i in data ){
        if( data.hasOwnProperty(i) ){
          for( var j in data[i]){
            if( data[i].hasOwnProperty(j) ){
				      node = {
					      label : data[i][j].filename,
                link : "file",
                username : data[i][j].file_user,
                devicename : data[i][j].file_device,
                link_file : data[i][j].essence_uri,
                thumb : data[i][j].thumbnail
				      };
				      nodes.push(node);
				      labelAnchors.push({
					      node : node
				      });
				      labelAnchors.push({
					      node : node
				      });
            }
          }
        }   
      }


			for(var i = 1; i < nodes.length; i++) {
      // Create links between center node and all other
				links.push({
					source : 0,
					target : i,
					weight : 1
        });
				
        // This is for label anchoring
				labelAnchorLinks.push({
					source : i * 2,
					target : i * 2 + 1,
					weight : 1
				});
			};
  
      createForceGraph(nodes, links, labelAnchors, labelAnchorLinks);
}


handleDevices = function(data){

			var nodes = [];
			var links = [];
			var labelAnchors = [];
			var labelAnchorLinks = [];
  
      // Create the center node
      var node = { link: "users", thumb: current_user_thumb };
      nodes.push(node);
	    labelAnchors.push({
  	    node : node
	    });
	    labelAnchors.push({
  	    node : node
	    });
    
      // Create all device nodes
      for( var i in data ){
        if( data.hasOwnProperty(i) ){
          if( data[i].hasOwnProperty("device_name") ){
            // Thumbnail icon	
            var thumb = "./img/server-icon.png";
            if( data[i].device_type == "virtual_container") {
              thumb = "./img/Database.png"
            } else if( data[i].device_type == "x86_64-linux___" ) {
              thumb = "./img/Computer-icon.png"
            } else if( data[i].device_type == "android" || data[i].device_type == "Nokia-N900" ) {
              thumb = "./img/Smartphone-icon.png"
            } else if( data[i].device_type == "arm-linux___" ) {
              thumb = "./img/PDA-icon.png"
            }

				    node = {
					    label : data[i].device_name,
              link : "files",
              username : data[i].owner_name,
              devicename : data[i].device_name,              
              thumb : thumb
				    };
				    nodes.push(node);
				    labelAnchors.push({
					    node : node
				    });
				    labelAnchors.push({
					    node : node
				    });
          }
        }   
      }

			for(var i = 1; i < nodes.length; i++) {
      // Create links between center node and all other
				links.push({
					source : 0,
					target : i,
					weight : 1
        });
				
        // This is for label anchoring
				labelAnchorLinks.push({
					source : i * 2,
					target : i * 2 + 1,
					weight : 1
				});
			};
  
      createForceGraph(nodes, links, labelAnchors, labelAnchorLinks);
}

handleUsers = function(data){

			var nodes = [];
			var links = [];
			var labelAnchors = [];
			var labelAnchorLinks = [];
  
      current_user = null;
      current_user_thumb = null;
      current_dev_thumb = null;

      // Create the center node
      var node = { thumb: "./img/user-group-2.png" };
      nodes.push(node);
	    labelAnchors.push({
  	    node : node
	    });
	    labelAnchors.push({
  	    node : node
	    });
    
      // Create all user nodes
      for( var i in data ){
        if( data.hasOwnProperty(i) ){
          if( data[i].hasOwnProperty("username") ){	
				    node = {
					    label : data[i].username,
              link : "devices",
              thumb : data[i].thumbnail_uri
				    };
				    nodes.push(node);
				    labelAnchors.push({
					    node : node
				    });
				    labelAnchors.push({
					    node : node
				    });
          }
        }   
      }

			for(var i = 1; i < nodes.length; i++) {
      // Create links between center node and all other
				links.push({
					source : 0,
					target : i,
					weight : 1
        });
				
        // This is for label anchoring
				labelAnchorLinks.push({
					source : i * 2,
					target : i * 2 + 1,
					weight : 1
				});
			};
  
      createForceGraph(nodes, links, labelAnchors, labelAnchorLinks);
}

createForceGraph = function(nodes, links, labelAnchors, labelAnchorLinks){
      var w = 800, h = 500;
			var labelDistance = 0;
      d3.select("svg").remove();
			var vis = d3.select("body #container").append("svg:svg").attr("width", w).attr("height", h);

      // Force for nodes
			var force = d3.layout.force().size([w, h]).nodes(nodes).links(links).gravity(1).linkDistance(75).charge(-6000).linkStrength(function(x) {
				return x.weight * 2
			}).friction(0.3);

			force.start();

      // Force for node names
			var force2 = d3.layout.force().nodes(labelAnchors).links(labelAnchorLinks).gravity(0).linkDistance(0).linkStrength(8).charge(-100).size([w, h]);
			force2.start();

			var link = vis.selectAll("line.link").data(links).enter().append("svg:line").attr("class", "link").style("stroke", "#CCC");

			var node = vis.selectAll("g.node").data(force.nodes()).enter().append("svg:g").attr("class", "node");
			//node.append("svg:circle").attr("r", 5).style("fill", "#555").style("stroke", color).style("stroke-width", 3);
			node.call(force.drag);

      
      var anode = vis.selectAll("g.node");
      var size = 16;
      if( anode[0].length < 20 ){
        size = 32;  
      }

      anode.each( function(i){
        var test = d3.select(this);
        if( i.thumb != null ){
          test.append("image")
              .attr("xlink:href", i.thumb)
              .attr("x", -(size/2))
              .attr("y", -(size/2))
              .attr("width", size)
              .attr("height", size);
        }
      });


			var anchorLink = vis.selectAll("line.anchorLink").data(labelAnchorLinks)//.enter().append("svg:line").attr("class", "anchorLink").style("stroke", "#999");

			var anchorNode = vis.selectAll("g.anchorNode").data(force2.nodes()).enter().append("svg:g").attr("class", "anchorNode");
			anchorNode.append("svg:circle").attr("r", 0).style("fill", "#FFF");
				anchorNode.append("svg:text").text(function(d, i) {
				return i % 2 == 0 ? "" : d.node.label
			}).style("fill", "#555").style("font-family", "Arial").style("font-size", 12);

			var updateLink = function() {
				this.attr("x1", function(d) {
					return d.source.x;
				}).attr("y1", function(d) {
					return d.source.y;
				}).attr("x2", function(d) {
					return d.target.x;
				}).attr("y2", function(d) {
					return d.target.y;
				});

			}

       vis.selectAll("g.node").on("click", function(d){
        if( d.link == "users"){
          document.getElementById("path").innerHTML = "<b>Path:</b> /";
          GetUsers();
        }
        else if( d.link == "devices" ){
          current_user = d.label;
          current_user_thumb = base_url + "/user/"+current_user+"/metadatas/thumbnail";

          document.getElementById("path").innerHTML = "<b>Path:</b> /user/"+current_user;
          GetUserDevices(current_user);
        }
        else if( d.link == "files"){
          current_user = d.username;
          current_dev_thumb = d.thumb;
          document.getElementById("path").innerHTML = "<b>Path:</b> /user/"+current_user+"/device/"+d.devicename;
console.log(current_user);
console.log(d.devicename);
          GetDeviceFiles(current_user, d.devicename);
        }
        else if( d.link == "file"){
          var tmpPath = d.link_file.slice(d.link_file.indexOf("/user/"));
//          console.log(tmpPath);
//          console.log(authParams(tmpPath));
          var params = authParams(tmpPath);
          window.open(d.link_file+"?auth_hash=" + params.auth_hash +
                                   "&auth_timestamp=" + params.auth_timestamp +
                                   "&auth_username=" + params.auth_username +
                                   "&i_am_client=true"  , '_new_tab');
        }
      });


			var updateNode = function() {
				this.attr("transform", function(d) {
					return "translate(" + d.x + "," + d.y + ")";
				});

			}

			force.on("tick", function() {

				force2.start();

				node.call(updateNode);

				anchorNode.each(function(d, i) {
					if(i % 2 == 0) {
						d.x = d.node.x;
						d.y = d.node.y;
					} else {
						var b = this.childNodes[1].getBBox();

						var diffX = d.x - d.node.x;
						var diffY = d.y - d.node.y;

						var dist = Math.sqrt(diffX * diffX + diffY * diffY);

						var shiftX = b.width * (diffX - dist) / (dist * 2);
						shiftX = Math.max(-b.width, Math.min(0, shiftX));
						var shiftY = 5;
						this.childNodes[1].setAttribute("transform", "translate(" + shiftX + "," + shiftY + ")");
					}
				});


				anchorNode.call(updateNode);

				link.call(updateLink);
				anchorLink.call(updateLink);

			});

}

Login = function(){

  var user = $("#Username");
  var pass = $("#Password");

  if ( user[0].value.length != 0 && pass[0].value.length != 0 ){
    username = user[0].value;
		password = pass[0].value;
   
    var path = "/authenticateUser";  	

    var params = {};
    params = authParams(path);
    params["access-control-allow-origin"] = "true";

    $.ajax({
		  url: base_url + path, 
		  data: params,
      success: function(){
        document.getElementById("login").style.display = 'none';
        document.getElementById("logged_in").style.display = 'show';
        document.getElementById("logged_username").innerHTML = "Logged in as: " + username;         
        // Get groups the user is in
        UserGroups();
      },
      error: function(){alert("Error authenticating the user")}
    });
  }
  else{
    alert("Username/password missing");
  }

}

var UserGroups = function(){

  var path = "/user/" + username;
  var params = {};
  params = authParams(path);
  params["qoption[format]"] = "json";

  $.ajax({
	  url: base_url + path, 
	  data: params, 
	  dataType: 'jsonp',
  	jsonp: "qoption[json_callback]",
	  jsonpCallback: 'handleGroups',
    error: function(){alert("This user does not have any devices!")}
  });
}

var handleGroups = function(data){
  document.getElementById("user_own_groups").innerHTML = "Own groups:<br />";
  document.getElementById("user_member_in_groups").innerHTML = "Member in groups:<br />";
  for( var i in data ){
    if( data.hasOwnProperty(i) ){
      // Users own groups
      for( var j in data[i]["own_groups"] ){
        var groupname = data[i]["own_groups"][j]["name"];
        var button = document.createElement("button");
        button.innerHTML = groupname;
        button.setAttribute("type", "button");
        button.setAttribute("onclick", "GetGroup('"+username+"','"+groupname+"' )");
        document.getElementById("user_own_groups").appendChild(button);
        document.getElementById("user_own_groups").innerHTML += "<br />";
      }

      // Member in groups
      for( var j in data[i]["member_in_groups"] ){
        var groupname = data[i]["member_in_groups"][j]["name"];
        var ownername = data[i]["member_in_groups"][j]["owner_name"];
        var button = document.createElement("button");
        button.innerHTML = groupname;
        button.setAttribute("type", "button");
        button.setAttribute("onclick", "GetGroup('"+ownername+"','"+groupname+"' )");
        document.getElementById("user_member_in_groups").appendChild(button);
        document.getElementById("user_member_in _groups").innerHTML += "<br />";
      }      

    }
  }
}

// If enter is pressed, make query
function checkEnterMakeQuery(e){
   if (e.keyCode == 13){
        Login();
    }
}


// Create authentication parameters based on: username, password, path
authParams = function(path){
  var params = {};

  if( username && password ){
    params.i_am_client = "true";
    params.auth_username = username;
    params.auth_timestamp = new Date().getTime();
    params.auth_hash = Crypto.SHA1(params.auth_timestamp+password+path);
  }

  return params
}

var base_url = "http://visualrest.cs.tut.fi";
var current_user;
var current_user_thumb;
var current_dev_thumb;
var username;
var password;

GetUsers();
