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

    //Create a group that can hold map objects
    markerGroup = new H.map.Group();

    //Add the group to the map object
    map.addObject(markerGroup);
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
	  	var title = document.createElement('p');
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

  	updateMapHTML();
}
