// lib/main.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'firebase_options_dev.dart' as dev;
import 'firebase_options_prod.dart' as prod;

// Nova constante para definir o Flavor
const flavor = String.fromEnvironment('FLAVOR');

// AppBackground, BjjApp (Tema) e showBjjSnackBar (sem alterações)
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({Key? key, required this.child}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/planofundo.png"),
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Match BJJ',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('pt', 'BR'),
      ],
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: darkSurface,
          scaffoldBackgroundColor: Colors.transparent,
          dialogBackgroundColor: darkSurface,
          cardColor: darkSurface.withOpacity(0.85),
          canvasColor: darkScaffoldBackground,
          colorScheme: ColorScheme.dark(
            primary: primaryAccent,
            secondary: primaryAccent,
            surface: darkSurface,
            background: darkScaffoldBackground,
            error: errorColor,
            onPrimary: primaryAccentForeground,
            onSecondary: primaryAccentForeground,
            onSurface: textPrimary,
            onBackground: textPrimary,
            onError: Colors.white,
          ),
          hintColor: textHint,
          textTheme: TextTheme(
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
          appBarTheme: AppBarTheme(
            backgroundColor: darkSurface,
            elevation: 2.0,
            titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            iconTheme: IconThemeData(color: textPrimary),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
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
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: primaryAccent,
            foregroundColor: primaryAccentForeground,
            elevation: 4.0,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 19.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            contentTextStyle: TextStyle(
                color: textSecondary, fontSize: 15, fontFamily: 'Roboto'),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: textHint),
            hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
            filled: true,
            fillColor: darkScaffoldBackground.withOpacity(0.5),
            contentPadding:
                EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: borderNormal)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: borderNormal)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: borderFocused, width: 2.0)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: errorColor, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: errorColor, width: 2.0)),
            errorStyle:
                TextStyle(color: errorColor, fontWeight: FontWeight.w500),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: textHint),
              hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
              filled: true,
              fillColor: darkScaffoldBackground.withOpacity(0.5),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: borderNormal)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: borderNormal)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: borderFocused, width: 2.0)),
            ),
            menuStyle: MenuStyle(
              backgroundColor: MaterialStatePropertyAll(darkSurface),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
              elevation: MaterialStatePropertyAll(3.0),
            ),
            textStyle: TextStyle(color: textSecondary, fontFamily: 'Roboto'),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            textStyle: TextStyle(color: textSecondary, fontFamily: 'Roboto'),
            elevation: 4.0,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.resolveWith((states) =>
                states.contains(MaterialState.selected)
                    ? primaryAccent
                    : textHint.withOpacity(0.2)),
            checkColor: MaterialStateProperty.all(primaryAccentForeground),
            side: BorderSide(color: textHint.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: primaryAccent,
                textStyle: TextStyle(
                    fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          ),
          cardTheme: CardThemeData(
            color: darkSurface.withOpacity(0.85),
            elevation: 2.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      home: AuthGate(),
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
      SizedBox(width: 10),
      Expanded(
          child: Text(message,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
    ]),
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(16, 10, 16, 10),
    elevation: 4.0,
    duration: Duration(seconds: 4),
  ));
}

// --- TELAS DE AUTENTICAÇÃO ---
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
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
                  Text('Faça o login para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BjjApp.textHint, fontSize: 16)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
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
                    decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline_rounded)),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6)
                        ? 'A senha deve ter pelo menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text('ENTRAR'),
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16)),
                    ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => RegisterAcademyPage(),
                      ));
                    },
                    child: Text('Não tem uma conta? Cadastre sua academia',
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
  const RegisterAcademyPage({Key? key}) : super(key: key);
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _academyNameController.dispose();
    _managerNameController.dispose();
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
        title: Text("Registrar Academia"),
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
                    decoration: InputDecoration(
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
                    decoration: InputDecoration(
                        labelText: 'Seu Nome Completo',
                        prefixIcon: Icon(Icons.person_rounded)),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'Por favor, insira o seu nome.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
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
                    decoration: InputDecoration(
                        labelText: 'Sua Senha',
                        prefixIcon: Icon(Icons.lock_outline_rounded)),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6)
                        ? 'A senha deve ter pelo menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text('CADASTRAR E CRIAR ACADEMIA'),
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16)),
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
  const AuthGate({Key? key}) : super(key: key);

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
          return LoginPage();
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
              return LoginPage();
            }

            final userModel = UserModel.fromFirestore(userDocSnapshot.data!);

            switch (userModel.role) {
              case UserRole.manager:
                return ManagerHomePage(user: userModel);
              case UserRole.teacher:
                return TeacherHomePage(user: userModel);
              case UserRole.student:
                return StudentHomePage(user: userModel);
              default:
                return LoginPage();
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
    Key? key,
    required this.icon,
    required this.title,
    this.message,
  }) : super(key: key);

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

// --- TELAS DO GERENTE ---
class ManagerHomePage extends StatefulWidget {
  final UserModel user;
  const ManagerHomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  int _paginaAtual = 0;
  late final List<Widget> _telas;

  @override
  void initState() {
    super.initState();
    _telas = [
      ManagerDashboardPage(user: widget.user),
      AlunosManagerPage(academyId: widget.user.academyId),
      ProfessoresManagerPage(academyId: widget.user.academyId),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _paginaAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        ],
      ),
    );
  }
}

