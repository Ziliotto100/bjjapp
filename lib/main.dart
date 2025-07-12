import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
// Certifique-se que esses arquivos existem ou comente-os se não estiver usando flavors
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

// --- NOVOS IMPORTS PARA O CADERNO DE ESTUDOS ---
import 'study_note_service.dart';
import 'study_notebook_page.dart';

// Nova constante para definir o Flavor
const flavor = String.fromEnvironment('FLAVOR');

// AppBackground, BjjApp (Tema) e showBjjSnackBar (sem alterações)
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage("assets/images/planofundo.png"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.65),
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}

class BjjApp extends StatelessWidget {
  static const Color darkScaffoldBackground = Color(0xFF0A0F14);
  static const Color darkSurface = Color(0xFF10181F);
  static const Color primaryAccent = Color(0xFFD4AF37);
  static const Color primaryAccentForeground = Colors.black;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textHint = Color(0xFFB0B0B0);
  static const Color borderNormal = Color(0xFF37474F);
  static const Color borderFocused = primaryAccent;
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color infoColor = Color(0xFF54A0FF);

  const BjjApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Match BJJ',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: darkSurface,
          scaffoldBackgroundColor: Colors.transparent,
          cardColor: darkSurface.withOpacity(0.85),
          canvasColor: darkScaffoldBackground,
          colorScheme: const ColorScheme.dark(
            primary: primaryAccent,
            secondary: primaryAccent,
            surface: darkSurface,
            error: errorColor,
            onPrimary: primaryAccentForeground,
            onSecondary: primaryAccentForeground,
            onSurface: textPrimary,
            onError: Colors.white,
          ),
          hintColor: textHint,
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
            bodyLarge: TextStyle(color: textSecondary, fontSize: 16),
            bodySmall: TextStyle(color: textSecondary, fontSize: 12),
            headlineSmall: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
            titleLarge: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
            titleMedium: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w500, fontSize: 18),
            titleSmall: TextStyle(color: textPrimary, fontSize: 16),
            labelLarge: TextStyle(
                color: primaryAccentForeground,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ).apply(fontFamily: 'Roboto'),
          appBarTheme: const AppBarTheme(
            backgroundColor: darkSurface,
            elevation: 2.0,
            titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            iconTheme: IconThemeData(color: textPrimary),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: darkSurface,
            selectedItemColor: primaryAccent,
            unselectedItemColor: textHint,
            elevation: 4.0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
              foregroundColor: primaryAccentForeground,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: primaryAccent,
            foregroundColor: primaryAccentForeground,
            elevation: 4.0,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            titleTextStyle: const TextStyle(
                color: textPrimary,
                fontSize: 19.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            contentTextStyle: const TextStyle(
                color: textSecondary, fontSize: 15, fontFamily: 'Roboto'),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: const TextStyle(color: textHint),
            hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
            filled: true,
            fillColor: darkScaffoldBackground.withOpacity(0.5),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: borderNormal)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: borderNormal)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: borderFocused, width: 2.0)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: errorColor, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(color: errorColor, width: 2.0)),
            errorStyle:
                const TextStyle(color: errorColor, fontWeight: FontWeight.w500),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: const TextStyle(color: textHint),
              hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
              filled: true,
              fillColor: darkScaffoldBackground.withOpacity(0.5),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: borderNormal)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: borderNormal)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: borderFocused, width: 2.0)),
            ),
            menuStyle: MenuStyle(
              backgroundColor: const WidgetStatePropertyAll(darkSurface),
              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
              elevation: const WidgetStatePropertyAll(3.0),
            ),
            textStyle: const TextStyle(color: textSecondary, fontFamily: 'Roboto'),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            textStyle: const TextStyle(color: textSecondary, fontFamily: 'Roboto'),
            elevation: 4.0,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? primaryAccent
                    : textHint.withOpacity(0.2)),
            checkColor: WidgetStateProperty.all(primaryAccentForeground),
            side: BorderSide(color: textHint.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: primaryAccent,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          ),
          cardTheme: CardThemeData(
            color: darkSurface.withOpacity(0.85),
            elevation: 2.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: SegmentedButton.styleFrom(
              backgroundColor: darkSurface,
              foregroundColor: textSecondary,
              selectedForegroundColor: primaryAccentForeground,
              selectedBackgroundColor: primaryAccent,
            ),
          )),
      home: const AuthGate(),
    );
  }
}

void showBjjSnackBar(BuildContext context, String message,
    {String type = 'info'}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  Color backgroundColor;
  IconData icon;
  switch (type) {
    case 'success':
      backgroundColor = BjjApp.successColor;
      icon = Icons.check_circle_outline_rounded;
      break;
    case 'warning':
      backgroundColor = BjjApp.warningColor;
      icon = Icons.warning_amber_rounded;
      break;
    case 'error':
      backgroundColor = BjjApp.errorColor;
      icon = Icons.error_outline_rounded;
      break;
    default:
      backgroundColor = BjjApp.infoColor;
      icon = Icons.info_outline_rounded;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(icon, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(
          child: Text(message,
              style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
    ]),
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    elevation: 4.0,
    duration: const Duration(seconds: 4),
  ));
}

// --- TELAS DE AUTENTICAÇÃO ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'E-mail ou senha incorretos.';
      }
      if (mounted) {
        showBjjSnackBar(context, message, type: 'error');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado.', type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Match BJJ',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: BjjApp.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 38)),
                  const SizedBox(height: 8),
                  const Text('Faça o login para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BjjApp.textHint, fontSize: 16)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                            ? 'Por favor, insira um e-mail válido.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline_rounded)),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6)
                        ? 'A senha deve ter pelo menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('ENTRAR'),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const RegisterAcademyPage(),
                      ));
                    },
                    child: const Text('Não tem uma conta? Cadastre sua academia',
                        style: TextStyle(color: BjjApp.textHint)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterAcademyPage extends StatefulWidget {
  const RegisterAcademyPage({super.key});
  @override
  _RegisterAcademyPageState createState() => _RegisterAcademyPageState();
}

class _RegisterAcademyPageState extends State<RegisterAcademyPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _academyNameController = TextEditingController();
  final _managerNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _faixa;
  int? _graus;
  final List<String> _faixasList = ['Azul', 'Roxa', 'Marrom', 'Preta'];
  List<int> _grausList = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _academyNameController.dispose();
    _managerNameController.dispose();
    super.dispose();
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final newUser = userCredential.user;
      if (newUser == null) {
        throw Exception("Não foi possível criar o usuário.");
      }

      final firestore = FirebaseFirestore.instance;
      final academyRef = firestore.collection('academies').doc();
      final userRef = firestore.collection('users').doc(newUser.uid);
      final batch = firestore.batch();

      batch.set(academyRef, {
        'name': _academyNameController.text.trim(),
        'plan': 'premium',
        'ownerId': newUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.set(userRef, {
        'name': _managerNameController.text.trim(),
        'email': newUser.email,
        'academyId': academyRef.id,
        'role': 'manager',
        'faixa': _faixa,
        'graus': _graus,
        'peso': null, // Gerente pode preencher depois
        'createdAt': FieldValue.serverTimestamp(),
        'mustChangePassword': false,
        'isActive': true,
      });

      await batch.commit();

      if (mounted) {
        showBjjSnackBar(
            context, 'Academia registrada com sucesso! Faça o login.',
            type: 'success');
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro no registro.';
      if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está em uso.';
      } else if (e.code == 'weak-password') {
        message = 'A senha é muito fraca.';
      }
      if (mounted) {
        showBjjSnackBar(context, message, type: 'error');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Academia"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dados da Academia',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _academyNameController,
                    decoration: const InputDecoration(
                        labelText: 'Nome da Academia',
                        prefixIcon: Icon(Icons.business_rounded)),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Por favor, insira o nome da academia.'
                            : null,
                  ),
                  const SizedBox(height: 24),
                  Text('Seus Dados de Gerente',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _managerNameController,
                    decoration: const InputDecoration(
                        labelText: 'Seu Nome Completo',
                        prefixIcon: Icon(Icons.person_rounded)),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Por favor, insira o seu nome.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _faixa,
                    decoration: const InputDecoration(
                        labelText: 'Sua Faixa',
                        prefixIcon: Icon(Icons.shield_outlined)),
                    hint: const Text("Selecione sua Faixa"),
                    items: _faixasList
                        .map((faixa) =>
                            DropdownMenuItem(value: faixa, child: Text(faixa)))
                        .toList(),
                    onChanged: (value) => setState(() {
                      _faixa = value;
                      _grausList = _getGrausForFaixa(_faixa);
                      _graus = null;
                    }),
                    validator: (value) =>
                        value == null ? 'Selecione sua faixa' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_faixa != null)
                    DropdownButtonFormField<int>(
                      value: _graus,
                      decoration: const InputDecoration(
                          labelText: 'Seus Graus (opcional)',
                          prefixIcon: Icon(Icons.star_outline_rounded)),
                      hint: const Text("Selecione seus Graus"),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text("Nenhum")),
                        ..._grausList.map((g) => DropdownMenuItem(
                            value: g, child: Text("$gº Grau"))),
                      ],
                      onChanged: (value) => setState(() => _graus = value),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        labelText: 'Seu E-mail',
                        prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                            ? 'Por favor, insira um e-mail válido.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                        labelText: 'Sua Senha',
                        prefixIcon: Icon(Icons.lock_outline_rounded)),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6)
                        ? 'A senha deve ter pelo menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('CADASTRAR E CRIAR ACADEMIA'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: AppBackground(
                  child: Center(child: CircularProgressIndicator())));
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginPage();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(authSnapshot.data!.uid)
              .get(),
          builder: (context, userDocSnapshot) {
            if (userDocSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: AppBackground(
                      child: Center(child: CircularProgressIndicator())));
            }

            if (userDocSnapshot.hasError ||
                !userDocSnapshot.hasData ||
                !userDocSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            final userModel = UserModel.fromFirestore(userDocSnapshot.data!);

            if (userModel.mustChangePassword) {
              return const ChangePasswordPage(isFirstLogin: true);
            }

            if (userModel.role == UserRole.student &&
                userModel.studentRecordId == null) {
              // Redireciona para a home do aluno, que mostrará a tela de perfil.
              return StudentHomePage(user: userModel);
            }

            switch (userModel.role) {
              case UserRole.manager:
                return ManagerHomePage(user: userModel);
              case UserRole.teacher:
                return TeacherHomePage(user: userModel);
              case UserRole.student:
                return StudentHomePage(user: userModel);
              default:
                FirebaseAuth.instance.signOut();
                return const LoginPage();
            }
          },
        );
      },
    );
  }
}

// --- WIDGETS GENÉRICOS ---
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BjjApp.textHint.withOpacity(0.5), size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: BjjApp.textPrimary.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BjjApp.textHint.withOpacity(0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final UserModel user;
  const SettingsPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurações"),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(8.0),
          children: [
            if (user.role == UserRole.student ||
                user.role == UserRole.teacher ||
                user.role == UserRole.manager)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text("Editar Meu Perfil"),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    if (user.role == UserRole.student) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EditStudentProfilePage(user: user),
                      ));
                    } else {
                      // Para Manager ou Teacher
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => EditUserProfilePage(user: user),
                      ));
                    }
                  },
                ),
              ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_reset_rounded),
                title: const Text("Alterar Senha"),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ChangePasswordPage(),
                  ));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA DE EDIÇÃO DE PERFIL PARA GERENTE E PROFESSOR ---
class EditUserProfilePage extends StatefulWidget {
  final UserModel user;
  const EditUserProfilePage({super.key, required this.user});

  @override
  State<EditUserProfilePage> createState() => _EditUserProfilePageState();
}

class _EditUserProfilePageState extends State<EditUserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  String? _faixa;
  int? _graus;
  bool _isSaving = false;

  final List<String> _faixasList = ['Azul', 'Roxa', 'Marrom', 'Preta'];
  List<int> _grausList = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name;
    _weightController.text = widget.user.peso?.toString() ?? '';
    _faixa = widget.user.faixa;
    _graus = widget.user.graus;
    _grausList = _getGrausForFaixa(_faixa);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

      await userRef.update({
        'name': _nameController.text.trim(),
        'peso': double.tryParse(_weightController.text.replaceAll(',', '.')) ??
            widget.user.peso,
        'faixa': _faixa,
        'graus': _graus,
      });

      if (mounted) {
        showBjjSnackBar(context, "Perfil atualizado com sucesso!",
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao atualizar perfil: $e", type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar Perfil")),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nome Completo'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Nome não pode ser vazio'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Peso inválido';
                      final x = double.tryParse(v.replaceAll(',', '.'));
                      return (x == null || x <= 0)
                          ? 'Peso inválido (deve ser > 0)'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _faixa,
                    decoration: const InputDecoration(labelText: 'Faixa'),
                    items: _faixasList
                        .map((faixa) =>
                            DropdownMenuItem(value: faixa, child: Text(faixa)))
                        .toList(),
                    onChanged: (value) => setState(() {
                      _faixa = value;
                      _grausList = _getGrausForFaixa(_faixa);
                      _graus = null;
                    }),
                    validator: (value) =>
                        value == null ? 'Selecione sua faixa' : null,
                  ),
                  if (_faixa != null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _graus,
                      decoration:
                          const InputDecoration(labelText: 'Graus (opcional)'),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text("Nenhum")),
                        ..._grausList.map((g) => DropdownMenuItem(
                            value: g, child: Text("$gº Grau"))),
                      ],
                      onChanged: (value) => setState(() => _graus = value),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: _updateProfile,
                          icon: const Icon(Icons.save),
                          label: const Text("Salvar Alterações"),
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16)),
                        ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- TELAS DO GERENTE ---
