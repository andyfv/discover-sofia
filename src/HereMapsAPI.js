var map,
	platform,
	markerGroup,
	routeGroup,
	mapHTML,
	routes;
	

const sofiaPos = { lat: 42.693, lng: 23.33 };
const bodyTag = document.getElementsByTagName('body')[0];

const LIBS = {
    mapsjsCore: 'https://js.api.here.com/v3/3.1/mapsjs-core.js',
    mapsjsService: 'https://js.api.here.com/v3/3.1/mapsjs-service.js',
    mapjsEvents: 'https://js.api.here.com/v3/3.1/mapsjs-mapevents.js',
    mapjsPlaces: 'https://js.api.here.com/v3/3.1/mapsjs-places.js',
    mapjsUI: 'https://js.api.here.com/v3/3.1/mapsjs-ui.js'
};


/** 
    The HereMaps libraries are loaded in the following sequence:
        1) mapjsCore
        2) mapjsService, mapjsEvents, mapjsUI (dependent on mapjsCore)
        3) mapjsPlaces (dependent on mapjsCore, mapjsService)

    @return {Promise} Promise if the loading succeeds or fails
*/
export function loadMapLibs() {
    return loadLibrary(LIBS.mapsjsCore)
        .then(() => Promise.all([
            loadLibrary(LIBS.mapsjsService),
            loadLibrary(LIBS.mapjsEvents),
        ]))
        .then(() => loadLibrary(LIBS.mapjsUI))
        .catch((error) => 'Failed to load map libraries');
}



/**
 * Loads library by adding it to the headTag
 * 
 * @param  {string} url - String representing the url of the library to load
 * @return {Promise} - Promise representing the failure or success of loading
 */
function loadLibrary(url) {
    return new Promise((resolve, reject) => {
        let scriptHTML = document.createElement('script');

        scriptHTML.type = 'text/javascript';
        scriptHTML.charset = 'utf-8';
        scriptHTML.async = true;
        scriptHTML.src = url;

        // Resolves callback if loading is successful
        scriptHTML.onload = function () {
            resolve(url);
        }

        // Rejects callback if loading has failed
        scriptHTML.onerror = function () {
            reject('Failed to load library: ' + url);
        }

        // Appends the script to the bodyTag
        bodyTag.appendChild(scriptHTML);
    })
}



/**
 * Creates HTMLElement containing the map and append it to the 'map-page' element
 * 
 * @return {void}
 */
export function createMapHTML() {
 	let mapElement = document.createElement('div');
 
 	// Adds id "map"
	mapElement.setAttribute("id", "map");

	// Appends the created mapElement to the map-page element
 	document.getElementById('map-page').appendChild(mapElement);
}


/**
 * Initializes the map using the HereMap Service API key
 *
 * @param {requestCallback} onMapLoad - Callback function used to notify Elm runtime
 * when the map is loaded
 * 
 * @return {void}
 */
export function initMap(onMapLoad) {

	// Creates new platform service using the apikey
	platform = new H.service.Platform({
		'apikey' : 'dP5zwyCeAD7lpfNYrPowSIoJajsYo5P4NQunUM10bw0'
	});

	// Obtains the default map types from the platform object:
	let defaultLayers = platform.createDefaultLayers();

	// Instantiates (and display) a map object:
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

	// Makes the map interactive
    let behavior = new H.mapevents.Behavior(new H.mapevents.MapEvents(map));

    // Creates group that can hold map objects
    markerGroup = new H.map.Group();

    // Creates group that can hold route lines 
    routeGroup = new H.map.Group();

    // Adds the group to the map object
    map.addObjects([markerGroup, routeGroup]);

    // Notifies Elm runtime that the map is loaded
    onMapLoad("loaded");
}


/**
 * Search address
 * 
 * @param  {string} query - String representing the address to be searched
 * @param  {requestCallback} callback - Callback function used to return
 * the found addresses
 *  
 * @return {void}
 */