class ManagerDashboardPage extends StatelessWidget {
  final UserModel user;
  const ManagerDashboardPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel Principal"),
        actions: [
          IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChangePasswordPage()))),
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.manage_accounts,
                  size: 80, color: BjjApp.primaryAccent),
              SizedBox(height: 20),
              Text('Bem-vindo, ${user.name}!',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              Text('ID da sua Academia: ${user.academyId}',
                  style: TextStyle(color: BjjApp.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}

class AlunosManagerPage extends StatefulWidget {
  final String academyId;
  const AlunosManagerPage({Key? key, required this.academyId})
      : super(key: key);

  @override
  State<AlunosManagerPage> createState() => _AlunosManagerPageState();
}

class _AlunosManagerPageState extends State<AlunosManagerPage> {
  Future<void> _adicionarAluno(Aluno novoAluno) async {
    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .add(novoAluno.toJson());

      if (mounted) {
        showBjjSnackBar(context, '${novoAluno.nome} adicionado com sucesso!',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao adicionar aluno: $e', type: 'error');
      }
    }
  }

  void _showCreateAccessDialog(Aluno aluno) {
    showDialog(
      context: context,
      builder: (_) => CreateStudentAccessDialog(
        academyId: widget.academyId,
        aluno: aluno,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gerenciar Alunos"),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('academies')
              .doc(widget.academyId)
              .collection('students')
              .orderBy('nome')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erro: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.no_accounts_rounded,
                title: 'Nenhum Aluno Cadastrado',
                message:
                    'Clique no botão "+" para adicionar o primeiro aluno da sua academia.',
              );
            }

            final alunos = snapshot.data!.docs.map((doc) {
              return Aluno.fromJson(doc.id, doc.data() as Map<String, dynamic>);
            }).toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
              itemCount: alunos.length,
              itemBuilder: (context, index) {
                final aluno = alunos[index];
                return Card(
                  child: ListTile(
                    title: Text(aluno.nome,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text('${aluno.faixa} - ${aluno.peso}kg'),
                    trailing: aluno.userId == null
                        ? TextButton(
                            child: Text("Criar Acesso"),
                            onPressed: () => _showCreateAccessDialog(aluno),
                          )
                        : Icon(Icons.check_circle, color: BjjApp.successColor),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) =>
                AdicionarAlunoDialog(onAlunoAdicionado: _adicionarAluno),
          );
        },
        child: Icon(Icons.add_rounded),
        tooltip: 'Adicionar Aluno',
      ),
    );
  }
}

class AdicionarAlunoDialog extends StatefulWidget {
  final Function(Aluno) onAlunoAdicionado;
  AdicionarAlunoDialog({required this.onAlunoAdicionado});
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
  final List<int> grausList = [1, 2, 3, 4, 5, 6];
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    bool mostrarGrausDropdown = fS != null;
    return AlertDialog(
      title: Text('Adicionar Novo Aluno'),
      content: SingleChildScrollView(
          child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: nC,
                    decoration: InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_add_alt_1_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nome inválido'
                        : null),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: fS,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: 'Faixa',
                        prefixIcon: Icon(Icons.shield_outlined)),
                    hint: Text("Selecione a Faixa"),
                    onChanged: (v) => setState(() {
                          fS = v;
                        }),
                    items: faixasList
                        .map((v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)))
                        .toList(),
                    validator: (v) => v == null ? 'Selecione uma faixa' : null),
                if (mostrarGrausDropdown) ...[
                  SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                      value: gS,
                      decoration: InputDecoration(
                          labelText: 'Graus (opcional)',
                          prefixIcon: Icon(Icons.star_outline_rounded)),
                      hint: Text("Graus (opcional)"),
                      onChanged: (v) => setState(() => gS = v),
                      items: [
                        DropdownMenuItem<int>(
                            value: null, child: Text("Nenhum")),
                        ...grausList.map((v) => DropdownMenuItem<int>(
                            value: v, child: Text('$vº Grau')))
                      ].toList())
                ],
                SizedBox(height: 16),
                TextFormField(
                    controller: pC,
                    decoration: InputDecoration(
                        labelText: 'Peso (kg)',
                        prefixIcon: Icon(Icons.fitness_center_rounded)),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
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
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop()),
        ElevatedButton.icon(
            icon: Icon(Icons.person_add_rounded, size: 18),
            label: Text('Adicionar'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                widget.onAlunoAdicionado(Aluno.novo(
                  nome: nC.text.trim(),
                  faixa: fS!,
                  peso: double.parse(pC.text.replaceAll(',', '.')),
                  graus: gS,
                ));
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
      {Key? key, required this.academyId, required this.aluno})
      : super(key: key);

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
      // Usar um nome de app temporário e único para evitar conflitos
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
        throw Exception("Falha ao criar a conta de autenticação.");
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
      });

      await batch.commit();
      await tempApp.delete(); // Limpar a instância temporária do app

      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text("Acesso Criado!"),
                  content: Text(
                      "A conta para ${widget.aluno.nome} foi criada.\n\nE-mail: $email\nSenha Temporária: $temporaryPassword\n\nPeça para que ele(a) faça o login."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("OK"))
                  ],
                ));
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao criar acesso.';
      if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está sendo usado por outra conta.';
      }
      if (mounted) showBjjSnackBar(context, message, type: 'error');
    } catch (e) {
      if (mounted)
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
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
          decoration: InputDecoration(
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
            child: Text("Cancelar")),
        ElevatedButton(
          onPressed: _isLoading ? null : _createAccess,
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text("Criar"),
        )
      ],
    );
  }
}

