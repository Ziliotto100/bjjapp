// web/firebase-messaging-sw-dev.js
//QUANDO FOR USAR PARA DEV, TIRAR O "-DEV" DO NOME DO ARQUIVO DEIXAR ELE SOMENTE firebase-messaging-sw
//QUANDO FOR USAR PARA PROD, TIRAR O "-PROD" DO NOME DO ARQUIVO, DEIXAR ELE SOMENTE firebase-messaging-sw

// Imports do Firebase
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js");

// Configurações do seu projeto Firebase de DESENVOLVIMENTO (dev-bjjmatch)
const firebaseConfig = {
  apiKey: "AIzaSyCA5qdkvN13Xje5-V9SsPpC-k3nQ8D5Zaw",
  authDomain: "dev-bjjmatch.firebaseapp.com",
  projectId: "dev-bjjmatch",
  storageBucket: "dev-bjjmatch.firebasestorage.app",
  messagingSenderId: "461427127162",
  appId: "1:461427127162:web:3026e581a3597a08765cc3"
};

// Inicializa o Firebase
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw-dev.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});