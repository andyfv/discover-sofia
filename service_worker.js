const FILES_TO_CACHE = [
    '/',
    '/elm.js',
    '/index.html',
    '/public/manifest/json',
    '/js/HereMAps.js',
    '/js/TensorFlow.js',
    '/css/normalize/css',
    '/css/style.css',
    '/public/model/tfjs_model_quantized_uint16/model.json',
    '/public/model/tfjs_model_quantized_uint16/group1-shard1of2.bin',
    '/public/model/tfjs_model_quantized_uint16/group1-shard2of2.bin'
]


self.addEventListener('install', function (e) {
    e.waitUntil(
        caches.open('discover-sofia-app').then(function (cache) {
            return cache.addAll(FILES_TO_CACHE);
        })
    )
});

self.addEventListener('fetch', function (event) {
  event.respondWith(
    caches.match(event.request).then(function (response) {
      return response || fetch(event.request);
    })
  );
});