class ManagerHomePage extends StatefulWidget {
  final UserModel user;
  const ManagerHomePage({super.key, required this.user});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  int _paginaAtual = 0;
  late final List<Widget> _telas;
  final List<String> _titulos = const [
    'Painel Principal',
    'Gerenciar Alunos',
    'Gerenciar Professores',
    'Mensalidades'
  ];

  @override
  void initState() {
    super.initState();
    _telas = [
      ManagerDashboardPage(user: widget.user),
      AlunosManagerPage(academyId: widget.user.academyId),
      ProfessoresManagerPage(academyId: widget.user.academyId),
      MonthlyFeeManagerPage(academyId: widget.user.academyId),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _paginaAtual = index;
    });
  }

  void _onAdicionarAluno() {
    showDialog(
      context: context,
      builder: (_) =>
          AdicionarAlunoDialog(onAlunoAdicionado: (novoAluno) async {
        try {
          await FirebaseFirestore.instance
              .collection('academies')
              .doc(widget.user.academyId)
              .collection('students')
              .add(novoAluno.toJson());

          if (mounted) {
            showBjjSnackBar(
                context, '${novoAluno.nome} adicionado com sucesso!',
                type: 'success');
          }
        } catch (e) {
          if (mounted) {
            showBjjSnackBar(context, 'Erro ao adicionar aluno: $e',
                type: 'error');
          }
        }
      }),
    );
  }

  void _onAdicionarProfessor() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => AdicionarProfessorDialog(
        academyId: widget.user.academyId,
      ),
    );

    if (result != null && mounted) {
      final name = result['name']!;
      final email = result['email']!;
      final temporaryPassword = result['password']!;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Professor Criado!"),
          content: SelectableText(
              "A conta para $name foi criada.\n\nE-mail: $email\nSenha Temporária: $temporaryPassword\n\nPeça para que ele(a) faça o login e altere a senha."),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text("OK"))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_paginaAtual]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsPage(user: widget.user)))),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: IndexedStack(index: _paginaAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Alunos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: 'Professores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_rounded),
            label: 'Mensalidades',
          ),
        ],
      ),
      floatingActionButton: _paginaAtual == 1
          ? FloatingActionButton(
              onPressed: _onAdicionarAluno,
              tooltip: 'Adicionar Aluno',
              child: const Icon(Icons.add_rounded),
            )
          : _paginaAtual == 2
              ? FloatingActionButton(
                  onPressed: _onAdicionarProfessor,
                  tooltip: 'Adicionar Professor',
                  child: const Icon(Icons.add_rounded),
                )
              : null,
    );
  }
}

class ManagerDashboardPage extends StatelessWidget {
  final UserModel user;
  const ManagerDashboardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.manage_accounts, size: 80, color: BjjApp.primaryAccent),
            const SizedBox(height: 20),
            Text('Bem-vindo, ${user.name}!',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text('ID da sua Academia: ${user.academyId}',
                style: const TextStyle(color: BjjApp.textHint)),
          ],
        ),
      ),
    );
  }
}

class AlunosManagerPage extends StatefulWidget {
  final String academyId;
  const AlunosManagerPage({super.key, required this.academyId});

  @override
  State<AlunosManagerPage> createState() => _AlunosManagerPageState();
}

class _AlunosManagerPageState extends State<AlunosManagerPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteAluno(Aluno aluno) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final studentDocRef = firestore
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .doc(aluno.id);
      batch.delete(studentDocRef);

      if (aluno.userId != null) {
        final userDocRef = firestore.collection('users').doc(aluno.userId);
        batch.delete(userDocRef);
      }
      await batch.commit();

      if (mounted) {
        showBjjSnackBar(context, 'Aluno ${aluno.nome} excluído com sucesso.',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao excluir aluno: $e', type: 'error');
      }
    }
  }

  void _confirmDeleteAluno(Aluno aluno) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente o aluno ${aluno.nome}? Esta ação removerá o aluno da lista e também seu acesso de login, caso exista. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BjjApp.errorColor,
                foregroundColor: Colors.white),
            child: const Text("Excluir"),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAluno(aluno);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateAccessDialog(Aluno aluno) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => CreateStudentAccessDialog(
        academyId: widget.academyId,
        aluno: aluno,
      ),
    );

    if (result?['success'] == true && mounted) {
      final email = result!['email'];
      const temporaryPassword = 'mudar123';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Acesso Criado!"),
          content: SelectableText(
              "A conta para ${aluno.nome} foi criada.\n\nE-mail: $email\nSenha Temporária: $temporaryPassword\n\nPeça para que ele(a) faça o login e altere a senha."),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text("OK"))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar aluno por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('academies')
                  .doc(widget.academyId)
                  .collection('students')
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erro: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.no_accounts_rounded,
                    title: 'Nenhum Aluno Cadastrado',
                    message:
                        'Clique no botão "+" para adicionar o primeiro aluno da sua academia.',
                  );
                }

                final allAlunos = snapshot.data!.docs.map((doc) {
                  return Aluno.fromJson(
                      doc.id, doc.data() as Map<String, dynamic>);
                }).toList();

                final filteredAlunos = allAlunos.where((aluno) {
                  return aluno.nome
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredAlunos.isEmpty && _searchQuery.isNotEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.person_search,
                    title: "Nenhum Aluno Encontrado",
                    message:
                        "Nenhum aluno corresponde à sua busca '$_searchQuery'.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                  itemCount: filteredAlunos.length,
                  itemBuilder: (context, index) {
                    final aluno = filteredAlunos[index];
                    return Card(
                      child: ListTile(
                        title: Text(aluno.nome,
                            style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text('${aluno.faixa} - ${aluno.peso}kg'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (aluno.userId == null)
                              TextButton(
                                child: const Text("Criar Acesso"),
                                onPressed: () => _showCreateAccessDialog(aluno),
                              )
                            else
                              const Tooltip(
                                message: "Acesso de aluno já criado",
                                child: Icon(Icons.check_circle,
                                    color: BjjApp.successColor),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: BjjApp.errorColor),
                              onPressed: () => _confirmDeleteAluno(aluno),
                              tooltip: 'Excluir Aluno',
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdicionarAlunoDialog extends StatefulWidget {
  final Function(Aluno) onAlunoAdicionado;
  final Aluno? alunoParaEditar; // Parâmetro opcional para edição
  const AdicionarAlunoDialog({super.key, required this.onAlunoAdicionado, this.alunoParaEditar});
  @override
  _AdicionarAlunoDialogState createState() => _AdicionarAlunoDialogState();
}

class _AdicionarAlunoDialogState extends State<AdicionarAlunoDialog> {
  final nC = TextEditingController(), pC = TextEditingController();
  String? fS;
  int? gS;
  final List<String> faixasList = [
    'Branca',
    'Cinza com Ponta Branca',
    'Cinza',
    'Cinza com Ponta Preta',
    'Amarela com Ponta Branca',
    'Amarela',
    'Amarela com Ponta Preta',
    'Laranja com Ponta Branca',
    'Laranja',
    'Laranja com Ponta Preta',
    'Verde com Ponta Branca',
    'Verde',
    'Verde com Ponta Preta',
    'Azul',
    'Roxa',
    'Marrom',
    'Preta'
  ];
  List<int> grausList = [];
  final formKey = GlobalKey<FormState>();

  bool get isEditing => widget.alunoParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final aluno = widget.alunoParaEditar!;
      nC.text = aluno.nome;
      pC.text = aluno.peso.toString();
      fS = aluno.faixa;
      gS = aluno.graus;
      grausList = _getGrausForFaixa(fS);
    }
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    bool mostrarGrausDropdown = fS != null;
    return AlertDialog(
      title: Text(isEditing ? 'Editar Aluno' : 'Adicionar Novo Aluno'),
      content: SingleChildScrollView(
          child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: nC,
                    decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_add_alt_1_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nome inválido'
                        : null),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: fS,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Faixa',
                        prefixIcon: Icon(Icons.shield_outlined)),
                    hint: const Text("Selecione a Faixa"),
                    onChanged: (v) => setState(() {
                          fS = v;
                          grausList = _getGrausForFaixa(fS);
                          gS = null;
                        }),
                    items: faixasList
                        .map((v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)))
                        .toList(),
                    validator: (v) => v == null ? 'Selecione uma faixa' : null),
                if (mostrarGrausDropdown) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                      value: gS,
                      decoration: const InputDecoration(
                          labelText: 'Graus (opcional)',
                          prefixIcon: Icon(Icons.star_outline_rounded)),
                      hint: const Text("Graus (opcional)"),
                      onChanged: (v) => setState(() => gS = v),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text("Nenhum")),
                        ...grausList.map((v) => DropdownMenuItem<int>(
                            value: v, child: Text('$vº Grau')))
                      ].toList())
                ],
                const SizedBox(height: 16),
                TextFormField(
                    controller: pC,
                    decoration: const InputDecoration(
                        labelText: 'Peso (kg)',
                        prefixIcon: Icon(Icons.fitness_center_rounded)),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Peso inválido';
                      final x = double.tryParse(v.replaceAll(',', '.'));
                      return (x == null || x <= 0)
                          ? 'Peso inválido (deve ser > 0)'
                          : null;
                    }),
              ]))),
      actions: [
        TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop()),
        ElevatedButton.icon(
            icon: Icon(
                isEditing ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
                size: 18),
            label: Text(isEditing ? 'Salvar' : 'Adicionar'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final double peso = double.parse(pC.text.replaceAll(',', '.'));
                // Se estiver editando, cria um Aluno com o ID existente.
                // Se não, cria um Aluno novo (ID será gerado pelo Firestore depois).
                final alunoResult = Aluno(
                  id: isEditing ? widget.alunoParaEditar!.id : '',
                  nome: nC.text.trim(),
                  faixa: fS!,
                  peso: peso,
                  graus: gS,
                  // Mantém o userId se já existir
                  userId: isEditing ? widget.alunoParaEditar!.userId : null,
                );

                widget.onAlunoAdicionado(alunoResult);
                Navigator.of(context).pop();
              }
            })
      ],
    );
  }
}

class CreateStudentAccessDialog extends StatefulWidget {
  final String academyId;
  final Aluno aluno;
  const CreateStudentAccessDialog(
      {super.key, required this.academyId, required this.aluno});

  @override
  State<CreateStudentAccessDialog> createState() =>
      _CreateStudentAccessDialogState();
}

class _CreateStudentAccessDialogState extends State<CreateStudentAccessDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _createAccess() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    const temporaryPassword = 'mudar123';
    final email = _emailController.text.trim();

    try {
      final tempApp = await Firebase.initializeApp(
        name: 'temp_student_creation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: temporaryPassword,
      );
      final newUser = userCredential.user;

      if (newUser == null) {
        await tempApp.delete();
        throw Exception("Falha ao criar la cuenta de autenticação.");
      }

      final batch = FirebaseFirestore.instance.batch();
      final studentRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .doc(widget.aluno.id);
      batch.update(studentRef, {'userId': newUser.uid});

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(newUser.uid);

      batch.set(userRef, {
        'name': widget.aluno.nome,
        'email': email,
        'academyId': widget.academyId,
        'role': 'student',
        'studentRecordId': widget.aluno.id,
        'createdAt': FieldValue.serverTimestamp(),
        'mustChangePassword': true,
        'isActive': true,
      });

      await batch.commit();
      await tempApp.delete();

      if (mounted) {
        Navigator.of(context).pop({'success': true, 'email': email});
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao criar acesso.';
      if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está sendo usado por outra conta.';
      }
      if (mounted) showBjjSnackBar(context, message, type: 'error');
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Criar Acesso para ${widget.aluno.nome}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'E-mail do Aluno (para login)',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _isLoading ? null : _createAccess,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Criar"),
        )
      ],
    );
  }
}

class ProfessoresManagerPage extends StatefulWidget {
  final String academyId;
  const ProfessoresManagerPage({super.key, required this.academyId});

  @override
  State<ProfessoresManagerPage> createState() => _ProfessoresManagerPageState();
}

