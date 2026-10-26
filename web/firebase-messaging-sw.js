// web/firebase-messaging-sw.js
// Background push for the PWA build.
//
// The config below mirrors lib/firebase_options.dart (web). If you rotate the
// Firebase web app, update both files.
//
// Web push also needs a VAPID key: set kWebPushVapidKey in
// lib/data/push-service.dart from
// Firebase console → Project settings → Cloud Messaging → Web configuration.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAry63P1sDvSkTH52GrOSerPQ4kHAmhYIg',
  appId: '1:839354323522:web:15047f130410340c01d3db',
  messagingSenderId: '839354323522',
  projectId: 'project-chatmate',
  authDomain: 'project-chatmate.firebaseapp.com',
  storageBucket: 'project-chatmate.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};

  self.registration.showNotification(notification.title || 'ChatMate', {
    body: notification.body || 'You have a new message.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.room_id ? 'room-' + data.room_id : 'chatmate',
    data: data,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const roomId = (event.notification.data || {}).room_id;
  const target = roomId ? '/?room=' + encodeURIComponent(roomId) : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) {
          client.navigate(target);
          return client.focus();
        }
      }
      return clients.openWindow(target);
    })
  );
});
