var map;

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


export function initMap() {
	var platform = new H.service.Platform({
		'apikey' : 'dP5zwyCeAD7lpfNYrPowSIoJajsYo5P4NQunUM10bw0'
	});

	// Obtain the default map types from the platform object:
	var defaultLayers = platform.createDefaultLayers();

	// Instantiate (and display) a map object:
	map = new H.Map(
	    document.getElementById('map-container'),
	    defaultLayers.vector.normal.map,
	    {
	      zoom: 14,
	      center: { lat: 42.7, lng: 23.33 }
    	}
    );

	// Resize listener to make sure that the map occupies the whole container
    window.addEventListener('resize', () => map.getViewPort().resize());

	// Make the map interactive
    var behavior = new H.mapevents.Behavior(new H.mapevents.MapEvents(map));

    return {map, behavior};
}
