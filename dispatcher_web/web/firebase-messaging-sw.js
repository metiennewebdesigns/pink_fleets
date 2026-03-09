// Firebase Messaging service worker for Pink Fleets Dispatcher
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB88mPsi4HXs-vR3I0HBY2mljgrWmRc0a4',
  authDomain: 'pink-fleets.firebaseapp.com',
  projectId: 'pink-fleets',
  storageBucket: 'pink-fleets.firebasestorage.app',
  messagingSenderId: '93607564611',
  appId: '1:93607564611:web:9deb249bff8d2d409e4bf6',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload?.notification?.title || 'Pink Fleets';
  const options = {
    body: payload?.notification?.body || '',
    data: payload?.data || {},
  };

  self.registration.showNotification(title, options);
});
