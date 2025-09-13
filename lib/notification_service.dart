// lib/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Helper para obter a chave correta com base no flavor
class _VapidKeyConfig {
  static const _flavor = String.fromEnvironment('FLAVOR');

  // Chave do seu projeto de PRODUÇÃO (matchbjj)
  static const _prodVapidKey =
      "BEPq30M1dSl_5v3o3miCOEBLsIH_JD7atFFqynD-Ck3qWFPFlw0nJPhxKq-CnLZ4qZiDQuZZojItUeT90C5JFCs";

  // Chave do seu projeto de DESENVOLVIMENTO (dev-bjjmatch)
  // !!! COLE AQUI A CHAVE QUE VOCÊ COPIOU DO SEU PROJETO 'dev-bjjmatch' !!!
  static const _devVapidKey =
      "BB8zfRTrPs_sC08kThSO01jGOnyVNS0daY3xcoVlHtLMmAcGwEDbFRPy_ktJvjchwVW9Caj6AVd1csmcG4yUeVU";

  static String get current {
    if (_flavor == 'prod') {
      return _prodVapidKey;
    }
    return _devVapidKey;
  }
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initNotifications() async {
    // Apenas executa na web
    if (!kIsWeb) {
      return;
    }

    // Pede permissão ao usuário
    await _fcm.requestPermission();

    // Listener para quando o app está aberto (em primeiro plano)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          'Recebeu uma mensagem em primeiro plano: ${message.notification?.title}');
      // Aqui você pode mostrar um diálogo ou uma snackbar
    });
  }

  Future<void> saveTokenForCurrentUser() async {
    if (!kIsWeb) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    // Usa a chave VAPID correta para o ambiente atual
    final vapidKey = _VapidKeyConfig.current;

    try {
      final token = await _fcm.getToken(vapidKey: vapidKey);
      if (token == null) {
        print('Não foi possível obter o token de notificação.');
        return;
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final tokens = List<String>.from(userDoc.data()?['fcmTokens'] ?? []);
        if (!tokens.contains(token)) {
          // Adiciona o novo token à lista de tokens existentes
          await userRef.update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
          print('Token de notificação salvo para o usuário!');
        } else {
          print('Token já existe para este usuário.');
        }
      }
    } catch (e) {
      print('Erro ao salvar o token de notificação: $e');
    }
  }
}
