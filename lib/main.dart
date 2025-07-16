// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

// [MODIFICAÇÃO PRINCIPAL]
// Importamos o seu arquivo de tema, que agora contém o widget BjjApp.
import 'app_theme.dart';

// A lógica de flavors e Firebase continua a mesma
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

const flavor = String.fromEnvironment('FLAVOR');

void main() async {
  // 1. Garante que os serviços do Flutter estão prontos.
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Configura a UI para o modo imersivo (edge-to-edge).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // 3. Seleciona as configurações do Firebase com base no flavor.
  FirebaseOptions options;
  if (flavor == 'prod') {
    options = prod.DefaultFirebaseOptions.currentPlatform;
  } else {
    options = dev.DefaultFirebaseOptions.currentPlatform;
  }

  // Inicializa o Firebase com as opções corretas.
  await Firebase.initializeApp(
    options: options,
  );

  // 4. Executa o aplicativo usando o widget BjjApp importado de app_theme.dart.
  runApp(const BjjApp());
}