class ProfessoresManagerPage extends StatefulWidget {
  final String academyId;
  const ProfessoresManagerPage({Key? key, required this.academyId})
      : super(key: key);

  @override
  State<ProfessoresManagerPage> createState() => _ProfessoresManagerPageState();
}

class _ProfessoresManagerPageState extends State<ProfessoresManagerPage> {
  Future<void> _adicionarProfessor(String name, String email) async {
    const temporaryPassword = 'mudar123';

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
        throw Exception("Falha ao criar a conta de autenticação.");
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set({
        'name': name,
        'email': email,
        'academyId': widget.academyId,
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await tempApp.delete();

      if (mounted) {
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: Text("Professor Criado!"),
                  content: Text(
                      "A conta para $name foi criada.\n\nE-mail: $email\nSenha Temporária: $temporaryPassword\n\nPeça para que ele(a) faça o login e altere a senha."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("OK"))
                  ],
                ));
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
      if (mounted)
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gerenciar Professores"),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('academyId', isEqualTo: widget.academyId)
              .where('role', isEqualTo: 'teacher')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text("Erro: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.school_outlined,
                title: 'Nenhum Professor Cadastrado',
                message:
                    'Clique no botão "+" para adicionar o primeiro professor.',
              );
            }

            final professores = snapshot.data!.docs.map((doc) {
              return UserModel.fromFirestore(doc);
            }).toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
              itemCount: professores.length,
              itemBuilder: (context, index) {
                final professor = professores[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(Icons.school_rounded)),
                    title: Text(professor.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: Text(professor.email),
                    trailing: Icon(Icons.more_vert),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AdicionarProfessorDialog(
                onProfessorAdicionado: _adicionarProfessor),
          );
        },
        child: Icon(Icons.add_rounded),
        tooltip: 'Adicionar Professor',
      ),
    );
  }
}

class AdicionarProfessorDialog extends StatefulWidget {
  final Future<void> Function(String name, String email) onProfessorAdicionado;
  const AdicionarProfessorDialog(
      {Key? key, required this.onProfessorAdicionado})
      : super(key: key);

  @override
  State<AdicionarProfessorDialog> createState() =>
      _AdicionarProfessorDialogState();
}

class _AdicionarProfessorDialogState extends State<AdicionarProfessorDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      widget
          .onProfessorAdicionado(
              _nameController.text.trim(), _emailController.text.trim())
          .whenComplete(() {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adicionar Novo Professor'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nome do Professor',
                prefixIcon: Icon(Icons.person_add_alt_1_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nome inválido' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'E-mail (para login)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Adicionar'),
        ),
      ],
    );
  }
}

// --- TELAS DO PROFESSOR ---
class TeacherHomePage extends StatefulWidget {
  final UserModel user;
  const TeacherHomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _paginaAtual = 0;
  late final List<Widget> _telas;
  List<Aluno> _todosOsAlunosDaAcademia = [];
  bool _isLoadingAlunos = true;

  @override
  void initState() {
    super.initState();
    _fetchAlunosDaAcademia();
  }

  Future<void> _fetchAlunosDaAcademia() async {
    if (!mounted) return;
    setState(() => _isLoadingAlunos = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .orderBy('nome')
          .get();

      final alunos = snapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();
      if (mounted) {
        setState(() {
          _todosOsAlunosDaAcademia = alunos;
          _isLoadingAlunos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAlunos = false);
        showBjjSnackBar(context, 'Erro ao carregar lista de alunos.',
            type: 'error');
      }
    }
  }

  void _buildScreens() {
    _telas = [
      TeacherDashboardPage(user: widget.user),
      CheckinTeacherPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosOsAlunosDaAcademia),
      StudiesTeacherPage(user: widget.user),
      SorteioTeacherPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosOsAlunosDaAcademia),
      PlacarSetupPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosOsAlunosDaAcademia),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAlunos) {
      return const Scaffold(
          body:
              AppBackground(child: Center(child: CircularProgressIndicator())));
    }

    _buildScreens();

    return Scaffold(
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
            icon: Icon(Icons.check_circle_outline_rounded),
            label: 'Check-in',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_rounded),
            label: 'Estudos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shuffle_rounded),
            label: 'Sorteio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.scoreboard_rounded),
            label: 'Placar',
          ),
        ],
      ),
    );
  }
}