class _ProfessoresManagerPageState extends State<ProfessoresManagerPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteProfessor(UserModel professor) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(professor.uid)
          .delete();

      if (mounted) {
        showBjjSnackBar(
            context, 'Professor ${professor.name} excluído com sucesso.',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao excluir professor: $e',
            type: 'error');
      }
    }
  }

  void _confirmDeleteProfessor(UserModel professor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente o professor ${professor.name}? Esta ação removerá seu acesso de login. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BjjApp.errorColor,
                foregroundColor: Colors.white),
            child: const Text("Excluir"),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteProfessor(professor);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar professor por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('academyId', isEqualTo: widget.academyId)
                  .where('role', isEqualTo: 'teacher')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erro: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.school_outlined,
                    title: 'Nenhum Professor Cadastrado',
                    message:
                        'Clique no botão "+" para adicionar o primeiro professor.',
                  );
                }

                final allProfessores = snapshot.data!.docs.map((doc) {
                  return UserModel.fromFirestore(doc);
                }).toList();

                final filteredProfessores = allProfessores.where((prof) {
                  return prof.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredProfessores.isEmpty && _searchQuery.isNotEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.person_search,
                    title: "Nenhum Professor Encontrado",
                    message:
                        "Nenhum professor corresponde à sua busca '$_searchQuery'.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                  itemCount: filteredProfessores.length,
                  itemBuilder: (context, index) {
                    final professor = filteredProfessores[index];
                    return Card(
                      child: ListTile(
                        leading:
                            const CircleAvatar(child: Icon(Icons.school_rounded)),
                        title: Text(professor.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(professor.email),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: BjjApp.errorColor),
                          onPressed: () => _confirmDeleteProfessor(professor),
                          tooltip: 'Excluir Professor',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdicionarProfessorDialog extends StatefulWidget {
  final String academyId;
  const AdicionarProfessorDialog({super.key, required this.academyId});

  @override
  State<AdicionarProfessorDialog> createState() =>
      _AdicionarProfessorDialogState();
}

class _AdicionarProfessorDialogState extends State<AdicionarProfessorDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _faixa;
  int? _graus;
  final List<String> _faixasList = ['Azul', 'Roxa', 'Marrom', 'Preta'];
  List<int> _grausList = [];

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    const temporaryPassword = 'mudar123';
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    try {
      final tempApp = await Firebase.initializeApp(
        name: 'temp_teacher_creation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: temporaryPassword,
      );
      final newUser = userCredential.user;

      if (newUser == null) {
        await tempApp.delete();
        throw Exception("Falha ao criar la cuenta de autenticação.");
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set({
        'name': name,
        'email': email,
        'academyId': widget.academyId,
        'role': 'teacher',
        'faixa': _faixa,
        'graus': _graus,
        'peso': null, // Professor pode preencher depois
        'createdAt': FieldValue.serverTimestamp(),
        'mustChangePassword': true,
        'isActive': true,
      });

      await tempApp.delete();

      if (mounted) {
        Navigator.of(context).pop({
          'name': name,
          'email': email,
          'password': temporaryPassword,
        });
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao criar professor.';
      if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está sendo usado por outra conta.';
      } else if (e.code == 'invalid-email') {
        message = 'O e-mail fornecido é inválido.';
      }
      if (mounted) showBjjSnackBar(context, message, type: 'error');
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Novo Professor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Professor',
                  prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail (para login)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _faixa,
                decoration: const InputDecoration(
                    labelText: 'Faixa',
                    prefixIcon: Icon(Icons.shield_outlined)),
                hint: const Text("Selecione a Faixa"),
                items: _faixasList
                    .map((faixa) =>
                        DropdownMenuItem(value: faixa, child: Text(faixa)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _faixa = value;
                  _grausList = _getGrausForFaixa(_faixa);
                  _graus = null;
                }),
                validator: (value) =>
                    value == null ? 'Selecione a faixa' : null,
              ),
              if (_faixa != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _graus,
                  decoration: const InputDecoration(
                      labelText: 'Graus (opcional)',
                      prefixIcon: Icon(Icons.star_outline_rounded)),
                  hint: const Text("Selecione os Graus"),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text("Nenhum")),
                    ..._grausList.map((g) =>
                        DropdownMenuItem(value: g, child: Text("$gº Grau"))),
                  ],
                  onChanged: (value) => setState(() => _graus = value),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Adicionar'),
        ),
      ],
    );
  }
}

// --- TELA DE MENSALIDADES (ATUALIZADA) ---
class MonthlyFeeManagerPage extends StatefulWidget {
  final String academyId;
  const MonthlyFeeManagerPage({super.key, required this.academyId});

  @override
  _MonthlyFeeManagerPageState createState() => _MonthlyFeeManagerPageState();
}

