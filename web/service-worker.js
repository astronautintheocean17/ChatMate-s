/*
 * ChatMate install service worker.
 *
 * Keeps an active fetch handler for Chromium installability and runtime-caches
 * large static assets (CanvasKit wasm, icons, fonts) so repeat loads start
 * faster. App code (HTML/JS) always goes to the network.
 */
'use strict';

var CACHE = 'chatmate-assets-v1';

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(keys.map(function (key) {
        if (key !== CACHE) return caches.delete(key);
        return undefined;
      }));
    }).then(function () {
      return self.clients.claim();
    })
  );
});

function isCacheable(request) {
  if (request.method !== 'GET') return false;
  var url = new URL(request.url);
  var sameOrigin = url.origin === self.location.origin;
  var canvasKit = url.origin === 'https://www.gstatic.com' &&
    url.pathname.indexOf('/flutter-canvaskit/') === 0;
  if (!sameOrigin && !canvasKit) return false;
  if (canvasKit) return /\.(?:js|wasm)$/i.test(url.pathname);
  return /\.(?:wasm|png|jpe?g|webp|svg|woff2?|ttf|otf)$/i.test(url.pathname);
}

self.addEventListener('fetch', function (event) {
  var request = event.request;
  if (request.method !== 'GET') return;
  if (!isCacheable(request)) {
    event.respondWith(fetch(request));
    return;
  }

  event.respondWith(
    caches.open(CACHE).then(function (cache) {
      return cache.match(request).then(function (cached) {
        var network = fetch(request).then(function (response) {
          if (response && response.status === 200) {
            cache.put(request, response.clone()).catch(function () {});
          }
          return response;
        }).catch(function () {
          return cached;
        });
        return cached || network;
      });
    }).catch(function () {
      return fetch(request);
    })
  );
});
