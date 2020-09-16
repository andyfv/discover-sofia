const FILES_TO_CACHE = [
    '/',
    '/discover-sofia/',
    '/discover-sofia/elm.min.js',
    '/discover-sofia/index.html',
    '/discover-sofia/public/manifest.json',
    '/discover-sofia/js/HereMaps.js',
    '/discover-sofia/js/TensorFlow.js',
    '/discover-sofia/css/normalize.css',
    '/discover-sofia/css/style.css',
    '/discover-sofia/public/model/tfjs_model_quantized_uint16/model.json',
    '/discover-sofia/public/model/tfjs_model_quantized_uint16/group1-shard1of2.bin',
    '/discover-sofia/public/model/tfjs_model_quantized_uint16/group1-shard2of2.bin'
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
      return response || fetch(event.request)
    })
  );
});

