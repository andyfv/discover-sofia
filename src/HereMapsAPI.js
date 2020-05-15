var map,
	platform,
	markerGroup,
	routeGroup,
	mapHTML,
	routes,
	sofiaPos = { lat: 42.693, lng: 23.33 };

const bodyTag = document.getElementsByTagName('body')[0];

const LIBS = {
    mapsjsCore: 'https://js.api.here.com/v3/3.1/mapsjs-core.js',
    mapsjsService: 'https://js.api.here.com/v3/3.1/mapsjs-service.js',
    mapjsEvents: 'https://js.api.here.com/v3/3.1/mapsjs-mapevents.js',
    mapjsPlaces: 'https://js.api.here.com/v3/3.1/mapsjs-places.js',
    mapjsUI: 'https://js.api.here.com/v3/3.1/mapsjs-ui.js'
};


/* 
    The HereMaps libraries are loaded in the following sequence:
        1) mapjsCore
        2) mapjsService, mapjsEvents, mapjsUI (dependent on mapjsCore)
        3) mapjsPlaces (dependent on mapjsCore, mapjsService)
    Return error if the loading fails
*/
export function loadMapLibs() {
    return loadLibrary(LIBS.mapsjsCore)
        .then(() => Promise.all([
            loadLibrary(LIBS.mapsjsService),
            loadLibrary(LIBS.mapjsEvents),
        ]))
        .then(() => loadLibrary(LIBS.mapjsUI))
        .catch((error) => 'Failed to map libraries');
}

// Load library by adding it to the headTag
function loadLibrary(url) {
    return new Promise((resolve, reject) => {
        let scriptHTML = document.createElement('script');

        scriptHTML.type = 'text/javascript';
        scriptHTML.charset = 'utf-8';
        scriptHTML.async = true;
        scriptHTML.src = url;

        // Resolve callback if loading is successful
        scriptHTML.onload = function () {
            resolve(url);
        }

        // Reject callback if loading has failed
        scriptHTML.onerror = function () {
            reject('Failed to load library: ' + url);
        }

        // Append the script to the bodyTag
        bodyTag.appendChild(scriptHTML);
    })
}


// Create map HTML div and append it to the map-page element
export function createMapHTML() {
 	let mapElement = document.createElement('div');
 
 	// Add id "map"
	mapElement.setAttribute("id", "map");

	// Append the created mapElement to the map-page element
 	document.getElementById('map-page').appendChild(mapElement);
}


// Initialize the map using the apikey
export function initMap() {
	// Create new platform service using the apikey
	platform = new H.service.Platform({
		'apikey' : 'dP5zwyCeAD7lpfNYrPowSIoJajsYo5P4NQunUM10bw0'
	});

	// Obtain the default map types from the platform object:
	let defaultLayers = platform.createDefaultLayers({ lg: ''});

	// Instantiate (and display) a map object:
	map = new H.Map(
	    document.getElementById('map'),
	    defaultLayers.vector.normal.map,
	    {
	      zoom: 15,
	      center: sofiaPos
    	}
    );

	// Resize listener to make sure that the map occupies the whole container
    window.addEventListener('resize', () => map.getViewPort().resize());

	// Make the map interactive
    let behavior = new H.mapevents.Behavior(new H.mapevents.MapEvents(map));

    //Create group that can hold map objects
    markerGroup = new H.map.Group();

    //Create group that can hold route lines 
    routeGroup = new H.map.Group();

    //Add the group to the map object
    map.addObjects([markerGroup, routeGroup]);
}


export function search(query, onSuccess, onError) {
	//	Get SearchService and create search paramaters
	let service = platform.getSearchService(),
		geocodingParamaters = {
			searchText : query,
			jsonattributes : 1 
		};


	// Get location of Sofia center 
	let lat = sofiaPos.lat.toString(),
		lng = sofiaPos.lng.toString(),
		at = lat.concat(',', lng);


	// Use [/browse] endpoint service to search for locations using the text query
	service.autosuggest({
		q: query,
		at: at,
		limit: 10,
		lang: 'en-US'
	}
	, (results) => {
		let items = results.items.map(i => 
			({ address : i.address
			, position : i.position
			, resultType : i.resultType
			, title : i.title
			}));

			onSuccess(items);
	}
	, (err) => {
		onError(err);
	}
	)
}



export function addMarker(landmark, callback) {
	let coords = {
		lat : landmark.coords.lat,
		lng : landmark.coords.lng
	}

	let innerElement = document.createElement('img'),
		outerElement = document.createElement('div'),
		domIcon,
		marker;


	// If there is no thumbnail just render empty icon
	if (landmark.thumbnail == "") {

		outerElement.classList.add('marker-text');

		//Create paragraph node and add the landmark title to it
	  	let title = document.createElement('p');
  		title.innerHTML = landmark.title;

	  	// Add the paragraph to the div
	  	outerElement.appendChild(title);

	  	//Create new DomIcon by passing the created dom element
	  	domIcon = new H.map.DomIcon(outerElement,{});

	} else {

		innerElement.classList.add('marker-image');
		innerElement.src = landmark.thumbnail;
		innerElement.alt = landmark.title;

	  	//Create new DomIcon by passing the created dom element
	  	domIcon = new H.map.DomIcon(innerElement,{});
	}

	// Create new marker
  	marker = new H.map.DomMarker(coords,{
  		icon: domIcon,
  		data: landmark.id
  	});

	  	marker.addEventListener('tap', (evt) => {
  		callback(evt.target.data)
  	});

  	// map.addObject(marker);
  	markerGroup.addObject(marker);
}



