// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 1. IMPORTE O PACOTE DE SERVIÇOS
import 'package:firebase_core/firebase_core.dart';
import 'app_theme.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

const flavor = String.fromEnvironment('FLAVOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Habilita o modo Edge-to-Edge para uma UI mais imersiva
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Deixa as barras de navegação e de status transparentes para que o fundo do app apareça
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor:
        Colors.transparent, // Cor da barra de navegação (inferior)
    statusBarColor: Colors.transparent, // Cor da barra de status (superior)
    statusBarIconBrightness: Brightness
        .light, // Ícones da barra de status (relógio, bateria) em branco/claro
    systemNavigationBarIconBrightness: Brightness
        .light, // Ícones da barra de navegação (botões) em branco/claro
  ));

  FirebaseOptions options;
  if (flavor == 'prod') {
    options = prod.DefaultFirebaseOptions.currentPlatform;
  } else {
    options = dev.DefaultFirebaseOptions.currentPlatform;
  }

  await Firebase.initializeApp(
    options: options,
  );

  runApp(
    const BjjApp(),
  );
}