class TeacherDashboardPage extends StatelessWidget {
  final UserModel user;
  const TeacherDashboardPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Painel do Professor"), actions: [
        IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ChangePasswordPage()))),
        IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut()),
      ]),
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 80, color: BjjApp.successColor),
              SizedBox(height: 20),
              Text('Bem-vindo, Prof. ${user.name}!',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              Text(
                'Use a barra de navegação para gerenciar seus treinos.',
                style: TextStyle(color: BjjApp.textHint),
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
  final List<Aluno> todosAlunosDaAcademia;
  const CheckinTeacherPage(
      {Key? key, required this.academyId, required this.todosAlunosDaAcademia})
      : super(key: key);

  @override
  State<CheckinTeacherPage> createState() => _CheckinTeacherPageState();
}

class _CheckinTeacherPageState extends State<CheckinTeacherPage> {
  Aluno? _alunoSelecionado;

  Future<void> _saveCheckin(DateTime date) async {
    if (_alunoSelecionado == null) return;
    final dateOnly = DateTime(date.year, date.month, date.day);

    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins');

    final querySnapshot = await checkinRef
        .where('studentId', isEqualTo: _alunoSelecionado!.id)
        .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      await checkinRef.add({
        'studentId': _alunoSelecionado!.id,
        'date': Timestamp.fromDate(dateOnly),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showBjjSnackBar(
            context, 'Check-in para ${_alunoSelecionado!.nome} salvo!',
            type: 'success');
      }
    } else {
      if (mounted) {
        showBjjSnackBar(context, 'Este aluno já possui check-in neste dia.',
            type: 'warning');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Check-in de Presença"),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        DropdownButtonFormField<Aluno>(
                          value: _alunoSelecionado,
                          isExpanded: true,
                          decoration:
                              InputDecoration(labelText: 'Selecione o Aluno'),
                          items: widget.todosAlunosDaAcademia.map((aluno) {
                            return DropdownMenuItem<Aluno>(
                              value: aluno,
                              child: Text(aluno.nome,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (aluno) =>
                              setState(() => _alunoSelecionado = aluno),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: Icon(Icons.check_circle_outline_rounded),
                          label: Text('Fazer Check-in Hoje'),
                          onPressed: _alunoSelecionado == null
                              ? null
                              : () => _saveCheckin(DateTime.now()),
                          style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 48)),
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            icon: Icon(Icons.leaderboard_rounded,
                                color: BjjApp.primaryAccent),
                            label: Text('Ver Ranking de Presença'),
                            onPressed: () {
                              if (widget.todosAlunosDaAcademia.isEmpty) {
                                showBjjSnackBar(
                                    context, 'Cadastre alunos primeiro.',
                                    type: 'info');
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RankingTeacherPage(
                                      academyId: widget.academyId),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RankingTeacherPage extends StatefulWidget {
  final String academyId;
  const RankingTeacherPage({Key? key, required this.academyId})
      : super(key: key);

  @override
  State<RankingTeacherPage> createState() => _RankingTeacherPageState();
}

class _RankingTeacherPageState extends State<RankingTeacherPage> {
  Map<String, int> _checkinCounts = {};
  List<Aluno> _todosAlunos = [];
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
      final alunosSnapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .get();
      final fetchedAlunos = alunosSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      final checkinsSnapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('checkins')
          .get();
      final allCheckins = checkinsSnapshot.docs
          .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
          .toList();

      final now = DateTime.now();
      final Map<String, int> counts = {
        for (var aluno in fetchedAlunos) aluno.id: 0
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
          _todosAlunos = fetchedAlunos;
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
    final rankedAlunos = List<Aluno>.from(_todosAlunos);
    rankedAlunos.sort((a, b) {
      final countA = _checkinCounts[a.id] ?? 0;
      final countB = _checkinCounts[b.id] ?? 0;
      return countB.compareTo(countA) != 0
          ? countB.compareTo(countA)
          : a.nome.compareTo(b.nome);
    });

    return Scaffold(
      appBar: AppBar(title: Text('Ranking de Presença')),
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
                  ? Center(child: CircularProgressIndicator())
                  : rankedAlunos.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.group_off_rounded,
                          title: "Nenhum aluno encontrado.")
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 16.0),
                          itemCount: rankedAlunos.length,
                          itemBuilder: (context, index) {
                            final aluno = rankedAlunos[index];
                            final count = _checkinCounts[aluno.id] ?? 0;
                            final rank = index + 1;
                            Widget leadingIcon;
                            if (rank == 1)
                              leadingIcon = Icon(Icons.emoji_events,
                                  color: BjjApp.primaryAccent, size: 30);
                            else if (rank == 2)
                              leadingIcon = Icon(Icons.emoji_events,
                                  color: Color(0xFFC0C0C0), size: 28);
                            else if (rank == 3)
                              leadingIcon = Icon(Icons.emoji_events,
                                  color: Color(0xFFCD7F32), size: 26);
                            else
                              leadingIcon = CircleAvatar(
                                  radius: 14,
                                  backgroundColor: BjjApp.darkSurface,
                                  child: Text('$rank',
                                      style: TextStyle(
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
                                    style: TextStyle(
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

class StudiesTeacherPage extends StatelessWidget {
  final UserModel user;
  const StudiesTeacherPage({Key? key, required this.user}) : super(key: key);

  void _navigateToStudyDetails(BuildContext context,
      {StudyInstructional? study}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditStudyPage(user: user, study: study),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Cadernos de Estudo"),
        actions: [
          IconButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: Icon(Icons.logout))
        ],
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('academies')
              .doc(user.academyId)
              .collection('instructionals')
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return EmptyStateWidget(
                  icon: Icons.book_outlined,
                  title: "Nenhum Estudo Criado",
                  message:
                      "Clique no '+' para criar o primeiro caderno de estudos.");

            final studiesDocs = snapshot.data!.docs;

            final visibleStudies = studiesDocs.where((doc) {
              final study = StudyInstructional.fromFirestore(doc);
              return study.visibility == 'public' ||
                  study.createdByUid == user.uid;
            }).toList();

            if (visibleStudies.isEmpty)
              return EmptyStateWidget(
                  icon: Icons.book_outlined,
                  title: "Nenhum Estudo Para Mostrar",
                  message:
                      "Crie um novo estudo ou peça para outros professores tornarem os seus públicos.");

            return ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: visibleStudies.length,
              itemBuilder: (context, index) {
                final study =
                    StudyInstructional.fromFirestore(visibleStudies[index]);
                final bool isOwner = study.createdByUid == user.uid;

                return Card(
                  child: ListTile(
                    leading: Icon(study.visibility == 'public'
                        ? Icons.public_rounded
                        : Icons.lock_person_rounded),
                    title: Text(study.title),
                    subtitle: Text("Criado por: ${study.createdByName}"),
                    trailing:
                        isOwner ? Icon(Icons.edit) : Icon(Icons.visibility),
                    onTap: () {
                      if (isOwner) {
                        _navigateToStudyDetails(context, study: study);
                      } else {
                        // Navega para a tela de visualização para o professor também
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => StudyDetailViewPage(study: study)));
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToStudyDetails(context),
        child: Icon(Icons.add),
        tooltip: 'Criar Novo Estudo',
      ),
    );
  }
}

class EditStudyPage extends StatefulWidget {
  final UserModel user;
  final StudyInstructional? study;
  const EditStudyPage({Key? key, required this.user, this.study})
      : super(key: key);

  @override
  State<EditStudyPage> createState() => _EditStudyPageState();
}

class _EditStudyPageState extends State<EditStudyPage> {
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPublic = false;
  List<StudyNote> _notes = [];

  @override
  void initState() {
    super.initState();
    if (widget.study != null) {
      _titleController.text = widget.study!.title;
      _isPublic = widget.study!.visibility == 'public';
      _notes = List<StudyNote>.from(widget.study!.notes);
    }
  }

  Future<void> _saveStudy() async {
    if (!_formKey.currentState!.validate()) return;

    final studyData = {
      'title': _titleController.text.trim(),
      'createdByUid': widget.user.uid,
      'createdByName': widget.user.name,
      'visibility': _isPublic ? 'public' : 'private',
      'notes': _notes.map((note) => note.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final collection = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('instructionals');

    try {
      if (widget.study == null) {
        await collection.add(studyData);
        showBjjSnackBar(context, 'Estudo criado com sucesso!', type: 'success');
      } else {
        await collection.doc(widget.study!.id).update(studyData);
        showBjjSnackBar(context, 'Estudo atualizado!', type: 'success');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted)
        showBjjSnackBar(context, 'Erro ao salvar estudo: $e', type: 'error');
    }
  }

  void _showNoteDialog({StudyNote? note, int? index}) async {
    final result = await showDialog<StudyNote>(
      context: context,
      builder: (_) => NoteEditDialog(note: note),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _notes[index] = result;
        } else {
          _notes.add(result);
        }
      });
    }
  }

  void _deleteNote(int index) {
    setState(() {
      _notes.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.study == null ? "Novo Estudo" : "Editar Estudo"),
        actions: [IconButton(icon: Icon(Icons.save), onPressed: _saveStudy)],
      ),
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration:
                          InputDecoration(labelText: 'Título do Caderno'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Título não pode ser vazio'
                          : null,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text("Público para a Academia"),
                      subtitle: Text(
                          "Se ativo, alunos e outros professores poderão ver."),
                      value: _isPublic,
                      onChanged: (val) => setState(() => _isPublic = val),
                      secondary: Icon(_isPublic
                          ? Icons.public_rounded
                          : Icons.lock_person_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              Expanded(
                  child: _notes.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: OutlinedButton.icon(
                              icon: Icon(Icons.add),
                              label: Text("Adicionar Primeira Anotação"),
                              onPressed: () => _showNoteDialog(),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(8, 16, 8, 80),
                          itemCount: _notes.length + 1,
                          separatorBuilder: (_, __) => SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            if (index == _notes.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.add),
                                  label: Text("Adicionar Anotação"),
                                  onPressed: () => _showNoteDialog(),
                                ),
                              );
                            }
                            final note = _notes[index];
                            return Card(
                              child: ListTile(
                                title: Text(note.title),
                                subtitle: Text(note.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: BjjApp.errorColor),
                                    onPressed: () => _deleteNote(index)),
                                onTap: () =>
                                    _showNoteDialog(note: note, index: index),
                              ),
                            );
                          },
                        )),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteEditDialog extends StatefulWidget {
  final StudyNote? note;
  const NoteEditDialog({Key? key, this.note}) : super(key: key);

  @override
  State<NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<NoteEditDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _descController.text = widget.note!.description;
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newNote = StudyNote(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
      );
      Navigator.of(context).pop(newNote);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? "Nova Anotação" : "Editar Anotação"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration:
                    InputDecoration(labelText: "Título (Ex: Kimura da Guarda)"),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Título é obrigatório"
                    : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(labelText: "Descrição / Detalhes"),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? "Descrição é obrigatória"
                    : null,
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancelar")),
        ElevatedButton(onPressed: _save, child: Text("Salvar")),
      ],
    );
  }
}

class SorteioTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosAlunosDaAcademia;

  const SorteioTeacherPage(
      {Key? key, required this.academyId, required this.todosAlunosDaAcademia})
      : super(key: key);

  @override
  State<SorteioTeacherPage> createState() => _SorteioTeacherPageState();
}

class _SorteioTeacherPageState extends State<SorteioTeacherPage> {
  List<Aluno> _alunosParticipantes = [];
  List<Luta> _lutasGeradas = [];

  void _atualizarAlunosParticipantes(List<Aluno> novosParticipantes) {
    setState(() {
      _alunosParticipantes = novosParticipantes;
      _lutasGeradas = [];
    });
  }

  Future<void> _navegarParaSelecaoAlunos() async {
    final List<Aluno>? r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SelecaoAlunosTeacherPage(
        todosOsAlunos: widget.todosAlunosDaAcademia,
        alunosSelecionadosIniciais: _alunosParticipantes,
      ),
    ));
    if (r != null) {
      _atualizarAlunosParticipantes(r);
    }
  }

  void _gerarRodadas() {
    if (_alunosParticipantes.length < 2) return;
    List<Luta> lutas = [];
    List<Aluno> listaSorteio = List.from(_alunosParticipantes);
    listaSorteio.shuffle();

    while (listaSorteio.length >= 2) {
      lutas.add(Luta(listaSorteio.removeAt(0), listaSorteio.removeAt(0), 0));
    }

    setState(() {
      _lutasGeradas = lutas;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sorteio de Duplas"),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: AppBackground(
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
                      Text(
                        '1. Alunos para o Treino (${_alunosParticipantes.length})',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: BjjApp.primaryAccent),
                      ),
                      SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: Icon(Icons.group_add_outlined),
                        label: Text('Selecionar / Alterar Alunos'),
                        onPressed: _navegarParaSelecaoAlunos,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.shuffle),
                        label: Text('Gerar Lutas Aleatórias'),
                        onPressed: _alunosParticipantes.length < 2
                            ? null
                            : _gerarRodadas,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
                child: _lutasGeradas.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.people_outline,
                        title: "Nenhuma Luta Gerada",
                        message: "Selecione os alunos e gere as lutas.")
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _lutasGeradas.length,
                        itemBuilder: (context, index) {
                          final luta = _lutasGeradas[index];
                          return Card(
                              child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text(luta.aluno1.nome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                Icon(Icons.close, color: BjjApp.primaryAccent),
                                Text(luta.aluno2.nome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                              ],
                            ),
                          ));
                        },
                      ))
          ],
        ),
      ),
    );
  }
}

