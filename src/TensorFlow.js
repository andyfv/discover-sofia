const LIBS = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@2.0.0/dist/tf.min.js";
const bodyTag = document.getElementsByTagName('body')[0];
const stringDecoder = new TextDecoder;

var model,
    worker;

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
        // const videoWrapper = document.getElementById('camera-results-wrapper');
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

        // videoWrapper.appendChild(video);

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

    // let img, imgArr;


    let interval = setInterval(async () => {
        if (!videoEl.paused) {
            const img = await videoCam.capture();

            const imgArr = await img.buffer();

            worker.postMessage(imgArr.values, [imgArr.values.buffer]);

            img.dispose();
        } else {
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
    let worker = new Worker("src/worker.js");

    worker.onmessage = (e) => {
        let msg = e.data.msg;
        if (msg == "modelReady") { onLoad(true) }
        else if (msg == "modelFailed" ) { onLoad(false) }
        else { console.log(modelReady) }
        // let msg = e.data;
        // switch(msg) {
        //     case (1) : 
        //         onLoad(true);
        //         break;

        //     case (2) :
        //         onLoad(false);
        //         break;

        //     case (3) :
        //         console.log(e.data);
        //         onResult({ result : e.data.result });
        //         break;

        //     default :
        //         onResult({ error: "Message from Web Worker not understood"});
        //         console.log("Message not understood: " + e.data);
        //         break;           
        // };
    };

    // worker.onmessage = (e) => {
    //     let msg = decodeBuffer(e.data[0]);

    //     if (msg == "result") {
    //         onResult({ result : { 
    //             className : e.data.className,
    //             percentage: e.data.percentage
    //             } 
    //         });
    //     }
    //     else if (msg == "modelLoaded") {
    //         onLoad(true);
    //     }
    //     else if (msg == "modelFailed") {
    //         onLoad(false);
    //     }
    //     else {
    //         console.log("command not recognized");
    //     }
    // }

    return worker;
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

        let imgArr = await tensor.array();
            worker.postMessage(JSON.stringify(imgArr));

        // Dispose the tensors to free the memory
        tensor.dispose();
    }

    // Assign the incoming imgSrc
    imgEl.src = imgSrc;
}