class _MonthlyFeeManagerPageState extends State<MonthlyFeeManagerPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Aluno> _allStudentsWithStatus = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentsWithPaymentStatus();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentsWithPaymentStatus() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final firestore = FirebaseFirestore.instance;

    final studentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('students')
        .orderBy('nome')
        .get();
    final students = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();

    final paymentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('paymentYear', isEqualTo: now.year)
        .where('paymentMonth', isEqualTo: now.month)
        .get();

    final paidStudentIds =
        paymentsSnapshot.docs.map((doc) => doc['studentId'] as String).toSet();

    for (var student in students) {
      if (paidStudentIds.contains(student.id)) {
        student.paymentStatus = PaymentStatus.pago;
      } else {
        // Regra de negócio: Vencimento dia 10
        student.paymentStatus =
            (now.day > 10) ? PaymentStatus.atrasado : PaymentStatus.pendente;
      }
    }

    if (mounted) {
      setState(() {
        _allStudentsWithStatus = students;
        _isLoading = false;
      });
    }
  }

  void _showAddPaymentDialog(Aluno student) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AddPaymentDialog(academyId: widget.academyId, student: student),
    );

    if (success == true) {
      showBjjSnackBar(context, "Pagamento registrado com sucesso!",
          type: 'success');
      _fetchStudentsWithPaymentStatus(); // Recarrega os dados
    }
  }

  void _navigateToHistory(Aluno student) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudentPaymentHistoryPage(
          academyId: widget.academyId, student: student),
    ));
  }

  Widget _buildStatusChip(PaymentStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case PaymentStatus.pago:
        color = BjjApp.successColor;
        label = "Em dia";
        icon = Icons.check_circle_rounded;
        break;
      case PaymentStatus.pendente:
        color = BjjApp.warningColor;
        label = "Pendente";
        icon = Icons.hourglass_empty_rounded;
        break;
      case PaymentStatus.atrasado:
        color = BjjApp.errorColor;
        label = "Atrasado";
        icon = Icons.error_rounded;
        break;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _allStudentsWithStatus.where((student) {
      return student.nome.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return AppBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar aluno por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allStudentsWithStatus.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.no_accounts_rounded,
                        title: 'Nenhum Aluno Cadastrado',
                        message: 'Adicione alunos na aba "Gerenciar Alunos".',
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchStudentsWithPaymentStatus,
                        child: filteredStudents.isEmpty &&
                                _searchQuery.isNotEmpty
                            ? EmptyStateWidget(
                                icon: Icons.person_search,
                                title: "Nenhum Aluno Encontrado",
                                message:
                                    "Nenhum aluno corresponde à sua busca '$_searchQuery'.",
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    8.0, 8.0, 8.0, 80.0),
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) {
                                  final student = filteredStudents[index];
                                  final bool isPaid = student.paymentStatus ==
                                      PaymentStatus.pago;
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(student.nome,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          const Divider(
                                              height: 16,
                                              color: BjjApp.borderNormal),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildStatusChip(
                                                  student.paymentStatus),
                                              Row(
                                                children: [
                                                  if (!isPaid)
                                                    TextButton.icon(
                                                      icon: const Icon(Icons.payment,
                                                          size: 20),
                                                      label: const Text("Registrar"),
                                                      onPressed: () =>
                                                          _showAddPaymentDialog(
                                                              student),
                                                    ),
                                                  TextButton.icon(
                                                    icon: const Icon(Icons.history,
                                                        size: 20,
                                                        color: BjjApp.textHint),
                                                    label: const Text("Histórico",
                                                        style: TextStyle(
                                                            color: BjjApp
                                                                .textHint)),
                                                    onPressed: () =>
                                                        _navigateToHistory(
                                                            student),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

// --- NOVA TELA DE HISTÓRICO DE PAGAMENTOS ---
class StudentPaymentHistoryPage extends StatefulWidget {
  final String academyId;
  final Aluno student;
  const StudentPaymentHistoryPage(
      {super.key, required this.academyId, required this.student});

  @override
  _StudentPaymentHistoryPageState createState() =>
      _StudentPaymentHistoryPageState();
}

class _StudentPaymentHistoryPageState extends State<StudentPaymentHistoryPage> {
  late Future<Map<int, List<MonthlyFee>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchPaymentHistory();
  }

  Future<Map<int, List<MonthlyFee>>> _fetchPaymentHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('paymentDate', descending: true)
        .get();

    final payments =
        snapshot.docs.map((doc) => MonthlyFee.fromFirestore(doc)).toList();

    // Agrupa por ano
    final Map<int, List<MonthlyFee>> groupedByYear = {};
    for (var payment in payments) {
      groupedByYear.putIfAbsent(payment.paymentYear, () => []).add(payment);
    }
    return groupedByYear;
  }

  String _getMonthName(int month) {
    // Usando DateFormat para obter o nome do mês formatado em português.
    // Cria uma data qualquer com o mês desejado.
    return DateFormat.MMMM('pt_BR').format(DateTime(0, month)).capitalize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Histórico de ${widget.student.nome}"),
      ),
      body: AppBackground(
        child: FutureBuilder<Map<int, List<MonthlyFee>>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erro: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_long_rounded,
                title: 'Nenhum Pagamento Registrado',
                message:
                    'Este aluno ainda não possui um histórico de pagamentos.',
              );
            }

            final history = snapshot.data!;
            final years = history.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: years.length,
              itemBuilder: (context, index) {
                final year = years[index];
                final paymentsForYear = history[year]!;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: ExpansionTile(
                    initiallyExpanded: year == DateTime.now().year,
                    title: Text(year.toString(),
                        style: Theme.of(context).textTheme.titleLarge),
                    children: paymentsForYear.map((payment) {
                      return ListTile(
                        leading: const Icon(Icons.check_circle,
                            color: BjjApp.successColor),
                        title: Text(_getMonthName(payment.paymentMonth)),
                        subtitle: Text(
                            'Pago em: ${DateFormat.yMd('pt_BR').format(payment.paymentDate)} - ${payment.paymentMethod}'),
                        trailing: Text(
                          'R\$ ${payment.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: BjjApp.textPrimary,
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// Extensão para capitalizar a primeira letra
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// --- DIÁLOGO PARA ADICIONAR PAGAMENTO ---
class AddPaymentDialog extends StatefulWidget {
  final String academyId;
  final Aluno student;

  const AddPaymentDialog(
      {super.key, required this.academyId, required this.student});

  @override
  _AddPaymentDialogState createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _paymentMethod;
  bool _isLoading = false;

  final List<String> _paymentMethods = [
    'Dinheiro',
    'Pix',
    'Cartão de Débito',
    'Cartão de Crédito'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final newPayment = MonthlyFee(
      id: '', // será gerado pelo firestore
      studentId: widget.student.id,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      paymentDate: now,
      paymentMethod: _paymentMethod!,
      paymentYear: now.year,
      paymentMonth: now.month,
    );

    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('monthly_fees')
          .add(newPayment.toMap());

      if (mounted) {
        Navigator.of(context).pop(true); // Retorna sucesso
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao registrar pagamento: $e",
            type: 'error');
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Registrar Pagamento para ${widget.student.nome}"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Valor inválido';
                  final x = double.tryParse(v.replaceAll(',', '.'));
                  return (x == null || x <= 0)
                      ? 'O valor deve ser positivo'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Método de Pagamento',
                  prefixIcon: Icon(Icons.payment_rounded),
                ),
                hint: const Text("Selecione o método"),
                items: _paymentMethods
                    .map((method) =>
                        DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) => setState(() => _paymentMethod = value),
                validator: (v) => v == null ? 'Selecione um método' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPayment,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Confirmar"),
        ),
      ],
    );
  }
}

// --- TELAS DO PROFESSOR ---
class TeacherHomePage extends StatefulWidget {
  final UserModel user;
  const TeacherHomePage({super.key, required this.user});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _paginaAtual = 0;
  List<Widget> _telas = [];
  bool _isLoadingAlunos = true;
  List<Aluno> _todosParticipantesDaAcademia = [];
  Map<String, dynamic> _sparringState = {};
  StreamSubscription? _sparringStateSubscription;
  bool get _isSparringMode => _sparringState['isSparringMode'] ?? false;

  final List<String> _titulos = const [
    'Painel do Professor',
    'Gerenciar Alunos',
    'Check-in',
    'Sorteio',
    'Caderno de Estudos', // NOVO
    'Placar'
  ];

  @override
  void initState() {
    super.initState();
    _fetchParticipantsAndBuildScreens();
    _listenToSparringState();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchParticipantsAndBuildScreens() async {
    if (!mounted) return;
    setState(() => _isLoadingAlunos = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;

      // Fetch students
      final studentsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .orderBy('nome') // Ordenação aqui
          .get();
      final studentParticipants = studentsSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      // Fetch ONLY teachers (NOT managers)
      final usersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', isEqualTo: 'teacher')
          .get();
      final userParticipants = usersSnapshot.docs
          .map((doc) => Aluno.fromUserModel(UserModel.fromFirestore(doc)))
          .toList();

      // Combine and sort
      final allParticipants = [...studentParticipants, ...userParticipants];
      allParticipants.sort((a, b) => a.nome.compareTo(b.nome));

      if (mounted) {
        _todosParticipantesDaAcademia = allParticipants;
        _buildScreens();
        setState(() => _isLoadingAlunos = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAlunos = false);
        showBjjSnackBar(context, 'Erro ao carregar lista de participantes.',
            type: 'error');
        _buildScreens();
      }
    }
  }

  void _buildScreens() {
    _telas = [
      TeacherDashboardPage(
        user: widget.user,
        isSparringMode: _isSparringMode,
        onNavigateToSparring: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SparringTeacherPage(
                  academyId: widget.user.academyId,
                  todosAlunos: _todosParticipantesDaAcademia)));
        },
      ),
      AlunosTeacherPage(academyId: widget.user.academyId),
      CheckinTeacherPage(
          academyId: widget.user.academyId,
          todosParticipantesDaAcademia: _todosParticipantesDaAcademia),
      SorteioTeacherPage(
          academyId: widget.user.academyId,
          todosParticipantesDaAcademia: _todosParticipantesDaAcademia,
          isSparringMode: _isSparringMode,
          onIniciarSparring: _startSparring,
          onCheckinAlunos: _checkinStudents),
      // MODIFICADO: Passa o userId para a tela de estudos
      StudyNotebookPage(userId: widget.user.uid),
      MatchSetupPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosParticipantesDaAcademia),
    ];
  }

  void _listenToSparringState() {
    _sparringStateSubscription = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('state')
        .doc('sparring')
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _sparringState = doc.exists ? doc.data()! : {};
          _buildScreens();
        });
      }
    });
  }

  Future<void> _startSparring(List<List<String>> rounds, String generationType,
      List<Aluno> participants) async {
    final newState = {
      'isSparringMode': true,
      'currentRoundIndex': 1,
      'allRounds': rounds.map((round) => {'fights': round}).toList(),
      'generationType': generationType,
      'participantIds': participants.map((p) => p.id).toList(),
    };
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('state')
        .doc('sparring')
        .set(newState);

    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SparringTeacherPage(
            academyId: widget.user.academyId,
            todosAlunos: _todosParticipantesDaAcademia)));
  }

  Future<void> _checkinStudents(List<Aluno> studentsToCheckin) async {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('checkins');
    final batch = FirebaseFirestore.instance.batch();
    int count = 0;
    for (var student in studentsToCheckin) {
      batch.set(checkinRef.doc(), {
        'studentId': student.id,
        'date': Timestamp.fromDate(dateOnly),
      });
      count++;
    }
    await batch.commit();
    if (mounted) {
      showBjjSnackBar(context, '$count check-ins confirmados!',
          type: 'success');
    }
  }

  void _onAdicionarAluno() {
    showDialog(
      context: context,
      builder: (_) =>
          AdicionarAlunoDialog(onAlunoAdicionado: (novoAluno) async {
        try {
          await FirebaseFirestore.instance
              .collection('academies')
              .doc(widget.user.academyId)
              .collection('students')
              .add(novoAluno.toJson());

          if (mounted) {
            showBjjSnackBar(
                context, '${novoAluno.nome} adicionado com sucesso!',
                type: 'success');
            _fetchParticipantsAndBuildScreens(); // Recarrega a lista
          }
        } catch (e) {
          if (mounted) {
            showBjjSnackBar(context, 'Erro ao adicionar aluno: $e',
                type: 'error');
          }
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAlunos) {
      return const Scaffold(
          body:
              AppBackground(child: Center(child: CircularProgressIndicator())));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_paginaAtual]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsPage(user: widget.user)))),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: IndexedStack(index: _paginaAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (index) => setState(() => _paginaAtual = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Alunos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline_rounded),
            label: 'Check-in',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shuffle_rounded),
            label: 'Sorteio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_rounded), // NOVO
            label: 'Estudos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.scoreboard_rounded),
            label: 'Placar',
          ),
        ],
      ),
      floatingActionButton: _paginaAtual == 1 // Aba Alunos
          ? FloatingActionButton(
              onPressed: _onAdicionarAluno,
              tooltip: 'Adicionar Aluno',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class AlunosTeacherPage extends StatefulWidget {
  final String academyId;
  const AlunosTeacherPage({super.key, required this.academyId});

  @override
  State<AlunosTeacherPage> createState() => _AlunosTeacherPageState();
}

class _AlunosTeacherPageState extends State<AlunosTeacherPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editAluno(Aluno aluno) {
    showDialog(
      context: context,
      builder: (_) => AdicionarAlunoDialog(
        alunoParaEditar: aluno,
        onAlunoAdicionado: (alunoEditado) async {
          try {
            await FirebaseFirestore.instance
                .collection('academies')
                .doc(widget.academyId)
                .collection('students')
                .doc(alunoEditado.id)
                .update(alunoEditado.toJson());
            if (mounted) {
              showBjjSnackBar(
                  context, '${alunoEditado.nome} atualizado com sucesso!',
                  type: 'success');
            }
          } catch (e) {
            if (mounted) {
              showBjjSnackBar(context, 'Erro ao atualizar aluno: $e',
                  type: 'error');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar aluno por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('academies')
                  .doc(widget.academyId)
                  .collection('students')
                  .orderBy('nome')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Erro: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.no_accounts_rounded,
                    title: 'Nenhum Aluno Cadastrado',
                    message:
                        'Clique no botão "+" para adicionar o primeiro aluno da sua academia.',
                  );
                }

                final allAlunos = snapshot.data!.docs.map((doc) {
                  return Aluno.fromJson(
                      doc.id, doc.data() as Map<String, dynamic>);
                }).toList();

                final filteredAlunos = allAlunos.where((aluno) {
                  return aluno.nome
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredAlunos.isEmpty && _searchQuery.isNotEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.person_search,
                    title: "Nenhum Aluno Encontrado",
                    message:
                        "Nenhum aluno corresponde à sua busca '$_searchQuery'.",
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                  itemCount: filteredAlunos.length,
                  itemBuilder: (context, index) {
                    final aluno = filteredAlunos[index];
                    return Card(
                      child: ListTile(
                        title: Text(aluno.nome,
                            style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(
                            '${aluno.faixa}${aluno.graus != null ? ' - ${aluno.graus}º' : ''} - ${aluno.peso}kg'),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: BjjApp.primaryAccent),
                          onPressed: () => _editAluno(aluno),
                          tooltip: 'Editar Aluno',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TeacherDashboardPage extends StatelessWidget {
  final UserModel user;
  final bool isSparringMode;
  final VoidCallback onNavigateToSparring;

  const TeacherDashboardPage(
      {super.key,
      required this.user,
      required this.isSparringMode,
      required this.onNavigateToSparring});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bem-vindo, Prof. ${user.name}!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 32),
              if (isSparringMode)
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: BjjApp.primaryAccent, width: 2),
                  ),
                  child: InkWell(
                    onTap: onNavigateToSparring,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.sports_kabaddi_rounded,
                              color: BjjApp.primaryAccent, size: 30),
                          const SizedBox(width: 16),
                          Text("Ver Treino em Andamento",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: BjjApp.primaryAccent)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                const Text(
                  'Use a barra de navegação para gerenciar suas aulas.',
                  style: TextStyle(color: BjjApp.textHint, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckinTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;
  const CheckinTeacherPage(
      {super.key,
      required this.academyId,
      required this.todosParticipantesDaAcademia});

  @override
  State<CheckinTeacherPage> createState() => _CheckinTeacherPageState();
}

class _CheckinTeacherPageState extends State<CheckinTeacherPage> {
  void _navigateToBulkCheckin() async {
    final checkedInCount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => BulkCheckinPage(
          academyId: widget.academyId,
          todosParticipantesDaAcademia: widget.todosParticipantesDaAcademia,
        ),
      ),
    );

    if (checkedInCount != null && checkedInCount > 0 && mounted) {
      showBjjSnackBar(context, '$checkedInCount presenças confirmadas!',
          type: 'success');
    }
  }

  void _navigateToRetroactiveCheckin() async {
    final checkedInCount = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RetroactiveCheckinPage(
          academyId: widget.academyId,
          todosParticipantesDaAcademia: widget.todosParticipantesDaAcademia,
        ),
      ),
    );

    if (checkedInCount != null && mounted) {
      if (checkedInCount > 0) {
        showBjjSnackBar(
            context, '$checkedInCount presenças retroativas confirmadas!',
            type: 'success');
      } else {
        showBjjSnackBar(context, 'Nenhuma presença nova foi registrada.',
            type: 'info');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              leading: const Icon(Icons.checklist_rtl_rounded,
                  color: BjjApp.primaryAccent, size: 40),
              title: Text("Fazer Chamada da Turma",
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text("Registre a presença de hoje."),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, color: BjjApp.textHint),
              onTap: _navigateToBulkCheckin,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              leading: const Icon(Icons.edit_calendar_rounded,
                  color: BjjApp.warningColor, size: 40),
              title: Text("Lançar Check-in Retroativo",
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text("Registre uma presença de um dia anterior."),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, color: BjjApp.textHint),
              onTap: _navigateToRetroactiveCheckin,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              leading: const Icon(Icons.leaderboard_rounded,
                  color: BjjApp.infoColor, size: 40),
              title: Text("Ver Ranking de Presença",
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: const Text("Acompanhe a frequência dos participantes."),
              trailing:
                  const Icon(Icons.arrow_forward_ios_rounded, color: BjjApp.textHint),
              onTap: () {
                if (widget.todosParticipantesDaAcademia.isEmpty) {
                  showBjjSnackBar(context, 'Cadastre participantes primeiro.',
                      type: 'info');
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RankingTeacherPage(academyId: widget.academyId),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BulkCheckinPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;

  const BulkCheckinPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
  });

  @override
  _BulkCheckinPageState createState() => _BulkCheckinPageState();
}

class _BulkCheckinPageState extends State<BulkCheckinPage> {
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];

  @override
  void initState() {
    super.initState();
    _filteredParticipants = widget.todosParticipantesDaAcademia;
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterParticipants);
    _searchController.dispose();
    super.dispose();
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.todosParticipantesDaAcademia.where((aluno) {
        return aluno.nome.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _saveBulkCheckin() async {
    if (_selectedStudentIds.isEmpty) {
      showBjjSnackBar(context, 'Nenhum participante selecionado.',
          type: 'warning');
      return;
    }
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins');

    try {
      final querySnapshot = await checkinRef
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .where('studentId', whereIn: _selectedStudentIds.toList())
          .get();
      final alreadyCheckedInIds =
          querySnapshot.docs.map((doc) => doc['studentId'] as String).toSet();
      final batch = FirebaseFirestore.instance.batch();
      int newCheckinsCount = 0;
      for (final studentId in _selectedStudentIds) {
        if (!alreadyCheckedInIds.contains(studentId)) {
          final newDoc = checkinRef.doc();
          batch.set(newDoc, {
            'studentId': studentId,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
          });
          newCheckinsCount++;
        }
      }

      if (newCheckinsCount > 0) {
        await batch.commit();
      }
      if (mounted) {
        Navigator.of(context).pop(newCheckinsCount);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar presenças: $e', type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chamada da Turma"),
      ),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar por nome...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: _filteredParticipants.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.person_off,
                      title: "Nenhum Participante Encontrado",
                      message: _searchController.text.isNotEmpty
                          ? "Verifique o nome digitado."
                          : "Adicione alunos ou professores para fazer a chamada.",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                      itemCount: _filteredParticipants.length,
                      itemBuilder: (context, index) {
                        final aluno = _filteredParticipants[index];
                        final isSelected =
                            _selectedStudentIds.contains(aluno.id);
                        return Card(
                          child: CheckboxListTile(
                            title: Text(aluno.nome),
                            subtitle: Text(aluno.faixa),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedStudentIds.add(aluno.id);
                                } else {
                                  _selectedStudentIds.remove(aluno.id);
                                }
                              });
                            },
                            secondary: const Icon(Icons.person_outline),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isLoading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(
                  color: BjjApp.primaryAccentForeground),
            )
          : FloatingActionButton.extended(
              onPressed: _saveBulkCheckin,
              label: Text("Confirmar (${_selectedStudentIds.length})"),
              icon: const Icon(Icons.check_circle_outline),
            ),
    );
  }
}

class RetroactiveCheckinPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;

  const RetroactiveCheckinPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
  });

  @override
  _RetroactiveCheckinPageState createState() => _RetroactiveCheckinPageState();
}

class _RetroactiveCheckinPageState extends State<RetroactiveCheckinPage> {
  final Set<String> _selectedStudentIds = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];

  @override
  void initState() {
    super.initState();
    _filteredParticipants = widget.todosParticipantesDaAcademia;
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterParticipants);
    _searchController.dispose();
    super.dispose();
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.todosParticipantesDaAcademia.where((aluno) {
        return aluno.nome.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveRetroactiveCheckin() async {
    if (_selectedStudentIds.isEmpty) {
      showBjjSnackBar(context, 'Nenhum participante selecionado.',
          type: 'warning');
      return;
    }

    setState(() => _isLoading = true);

    final dateOnly =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins');

    try {
      final querySnapshot = await checkinRef
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .where('studentId', whereIn: _selectedStudentIds.toList())
          .get();

      final alreadyCheckedInIds =
          querySnapshot.docs.map((doc) => doc['studentId'] as String).toSet();

      final batch = FirebaseFirestore.instance.batch();
      int newCheckinsCount = 0;

      for (final studentId in _selectedStudentIds) {
        if (!alreadyCheckedInIds.contains(studentId)) {
          final newDoc = checkinRef.doc();
          batch.set(newDoc, {
            'studentId': studentId,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
          });
          newCheckinsCount++;
        }
      }

      if (newCheckinsCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        Navigator.of(context).pop(newCheckinsCount);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar presenças: $e', type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Check-in Retroativo"),
      ),
      body: AppBackground(
        child: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: ListTile(
                leading:
                    const Icon(Icons.calendar_month, color: BjjApp.primaryAccent),
                title: const Text("Data do Check-in"),
                subtitle:
                    Text(DateFormat.yMMMMd('pt_BR').format(_selectedDate)),
                onTap: _pickDate,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar por nome...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: _filteredParticipants.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.person_search,
                      title: "Nenhum Participante Encontrado")
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                      itemCount: _filteredParticipants.length,
                      itemBuilder: (context, index) {
                        final aluno = _filteredParticipants[index];
                        final isSelected =
                            _selectedStudentIds.contains(aluno.id);
                        return Card(
                          child: CheckboxListTile(
                            title: Text(aluno.nome),
                            subtitle: Text(aluno.faixa),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedStudentIds.add(aluno.id);
                                } else {
                                  _selectedStudentIds.remove(aluno.id);
                                }
                              });
                            },
                            secondary: const Icon(Icons.person_outline),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isLoading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(
                  color: BjjApp.primaryAccentForeground),
            )
          : FloatingActionButton.extended(
              onPressed: _saveRetroactiveCheckin,
              label: Text("Confirmar (${_selectedStudentIds.length})"),
              icon: const Icon(Icons.check_circle_outline),
            ),
    );
  }
}

class RankingTeacherPage extends StatefulWidget {
  final String academyId;
  const RankingTeacherPage({super.key, required this.academyId});

  @override
  State<RankingTeacherPage> createState() => _RankingTeacherPageState();
}

class _RankingTeacherPageState extends State<RankingTeacherPage> {
  Map<String, int> _checkinCounts = {};
  List<Aluno> _todosParticipantes = [];
  bool _isLoading = true;
  String _filter = 'total';

  @override
  void initState() {
    super.initState();
    _fetchRankingData();
  }

  Future<void> _fetchRankingData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.academyId;

      // Fetch students
      final alunosSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .get();
      final fetchedAlunos = alunosSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      // Fetch ONLY teachers
      final usersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', isEqualTo: 'teacher')
          .get();
      final fetchedUsersAsAlunos = usersSnapshot.docs
          .map((doc) => Aluno.fromUserModel(UserModel.fromFirestore(doc)))
          .toList();

      final allParticipants = [...fetchedAlunos, ...fetchedUsersAsAlunos];

      final checkinsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('checkins')
          .get();
      final allCheckins = checkinsSnapshot.docs
          .map((doc) =>
              CheckinEntry.fromJson(doc.id, doc.data()))
          .toList();

      final now = DateTime.now();
      final Map<String, int> counts = {
        for (var participant in allParticipants) participant.id: 0
      };

      for (var checkin in allCheckins) {
        bool shouldCount = false;
        switch (_filter) {
          case 'total':
            shouldCount = true;
            break;
          case 'mes':
            if (checkin.date.month == now.month &&
                checkin.date.year == now.year) {
              shouldCount = true;
            }
            break;
          case 'ano':
            if (checkin.date.year == now.year) {
              shouldCount = true;
            }
            break;
        }
        if (shouldCount) {
          counts.update(checkin.studentId, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }

      if (mounted) {
        setState(() {
          _todosParticipantes = allParticipants;
          _checkinCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar o ranking.", type: "error");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedParticipantes = List<Aluno>.from(_todosParticipantes);
    rankedParticipantes.sort((a, b) {
      final countA = _checkinCounts[a.id] ?? 0;
      final countB = _checkinCounts[b.id] ?? 0;
      return countB.compareTo(countA) != 0
          ? countB.compareTo(countA)
          : a.nome.compareTo(b.nome);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking de Presença')),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'mes', label: Text('Mês Atual')),
                  ButtonSegment<String>(value: 'ano', label: Text('Este Ano')),
                  ButtonSegment<String>(value: 'total', label: Text('Total')),
                ],
                selected: {_filter},
                onSelectionChanged: (newSelection) {
                  setState(() => _filter = newSelection.first);
                  _fetchRankingData();
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : rankedParticipantes.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.group_off_rounded,
                          title: "Nenhum participante encontrado.")
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 16.0),
                          itemCount: rankedParticipantes.length,
                          itemBuilder: (context, index) {
                            final aluno = rankedParticipantes[index];
                            final count = _checkinCounts[aluno.id] ?? 0;
                            final rank = index + 1;
                            Widget leadingIcon;
                            if (rank == 1) {
                              leadingIcon = const Icon(Icons.emoji_events,
                                  color: BjjApp.primaryAccent, size: 30);
                            } else if (rank == 2)
                              leadingIcon = const Icon(Icons.emoji_events,
                                  color: Color(0xFFC0C0C0), size: 28);
                            else if (rank == 3)
                              leadingIcon = const Icon(Icons.emoji_events,
                                  color: Color(0xFFCD7F32), size: 26);
                            else
                              leadingIcon = CircleAvatar(
                                  radius: 14,
                                  backgroundColor: BjjApp.darkSurface,
                                  child: Text('$rank',
                                      style: const TextStyle(
                                          color: BjjApp.textHint,
                                          fontWeight: FontWeight.bold)));

                            return Card(
                              child: ListTile(
                                leading: leadingIcon,
                                title: Text(aluno.nome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                trailing: Text('$count treinos',
                                    style: const TextStyle(
                                        color: BjjApp.primaryAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class SorteioTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;
  final bool isSparringMode;
  final Function(List<List<String>>, String, List<Aluno>) onIniciarSparring;
  final Function(List<Aluno>) onCheckinAlunos;

  const SorteioTeacherPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
    required this.isSparringMode,
    required this.onIniciarSparring,
    required this.onCheckinAlunos,
  });

  @override
  State<SorteioTeacherPage> createState() => _SorteioTeacherPageState();
}

class _SorteioTeacherPageState extends State<SorteioTeacherPage> {
  List<Aluno> _alunosParticipantes = [];
  List<List<String>> _rodadasGeradas = [];
  String _tipoGeracao = 'Aleatório';
  final List<String> _opcoesGeracao = ['Aleatório', 'Por Faixa', 'Por Peso'];

  void _atualizarAlunosParticipantes(List<Aluno> novosParticipantes) {
    setState(() {
      _alunosParticipantes = novosParticipantes;
      _rodadasGeradas = [];
    });
  }

  Future<void> _navegarParaSelecaoAlunos() async {
    final List<Aluno>? r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SelecaoAlunosTeacherPage(
        todosOsAlunos: widget.todosParticipantesDaAcademia,
        alunosSelecionadosIniciais: _alunosParticipantes,
      ),
    ));
    if (r != null) {
      _atualizarAlunosParticipantes(r);
    }
  }

  void _gerarRodadasClicado() {
    if (widget.isSparringMode) {
      showBjjSnackBar(context, 'Finalize o treino atual primeiro.',
          type: 'warning');
      return;
    }
    if (_alunosParticipantes.length < 2) {
      showBjjSnackBar(context, 'Selecione pelo menos 2 participantes.',
          type: 'error');
      return;
    }
    setState(() => _rodadasGeradas = []);
    if (_tipoGeracao == 'Aleatório') {
      _gerarRodadasAleatorias();
    } else {
      _gerarRodadasHierarquicas();
    }
  }

  void _gerarRodadasAleatorias() {
    List<Aluno> tempAlunos = List.from(_alunosParticipantes);
    tempAlunos.shuffle();

    if (tempAlunos.length % 2 != 0) {
      tempAlunos.add(Aluno.novo(nome: "DESCANSA", faixa: "", peso: 0));
    }
    int numRodadas = tempAlunos.length - 1;
    if (numRodadas <= 0) numRodadas = 1;

    List<List<String>> rodadas = [];
    for (int i = 0; i < numRodadas; i++) {
      List<String> rodadaAtual = [];
      for (int j = 0; j < tempAlunos.length / 2; j++) {
        final aluno1 = tempAlunos[j];
        final aluno2 = tempAlunos[tempAlunos.length - 1 - j];
        if (aluno1.nome == "DESCANSA") {
          rodadaAtual.add('${aluno2.nome} (descansa)');
        } else if (aluno2.nome == "DESCANSA") {
          rodadaAtual.add('${aluno1.nome} (descansa)');
        } else {
          rodadaAtual.add('${aluno1.nome} x ${aluno2.nome}');
        }
      }
      rodadas.add(rodadaAtual);
      // Rotaciona os alunos, mantendo o primeiro fixo
      tempAlunos.insert(1, tempAlunos.removeLast());
    }
    setState(() => _rodadasGeradas = rodadas);
  }

  void _gerarRodadasHierarquicas() {
    List<Aluno> tempAlunos = List.from(_alunosParticipantes);
    List<Luta> todasLutasPossiveis = [];

    // Gera todas as lutas possíveis e calcula o custo
    for (int i = 0; i < tempAlunos.length; i++) {
      for (int j = i + 1; j < tempAlunos.length; j++) {
        double custo;
        if (_tipoGeracao == 'Por Peso') {
          custo = (tempAlunos[i].peso - tempAlunos[j].peso).abs();
        } else {
          // Por Faixa
          int indexFaixa1 = _getBeltIndex(tempAlunos[i].faixa);
          int indexFaixa2 = _getBeltIndex(tempAlunos[j].faixa);
          double diffPeso = (tempAlunos[i].peso - tempAlunos[j].peso).abs();
          custo =
              (indexFaixa1 - indexFaixa2).abs().toDouble() + (diffPeso * 0.01);
        }
        todasLutasPossiveis.add(Luta(tempAlunos[i], tempAlunos[j], custo));
      }
    }
    todasLutasPossiveis.sort((a, b) => a.custo.compareTo(b.custo));

    List<List<String>> rodadasConstruidas = [];
    Set<String> lutasJaRealizadasGlobal = {};
    int maxRodadasPossiveis = tempAlunos.length - 1;

    for (int i = 0; i < maxRodadasPossiveis; i++) {
      List<String> rodadaAtual = [];
      Set<String> alunosNestaRodada = {};

      for (var luta in todasLutasPossiveis) {
        String parId1 = '${luta.aluno1.id}-${luta.aluno2.id}';
        String parId2 = '${luta.aluno2.id}-${luta.aluno1.id}';

        if (!lutasJaRealizadasGlobal.contains(parId1) &&
            !alunosNestaRodada.contains(luta.aluno1.id) &&
            !alunosNestaRodada.contains(luta.aluno2.id)) {
          rodadaAtual.add('${luta.aluno1.nome} x ${luta.aluno2.nome}');
          alunosNestaRodada.add(luta.aluno1.id);
          alunosNestaRodada.add(luta.aluno2.id);
          lutasJaRealizadasGlobal.add(parId1);
          lutasJaRealizadasGlobal.add(parId2);
        }
      }

      // Adiciona descanso se sobrou alguém
      if (alunosNestaRodada.length < tempAlunos.length) {
        final alunoDescanso = tempAlunos
            .firstWhereOrNull((aluno) => !alunosNestaRodada.contains(aluno.id));
        if (alunoDescanso != null) {
          rodadaAtual.add('${alunoDescanso.nome} (descansa)');
        }
      }

      if (rodadaAtual.isNotEmpty) {
        rodadasConstruidas.add(rodadaAtual);
      } else {
        break; // Nao ha mais lutas ineditas possiveis
      }
    }
    setState(() => _rodadasGeradas = rodadasConstruidas);
  }

  int _getBeltIndex(String faixa) {
    // Ordena do mais baixo para o mais alto
    const List<String> ordemFaixas = [
      'Branca',
      'Cinza',
      'Amarela',
      'Laranja',
      'Verde',
      'Azul',
      'Roxa',
      'Marrom',
      'Preta'
    ];
    final faixaPrincipal = faixa.split(" ")[0].trim();
    final index = ordemFaixas
        .indexWhere((f) => f.toLowerCase() == faixaPrincipal.toLowerCase());
    return index == -1 ? 0 : index; // Retorna 0 (branca) se não encontrar
  }

  void _iniciarSparringClicado() {
    if (_rodadasGeradas.isEmpty) {
      showBjjSnackBar(context, 'Gere as rodadas primeiro.', type: 'error');
      return;
    }
    widget.onIniciarSparring(
        _rodadasGeradas, _tipoGeracao, _alunosParticipantes);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(
                          'Selecionar Participantes (${_alunosParticipantes.length})'),
                      onPressed: widget.isSparringMode
                          ? null
                          : _navegarParaSelecaoAlunos,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _tipoGeracao,
                      decoration: const InputDecoration(labelText: 'Tipo de Sorteio'),
                      items: _opcoesGeracao
                          .map((String value) => DropdownMenuItem<String>(
                              value: value, child: Text(value)))
                          .toList(),
                      onChanged: widget.isSparringMode
                          ? null
                          : (v) => setState(() {
                                _tipoGeracao = v!;
                                _rodadasGeradas = [];
                              }),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Gerar Rodadas'),
                      onPressed: widget.isSparringMode ||
                              _alunosParticipantes.length < 2
                          ? null
                          : _gerarRodadasClicado,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_rodadasGeradas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Iniciar Treino'),
                onPressed: _iniciarSparringClicado,
                style: ElevatedButton.styleFrom(
                  backgroundColor: BjjApp.successColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          Expanded(
            child: _rodadasGeradas.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.list_alt_rounded,
                    title: "Nenhuma Rodada Gerada",
                    message:
                        "Selecione os participantes e gere as rodadas acima.")
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: _rodadasGeradas.length,
                    itemBuilder: (context, index) {
                      final rodada = _rodadasGeradas[index];
                      return Card(
                        child: ExpansionTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text('Rodada ${index + 1}'),
                          children: rodada
                              .map((luta) => ListTile(title: Text(luta)))
                              .toList(),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SparringTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosAlunos;

  const SparringTeacherPage(
      {super.key, required this.academyId, required this.todosAlunos});

  @override
  _SparringTeacherPageState createState() => _SparringTeacherPageState();
}

class _SparringTeacherPageState extends State<SparringTeacherPage> {
  Map<String, dynamic> _sparringState = {};
  bool _isLoading = true;
  StreamSubscription? _sparringStateSubscription;

  int get _currentRoundIndex => _sparringState['currentRoundIndex'] ?? 0;
  List<List<String>> get _allRounds {
    final dynamic roundsData = _sparringState['allRounds'];
    if (roundsData is List) {
      return roundsData.map<List<String>>((item) {
        if (item is Map &&
            item.containsKey('fights') &&
            item['fights'] is List) {
          return List<String>.from(item['fights']);
        }
        return <String>[];
      }).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    super.dispose();
  }

  void _loadState() {
    _sparringStateSubscription = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _sparringState = doc.data()!;
          _isLoading = false;
        });
      } else {
        // Se o estado for deletado, volta para la tela anterior
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _updateSparringState(Map<String, dynamic> update) async {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .update(update);
  }

  Future<void> _finishSparring() async {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .delete();
  }

  void _nextRound() {
    final newIndex = _currentRoundIndex + 1;
    _updateSparringState({'currentRoundIndex': newIndex});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body:
              AppBackground(child: Center(child: CircularProgressIndicator())));
    }

    bool isSparringMode = _sparringState['isSparringMode'] ?? false;
    if (!isSparringMode) {
      return Scaffold(
        appBar: AppBar(title: const Text("Treino")),
        body: const EmptyStateWidget(
          icon: Icons.pause_circle_outline_rounded,
          title: 'Nenhum treino em andamento.',
          message: 'Volte para a tela de sorteio para iniciar um treino.',
        ),
      );
    }

    List<String> currentRoundFights = [];
    String roundTitle = '';
    bool isLastRound = _currentRoundIndex > _allRounds.length;

    if (_allRounds.isNotEmpty) {
      if (isLastRound) {
        currentRoundFights = _allRounds.last;
        roundTitle =
            'FIM - Última Rodada (${_allRounds.length}/${_allRounds.length})';
      } else {
        currentRoundFights = _allRounds[_currentRoundIndex - 1];
        roundTitle = 'Rodada $_currentRoundIndex / ${_allRounds.length}';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(roundTitle)),
      body: AppBackground(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: currentRoundFights.length,
                itemBuilder: (context, index) {
                  final matchText = currentRoundFights[index];
                  bool isResting = matchText.contains('(descansa)');

                  return Card(
                    color: isResting
                        ? BjjApp.darkSurface.withOpacity(0.5)
                        : BjjApp.darkSurface,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(matchText,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color: isResting
                                        ? BjjApp.textHint
                                        : BjjApp.textPrimary)),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop_circle_rounded),
                    onPressed: _finishSparring,
                    label: const Text('Finalizar'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: BjjApp.errorColor),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: isLastRound ? null : _nextRound,
                    label: const Text('Próxima'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelecaoAlunosTeacherPage extends StatefulWidget {
  final List<Aluno> todosOsAlunos;
  final List<Aluno> alunosSelecionadosIniciais;
  const SelecaoAlunosTeacherPage(
      {super.key, required this.todosOsAlunos, required this.alunosSelecionadosIniciais});
  @override
  _SelecaoAlunosTeacherPageState createState() =>
      _SelecaoAlunosTeacherPageState();
}

class _SelecaoAlunosTeacherPageState extends State<SelecaoAlunosTeacherPage> {
  late Set<Aluno> _alunosAtuaisSelecionados;

  @override
  void initState() {
    super.initState();
    _alunosAtuaisSelecionados =
        Set<Aluno>.from(widget.alunosSelecionadosIniciais);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar Participantes'),
      ),
      body: AppBackground(
        child: widget.todosOsAlunos.isEmpty
            ? const EmptyStateWidget(
                icon: Icons.person_search_rounded,
                title: 'Nenhum Participante Cadastrado na Academia')
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: widget.todosOsAlunos.length,
                itemBuilder: (context, index) {
                  final a = widget.todosOsAlunos[index];
                  final s = _alunosAtuaisSelecionados.contains(a);
                  return Card(
                    child: CheckboxListTile(
                      title: Text(a.nome),
                      subtitle: Text('${a.faixa} - ${a.peso}kg'),
                      value: s,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _alunosAtuaisSelecionados.add(a);
                        } else {
                          _alunosAtuaisSelecionados.remove(a);
                        }
                      }),
                      secondary: const Icon(Icons.person),
                    ),
                  );
                }),
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Navigator.of(context).pop(_alunosAtuaisSelecionados.toList()),
          label: Text('Confirmar (${_alunosAtuaisSelecionados.length})'),
          icon: const Icon(Icons.check_circle_outline_rounded)),
    );
  }
}

// --- TELAS DO PLACAR (ATUALIZADAS COM BUSCA) ---

/// Tela para configurar os parâmetros da luta antes de ir para o placar.
class MatchSetupPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosAlunosDaAcademia;

  const MatchSetupPage({
    super.key,
    required this.academyId,
    required this.todosAlunosDaAcademia,
  });

  @override
  State<MatchSetupPage> createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage> {
  final _formKey = GlobalKey<FormState>();
  Aluno? _athlete1;
  Aluno? _athlete2;
  String _kimonoColor1 = 'Branco';
  String _kimonoColor2 = 'Azul';
  int _matchTimeInMinutes = 5;

  final List<String> _kimonoColors = ['Branco', 'Azul', 'Preto'];
  final List<int> _matchTimes = List.generate(10, (index) => index + 1);

  void _startMatch() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final settings = MatchSettings(
      athlete1: _athlete1!,
      athlete2: _athlete2!,
      kimonoColor1: _kimonoColor1,
      kimonoColor2: _kimonoColor2,
      matchDuration: Duration(minutes: _matchTimeInMinutes),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScoreboardPage(settings: settings),
      ),
    );
  }

  Future<void> _selectAthlete(int playerNumber) async {
    final List<Aluno> availableAthletes =
        List.from(widget.todosAlunosDaAcademia);
    // Remove o outro atleta da lista de seleção
    if (playerNumber == 1 && _athlete2 != null) {
      availableAthletes.removeWhere((a) => a.id == _athlete2!.id);
    } else if (playerNumber == 2 && _athlete1 != null) {
      availableAthletes.removeWhere((a) => a.id == _athlete1!.id);
    }

    final Aluno? selectedAthlete = await showDialog<Aluno>(
      context: context,
      builder: (context) => _AthleteSelectionDialog(
        athletes: availableAthletes,
        title: "Selecione o Atleta $playerNumber",
      ),
    );

    if (selectedAthlete != null) {
      setState(() {
        if (playerNumber == 1) {
          _athlete1 = selectedAthlete;
        } else {
          _athlete2 = selectedAthlete;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Atleta 1",
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _buildAthleteSelector(
                        athlete: _athlete1,
                        onTap: () => _selectAthlete(1),
                        validator: (value) =>
                            value == null ? 'Selecione o atleta 1' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _kimonoColor1,
                        decoration: const InputDecoration(labelText: 'Cor do Kimono'),
                        items: _kimonoColors
                            .map((color) => DropdownMenuItem<String>(
                                value: color, child: Text(color)))
                            .toList(),
                        onChanged: (color) =>
                            setState(() => _kimonoColor1 = color!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Atleta 2",
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _buildAthleteSelector(
                        athlete: _athlete2,
                        onTap: () => _selectAthlete(2),
                        validator: (value) =>
                            value == null ? 'Selecione o atleta 2' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _kimonoColor2,
                        decoration: const InputDecoration(labelText: 'Cor do Kimono'),
                        items: _kimonoColors
                            .map((color) => DropdownMenuItem<String>(
                                value: color, child: Text(color)))
                            .toList(),
                        onChanged: (color) =>
                            setState(() => _kimonoColor2 = color!),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<int>(
                    value: _matchTimeInMinutes,
                    decoration: const InputDecoration(labelText: 'Tempo de Luta'),
                    items: _matchTimes
                        .map((time) => DropdownMenuItem<int>(
                            value: time, child: Text('$time minutos')))
                        .toList(),
                    onChanged: (time) =>
                        setState(() => _matchTimeInMinutes = time!),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('INICIAR LUTA'),
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAthleteSelector({
    required Aluno? athlete,
    required VoidCallback onTap,
    required FormFieldValidator<Aluno?> validator,
  }) {
    return FormField<Aluno?>(
      initialValue: athlete,
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: athlete == null
                      ? 'Clique para selecionar'
                      : 'Atleta Selecionado',
                  errorText: field.errorText,
                ),
                child: athlete == null
                    ? null
                    : Text(
                        athlete.nome,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AthleteSelectionDialog extends StatefulWidget {
  final List<Aluno> athletes;
  final String title;

  const _AthleteSelectionDialog(
      {required this.athletes, required this.title});

  @override
  __AthleteSelectionDialogState createState() =>
      __AthleteSelectionDialogState();
}

class __AthleteSelectionDialogState extends State<_AthleteSelectionDialog> {
  final _searchController = TextEditingController();
  List<Aluno> _filteredAthletes = [];

  @override
  void initState() {
    super.initState();
    _filteredAthletes = widget.athletes;
    _searchController.addListener(_filterAthletes);
  }

  void _filterAthletes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAthletes = widget.athletes.where((athlete) {
        return athlete.nome.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Buscar por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredAthletes.isEmpty
                  ? const Center(child: Text("Nenhum atleta encontrado."))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredAthletes.length,
                      itemBuilder: (context, index) {
                        final athlete = _filteredAthletes[index];
                        return ListTile(
                          title: Text(athlete.nome),
                          onTap: () {
                            Navigator.of(context).pop(athlete);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Armazena os dados de pontuação de um único atleta.
class _PlayerScore {
  int totalScore = 0;
  int advantages = 0;
  int penalties = 0;
  int takedowns = 0; // Queda / Raspagem (+2)
  int passes = 0; // Passagem (+3)
  int mountsOrBack = 0; // Montada / Costas (+4)

  void reset() {
    totalScore = 0;
    advantages = 0;
    penalties = 0;
    takedowns = 0;
    passes = 0;
    mountsOrBack = 0;
  }
}

/// A tela principal do placar, onde a luta acontece.
class ScoreboardPage extends StatefulWidget {
  final MatchSettings settings;

  const ScoreboardPage({
    super.key,
    required this.settings,
  });

  @override
  _ScoreboardPageState createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  // Estado da pontuação para cada atleta
  final _player1Score = _PlayerScore();
  final _player2Score = _PlayerScore();

  // Estado do cronômetro
  Timer? _timer;
  late Duration _timeRemaining;
  bool _isRunning = false;
  bool _isMatchOver = false;

  @override
  void initState() {
    super.initState();
    _timeRemaining = widget.settings.matchDuration;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Formata a duração para o formato MM:SS.
  String get _timerString {
    final minutes = _timeRemaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // --- LÓGICA DO CRONÔMETRO ---

  void _toggleTimer() {
    if (_isMatchOver) return;

    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_timer?.isActive ?? false) return; // Já está rodando
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_timeRemaining.inSeconds > 0) {
          _timeRemaining -= const Duration(seconds: 1);
        } else {
          _pauseTimer();
          _handleEndOfMatch(reason: "por tempo");
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _restartMatch() {
    _pauseTimer();
    setState(() {
      _timeRemaining = widget.settings.matchDuration;
      _isMatchOver = false;
      _player1Score.reset();
      _player2Score.reset();
    });
  }

  // --- LÓGICA DE PONTUAÇÃO E PENALIDADES ---

  void _updateScore(
      int playerIndex, int points, Function(int) updateCounter, int increment) {
    if (_isMatchOver) return;

    final score = playerIndex == 1 ? _player1Score : _player2Score;

    if (increment < 0) {
      if ((points == 2 && score.takedowns == 0) ||
          (points == 3 && score.passes == 0) ||
          (points == 4 && score.mountsOrBack == 0)) {
        return;
      }
    }

    setState(() {
      score.totalScore += (points * increment);
      updateCounter(increment);
    });
  }

  void _updateAdvantages(int playerIndex, int increment) {
    if (_isMatchOver) return;

    final score = playerIndex == 1 ? _player1Score : _player2Score;
    if (increment < 0 && score.advantages == 0) return;

    setState(() {
      score.advantages += increment;
    });
  }

  void _handlePenaltyUpdate(int playerIndex, int increment) {
    if (_isMatchOver) return;

    final punishedScore = playerIndex == 1 ? _player1Score : _player2Score;
    final opponentScore = playerIndex == 1 ? _player2Score : _player1Score;

    if (increment < 0 && punishedScore.penalties == 0) return;

    setState(() {
      final oldPenaltyCount = punishedScore.penalties;
      punishedScore.penalties += increment;
      final newPenaltyCount = punishedScore.penalties;

      if (increment > 0) {
        if (newPenaltyCount == 2) opponentScore.advantages += 1;
        if (newPenaltyCount == 3) opponentScore.totalScore += 2;
        if (newPenaltyCount >= 4) {
          final winner = playerIndex == 1
              ? widget.settings.athlete2
              : widget.settings.athlete1;
          _handleEndOfMatch(reason: "por desclassificação", winner: winner);
        }
      } else {
        if (oldPenaltyCount == 2) opponentScore.advantages -= 1;
        if (oldPenaltyCount == 3) opponentScore.totalScore -= 2;
      }
    });
  }

  // --- LÓGICA DE FIM DE LUTA ---

  void _handleEndOfMatch({String reason = "", Aluno? winner}) {
    _pauseTimer();
    setState(() => _isMatchOver = true);

    String resultMessage;
    if (winner != null) {
      resultMessage = "${winner.nome} venceu $reason!";
    } else {
      if (_player1Score.totalScore > _player2Score.totalScore) {
        resultMessage = "${widget.settings.athlete1.nome} venceu por pontos!";
      } else if (_player2Score.totalScore > _player1Score.totalScore) {
        resultMessage = "${widget.settings.athlete2.nome} venceu por pontos!";
      } else {
        if (_player1Score.advantages > _player2Score.advantages) {
          resultMessage =
              "${widget.settings.athlete1.nome} venceu por vantagens!";
        } else if (_player2Score.advantages > _player1Score.advantages) {
          resultMessage =
              "${widget.settings.athlete2.nome} venceu por vantagens!";
        } else {
          if (_player1Score.penalties < _player2Score.penalties) {
            resultMessage =
                "${widget.settings.athlete1.nome} venceu por menos punições!";
          } else if (_player2Score.penalties < _player1Score.penalties) {
            resultMessage =
                "${widget.settings.athlete2.nome} venceu por menos punições!";
          } else {
            resultMessage = "A luta terminou em EMPATE!";
          }
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Fim de Luta!"),
        content: Text(resultMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE CONSTRUÇÃO DA UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Placar da Luta"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: BjjApp.darkScaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Cabeçalho dos Atletas
            Row(
              children: [
                _buildPlayerHeader(
                  athlete: widget.settings.athlete1,
                  score: _player1Score,
                  color: widget.settings.colorForAthlete1,
                  isPlayer2: false,
                ),
                _buildPlayerHeader(
                  athlete: widget.settings.athlete2,
                  score: _player2Score,
                  color: widget.settings.colorForAthlete2,
                  isPlayer2: true,
                ),
              ],
            ),

            // 2. Cronômetro Central
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Botão Reiniciar
                  IconButton(
                    iconSize: 50,
                    color: BjjApp.errorColor,
                    icon: const Icon(Icons.restart_alt_rounded),
                    onPressed: _restartMatch,
                  ),

                  // Cronômetro
                  Text(
                    _timerString,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color:
                          _isMatchOver ? BjjApp.textHint : BjjApp.textPrimary,
                    ),
                  ),

                  // Botão Play/Pause
                  IconButton(
                    iconSize: 50,
                    color:
                        _isRunning ? BjjApp.warningColor : BjjApp.successColor,
                    icon: Icon(_isRunning
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded),
                    onPressed: _isMatchOver ? null : _toggleTimer,
                  ),
                ],
              ),
            ),

            // 3. Controles de Pontuação
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(top: 8.0),
                color: BjjApp.darkSurface.withOpacity(0.7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreControl(
                      playerIndex: 1,
                      score: _player1Score,
                    ),
                    const VerticalDivider(
                        color: BjjApp.borderNormal, thickness: 1, width: 1),
                    _buildScoreControl(
                      playerIndex: 2,
                      score: _player2Score,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader({
    required Aluno athlete,
    required _PlayerScore score,
    required Color color,
    required bool isPlayer2,
  }) {
    bool useGradient = isPlayer2 &&
        widget.settings.kimonoColor1 == widget.settings.kimonoColor2;
    final displayColor = (color == Colors.grey.shade800) ? Colors.white : color;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: BjjApp.borderNormal, width: 2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: useGradient ? BjjApp.primaryAccent : color,
                    width: 2),
                gradient: useGradient
                    ? LinearGradient(
                        colors: [BjjApp.primaryAccent, Colors.yellow.shade800])
                    : null,
              ),
              child: Text(
                athlete.nome.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: useGradient
                      ? BjjApp.primaryAccentForeground
                      : displayColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${score.totalScore}',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: displayColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("V: ${score.advantages}",
                    style:
                        const TextStyle(fontSize: 16, color: BjjApp.textSecondary)),
                Text("P: ${score.penalties}",
                    style:
                        const TextStyle(fontSize: 16, color: BjjApp.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreControl(
      {required int playerIndex, required _PlayerScore score}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildScoreButton(
              label: 'Montada / Costas (+4)',
              count: score.mountsOrBack,
              onAdd: () => _updateScore(
                  playerIndex, 4, (inc) => score.mountsOrBack += inc, 1),
              onRemove: () => _updateScore(
                  playerIndex, 4, (inc) => score.mountsOrBack += inc, -1),
            ),
            _buildScoreButton(
              label: 'Passagem (+3)',
              count: score.passes,
              onAdd: () =>
                  _updateScore(playerIndex, 3, (inc) => score.passes += inc, 1),
              onRemove: () => _updateScore(
                  playerIndex, 3, (inc) => score.passes += inc, -1),
            ),
            _buildScoreButton(
              label: 'Queda / Raspagem (+2)',
              count: score.takedowns,
              onAdd: () => _updateScore(
                  playerIndex, 2, (inc) => score.takedowns += inc, 1),
              onRemove: () => _updateScore(
                  playerIndex, 2, (inc) => score.takedowns += inc, -1),
            ),
            _buildScoreButton(
              label: 'Vantagens (+1)',
              count: score.advantages,
              onAdd: () => _updateAdvantages(playerIndex, 1),
              onRemove: () => _updateAdvantages(playerIndex, -1),
            ),
            _buildScoreButton(
              label: 'Punições (+1)',
              count: score.penalties,
              onAdd: () => _handlePenaltyUpdate(playerIndex, 1),
              onRemove: () => _handlePenaltyUpdate(playerIndex, -1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreButton({
    required String label,
    required int count,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    return FittedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _isMatchOver ? null : onRemove,
            color: BjjApp.textHint,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(
            width: 150,
            child: Column(
              children: [
                Text(label,
                    style:
                        const TextStyle(color: BjjApp.textSecondary, fontSize: 12)),
                Text('$count',
                    style: const TextStyle(
                        color: BjjApp.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _isMatchOver ? null : onAdd,
            color: BjjApp.textHint,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// --- TELAS DO ALUNO ---
class StudentHomePage extends StatefulWidget {
  final UserModel user;
  const StudentHomePage({super.key, required this.user});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _paginaAtual = 0;
  late List<Widget> _telas;
  List<Aluno> _todosOsAlunosDaAcademia = [];
  bool _isLoading = true;

  final List<String> _titulos = const [
    'Meu Perfil',
    'Histórico',
    'Caderno de Estudos',
    'Placar Individual'
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;

      // 1. Fetch students
      final studentsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .orderBy('nome')
          .get();
      final studentParticipants = studentsSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      // 2. Fetch teachers
      final teachersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', isEqualTo: 'teacher')
          .get();
      final teacherParticipants = teachersSnapshot.docs
          .map((doc) => Aluno.fromUserModel(UserModel.fromFirestore(doc)))
          .toList();

      // 3. Combine and sort
      final allParticipants = [...studentParticipants, ...teacherParticipants];
      allParticipants.sort((a, b) => a.nome.compareTo(b.nome));

      if (mounted) {
        setState(() {
          _todosOsAlunosDaAcademia = allParticipants;
          _buildScreens();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar dados da academia.',
            type: 'error');
        // Mesmo com erro, construímos as telas para que o usuário possa navegar
        _buildScreens();
      }
    }
  }

  void _buildScreens() {
    _telas = [
      StudentProfilePage(user: widget.user),
      MyCheckinsPage(user: widget.user),
      // MODIFICADO: Passa o userId para a tela de estudos
      StudyNotebookPage(userId: widget.user.uid),
      MatchSetupPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosOsAlunosDaAcademia),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body:
              AppBackground(child: Center(child: CircularProgressIndicator())));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_paginaAtual]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsPage(user: widget.user)))),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair',
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: IndexedStack(index: _paginaAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (index) => setState(() => _paginaAtual = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Meu Perfil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded), label: 'Histórico'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded), label: 'Estudos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.scoreboard_rounded), label: 'Placar'),
        ],
      ),
    );
  }
}

class StudentProfilePage extends StatefulWidget {
  final UserModel user;
  const StudentProfilePage({super.key, required this.user});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  Aluno? _aluno;
  MonthlyFee? _currentMonthFee; // Novo: para guardar o pagamento do mês
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (widget.user.studentRecordId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;
      final studentId = widget.user.studentRecordId!;
      final now = DateTime.now();

      // Fetch student data
      final doc = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .doc(studentId)
          .get();

      MonthlyFee? fee;
      // Fetch payment for the current month
      final paymentSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('monthly_fees')
          .where('studentId', isEqualTo: studentId)
          .where('paymentYear', isEqualTo: now.year)
          .where('paymentMonth', isEqualTo: now.month)
          .limit(1)
          .get();

      if (paymentSnapshot.docs.isNotEmpty) {
        fee = MonthlyFee.fromFirestore(paymentSnapshot.docs.first);
      }

      if (mounted) {
        if (doc.exists) {
          setState(() {
            _aluno = Aluno.fromJson(doc.id, doc.data()!);
            _currentMonthFee = fee;
          });
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar dados do perfil.",
            type: 'error');
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatGraduation(Aluno aluno) {
    String grad = aluno.faixa;
    if (aluno.graus != null && aluno.graus! > 0) {
      grad += ' - ${aluno.graus}º Grau';
    }
    return grad;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_aluno == null) {
      return const AppBackground(
        child: EmptyStateWidget(
          icon: Icons.person_add_alt_1_rounded,
          title: "Complete seu Perfil",
          message:
              "Vá para as Configurações para preencher seus dados de aluno e ter acesso a todas as funcionalidades.",
        ),
      );
    }

    final bool isPaid = _currentMonthFee != null;

    return AppBackground(
      child: RefreshIndicator(
        onRefresh: _loadStudentData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Center(
              child: Icon(Icons.account_circle,
                  size: 100, color: BjjApp.primaryAccent),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Bem-vindo, ${_aluno!.nome}!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield_outlined,
                    color: BjjApp.primaryAccent, size: 30),
                title:
                    const Text("Graduação", style: TextStyle(color: BjjApp.textHint)),
                subtitle: Text(
                  _formatGraduation(_aluno!),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: BjjApp.textPrimary),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center_rounded,
                    color: BjjApp.primaryAccent, size: 30),
                title: const Text("Peso", style: TextStyle(color: BjjApp.textHint)),
                subtitle: Text(
                  '${_aluno!.peso.toStringAsFixed(1)} kg',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: BjjApp.textPrimary),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.email_outlined,
                    color: BjjApp.primaryAccent, size: 30),
                title: const Text("E-mail", style: TextStyle(color: BjjApp.textHint)),
                subtitle: Text(
                  widget.user.email,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: BjjApp.textPrimary),
                ),
              ),
            ),

            // --- CARD DE STATUS DA MENSALIDADE (MOVIDO E SUAVIZADO) ---
            Card(
              child: ListTile(
                leading: Icon(
                  isPaid
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: isPaid ? BjjApp.successColor : BjjApp.warningColor,
                  size: 30,
                ),
                title: const Text("Status da Mensalidade",
                    style: TextStyle(color: BjjApp.textHint)),
                subtitle: Text(
                  isPaid
                      ? 'Paga em ${DateFormat.yMd('pt_BR').format(_currentMonthFee!.paymentDate)}'
                      : 'Pendente para este mês',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: BjjApp.textPrimary),
                ),
              ),
            ),
            // --- FIM DO CARD ---
          ],
        ),
      ),
    );
  }
}

class EditStudentProfilePage extends StatefulWidget {
  final UserModel user;
  const EditStudentProfilePage({super.key, required this.user});

  @override
  State<EditStudentProfilePage> createState() => _EditStudentProfilePageState();
}

class _EditStudentProfilePageState extends State<EditStudentProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  String? _faixa;
  int? _graus;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _faixasList = [
    'Branca',
    'Cinza com Ponta Branca',
    'Cinza',
    'Cinza com Ponta Preta',
    'Amarela com Ponta Branca',
    'Amarela',
    'Amarela com Ponta Preta',
    'Laranja com Ponta Branca',
    'Laranja',
    'Laranja com Ponta Preta',
    'Verde com Ponta Branca',
    'Verde',
    'Verde com Ponta Preta',
    'Azul',
    'Roxa',
    'Marrom',
    'Preta'
  ];
  List<int> _grausList = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      // Inclui a faixa branca e as faixas infantis
      return [1, 2, 3, 4];
    }
    return [];
  }

  Future<void> _loadStudentData() async {
    if (widget.user.studentRecordId == null) {
      // Se não há registro, preenche com o nome do UserModel para começar
      _nameController.text = widget.user.name;
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .doc(widget.user.studentRecordId)
          .get();

      if (mounted && doc.exists) {
        final aluno = Aluno.fromJson(doc.id, doc.data()!);
        _nameController.text = aluno.nome;
        _weightController.text = aluno.peso.toString();
        _faixa = aluno.faixa;
        _graus = aluno.graus;
        _grausList = _getGrausForFaixa(_faixa);
      } else if (mounted) {
        _nameController.text = widget.user.name;
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar dados do perfil.",
            type: 'error');
        _nameController.text = widget.user.name;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user.studentRecordId == null) {
      showBjjSnackBar(context,
          "Seu perfil de aluno ainda não foi criado pelo gerente. Contate sua academia.",
          type: 'error');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final studentRef = firestore
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .doc(widget.user.studentRecordId!);

      batch.update(studentRef, {
        'nome': _nameController.text.trim(),
        'peso': double.parse(_weightController.text.replaceAll(',', '.')),
        'faixa': _faixa,
        'graus': _graus,
      });

      if (_nameController.text.trim() != widget.user.name) {
        final userRef = firestore.collection('users').doc(widget.user.uid);
        batch.update(userRef, {'name': _nameController.text.trim()});
      }

      await batch.commit();

      if (mounted) {
        showBjjSnackBar(context, "Perfil atualizado com sucesso!",
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao atualizar perfil: $e", type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Editar Perfil")),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration:
                              const InputDecoration(labelText: 'Nome Completo'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Nome não pode ser vazio'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _weightController,
                          decoration: const InputDecoration(labelText: 'Peso (kg)'),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Peso inválido';
                            final x = double.tryParse(v.replaceAll(',', '.'));
                            return (x == null || x <= 0)
                                ? 'Peso inválido (deve ser > 0)'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _faixa,
                          decoration: const InputDecoration(labelText: 'Faixa'),
                          items: _faixasList
                              .map((faixa) => DropdownMenuItem(
                                  value: faixa, child: Text(faixa)))
                              .toList(),
                          onChanged: (value) => setState(() {
                            _faixa = value;
                            _grausList = _getGrausForFaixa(_faixa);
                            _graus = null; // Reseta o grau ao trocar de faixa
                          }),
                          validator: (value) =>
                              value == null ? 'Selecione sua faixa' : null,
                        ),
                        if (_faixa != null) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _graus,
                            decoration:
                                const InputDecoration(labelText: 'Graus (opcional)'),
                            items: [
                              const DropdownMenuItem<int>(
                                  value: null, child: Text("Nenhum")),
                              ..._grausList.map((g) => DropdownMenuItem(
                                  value: g, child: Text("$gº Grau"))),
                            ],
                            onChanged: (value) =>
                                setState(() => _graus = value),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: _updateProfile,
                                icon: const Icon(Icons.save),
                                label: const Text("Salvar Alterações"),
                                style: ElevatedButton.styleFrom(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 16)),
                              ),
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

class MyCheckinsPage extends StatefulWidget {
  final UserModel user;
  const MyCheckinsPage({super.key, required this.user});

  @override
  State<MyCheckinsPage> createState() => _MyCheckinsPageState();
}

class _MyCheckinsPageState extends State<MyCheckinsPage> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final studentId = widget.user.studentRecordId;
    if (studentId == null) {
      return const AppBackground(
        child: EmptyStateWidget(
            icon: Icons.link_off,
            title: "Perfil não vinculado",
            message:
                "Seu login não está vinculado a um registro de aluno. Complete seu perfil na primeira aba."),
      );
    }

    return AppBackground(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.user.academyId)
            .collection('checkins')
            .where('studentId', isEqualTo: studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCheckins = snapshot.data?.docs
                  .map((doc) => CheckinEntry.fromJson(
                      doc.id, doc.data() as Map<String, dynamic>))
                  .toList() ??
              [];

          final eventosAgrupados = <DateTime, List<CheckinEntry>>{};
          for (var checkin in allCheckins) {
            final dataNormalizada = DateTime.utc(
                checkin.date.year, checkin.date.month, checkin.date.day);
            eventosAgrupados
                .putIfAbsent(dataNormalizada, () => [])
                .add(checkin);
          }

          final checkinsForFocusedMonth = allCheckins.where((checkin) {
            return checkin.date.month == _focusedDay.month &&
                checkin.date.year == _focusedDay.year;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'Treinos em ${DateFormat.yMMMM('pt_BR').format(_focusedDay)}: ${checkinsForFocusedMonth.length}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: BjjApp.primaryAccent),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Card(
                    child: TableCalendar<CheckinEntry>(
                      locale: 'pt_BR',
                      firstDay: DateTime.utc(DateTime.now().year - 5, 1, 1),
                      lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: CalendarFormat.month,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      eventLoader: (day) =>
                          eventosAgrupados[
                              DateTime.utc(day.year, day.month, day.day)] ??
                          [],
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          if (events.isNotEmpty) {
                            return Positioned(
                              right: 1,
                              bottom: 1,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BjjApp.successColor),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        todayDecoration: BoxDecoration(
                            color: BjjApp.primaryAccent.withOpacity(0.3),
                            shape: BoxShape.circle),
                        selectedDecoration: const BoxDecoration(
                            color: BjjApp.primaryAccent,
                            shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// --- TELA DE TROCA DE SENHA ---
class ChangePasswordPage extends StatefulWidget {
  final bool isFirstLogin;
  const ChangePasswordPage({super.key, this.isFirstLogin = false});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (mounted) {
        showBjjSnackBar(context, "Usuário não encontrado.", type: "error");
      }
      setState(() => _isLoading = false);
      return;
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: _currentPasswordController.text,
    );

    try {
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text);

      if (widget.isFirstLogin) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'mustChangePassword': false});
      }

      if (mounted) {
        showBjjSnackBar(context, "Senha alterada com sucesso!",
            type: "success");

        if (widget.isFirstLogin) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthGate()),
            (Route<dynamic> route) => false,
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Ocorreu um erro.";
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = "A senha atual está incorreta.";
        } else if (e.code == 'weak-password') {
          message = "A nova senha é muito fraca.";
        }
        showBjjSnackBar(context, message, type: "error");
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro inesperado: $e", type: "error");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.isFirstLogin,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.isFirstLogin ? "Crie sua Nova Senha" : "Alterar Senha"),
          automaticallyImplyLeading: !widget.isFirstLogin,
          actions: widget.isFirstLogin
              ? [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Fazer Logout',
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  )
                ]
              : null,
        ),
        body: AppBackground(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (widget.isFirstLogin)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          "Por segurança, você precisa definir uma nova senha para continuar.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BjjApp.textHint),
                        ),
                      ),
                    TextFormField(
                      controller: _currentPasswordController,
                      decoration: const InputDecoration(
                          labelText: 'Senha Atual (ou Temporária)'),
                      obscureText: true,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "Campo obrigatório" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(labelText: 'Nova Senha'),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? "Mínimo 6 caracteres"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration:
                          const InputDecoration(labelText: 'Confirme a Nova Senha'),
                      obscureText: true,
                      validator: (v) => v != _newPasswordController.text
                          ? "As senhas não coincidem"
                          : null,
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50)),
                        child: const Text("Salvar Nova Senha"),
                      )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- NOVAS TELAS DO CADERNO DE ESTUDOS (PARA COMPLETUDE DO ARQUIVO) ---

class NoteDetailPage extends StatelessWidget {
  final StudyNote note;

  const NoteDetailPage({super.key, required this.note});

  Future<void> _launchUrl(BuildContext context) async {
    if (note.videoUrl != null && note.videoUrl!.isNotEmpty) {
      final uri = Uri.parse(note.videoUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        showBjjSnackBar(
            context, 'Não foi possível abrir o link: ${note.videoUrl}',
            type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note.title),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              note.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (note.tags.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children:
                    note.tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            const SizedBox(height: 16),
            if (note.imagePath != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.file(File(note.imagePath!)),
                ),
              ),
            if (note.videoUrl != null && note.videoUrl!.isNotEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.video_library_rounded,
                      color: BjjApp.primaryAccent),
                  title: const Text("Assistir Vídeo de Referência"),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _launchUrl(context),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              "Anotações",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(height: 20),
            SelectableText(
              note.content,
              style:
                  Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class EditStudyNotePage extends StatefulWidget {
  final StudyNote? note; // Se a nota for nula, é uma nova anotação
  final String userId; // MODIFICADO: Precisa saber quem é o usuário

  const EditStudyNotePage({super.key, this.note, required this.userId});

  @override
  _EditStudyNotePageState createState() => _EditStudyNotePageState();
}

class _EditStudyNotePageState extends State<EditStudyNotePage> {
  final _formKey = GlobalKey<FormState>();
  final _noteService = StudyNoteService();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _urlController = TextEditingController();

  String? _imagePath;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _tagsController.text = widget.note!.tags.join(', ');
      _urlController.text = widget.note!.videoUrl ?? '';
      _imagePath = widget.note!.imagePath;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Salvando imagem..."),
              ]),
            ),
          );
        },
      );

      // MODIFICADO: Passa o userId para salvar a imagem
      final savedPath = await _noteService.saveImage(widget.userId, image);

      Navigator.of(context).pop();

      if (savedPath != null) {
        setState(() {
          _imagePath = savedPath;
        });
      } else {
        showBjjSnackBar(context, "Não foi possível salvar a imagem.",
            type: 'error');
      }
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    // MODIFICADO: Carrega as notas do usuário específico
    final allNotes = await _noteService.loadNotes(widget.userId);
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_isEditing) {
      final index = allNotes.indexWhere((n) => n.id == widget.note!.id);
      if (index != -1) {
        allNotes[index].title = _titleController.text;
        allNotes[index].content = _contentController.text;
        allNotes[index].tags = tags;
        allNotes[index].videoUrl = _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim();
        allNotes[index].imagePath = _imagePath;
        allNotes[index].updatedAt = DateTime.now();
      }
    } else {
      final newNote = StudyNote.create(
        title: _titleController.text,
        content: _contentController.text,
        tags: tags,
        videoUrl: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        imagePath: _imagePath,
      );
      allNotes.add(newNote);
    }

    // MODIFICADO: Salva as notas para o usuário específico
    await _noteService.saveNotes(widget.userId, allNotes);

    if (mounted) {
      showBjjSnackBar(context, "Anotação salva com sucesso!", type: 'success');
      Navigator.of(context).pop();
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Anotação' : 'Nova Anotação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveNote,
            tooltip: 'Salvar Anotação',
          )
        ],
      ),
      body: AppBackground(
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'O título é obrigatório.' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Anotações',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                      validator: (v) => v!.trim().isEmpty
                          ? 'O conteúdo é obrigatório.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                          labelText: 'Tags (separadas por vírgula)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                          labelText: 'Link do Vídeo (Opcional)'),
                    ),
                    const SizedBox(height: 24),
                    if (_imagePath != null)
                      Column(
                        children: [
                          Text("Imagem Anexada:",
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(_imagePath!)),
                              ),
                              IconButton(
                                icon: const CircleAvatar(
                                    backgroundColor: Colors.black54,
                                    child:
                                        Icon(Icons.close, color: Colors.white)),
                                onPressed: _removeImage,
                              )
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file),
                      label: Text(_imagePath == null
                          ? 'Anexar Imagem'
                          : 'Trocar Imagem'),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// Função main (ponto de entrada)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseOptions options;
  if (flavor == 'prod') {
    options = prod.DefaultFirebaseOptions.currentPlatform;
    print("🚀 INICIANDO EM MODO PRODUÇÃO 🚀");
  } else {
    options = dev.DefaultFirebaseOptions.currentPlatform;
    print("🛠️ INICIANDO EM MODO DESENVOLVIMENTO 🛠️");
  }

  await Firebase.initializeApp(
    options: options,
  );

  runApp(
    const BjjApp(),
  );
}
