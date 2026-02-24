// Import the Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize Firebase
firebase.initializeApp({
  apiKey: 'AIzaSyC-ZQ_pS7_NDFgcmljGeLSy0dt9YvkKE24',
  authDomain: 'chatly-3ca5c.firebaseapp.com',
  projectId: 'chatly-3ca5c',
  storageBucket: 'chatly-3ca5c.firebasestorage.app',
  messagingSenderId: '687279755567',
  appId: '1:687279755567:web:6b94a86af0add08cc311da',
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
