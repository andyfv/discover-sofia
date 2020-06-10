try { 
    importScripts('https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@2.0.0/dist/tf.min.js');
} catch(e) {
    throw new Error ("Unable to load Tensorflow");
}

var model;
const stringEncoder = new TextEncoder;
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


async function app() {
    try {
        model = await tf.loadGraphModel('/assets/tfjs_model_quantized_2/model.json');
    } catch (e) {
        // let msg = new Uint8Array([1]);
        // postMessage([msg], [msg.buffer]);
        postMessage({ msg : "modelFailed"});
    }

    tf.enableProdMode();

    warmUp();

    // let msg = new Uint8Array([2]);
    // postMessage([msg], [msg.buffer]);
    postMessage({ msg : "modelReady"});
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
    let index = tf.argMax(predictionArr);
    let predictedClassIndex = await index.data()
        .then((indexArr) => indexArr[0])

    // console.log({ result : { 
    //             className : predictedClass, 
    //             percentage : Math.round((predictedPerc + Number.EPSILON) * 10000) / 10000
    //         }
    //     });

    // console.log();

    let resultPerc = encodeString(predictedPerc.toFixed(4));
    let resultClass = new  Uint8Array([predictedClassIndex]);
    // let result = new Uint8Array([0]);
    let msgArray = new Uint32Array([result.buffer, resultPerc.buffer, resultClass.buffer]);

    // console.log(msgArray);

    postMessage(JSON.stringify(
        { msg : "result" 
        , resultClass: resultClass
        , resultPerc: resultPerc 
        }
        )
    );
        // [ result.buffer, resultClass.buffer, resultPerc.buffer]

    // postMessage(JSON.stringify(
    //     { result : { 
    //             className : predictedClass, 
    //             percentage : Math.round((predictedPerc + Number.EPSILON) * 10000) / 10000
    //         }
    //     }
    // ));


    // Dispose the tensors to free the memory
    predictionArr.dispose();
    prediction.dispose();
    scaled.dispose();
    expanded.dispose();
    index.dispose();
    img.dispose();


    // Give time 
    await tf.nextFrame();
}


app();