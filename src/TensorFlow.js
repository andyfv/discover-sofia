const LIBS = "https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@2.0.0/dist/tf.min.js";
const bodyTag = document.getElementsByTagName('body')[0];

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


/**
 * Loads the TensorFlow library
 * 
 * @return {Promise} Promise - Holds the eventual success ot failure of 
 * loading the tensorflow.js library declared as @LIBS
 */
export function loadLibs() {
    return loadLibrary(LIBS)
    .catch((error) => 'Failed to load classification model');
}


/**
 * Load library by adding it to the @headTag
 * 
 * @param {string} url - String representing the url of the library to load
 * @return {Promise} - Promise representing the failure or success of loading 
 * the script
 */
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

/**
 * Loads the model for inference
 *  
 * @param  {function} onLoad - Callback function to notify Elm when 
 * the model is loaded
 * 
 * @return {boolean} onLoad - A callback to returns
 */
export async function loadModel(onLoad) {
    try {
        model = await tf.loadGraphModel('/assets/tfjs_model_quantized_2/model.json');
    } catch (e) {
        // Notifies Elm runtime that the loading has failed
        onLoad(false);
    }

    // Enables the Production Mode for optimization
    tf.enableProdMode();

    // Warm up the model by loading the weights to the GPU with one-time inference
    warmUp();

    // Notifies Elm runtime that the loading has failed
    onLoad(true);
}


/**
 *  Warms up the model by doing one-time inference to load the model weights 
 *  to the GPU. This way they will be loaded for any subsequent inference
 *  
 * @return {void}
 */
async function warmUp() {
    // Create temporary tensor filled with zeros
    const imageTensor = tf.zeros([1, 224, 224, 3], 'float32');
    const warmupResult = await model.execute(imageTensor);

    // Dispose the tensors to free the memory
    imageTensor.dispose();
    warmupResult.dispose();
}


/**
 *  Creates video element by getting @mediaStream track and pass it to 
 *  the video element src property
 * 
 * @return {void}
 */
export function createVideoElement() {
    return new Promise((resolve, reject) => {
        
        // @var {HTMLElement} video - take a refence to the 
        const videoElement = document.getElementById('video');

        // @var {object} constraints - holds the configurations for media stream
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

       
       /**
        * Stop the mediaStream from the camera when switching to 
        * prevent memory leaks and security issues.
        *
        * Note: Stops all mediaTracks, not just the camera 
        * 
        * @return {void}
        */
        videoElement.onpause = (e) => {
            const stream = videoElement.srcObject;
            const tracks = stream.getTracks();

            tracks.forEach(function(track) {
                track.stop();
            });

            videoElement.srcObject = null;
        };


        /**
         *  Plays the video after loading the metadata
         *  
         * @return {void}
         */
        video.onloadmetadata = (e) => {
            videoElement.play();
        };

        /**
         * Takes a mediaStream if the browser supports it
         *
         * @param {object} constraints - configuration for getting 
         * the mediaStream we need
         * 
         * @return {Promise} Promise object representing the presence of 
         * back-camera on the device 
         */
        navigator.mediaDevices.getUserMedia(constraints)
        .then((mediaStream) => {
            videoElement.srcObject = mediaStream;

            resolve(videoElement);
        })
        .catch((err) => reject(new Error("Camera not found")));
    });

}


/**
 * Predicts video feed
 * @param  {HTMLElement} videoElement - the element on ehich the video feed 
 * is visualized
 * 
 * @param  {requestCallback} onResult - Callback function used to notify Elm with 
 * the prediction results
 * 
 * @return {void}
 */
export async function predictVideo (videoElement, onResult) {
    const videoConfig = { 
        resizeWidth : 224,
        resizeHeight : 224,
        facingMode: 'environment' 
    };

    // Contains the video feed taken from the videoElement
    const videoCam = await tf.data.webcam(videoElement, videoConfig);

    /**
     * Async function used to make predictions on the the setted interval
     * 
     * @return {void}
     */
    let interval = setInterval(async () => {
        // Make predictions if the video is playing
        if (!videoElement.paused) {

            const img = await videoCam.capture();

            makePrediction(img, onResult);

            img.dispose();

            await tf.nextFrame();
        } 
        else {
            // Clear the interval to top the predictions if the video is paused
            clearInterval(interval);
        }
    }, 800);
}



/**
 * Predicts an image
 * 
 * @param  {string} imgSrc - string containing the image data in Base64 scheme
 * @param  {requestCallback} onResult - Callback to notify Elm runtime with the 
 * predictions results
 * 
 * @return {void}
 */
export async function predictImage(imgSrc, onResult) {

    // Create new Image Object
    const imgEl = new Image();

    // Use the @onload Event to predict the image after it loads 
    imgEl.onload = async () => {
        let tensor = tf.tidy(() => {
            let imgTensor = tf.browser.fromPixels(imgEl);
            return tf.image.resizeBilinear(imgTensor, [224,224])
        });

        makePrediction(tensor, onResult)

        // Dispose the tensors to free the memory
        tensor.dispose();
    }

    // Assign the incoming image data 
    imgEl.src = imgSrc;
}


/**
 * Makes predictions
 * 
 * @param  {tf.Tensor3D} img - tensor containing the image data
 * @param  {requestCallback} onResult - Callback to notify Elm runtime with the 
 * predictions results
 * 
 * @return {void}
 */
async function makePrediction (img, onResult) {

    // Normalizes the image data to float32 in the range 0-1 
    const scaled = img.div(255.0);

    // Adds one more dimension to the image at [postion 0] so the 
    // tensor is in the expected shape for the model inference
    const expanded = scaled.expandDims(0);


    // Makes an async prediction
    let prediction = await model.execute(expanded);

    // Takes the prediction data as an array
    let predictionArr = await prediction.buffer()
        .then((dataArray) => tf.softmax(dataArray.values));

    // Takes the highest predicted percentage
    let predictedPerc = await predictionArr.buffer()
        .then((dataArray) => Math.max(...dataArray.values) * 100);

    // Takes the predicted class index
    let indexTensor = tf.argMax(predictionArr);
    let predictedIndex = await indexTensor.buffer()
        .then((indexArray) => indexArray.values)

    // Formats the predicted percentage to 4 digits after the decimal point and 
    // returns it as a {string}
    let resultPerc = predictedPerc.toFixed(4);

    // Call the callback function with results
    onResult({ result: 
        {
            className: classes[predictedIndex[0]],
            percentage: resultPerc
        }
    });


    // Dispose the tensors to free the memory
    predictionArr.dispose();
    prediction.dispose();
    scaled.dispose();
    expanded.dispose();
    indexTensor.dispose();
    img.dispose();


    // Returns a promise that resolve when a requestAnimationFrame has completed
    await tf.nextFrame();
}
