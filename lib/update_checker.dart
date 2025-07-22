// lib/update_checker.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateChecker {
  final BuildContext context;
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.example.bjjapp'; // <-- MUDE PARA O ID DO SEU APP

  UpdateChecker({required this.context});

  Future<void> checkForUpdate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();

      final String remoteVersion = remoteConfig.getString('latest_app_version');
      if (remoteVersion.isEmpty) return;

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      if (_isUpdateRequired(currentVersion, remoteVersion)) {
        _showUpdateDialog();
      }
    } catch (e) {
      // A verificação de atualização não deve impedir o usuário de usar o app.
      // Apenas logamos o erro para fins de depuração.
      debugPrint("Erro ao verificar atualização: $e");
    }
  }

  bool _isUpdateRequired(String currentVersion, String remoteVersion) {
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final remoteParts = remoteVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < remoteParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Text("Atualização Disponível"),
            content: const Text(
                "Uma nova versão do aplicativo está disponível. Por favor, atualize para continuar usando."),
            actions: <Widget>[
              TextButton(
                child: const Text("ATUALIZAR AGORA"),
                onPressed: () async {
                  final uri = Uri.parse(_playStoreUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