export function search(query, callback) {

	// Takes SearchService and creates search paramaters
	let service = platform.getSearchService(),
		geocodingParamaters = {
			searchText : query,
			jsonattributes : 1 
		};


	// Takes location of Sofia center 
	let lat = sofiaPos.lat.toString(),
		lng = sofiaPos.lng.toString(),
		at = lat.concat(',', lng);


    /**
     * Searched the for locations using the /discover endopoint and the
     * @param query
     */
	service.discover({
		q: query,
		at: at,
		limit: 10,
		lang: 'en-US'
	}

    // Returns addresses and their relevant information
	, (results) => {
		let items = results.items.map(i => 
			({ address : i.address
			, position : i.position
			, resultType : i.resultType
			, title : i.title
			}));

            // Returns results if there are any
			callback( items );
	}

    // Returns any error
	, (err) => callback( { error : err } )
	);
}


/**
 *  Adds marker to the map
 * 
 * @param {obejct} landmark - Object containing all the information needed to 
 * create the marker and add it to the map
 * 
 * @param {requestCallback} callback - Callback function which is invoked if 
 * the user clicks on the marker
 */
export function addMarker(landmark, callback) {
	let coords = {
		lat : landmark.coords.lat,
		lng : landmark.coords.lng
	}

	let innerElement = document.createElement('img'),
		outerElement = document.createElement('div'),
		domIcon,
		marker;


    /**
     * Renders empty icon with the landmark name if there is 
     * no thumbnail available.
     *
     * Otherwise adds the thumbnail
     */
	if (landmark.thumbnail == "") {

		outerElement.classList.add('marker-text');

		//Creates paragraph node and add the landmark title to it
	  	let title = document.createElement('p');
  		title.innerHTML = landmark.title;

	  	// Adds the paragraph to the div
	  	outerElement.appendChild(title);

	  	//Creates new DomIcon by passing the created dom element
	  	domIcon = new H.map.DomIcon(outerElement,{});

	} else {

		innerElement.classList.add('marker-image');
		innerElement.src = landmark.thumbnail;
		innerElement.alt = landmark.title;

	  	//Creates new DomIcon by passing the created dom element
	  	domIcon = new H.map.DomIcon(innerElement,{});
	}

	// Creates new marker
  	marker = new H.map.DomMarker(coords,{
  		icon: domIcon,
  		data: landmark.id
  	});

    // Listens for the @event {tap} and invokes the callback
  	marker.addEventListener('tap', (evt) => {
  		callback(evt.target.data)
  	});

    // Adds the marker to the marker group
  	markerGroup.addObject(marker);
}



/**
 * Geoservices API
 * 
 * @param  {requestCallback} callback - Callback function used to notify if 
 * the device supports Geoservices or not
 *
 * @return {void}
 */
export function getGeolocation(callback) {

    // Checks if geoservices are supported
    if (navigator.geolocation) {

        // Takes the current position if geoservices are supported
	    navigator.geolocation.getCurrentPosition((position) => {

	        // Filters just the coordinates
	        let pos = {
	            lat: position.coords.latitude,
	            lng: position.coords.longitude
	        };

            // Returns the position
	        callback(pos);

            // Monitors the position for changes
	        monitorPosition(callback);
	    }

	
        // Invokes the callback with error if there is problem getting the 
        // current location
	    , (error) => callback("Couldn't get current position")

        // Apply options 
	    , { enableHighaccuracy: true, timeout: Infinity, maximumAge : 0 }
	    );
	}

    // Browser doesn't support Geolocation
    else {
      onError("Your device doesn't support geolocation")
    }
}


/**
 *  Monitors the device geolocation for changes
 * 
 * @param  {requestCallback} callback - Callback function used to notify if 
 * the device supports Geoservices or not
 * 
 * @return {void}
 */
export function monitorPosition(callback) {

    /**
     *  Watch geolocation position of the device
     * 
     * @param  {GeolocationPosition} position - Represents the position of the 
     * device at a given time
     * 
     * @return {void}
     */
    navigator.geolocation.watchPosition((pos) => {

        // Filters just the coordinates
        let position = {
            lat: pos.coords.latitude,
            lng: pos.coords.longitude
        };

        // Calls the callback with the current postion
        callback(position);
    }

    // Calls the callback with error 
    , (error) => callback("Couldn't get current position")

    // @param {PositionOptions} - object providing options for the location watch
    , { enableHighaccuracy: true, timeout: Infinity, maximumAge: 0 }
    )
}


