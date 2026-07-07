importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCezS9naRCgDeVReCm_jRkWbrAM2i-rm4A",
  authDomain: "lexbot-b93de.firebaseapp.com",
  projectId: "lexbot-b93de",
  storageBucket: "lexbot-b93de.firebasestorage.app",
  messagingSenderId: "803590597031",
  appId: "1:803590597031:web:d29098032ac9d39fd76e82"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Background message received:", payload);
  const { title, body } = payload.notification;
  self.registration.showNotification(title, { body });
});
