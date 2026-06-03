// lib/pwa_install_service.dart
// Serviço para acionar a instalação PWA a partir do Flutter (Web only)

// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class PwaInstallService {
  /// Retorna true se o prompt de instalação está disponível
  static bool get isInstallable {
    if (!kIsWeb) return false;
    try {
      final result = js.context.callMethod('isPwaInstallable', []);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Dispara o prompt de instalação nativo (Android/Chrome)
  /// ou mostra as instruções para iOS
  static bool triggerInstall() {
    if (!kIsWeb) return false;
    try {
      final result = js.context.callMethod('triggerPwaInstall', []);
      return result == true;
    } catch (_) {
      return false;
    }
  }
}
