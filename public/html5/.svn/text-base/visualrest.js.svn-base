if (typeof(VisualWebGL) == 'undefined' ){
	VisualWebGL = {};
}

var VisualWebGL = (function(VisualWebGL){

	var scene, camera, projector, plane, Model;
	var stats, renderer;
		
	//	init();
	//	animate();
	
	var _initialized = false;
	var _height;
	var _width;
	VisualWebGL.init = function(width, height){
		_width = width;
		_height = height;
		
		if ( Detector.webgl ){
			renderer = new THREE.WebGLRenderer({
				antialias: true
			});
			renderer.setClearColorHex( 0xf9f9f9, 1 );
		}
		else{
			renderer = new THREE.CanvasRenderer();
		}
			
		renderer.setSize(_width, _height);
		renderer.domElement.style.width = "100%";
		renderer.domElement.style.height = "100%";
		renderer.domElement.id = "VisualWebGLCanvas";
		
		document.getElementById('VisualWebGLContent').appendChild(renderer.domElement);
			
		scene = new THREE.Scene();
			
		camera = new THREE.PerspectiveCamera(75, _width / _height, 1, 10000);
		camera.position.z = 1600;
		scene.add( camera );
			
			
		projector = new THREE.Projector();
		/*	
		stats = new Stats();
		stats.getDomElement().style.position = 'absolute';
		stats.getDomElement().style.left = '0px';
		stats.getDomElement().style.top = '0px';

		document.body.appendChild( stats.getDomElement() );
		*/
		var light;
		scene.add( new THREE.AmbientLight( 0x404040 ) );

		light = new THREE.DirectionalLight( 0xffffff );
		light.position.set( 0, 0, 1 );
		scene.add( light );
		
		Model = new THREE.Object3D();
		scene.add(Model);
			
		plane = new THREE.Mesh( new THREE.PlaneGeometry( 2000, 2000, 10, 10 ), new THREE.MeshBasicMaterial( { color: 0x555555, wireframe: true } ) );
		plane.rotation.z = - 90 * Math.PI / 180;
		plane.position.x = 0;
		plane.position.y = 0;
		Model.add( plane );
			
		
		CreateUI();
		GetUsers();
		
		//$("#VisualWebGLContent").click(clickHandler);
		$("#VisualWebGLContent").mousedown(mousedownHandler).bind('touchstart', mousedownHandler);
		$("#VisualWebGLContent").mousemove(mousemoveHandler).bind('touchmove', mousemoveHandler);
		$("#VisualWebGLContent").mouseup(mouseupHandler).bind('touchend', mouseupHandler);
	
		
		_initialized = true;
	}
	
	VisualWebGL.initialized = function(){
		return _initialized;
	}
	
	var _id;
	var _animating;
	VisualWebGL.animate = function(){
		_id =requestAnimationFrame( VisualWebGL.animate );
		render();
		//stats.update();
		_animating = true;
	}
	
	VisualWebGL.stopAnimate = function(){
		cancelAnimationFrame(_id);
		_animating = false;
	}
	
	VisualWebGL.animating = function(){
		return _animating;
	}
		
	var render = function(){
		Model.rotation.y += ( ModelRotationY - Model.rotation.y ) * 0.05;
		Model.rotation.x += ( ModelRotationX - Model.rotation.x ) * 0.05;
			
		for ( var i in objects ){
			if ( objects.hasOwnProperty(i) ){
				if ( objects[i].material.map.visualrestdata && objects[i].material.map.visualrestdatatype == "video" ){
					if ( objects[i].material.map.visualrestdata.readyState === objects[i].material.map.visualrestdata.HAVE_ENOUGH_DATA ) {
						if ( objects[i].material.map ) objects[i].material.map.needsUpdate = true;

					}
				}
			}
		}
		
		renderer.render(scene, camera);
	}
		
			
	var GetUsers = function(){
		$.ajax({
			url:"http://visualrest.cs.tut.fi/users", 
			data: {'user': "", 'qoption[format]': 'json'}, 
			dataType: 'jsonp',
			jsonp: "qoption[json_callback]",
			jsonpCallback: 'VisualWebGL.DisplayUsers'
		});
		
		UIObjects[1].VisualRestFunc = UIObjects[1].PrevVisualRestFunc;
		UIObjects[1].PrevVisualRestFunc = function(){
			GetUsers();
		}
	}
	
	var DoQuery = function(query){
		var data = {'qoption[format]': 'json'};
		for ( var attr in query){
			data[attr] = query[attr];
		}
	
		$.ajax({
			url:"http://visualrest.cs.tut.fi/files", 
			data:  data, 
			dataType: 'jsonp',
			jsonp: "qoption[json_callback]",
			jsonpCallback: 'VisualWebGL.DisplayResults'
		});
		
		UIObjects[1].VisualRestFunc = UIObjects[1].PrevVisualRestFunc;
		UIObjects[1].PrevVisualRestFunc = function(){
			DoQuery(query);
		}
	}

	var objects = [];

	var findPos = function(obj) {
		var curleft = curtop = 0;
		if (obj.offsetParent) {
			do {
				curleft += obj.offsetLeft;
				curtop += obj.offsetTop;
			} while (obj = obj.offsetParent);
			return { x: curleft, y: curtop };
		}
	}

	var clickHandler = function(event, that){
		
				
		var mouse = new THREE.Vector2();
		var pos = findPos(that);
		mouse.x = ( (event.pageX-pos.x) / $("#VisualWebGLCanvas").width() ) * 2 - 1;
		mouse.y = - ( (event.pageY-pos.y) / $("#VisualWebGLCanvas").height() ) * 2 + 1;
	
	
		var vector = new THREE.Vector3(mouse.x, mouse.y, 0.5);
		projector.unprojectVector(vector, camera);
	
		var ray = new THREE.Ray( camera.position, vector.subSelf( camera.position ).normalize() );
	
		var planeCollision = ray.intersectObject(plane);
		
		var intersectsUI = ray.intersectObjects(UIObjects);
		if ( intersectsUI.length > 0 ){
			for ( var i in objects ){
				if ( objects.hasOwnProperty(i) ){
					Model.remove(objects[i]);
				}
			}
		
			objects = [];
		
			intersectsUI[0].object.VisualRestFunc();
		}
	
		var intersects = ray.intersectObjects(objects);
		
		
		if ( intersects.length == 1 ){
			for ( var i in objects ){
				if ( objects.hasOwnProperty(i) ){
					Model.remove(objects[i]);
				}
			}
		
			objects = [];

			if ( intersects[0].object.user ){
				console.log(intersects[0].object.user);
				DoQuery({'q[user]': intersects[0].object.user });
			}
		
			else if ( intersects[0].object.visualrestdata ){
				LoadImage(intersects[0].object.visualrestdata);
			}
				
		}
	}

	var MouseClickStart;
	var MouseClickEvent;
	
	var RotateObjects = false;
	var MouseClickLocation;
	var ModelRotationY = 0;
	var ModelRotationOnMousedownY;
	var ModelRotationX = 0;
	var ModelRotationOnMousedownX;
	var mousedownHandler = function(event){
		
		event.preventDefault();
				
		var e = event.originalEvent;
		if ( e.touches ){
			e = e.touches[0];
		}
		
		RotateObjects = true;
		var pos = findPos(this);
		
		MouseClickLocation = new THREE.Vector2((e.pageX - pos.x) - ($("#VisualWebGLCanvas").width() / 2), (e.pageY-pos.y) - ($("#VisualWebGLCanvas").height() / 2)); 
		ModelRotationOnMousedownY = ModelRotationY;
		ModelRotationOnMousedownX = ModelRotationX;
		MouseClickStart = new Date();
		MouseClickEvent = e;
		return false;
	}

	var mouseupHandler = function(event){
		event.preventDefault();
		var e = event.originalEvent;
		if ( e.touches ){
			e = e.touches[0];
		}
		
		RotateObjects = false;
		console.log(new Date() - MouseClickStart);
		if ( (new Date() - MouseClickStart) < 200 ){
			
			clickHandler(MouseClickEvent, this);
		}		
	}

	var mousemoveHandler = function(event){
		event.preventDefault();
		var e = event.originalEvent;
		if ( e.touches ){
			e = e.touches[0];
		}
		if (RotateObjects){
			var pos = findPos(this);
			var mouse = new THREE.Vector2((e.pageX - pos.x) - ($("#VisualWebGLCanvas").width() / 2), (e.pageY-pos.y) - ($("#VisualWebGLCanvas").height() / 2));
			ModelRotationY = ModelRotationOnMousedownY + ( mouse.x - MouseClickLocation.x ) * 0.02;
			ModelRotationX = ModelRotationOnMousedownX + ( mouse.y - MouseClickLocation.y ) * 0.02;
		}
	}

	VisualWebGL.DisplayUsers = function(data){
		console.log(data);
	
		var x = -900;
		var y = 900;
	
		for ( var i in data ){
			if ( data.hasOwnProperty(i) ){
			
				var url = data[i].thumbnail_uri;
				var texture = THREE.ImageUtils.loadTexture(url+ '?access-control-allow-origin=true');
				
				var geometry = new THREE.CubeGeometry(150,150,30);
				var mesh = new THREE.Mesh( geometry, new THREE.MeshLambertMaterial( { ambient: 0xbbbbbb, map: texture } ));
				
				mesh.position.x = x;
				mesh.position.y = y;
				mesh.user = data[i].username;
				objects.push(mesh);
				x += 200;
				if ( x >= 1100 ){
					x = -900;
					y -= 200;
					if ( y <= -900 ){
						y = 900;
					}
				}
				Model.add(mesh);
				
			}
			
		}
	}
	

	VisualWebGL.DisplayResults = function(data){
		console.log(data);
	
		var x = -900;
		var y = 900;
	
		for ( var i in data ){
			if ( data.hasOwnProperty(i) ){
				for ( var j in data[i] ){
					if ( data[i].hasOwnProperty(j) ){
				
					if ( data[i][j].filetype == "image/jpeg" || data[i][j].filetype == "video/vnd.objectvideo" || data[i][j].filetype == "image/gif" || data[i][j].filetype == "video/ogg"){
						var url = data[i][j].thumbnail;
						url = url.replace("thumbnails", "allowthumbnails");
						var texture = THREE.ImageUtils.loadTexture(url);
					
						var geometry = new THREE.CubeGeometry(150,150,30);
						var mesh = new THREE.Mesh( geometry, new THREE.MeshLambertMaterial( { ambient: 0xbbbbbb, map: texture } ));
					
						mesh.position.x = x;
						mesh.position.y = y;
						mesh.user = data[i].username;
						mesh.visualrestdata = data[i][j];
						objects.push(mesh);
						x += 200;
						if ( x >= 1100 ){
							x = -900;
							y -= 200;
							if ( y <= -900 ){
								y = 900;
							}
						}
						
						Model.add(mesh);
					}
				}
			}
			
			}
		}
	}


	var UIObjects = [];
	var CreateUI = function(){
	
		var geometry = new THREE.CubeGeometry(150,150,30);
		var homeTexture = THREE.ImageUtils.loadTexture("img/home.png");
		var home = new THREE.Mesh(geometry, new THREE.MeshLambertMaterial( { ambient: 0xbbbbbb, map: homeTexture } ));
	
		home.position.x = -1250;
		home.position.y = 500;
		home.VisualRestFunc = function(){
			GetUsers();
		}
	
		scene.add(home);
		UIObjects.push(home);
	
		var backTexture = THREE.ImageUtils.loadTexture("img/back.png");
		var back = new THREE.Mesh(geometry, new THREE.MeshLambertMaterial( { ambient: 0xbbbbbb, map: backTexture } ));
	
		back.position.x = -1250;
		back.position.y = 300;
		back.VisualRestFunc = function(){
	
		}
		back.PrevVisualRestFunc = function(){
			GetUsers();
		}
	
		scene.add(back);
		UIObjects.push(back);
	
	}

	var LoadImage = function(visualrestdata){

		if ( visualrestdata.filetype.match(/image.*/) ){
			var texture = THREE.ImageUtils.loadTexture(visualrestdata.essence_uri + '?access-control-allow-origin=true');
		}
		else if ( visualrestdata.filetype == "video/vnd.objectvideo" ){
			var video = document.createElement('video');
			video.autoplay = true;
			video.loop = true;
			var source = document.createElement('source');
			source.crossorigin = 'anonymous';
		
			source.src = visualrestdata.essence_uri + '?access-control-allow-origin=true';
			//source.src = "../sintel.mp4";
			source.type = 'video/mp4; codecs="avc1.42E01E, mp4a.40.2"';
			video.appendChild(source);
			
			var texture = new THREE.Texture(video);
			texture.minFilter = THREE.LinearFilter;
			texture.magFilter = THREE.LinearFilter;
			texture.format = THREE.RGBFormat;
			texture.visualrestdata = video;
			texture.visualrestdatatype = "video";
			
			
			//document.body.appendChild(video);
		}
		else if ( visualrestdata.filetype == "video/ogg" ){
			var video = document.createElement('video');
			video.autoplay = true;
			video.loop = true;
			var source = document.createElement('source');
			video.crossorigin = 'anonymous';
		
			source.src = visualrestdata.essence_uri + '?access-control-allow-origin=true';
			//source.src = "../sintel.mp4";
			source.type = 'video/ogg';
			video.appendChild(source);
			
			var texture = new THREE.Texture(video);
			texture.minFilter = THREE.LinearFilter;
			texture.magFilter = THREE.LinearFilter;
			texture.format = THREE.RGBFormat;
			texture.visualrestdata = video;
			texture.visualrestdatatype = "video";
			
			
			//document.body.appendChild(video);
		}
		var geometry = new THREE.CubeGeometry(2000,2000,30);
		var mesh = new THREE.Mesh( geometry, new THREE.MeshLambertMaterial({map: texture}));
		
		Model.add(mesh);
		objects.push(mesh);
			
		UIObjects[1].VisualRestFunc = UIObjects[1].PrevVisualRestFunc;
		UIObjects[1].PrevVisualRestFunc = function(){
			LoadImage(visualrestdata);
		}
	}
	
	return VisualWebGL;
})(VisualWebGL);