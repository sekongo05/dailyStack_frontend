importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyBLr01wIt85M4bXFSKHnjZcGUKAKqPkJPI",
  authDomain: "dailystack-app.firebaseapp.com",
  projectId: "dailystack-app",
  storageBucket: "dailystack-app.firebasestorage.app",
  messagingSenderId: "830598198131",
  appId: "1:830598198131:web:9b1a2f93c876d5c8504b06",
  measurementId: "G-6E67WGHPRK"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notif = payload.notification || {};
  const title = notif.title || 'DailyStack';
  const options = {
    body: notif.body || 'Votre séance du jour est prête.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {}
  };
  return self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
