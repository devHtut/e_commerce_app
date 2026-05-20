importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAMhYPsgxKOVK1zHn2Bv0SZ8dSeHSRE_w4',
  appId: '1:701850273720:web:1bc3410422f7e3b786f14d',
  messagingSenderId: '701850273720',
  projectId: 'burma-brands',
  authDomain: 'burma-brands.firebaseapp.com',
  storageBucket: 'burma-brands.firebasestorage.app',
  measurementId: 'G-2VSYXNQZDM',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  if (message.notification) return;

  const notification = message.notification || {};
  const title = notification.title || message.data?.title || 'Burma Brands';
  const options = {
    body: notification.body || message.data?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: message.data || {},
  };

  self.registration.showNotification(title, options);
});
