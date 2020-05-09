var map, markerGroup, mapHTML;

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
*/
export function loadMapLibs() {
    return loadLibrary(LIBS.mapsjsCore)
        .then(() => Promise.all([
            loadLibrary(LIBS.mapsjsService),
            loadLibrary(LIBS.mapjsEvents)
        ]))
        .catch(error => new Error('Failed to load map: ' + error))
}

// Load library by adding it to the headTag
function loadLibrary(url) {
    return new Promise((resolve, reject) => {
        let scriptHTML = document.createElement('script');

        scriptHTML.type = 'text/javascript';
        scriptHTML.charset = 'utf-8';
        scriptHTML.async = true;
        scriptHTML.src = url;

        scriptHTML.onload = function () {
            resolve(url);
        }

        scriptHTML.onerror = function () {
            reject('Failed to load library: ' + url);
        }

        bodyTag.appendChild(scriptHTML);
    })
}


export function createMapHTML() {
 	let mapElement = document.createElement('div');
 	mapElement.setAttribute("id", "map");
 	document.getElementById('map-container').appendChild(mapElement);
}

export function initMap() {
	var platform = new H.service.Platform({
		'apikey' : 'dP5zwyCeAD7lpfNYrPowSIoJajsYo5P4NQunUM10bw0'
	});

	// Obtain the default map types from the platform object:
	var defaultLayers = platform.createDefaultLayers({lg: "eng", lg2 : "eng"});


	// Instantiate (and display) a map object:
	map = new H.Map(
	    document.getElementById('map'),
	    defaultLayers.vector.normal.map,
	    {
	      zoom: 15,
	      center: { lat: 42.7, lng: 23.33 }
    	}
    );

    // map.setBaseLayer(defaultLayers.normal.mapnight);

	// Resize listener to make sure that the map occupies the whole container
    window.addEventListener('resize', () => map.getViewPort().resize());

	// Make the map interactive
    var behavior = new H.mapevents.Behavior(new H.mapevents.MapEvents(map));

    //Create a group that can hold map objects
    markerGroup = new H.map.Group();

    //Add the group to the map object
    map.addObject(markerGroup);

    // return {map, behavior};
    updateMapHTML();
}




export function addMarker(landmark, callback) {
	let coords = {
		lat : landmark.coords.lat,
		lng : landmark.coords.lon
	}

	var innerElement = document.createElement('img'),
		outerElement = document.createElement('div');

	// If there is no thumbnail just render empty icon
	if (landmark.thumbnail == "") {

		outerElement.classList.add('marker-text');

		//Create paragraph node and add the landmark title to it
	  	var title = document.createElement('p');
  		title.innerHTML = landmark.title;

	  	// Add the paragraph to the div
	  	outerElement.appendChild(title);

	  	//Create new DomIcon by passing the created dom element
	  	var domIcon = new H.map.DomIcon(outerElement,{});

	  	// Create new marker
	  	var marker = new H.map.DomMarker(coords,{
	  		icon: domIcon, 
	  		data: landmark.id
	  	});

  	  	marker.addEventListener('tap', (evt) => {
  			allback(evt.target.data)
	  	});

	  	// map.addObject(marker);
	  	markerGroup.addObject(marker);

	} else {

		innerElement.classList.add('marker-image');
		innerElement.src = landmark.thumbnail;

	  	//Create new DomIcon by passing the created dom element
	  	var domIcon = new H.map.DomIcon(innerElement,{});

	  	// Create new marker
	  	var marker = new H.map.DomMarker(coords,{
	  		icon: domIcon,
	  		data: landmark.id
	  	});

  	  	marker.addEventListener('tap', (evt) => {
	  		callback(evt.target.data)
	  	});

	  	// map.addObject(marker);
	  	markerGroup.addObject(marker);

  	updateMapHTML();
}
