try { 
    importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@2.0.0/dist/tf.min.js');
} catch(e) {
    throw new Error ("Unable to load Tensorflow");
}

var model;
const stringEncoder = new TextEncoder;

async function app() {
    try {
        model = await tf.loadGraphModel('/assets/tfjs_model_quantized_2/model.json');
    } catch (e) {
        let msg = new Uint8Array([2]);
        postMessage(msg, [msg.buffer]);
        // postMessage(JSON.stringify({ msg : "modelFailed"}));
    }

    tf.enableProdMode();

    warmUp();

    let msg = new Uint8Array([1]);
    postMessage(msg, [msg.buffer]);
    // postMessage(JSON.stringify({ msg : "modelReady"}));
}

async function warmUp() {
    // Create temporary tensor filled with zeros
    const imageTensor = tf.zeros([1, 224, 224, 3], 'float32');
    const warmupResult = await model.execute(imageTensor);

    // Dispose the tensors to free the memory
    imageTensor.dispose();
    warmupResult.dispose();
}


function encodeString (str) {
    return stringEncoder.encode(str);
}

onmessage = async function(e) {
    const img = tf.tensor3d(e.data, [224, 224, 3]);

    const scaled = img.div(255.0);
    const expanded = scaled.expandDims(0);

    let prediction = await model.execute(expanded);

    // Get the data as an array from the tensor
    let predictionArr = await prediction.data()
        .then((data) => tf.softmax(data));


    //Get the highest predicted percentage
    let predictedPerc = await predictionArr.data()
        .then((data) => Math.max(...data) * 100);


    // Get the predicted class
    let indexTensor = tf.argMax(predictionArr);
    let predictedIndex = await indexTensor.data()
        .then((index) => index[0])



    let resultPerc = encodeString(predictedPerc.toFixed(4));
    let resultClass = new Uint8Array([predictedIndex]);
    let result = new Uint8Array([3]);



    let full = new Uint8Array([...result, ...resultClass, ...resultPerc,]);

    // console.log(full);

    postMessage(full, [full.buffer]);
    


    // postMessage(JSON.stringify(
    //     { msg : "result" 
    //     , className: predictedClass
    //     , percentage: predictedPerc.toFixed(4) 
    //     })
    //     );
        // [ result.buffer, resultClass.buffer, resultPerc.buffer]


    // Dispose the tensors to free the memory
    predictionArr.dispose();
    prediction.dispose();
    scaled.dispose();
    expanded.dispose();
    indexTensor.dispose();
    img.dispose();


    // Give time 
    await tf.nextFrame();
}


app();