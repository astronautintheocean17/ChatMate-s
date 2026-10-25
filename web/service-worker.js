/*
 * ChatMate install service worker.
 *
 * Chrome/Edge still use an active service worker with a fetch handler as part
 * of their installability checks. This worker deliberately does not cache the
 * Flutter bundle, so every deploy is served fresh; it only keeps the origin
 * installable and claims the scope immediately after an update.
 */
'use strict';

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', function (event) {
  if (event.request.method !== 'GET') return;
  event.respondWith(fetch(event.request));
});
