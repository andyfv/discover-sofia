const FILES_TO_CACHE = [
    '/discorer-sofia/',
    '/discorer-sofia/elm.min.js',
    '/discorer-sofia/index.html',
    '/discorer-sofia/public/manifest.json',
    '/discorer-sofia/js/HereMaps.js',
    '/discorer-sofia/js/TensorFlow.js',
    '/discorer-sofia/css/normalize/css',
    '/discorer-sofia/css/style.css',
    '/discorer-sofia/public/model/tfjs_model_quantized_uint16/model.json',
    '/discorer-sofia/public/model/tfjs_model_quantized_uint16/group1-shard1of2.bin',
    '/discorer-sofia/public/model/tfjs_model_quantized_uint16/group1-shard2of2.bin'
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

