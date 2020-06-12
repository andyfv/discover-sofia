const LIBS = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@2.0.0/dist/tf.min.js";
const bodyTag = document.getElementsByTagName('body')[0];
const stringDecoder = new TextDecoder;

var model,
    worker,
    onLoadFunction,
    onResultFunction;

const classes = {
    0: 'Alexander Nevski',
    1: 'Holy Synod',
    2: 'Ivan Vazov Theater',
    3: 'Monument to the Soviet Army',
    4: 'National Gallery for Foreign Art',
    5: 'National Opera and Ballet',
    6: 'National Palace of Culture',
    7: 'Regional History Museum',
    8: 'Russian Church',
    9: 'Church of Saint George',
    10: 'Cathedral of St Joseph',
    11: 'Saint Sofia Church',
    12: 'Seven Saints Church',
    13: 'Slaveykov Square',
    14: 'Sofia Synagogue',
    15: 'Sofia University',
    16: 'St Nedelya Church',
    17: 'Church of St Paraskeva',
    18: 'Monument to the Tsar Liberator ',
    19: 'Vasil Levski Monument'
}

// Load the TensorFlow library or return error
export function loadLibs() {
    return loadLibrary(LIBS)
    .catch((error) => 'Failed to load classification model');
}



// Load library by adding it to the headTag
function loadLibrary(url) {
    return new Promise((resolve, reject) => {
        let scriptHTML = document.createElement('script');

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



export function createVideoElement() {
    return new Promise((resolve, reject) => {
        const video = document.getElementById('camera');

        const constraints =
            {
                audio : false,
                video : {
                    width : { ideal : 720 },
                    height : { ideal : 720 },
                    aspectRation : { ideal : 1/1 },
                    frameRate : { min : 24, max : 60 },
                    facingMode : { exact : "environment" }
                }
            }

        /*
            Use the @onpause Event to stop the mediaStream from the camera 
            to prevent memory leaks and security issues
        */
        video.onpause = (e) => {
            const stream = video.srcObject;
            const tracks = stream.getTracks();

            tracks.forEach(function(track) {
                track.stop();
            });

            video.srcObject = null;
        };

        video.onloadmetadata = (e) => {
            video.play();
        };

        navigator.mediaDevices.getUserMedia(constraints)
        .then((mediaStream) => {
            video.srcObject = mediaStream;

            resolve(video);
        })
        .catch((err) => reject(new Error("Camera not found")));
    });

}


export async function predictVideo (videoEl) {
    const videoConfig = { 
        resizeWidth : 224,
        resizeHeight : 224,
        facingMode: 'environment' 
    };


    const videoCam = await tf.data.webcam(videoEl, videoConfig);

    let interval = setInterval(async () => {
        if (!videoEl.paused) {

            const img = await videoCam.capture();
            const imgBuffer = await img.buffer();

            worker.postMessage(imgBuffer.values, [imgBuffer.values.buffer]);

            img.dispose();

            await tf.nextFrame();
        } 
        else {
            clearInterval(interval);
        }
    }, 800);
}

export async function loadModel(onLoad, onResult) {
    return new Promise((resolve, reject) => {
        if (typeof(Worker) !== "undefined") {
            worker = loadWorkerModel(onLoad, onResult);
            resolve();
        } 
        else {
            throw new Error("Unable to load the model");
        }
    });
}


function loadWorkerModel(onLoad, onResult) {
    let webWorker = new Worker("src/worker.js");

    webWorker.onmessage = (e) => {

        // let msg = new Uint8Array(e.data.slice(0,1));
        let msg = e.data.msg
        if (msg == "modelReady") { onLoad(true) }
        else if (msg == "modelFailed") { onLoad(false) }
        else if (msg == "result") {

            onResult(
                { result : 
                    { 
                        className : classes[e.data.classIndex],
                        percentage: decodeBuffer(e.data.percentage)
                    }
                }
            );
        }
        else { 
            console.log("command not underestood");
        }
    };

    return webWorker;
}

function decodeBuffer(buffer) {
    return stringDecoder.decode(buffer);
}

/*
    Predict an Image by passing an :
        - imgSrc : The image in a string format
        - callback : Function used to return the result back 
*/
export async function predictImage(imgSrc, callback) {

    // Create new Image Object
    const imgEl = new Image();

    // Use the @onload Event to predict the image after it loads 
    imgEl.onload = async () => {
        let tensor = tf.tidy(() => 
            tf.image.resizeBilinear(tf.browser.fromPixels(imgEl), [224,224])
        )

        let imgBuffer = await tensor.buffer();

        worker.postMessage(imgBuffer.values, [imgBuffer.values.buffer]);

        // Dispose the tensors to free the memory
        tensor.dispose();
    }

    // Assign the incoming imgSrc
    imgEl.src = imgSrc;
}