/**
 * HereMaps Routing API 
 * 
 * @param  {object} parameters - Routing parameters
 *   Example: 
 *      { origin: { lat: {float} , lng: {float} }
 *      , destination: { lat: {float}, lat: {float} }
 *      , transportMode: {string} // car or pedestrian 
 *      } 
 *      
 * @param  {requestCallback} callback - Callback function
 * 
 * @return {void}
 */
export function routing(parameters, callback) {

	// Instantiates routing service and asks for version 8
	let router = platform.getRoutingService(null, 8);

	// Takes the origin point
	let originLat = parameters.origin.lat.toString(),
		originLng = parameters.origin.lng.toString(),
		originPos = originLat.concat(',', originLng);

	// Takes the destination point 
	let destinationLat = parameters.destination.lat.toString(),
		destinationLng = parameters.destination.lng.toString(),
		destinationPos = destinationLat.concat(',', destinationLng);

	// Routing parameters
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

    // Creates function which will be invkoed if there is a result 
	let onResult = function(result) {
		let arrival,
			departure,
			routeSummaryList = [];

        // Takes each route and filters only the relevent information
		result.routes.forEach((route) => {

			// Creates actions array
			let actions = [],
				duration,
				distance;

			// Takes deparute and arrival points
			departure = route.sections[0].departure.place.location,
			arrival = route.sections[0].arrival.place.location;

			// Formats the duration and distance in a human-readable form
			duration = getTime(route.sections[0].summary.duration);
			distance = getDistance(route.sections[0].summary.length)

			// Takes list of action instructions for every route
			route.sections[0].actions.forEach((action) => {
				actions.push(action.instruction);
			})

			// Creates routing object 
			let routeObject = {
				id : route.sections[0].id,
				polyline : route.sections[0].polyline,
				actions : actions,
				summary : route.sections[0].summary,
				mode : route.sections[0].transport.mode,
				duration : duration,
				distance: distance,
				departure : departure,
				arrival : arrival
			};

			// Adds the routing object to the list of Routes
			routeSummaryList.push(routeObject);
		})

        // Invokes the callback with the results
		callback(routeSummaryList);
	}


	// Calls the routing service with the parameters
	router.calculateRoute( 
        routingParameter,
        onResult,
		(error) => callback({ error : error })
    );
}


/**
 *  Shows the selected route on the map
 *  
 * @param {object} route - Object holding information needed to add a route the map
 *  route = 
 *      { polyline: {string}
 *      , departure : { lat: {float}, lng: {float} }
 *      , arrival: { lat: {float}, lng: {float} }
 *      }
 * 
 */
export function addRouteShapeToMap(route) {

	// Cleans the previous routes and hides the markers
	cleanRouteGroup();
	hideMarkerGroup();

    // Creates a {LineString} from a polyline
	let lineString = new H.geo.LineString.fromFlexiblePolyline(route.polyline);


	// Creates a marker for the starting point 
	let	startMarker = new H.map.Marker(route.departure);

	// Create a marker for the end point
	let	endMarker = new H.map.Marker(route.arrival);


	// Creates polyline
	let polyline = new H.map.Polyline(lineString, {
		style: 
			{ strokeColor : 'rgba(156, 39, 176, 1)'
			, lineWidth : 13
			, lineTailCap : 'arrow-tail'
			, lineHeadCap : 'arrow-head'
			, lineJoin : 'round'
			}
	});


	// Creates patterned polyline
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
	

	// Adds the polyline and markers to the map;
	routeGroup.addObjects([polyline, routeArrows, startMarker, endMarker])


	// Sets the map
	map.getViewModel().setLookAtData({bounds: polyline.getBoundingBox()});
}


// Cleans the routeGroup
export function cleanRouteGroup() {
	routeGroup.removeAll();
}


// Hides the marker group
export function hideMarkerGroup() {
	markerGroup.setVisibility(false);
}


// Brings back the markers
export function showMarkerGroup() {
    markerGroup.setVisibility(true);
}


/**
 *  Formats the time from seconds to human-readable form
 * 
 * @param  {int} seconds - the travel time in seconds
 * 
 * @return {string} - formatted time
 */
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



/**
 *  Formats the distance to human-readable form
 * 
 * @param  {int} meters - the travel distance in meters
 * 
 * @returns {string} - formatted distance in km and meters
 */
function getDistance(meters) {
	if (meters < 1000) {
		return meters + ' m';
	} else 
		
    return (meters / 1000).toFixed(1) + ' km';
}