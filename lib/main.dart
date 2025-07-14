// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app_theme.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

const flavor = String.fromEnvironment('FLAVOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