class SelecaoAlunosTeacherPage extends StatefulWidget {
  final List<Aluno> todosOsAlunos;
  final List<Aluno> alunosSelecionadosIniciais;
  SelecaoAlunosTeacherPage(
      {required this.todosOsAlunos, required this.alunosSelecionadosIniciais});
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
        title: Text('Selecionar Alunos para o Treino'),
      ),
      body: AppBackground(
        child: widget.todosOsAlunos.isEmpty
            ? EmptyStateWidget(
                icon: Icons.person_search_rounded,
                title: 'Nenhum Aluno Cadastrado na Academia')
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
                        if (v == true)
                          _alunosAtuaisSelecionados.add(a);
                        else
                          _alunosAtuaisSelecionados.remove(a);
                      }),
                      secondary: Icon(Icons.person),
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

class PlacarSetupPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosAlunosDaAcademia;
  const PlacarSetupPage(
      {Key? key, required this.academyId, required this.todosAlunosDaAcademia})
      : super(key: key);

  @override
  State<PlacarSetupPage> createState() => _PlacarSetupPageState();
}

class _PlacarSetupPageState extends State<PlacarSetupPage> {
  Aluno? _selectedAluno1;
  Aluno? _selectedAluno2;

  void _startMatch() {
    if (_selectedAluno1 == null || _selectedAluno2 == null) {
      showBjjSnackBar(context, 'Selecione os dois atletas.', type: 'warning');
      return;
    }
    if (_selectedAluno1!.id == _selectedAluno2!.id) {
      showBjjSnackBar(context, 'Os atletas devem ser diferentes.',
          type: 'warning');
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => ScoreboardPage(
              aluno1: _selectedAluno1!,
              aluno2: _selectedAluno2!,
            )));
  }

  @override
  Widget build(BuildContext context) {
    List<Aluno> availableForPlayer2 = List.from(widget.todosAlunosDaAcademia);
    if (_selectedAluno1 != null) {
      availableForPlayer2.remove(_selectedAluno1);
    }
    if (_selectedAluno2 != null &&
        availableForPlayer2.indexWhere((a) => a.id == _selectedAluno2!.id) ==
            -1) {
      _selectedAluno2 = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Placar Individual"),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<Aluno>(
                        value: _selectedAluno1,
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: 'Selecione o Atleta 1'),
                        items: widget.todosAlunosDaAcademia
                            .map((aluno) => DropdownMenuItem<Aluno>(
                                value: aluno, child: Text(aluno.nome)))
                            .toList(),
                        onChanged: (aluno) => setState(() {
                          _selectedAluno1 = aluno;
                          if (_selectedAluno2 != null &&
                              _selectedAluno2!.id == aluno!.id) {
                            _selectedAluno2 = null;
                          }
                        }),
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<Aluno>(
                        value: _selectedAluno2,
                        isExpanded: true,
                        decoration:
                            InputDecoration(labelText: 'Selecione o Atleta 2'),
                        items: availableForPlayer2
                            .map((aluno) => DropdownMenuItem<Aluno>(
                                value: aluno, child: Text(aluno.nome)))
                            .toList(),
                        onChanged: (aluno) =>
                            setState(() => _selectedAluno2 = aluno),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.play_arrow_rounded),
                label: Text('Iniciar Luta'),
                onPressed: _startMatch,
                style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  final Aluno aluno1;
  final Aluno aluno2;
  const ScoreboardPage({
    Key? key,
    required this.aluno1,
    required this.aluno2,
  }) : super(key: key);
  @override
  _ScoreboardPageState createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  int p1 = 0, p2 = 0, v1 = 0, v2 = 0, m1 = 0, m2 = 0;
  Timer? _timer;
  int _start = 300; // 5 minutos
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          timer.cancel();
          _isRunning = false;
        });
      } else {
        setState(() => _start--);
      }
    });
  }

  void _pauseTimer() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() => _isRunning = false);
    }
  }

  void _resetTimer() {
    _pauseTimer();
    setState(() => _start = 300);
  }

  String get _timerString {
    final dur = Duration(seconds: _start);
    return "${dur.inMinutes.toString().padLeft(2, '0')}:${(dur.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
            child: Column(
          children: [
            // Placar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildPlayerSide(widget.aluno1, 1, p1, v1, m1),
                  _buildPlayerSide(widget.aluno2, 2, p2, v2, m2, isRight: true),
                ],
              ),
            ),
            // Controles
            Expanded(
              flex: 2,
              child: Container(
                color: BjjApp.darkSurface.withAlpha(200),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPointControls(1),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_timerString,
                            style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        Row(
                          children: [
                            IconButton(
                                onPressed:
                                    _isRunning ? _pauseTimer : _startTimer,
                                icon: Icon(
                                    _isRunning
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_filled,
                                    size: 40,
                                    color: BjjApp.primaryAccent)),
                            IconButton(
                                onPressed: _resetTimer,
                                icon: Icon(Icons.replay_circle_filled,
                                    size: 40, color: BjjApp.textHint)),
                            IconButton(
                                onPressed: _resetScore,
                                icon: Icon(Icons.refresh,
                                    size: 40, color: Colors.white)),
                          ],
                        )
                      ],
                    ),
                    _buildPointControls(2),
                  ],
                ),
              ),
            )
          ],
        )),
      ),
    );
  }

  void _resetScore() {
    setState(() {
      p1 = 0;
      p2 = 0;
      v1 = 0;
      v2 = 0;
      m1 = 0;
      m2 = 0;
    });
  }

  Widget _buildPlayerSide(Aluno a, int player, int p, int v, int m,
      {bool isRight = false}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: isRight
              ? Border(left: BorderSide(color: BjjApp.borderNormal, width: 2))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(a.nome,
                style: TextStyle(fontSize: 22, color: Colors.white),
                textAlign: TextAlign.center),
            Text('$p',
                style: TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1),
                textAlign: TextAlign.center),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("V: $v",
                    style: TextStyle(fontSize: 20, color: BjjApp.successColor)),
                Text("P: $m",
                    style: TextStyle(fontSize: 20, color: BjjApp.errorColor)),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _updateScore(int p, int v, int m, int player) {
    setState(() {
      if (player == 1) {
        p1 += p;
        v1 += v;
        m1 += m;
      } else {
        p2 += p;
        v2 += v;
        m2 += m;
      }
    });
  }

  Widget _buildPointControls(int player) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
            child: Text("+2"), onPressed: () => _updateScore(2, 0, 0, player)),
        SizedBox(height: 8),
        ElevatedButton(
            child: Text("+3"), onPressed: () => _updateScore(3, 0, 0, player)),
        SizedBox(height: 8),
        ElevatedButton(
            child: Text("+4"), onPressed: () => _updateScore(4, 0, 0, player)),
        SizedBox(height: 8),
        Row(children: [
          ElevatedButton(
              child: Text("+V"),
              onPressed: () => _updateScore(0, 1, 0, player),
              style: ElevatedButton.styleFrom(
                  backgroundColor: BjjApp.successColor)),
          SizedBox(width: 8),
          ElevatedButton(
              child: Text("+P"),
              onPressed: () => _updateScore(0, 0, 1, player),
              style:
                  ElevatedButton.styleFrom(backgroundColor: BjjApp.errorColor)),
        ]),
      ],
    );
  }
}