// Geoservices API 
export function getGeolocation(onSuccess, onError) {
    // Check if geoservices are supported
    if (navigator.geolocation) {

	    // If geoservices are supported get the current position
	    navigator.geolocation.getCurrentPosition((position) => {

	        // Filter just the coordinates
	        let pos = {
	            lat: position.coords.latitude,
	            lng: position.coords.longitude
	        };

	        onSuccess(pos);
	        monitorPosition(onSuccess, onError);
	    },

	    // Send message onError(app.ports.geoserviceLocationError.send) if there is problem with getting the current location 
	    (error) => {
	        onError("Couldn't get current position");
	    },

	    { enableHighaccuracy: true, timeout: 5000, maximumAge : 0 }
	    );
	}

    // Browser doesn't support Geolocation
    else {

      // handleLocationError(false, infoWindow, map.getCenter());
      onError("Your device doesn't support geolocation")
    }
}


export function monitorPosition(onSuccess, onError) {

    // Watch for changes
    navigator.geolocation.watchPosition((p) => {

        // Filter just the coordinates
        let pos = {
            lat: p.coords.latitude,
            lng: p.coords.longitude
        };

        // Call the onSuccess(app.ports.geoserviceLocationReceive.send) callback with the current postion
        onSuccess(pos);
    }
    , (error) => { 
    	onError("Couldn't get current position") 
    }
    , { enableHighaccuracy : true, timeout: Infinity, maximumAge: 0 }
    )
}


export function routing(parameters, onResponse) {
	// Instantiate routing service
	let router = platform.getRoutingService(null, 8);

	// Get the origin point
	let originLat = parameters.origin.lat.toString(),
		originLng = parameters.origin.lng.toString(),
		originPos = originLat.concat(',', originLng);

	// Get the destination point 
	let destinationLat = parameters.destination.lat.toString(),
		destinationLng = parameters.destination.lng.toString(),
		destinationPos = destinationLat.concat(',', destinationLng);

	// Create routing parameters
	let routingParameter = {
		'transportMode' : parameters.transportMode,
		'routingMode' : 'fast',
		'origin' : originPos,
		'destination' : destinationPos,
		'alternatives' : 5,
		'units' : 'metric',
		'lang' : 'en-US',
		'return' : ['polyline','summary','actions', 'instructions']
	}


	let onResult = function(result) {
		console.log(result);
		let arrival,
			departure,
			routeSummaryList = [];

		result.routes.forEach((route) => {
			// Create actions array
			let actions = [],
				duration,
				distance;

			// Take deparute and arrival points
			departure = route.sections[0].departure.place.location,
			arrival = route.sections[0].arrival.place.location;

			// 
			duration = getTime(route.sections[0].summary.duration);
			distance = getDistance(route.sections[0].summary.length)

			// Take action instructions for every route
			route.sections[0].actions.forEach((action) => {
				actions.push(action.instruction);
			})

			// Create routeObject 
			let routeObject = {
				id : route.sections[0].id,
				polyline : route.sections[0].polyline,
				actions : actions,
				summary : route.sections[0].summary,
				mode : route.sections[0].transport.mode,
				duration : duration,
				distance: distance
			};

			// Add routeObject to the list of Routes
			routeSummaryList.push(routeObject);
		})

		console.log(getDistance(routeSummaryList[0].summary.length));
		console.log(getTime(routeSummaryList[0].summary.duration));
		console.log(routeSummaryList);
		onResponse(routeSummaryList);

		// Get the first route polyline 
		let routePolyline = routeSummaryList[0].polyline;

		// Show polyline on the map
		addRouteShapeToMap(routePolyline, departure, arrival);
	}


	// Call the routing service with the parameters
	router.calculateRoute( routingParameter, onResult,
		function (error) {
			console.log(error);
		});
}

function addRouteShapeToMap(route, startPoint, endPoint) {
	// First clean the previous routes
	cleanRouteGroup();

	// Instantiate linestring
	let lineString = new H.geo.LineString.fromFlexiblePolyline(route);


	// Create a marker for the starting point 
	let	startMarker = new H.map.Marker(startPoint);

	// Create a marker for the end point
	let	endMarker = new H.map.Marker(endPoint);


	// Create polyline
	let polyline = new H.map.Polyline(lineString, {
		style: 
			{ strokeColor : 'rgba(156, 39, 176, 1)'
			, lineWidth : 13
			, lineTailCap : 'arrow-tail'
			, lineHeadCap : 'arrow-head'
			, lineJoin : 'round'
			}
	});


	// Create patterned polyline
	let routeArrows = new H.map.Polyline(lineString, {
		style : 
			{ lineWidth : 10
			, strokeColor : 'rgba(255, 255, 255, 1)'
			, lineDash : [1, 2]
			, lineTailCap : 'arrow-tail'
			, lineHeadCap : 'arrow-head'
			, metricSystem : 'metric'
			, language : 'en-US'
			}
	});
	

	// Add the polyline and markers to the map;
	routeGroup.addObjects([polyline, routeArrows, startMarker, endMarker])


	// Set the map
	map.getViewModel().setLookAtData({bounds: polyline.getBoundingBox()});
}


export function cleanRouteGroup() {
	routeGroup.removeAll();
}


function getTime(seconds) {
	let hours,
		min;


	if (seconds < 3600) {
		return Math.floor(seconds / 60) + ' min';
	}

	else 
		hours = Math.floor(seconds / (3600));
		min = Math.floor(hours % 60);

		return hours + ' h  ' + min + ' min' ;

}

function getDistance(meters) {
	if (meters < 1000) {
		return meters + ' m';
	} else 
		return (meters / 1000).toFixed(1) + ' km';

}