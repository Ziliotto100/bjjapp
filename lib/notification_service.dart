// lib/notification_service.dart
// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Helper para obter a chave correta com base no flavor
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
    await _fcm.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          'Recebeu uma mensagem em primeiro plano: ${message.notification?.title}');
    });

    // Ouve por atualizações de token (quando um token expira e um novo é gerado)
    _fcm.onTokenRefresh.listen((newToken) {
      saveTokenForCurrentUser(tokenToSave: newToken);
    });
  }

  // <<< FUNÇÃO ATUALIZADA >>>
  Future<void> saveTokenForCurrentUser({String? tokenToSave}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      // Se um token não foi passado (ex: no login), pega o atual.
      // Se foi passado (pelo onTokenRefresh), usa ele.
      String? token = tokenToSave;
      if (token == null) {
        if (kIsWeb) {
          token = await _fcm.getToken(vapidKey: _VapidKeyConfig.current);
        } else {
          token = await _fcm.getToken();
        }
      }

      if (token == null) {
        print('Não foi possível obter o token de notificação.');
        return;
      }

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      // Lógica de atualização: Substitui a lista de tokens pela nova.
      // Isso garante que apenas o token mais recente esteja associado.
      // Para suportar múltiplos dispositivos (ex: web e celular), a lógica seria
      // mais complexa, mas para um único dispositivo, isso resolve o problema.
      await userRef.update({
        'fcmTokens': [token], // Salva o novo token em uma lista
      });
      print('Token de notificação salvo/atualizado para o usuário!');
    } catch (e) {
      print('Erro ao salvar o token de notificação: $e');
    }
  }
}
