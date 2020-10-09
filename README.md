## Table Of Contents
 
* [About](#about)
* [Implementation](#implementation)
* [How to run it](#how-to-run-it)
* [How to use it](#how-to-use-it)
* [Project Structure](#project-structure)
* [Dependencies](#dependencies)
* [TODO](#todo)
* [Issues](#issues)

***

## About

The **Discover Sofia** project was my Bachelor Thesis. The main idea was to 
explore the Web-browser's capabilties as a platform for Machine Learning. 
The current implementation is far from complete but for now it allows the user to:

- Use Image Recognition to recognize particular landmark by using the 
video feed from the back camera or by uploading a photo
- Check interesting landmarks on the map and get short information about them
- Get basic Navigation to the selected landmark

**Functional programming** in the form of **Elm** was used for:
- Being the single source of truth for the most of the application state 
- Implementing the UI 
- Putting together the logic from the additional JavaScript libraries.

*** 

## Implementation

The implementation is split in four parts:

1. Use Machine Learing to create model for Image Recognition using TensorFlow
2. Create the UI using Elm
3. Integrate the Image Recognition Model with the UI
4. Integrate an Interactive Map with the UI

#### Machine Learning

Transfer Learning is used to improve the overall accuracy of the 
model since the size of the photos set is extremely small.

Post-training quantization is used to reduce the model size. 

#### Create the UI

The interface is devided in three pages:

1) **Map**:Represents an interactive map with visualized landmarks. 
Choosing a certain landmark shows the user a basic info about the landmark 
and an option for basic navigation. 

2) **Camera**: Represents an interface which shows the video feed from the 
back camera if there is one. If there is back camera the video feed is used 
for inference using the Image Recognition model. The result is displayed below the video element.

3) **Photo**: Represents an interface for uploading photo from the device.
 The uploaded photo is then used for inference using the Image Recognitionn 
 model and the result is displayed below the photo.

#### Integrating the Image Recognition Model with the UI

Elm Ports are used for communication bewteen the UI and Image Recognition model. 
The logic for working with the model and preparing the images for inference is
 implemented with the help of the TensorFlow.js library.
 
#### Integrating the Interactive Map with the UI

Two external APIs are used for implementing the interactive map:

1) Wikipedia REST API

> Used to take request information about the landmarks(histoty, images, coordinates, etc.) 

2) HereMaps API

> Used to display the map and vizualize the landmarks on it. 
Also provideing the basic navigation features.

***

## How to run it

#### [Open the Link](https://andyfv.github.io/discover-sofia/)

#### Or download/clone locally:

1) Download or Clone the repository

2) Install the needed dependecies
* elm 
* elm-live
* cors-anywhere

3) Start `cors-anywhere`. From the installation directory of `cors-anywhere` issue the 
following command in a terminal:
    
```node server.js```

4) Start the local server. First checkout to the `development` branch. Then from the 
base of the project directory issue the following command:

```elm-live src/Main.elm --pushstate -- --debug --output =elm.js```

***

## How to use it

Navigate through the three pages to use the functionality you want:

* /map
* /camera
* /photos 

***

## Project Structure

    .
    ├── 404.html
    ├── css
    │   ├── normalize.css       # Normalize styles across web browsers
    │   └── style.css           # Styling
    ├── elm.js                  # Compiled file
    ├── elm.json                # Elm dependencies
    ├── elm.min.js              # Minified version of elm used for deployment
    ├── index.html              
    ├── js              
    │   ├── HereMaps.js         # Logic to work with HereMaps API
    │   └── TensorFlow.js       # Logic to work with the inference model
    ├── public
    │   ├── data.json           # Stores the landmarks links 
    │   └── model               # Stores the inference model files
    ├── src     
    │   ├── Main.elm            # Root file. Start here if you want to explore more
    │   ├── MapHelper.elm       # Additional types, coders and decoderes to work with the map
    │   ├── NavBar.elm          # Navbar logic
    │   ├── Page                # Direcotory containing the pages
    │   ├── Route.elm           # Router for the pages
    │   ├── TensorFlow.elm      # Helper file to work with TensorFlow
    │   └── ViewPort.elm        # Viewport logic
    └── tests                   


***

## Dependencies

* TensorFlow.js
* HereMaps API
* Wikipedia REST API

Elm dependencies:

* elm/file
* elm/url
* elm/http
* elm/json
* NoRedInk/elm-json-decode-pipeline
* elm-explorations/test

***

## TODO

There is much to be done: 

* Use the inference result so that the user can be redirected to the Map page
 showing the basic information about the landmark. To do this it should be analized how 
 and where to do it.
* Implement back-end server and transform the app to PWA
* Making the experience more interactive
* Update the model architecture from MobilenetV2 to MobilenetV3
* Try further optimizing the inference times by using smaller input images. 
Currently using [224x224]

***

## Issues

* In some versions of Firefox the GPU backend could not be used. Looks like an issue 
with Firefox and not TensorFlow.js.