// --- TELAS DO ALUNO ---
class StudentHomePage extends StatefulWidget {
  final UserModel user;
  const StudentHomePage({Key? key, required this.user}) : super(key: key);

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _paginaAtual = 0;
  late final List<Widget> _telas;
  List<Aluno> _todosOsAlunosDaAcademia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .get();
      final alunos = snapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      if (mounted) {
        setState(() {
          _todosOsAlunosDaAcademia = alunos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar dados da academia.',
            type: 'error');
      }
    }
  }

  void _buildScreens() {
    _telas = [
      StudentDashboardPage(user: widget.user),
      MyCheckinsPage(user: widget.user),
      StudiesStudentPage(user: widget.user),
      PlacarSetupPage(
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
    _buildScreens();
    return Scaffold(
      body: IndexedStack(index: _paginaAtual, children: _telas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (index) => setState(() => _paginaAtual = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Início'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded),
              label: 'Meus Check-ins'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded), label: 'Estudos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.scoreboard_rounded), label: 'Placar'),
        ],
      ),
    );
  }
}

class StudentDashboardPage extends StatelessWidget {
  final UserModel user;
  const StudentDashboardPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Minha Área"), actions: [
        IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => ChangePasswordPage()))),
        IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut()),
      ]),
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 80, color: BjjApp.infoColor),
              SizedBox(height: 20),
              Text('Bem-vindo, ${user.name}!',
                  style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 10),
              Text('Aqui você pode acompanhar seu progresso.',
                  style: TextStyle(color: BjjApp.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}

class MyCheckinsPage extends StatefulWidget {
  final UserModel user;
  const MyCheckinsPage({Key? key, required this.user}) : super(key: key);

  @override
  State<MyCheckinsPage> createState() => _MyCheckinsPageState();
}

class _MyCheckinsPageState extends State<MyCheckinsPage> {
  Map<DateTime, List<CheckinEntry>> _eventosAgrupados = {};
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final studentId = widget.user.studentRecordId;
    if (studentId == null) {
      return Scaffold(
          appBar: AppBar(title: Text("Meus Check-ins")),
          body: EmptyStateWidget(
              icon: Icons.link_off,
              title: "Perfil não vinculado",
              message:
                  "Seu login não está vinculado a um registro de aluno. Peça ao seu professor ou gerente para criar seu acesso."));
    }

    return Scaffold(
      appBar: AppBar(title: Text("Meus Check-ins"), actions: [
        IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut())
      ]),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('academies')
              .doc(widget.user.academyId)
              .collection('checkins')
              .where('studentId', isEqualTo: studentId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            final checkins = snapshot.data?.docs
                    .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
                    .toList() ??
                [];
            _eventosAgrupados = {};
            for (var checkin in checkins) {
              final dataNormalizada = DateTime.utc(
                  checkin.date.year, checkin.date.month, checkin.date.day);
              if (_eventosAgrupados[dataNormalizada] == null)
                _eventosAgrupados[dataNormalizada] = [];
              _eventosAgrupados[dataNormalizada]!.add(checkin);
            }

            return TableCalendar<CheckinEntry>(
              locale: 'pt_BR',
              firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
              lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              eventLoader: (day) =>
                  _eventosAgrupados[
                      DateTime.utc(day.year, day.month, day.day)] ??
                  [],
              onPageChanged: (focusedDay) =>
                  setState(() => _focusedDay = focusedDay),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                    color: BjjApp.primaryAccent.withOpacity(0.3),
                    shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(
                    color: BjjApp.primaryAccent, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(
                    color: BjjApp.successColor, shape: BoxShape.circle),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StudiesStudentPage extends StatelessWidget {
  final UserModel user;
  const StudiesStudentPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Estudos da Academia"),
        actions: [
          IconButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: Icon(Icons.logout))
        ],
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('academies')
              .doc(user.academyId)
              .collection('instructionals')
              .where('visibility', isEqualTo: 'public')
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return EmptyStateWidget(
                  icon: Icons.book_outlined,
                  title: "Nenhum Estudo Público",
                  message:
                      "Peça aos seus professores para publicarem seus cadernos de estudo.");

            final studies = snapshot.data!.docs
                .map((doc) => StudyInstructional.fromFirestore(doc))
                .toList();

            return ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: studies.length,
              itemBuilder: (context, index) {
                final study = studies[index];
                return Card(
                  child: ListTile(
                    leading:
                        Icon(Icons.public_rounded, color: BjjApp.infoColor),
                    title: Text(study.title),
                    subtitle: Text("Criado por: ${study.createdByName}"),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => StudyDetailViewPage(study: study)));
                    },
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

class StudyDetailViewPage extends StatelessWidget {
  final StudyInstructional study;
  const StudyDetailViewPage({Key? key, required this.study}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(study.title),
      ),
      body: AppBackground(
        child: study.notes.isEmpty
            ? EmptyStateWidget(
                icon: Icons.notes,
                title: "Nenhuma Anotação",
                message: "Este caderno de estudos ainda não possui anotações.")
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: study.notes.length,
                itemBuilder: (context, index) {
                  final note = study.notes[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(note.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          Divider(height: 16),
                          Text(note.description,
                              style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  );
                }),
      ),
    );
  }
}

// --- TELA DE TROCA DE SENHA ---
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

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
      showBjjSnackBar(context, "Usuário não encontrado.", type: "error");
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
      if (mounted) {
        showBjjSnackBar(context, "Senha alterada com sucesso!",
            type: "success");
        Navigator.of(context).pop();
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
      if (mounted) showBjjSnackBar(context, "Erro inesperado.", type: "error");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Alterar Senha")),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPasswordController,
                    decoration: InputDecoration(labelText: 'Senha Atual'),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Campo obrigatório" : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(labelText: 'Nova Senha'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6)
                        ? "Mínimo 6 caracteres"
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    decoration:
                        InputDecoration(labelText: 'Confirme a Nova Senha'),
                    obscureText: true,
                    validator: (v) => v != _newPasswordController.text
                        ? "As senhas não coincidem"
                        : null,
                  ),
                  SizedBox(height: 24),
                  if (_isLoading)
                    CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _changePassword,
                      child: Text("Salvar Nova Senha"),
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50)),
                    )
                ],
              ),
            ),
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
    BjjApp(),
  );
}
