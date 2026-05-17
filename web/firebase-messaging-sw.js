importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB6Q5DE_VkpqO3qTn3bqPBawQjxzGEngxY',
  appId: '1:802503541368:web:652e4356653d7cbcf6a38d',
  messagingSenderId: '802503541368',
  projectId: 'van-merchant',
  authDomain: 'van-merchant.firebaseapp.com',
  storageBucket: 'van-merchant.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'SHOP';
  const notificationOptions = {
    body: payload.notification?.body || 'คุณมีการแจ้งเตือนใหม่',
    icon: payload.notification?.image || '/icons/Icon-192.png',
    data: payload.data,
    actions: payload.data?.actionButtons ? JSON.parse(payload.data.actionButtons) : undefined,
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = event.notification?.data?.deepLink || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(targetUrl) && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
      return undefined;
    }),
  );
});
