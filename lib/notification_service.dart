// lib/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Helper para obter a chave correta com base no flavor (permanece o mesmo)
class _VapidKeyConfig {
  static const _flavor = String.fromEnvironment('FLAVOR');

  static const _prodVapidKey =
      "BEPq30M1dSl_5v3o3miCOEBLsIH_JD7atFFqynD-Ck3qWFPFlw0nJPhxKq-CnLZ4qZiDQuZZojItUeT90C5JFCs";

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
    // Pede permissão ao usuário (funciona para iOS, Android e Web)
    await _fcm.requestPermission();

    // Listener para quando o app está aberto (em primeiro plano)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          'Recebeu uma mensagem em primeiro plano: ${message.notification?.title}');
      // No futuro, você pode mostrar um diálogo ou uma snackbar aqui
    });
  }

  Future<void> saveTokenForCurrentUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      String? token;
      // <<< ALTERAÇÃO AQUI >>>
      // Pega o token de forma diferente dependendo da plataforma.
      if (kIsWeb) {
        // Para a web, precisa da chave VAPID.
        token = await _fcm.getToken(vapidKey: _VapidKeyConfig.current);
      } else {
        // Para Android e iOS, não precisa da chave.
        token = await _fcm.getToken();
      }

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
