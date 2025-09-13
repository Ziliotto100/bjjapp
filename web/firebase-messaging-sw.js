// web/firebase-messaging-sw-prod.js
//QUANDO FOR USAR PARA DEV, TIRAR O "-DEV" DO NOME DO ARQUIVO DEIXAR ELE SOMENTE firebase-messaging-sw
//QUANDO FOR USAR PARA PROD, TIRAR O "-PROD" DO NOME DO ARQUIVO, DEIXAR ELE SOMENTE firebase-messaging-sw

// Imports do Firebase
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js");

// Configurações do seu projeto Firebase de PRODUÇÃO (matchbjj)
const firebaseConfig = {
  apiKey: "AIzaSyAxtyejLeFMErqGtHU-NCvhVFG6US6OylU",
  authDomain: "matchbjj.firebaseapp.com",
  projectId: "matchbjj",
  storageBucket: "matchbjj.firebasestorage.app",
  messagingSenderId: "757933813601",
  appId: "1:757933813601:web:2f7aabfec9765eb18c9f20",
  measurementId: "G-VBQLGV95WN"
};

// Inicializa o Firebase
firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw-prod.js] Received background message ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});