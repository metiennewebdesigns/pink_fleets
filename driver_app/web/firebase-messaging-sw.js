importScripts("https://www.gstatic.com/firebasejs/10.12.4/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.4/firebase-messaging-compat.js");

// ✅ Replace with YOUR Firebase web config (same project)
firebase.initializeApp({
  apiKey: "AIzaSyB88mPsi4HXs-vR3I0HBY2mljgrWmRc0a4",
  authDomain: "pink-fleets.firebaseapp.com",
  projectId: "pink-fleets",
  storageBucket: "Ppink-fleets.firebasestorage.app",
  messagingSenderId: "93607564611",
  appId: "G-YLJBPQ1X7S"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  const title = payload.notification?.title || "Pink Fleets";
  const options = {
    body: payload.notification?.body || "",
    icon: "/icons/Icon-192.png"
  };
  self.registration.showNotification(title, options);
});