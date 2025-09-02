// lib/auth_gate.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unused_import, unnecessary_import, unnecessary_brace_in_string_interps

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'manager_module.dart';
import 'teacher_module.dart';
import 'student_module.dart';
import 'update_checker.dart';
import 'super_admin_module.dart';
import 'dev_quick_login.dart';

// --- CLASSE DE CONFIGURAÇÃO ---
class EnvConfig {
  static const _flavor = String.fromEnvironment('FLAVOR');

  // --- SEUS UIDs JÁ ESTÃO AQUI ---
  static const _devAdminUid = "rwq5LYtBxLU9o54h0wNN2H1hHJ02";
  static const _prodAdminUid = "tV5CXlYjQcOdD4dOqMUc4Ac5Odw1";
  // -----------------------------

  static String get superAdminUid {
    if (_flavor == 'prod') {
      return _prodAdminUid;
    }
    return _devAdminUid;
  }

  // *** NOVA FUNÇÃO PARA VERIFICAR O AMBIENTE ***
  static bool isProd() {
    return _flavor == 'prod';
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker(context: context).checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    const loadingScaffold = Scaffold(
        body: AppBackground(child: Center(child: CircularProgressIndicator())));

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return loadingScaffold;
        }

        if (!authSnapshot.hasData || authSnapshot.data == null) {
          // *** LÓGICA ALTERADA PARA USAR O FLAVOR ***
          // Se o flavor for 'prod', mostra a tela de login normal.
          // Caso contrário, mostra a tela de atalhos de desenvolvimento.
          if (EnvConfig.isProd()) {
            return const LoginPage();
          } else {
            return const DevQuickLoginPage();
          }
        }

        final authUser = authSnapshot.data!;

        if (authUser.uid == EnvConfig.superAdminUid) {
          return FutureBuilder<DocumentSnapshot?>(
            future: _getImpersonationSession(authUser.uid),
            builder: (context, impersonationSnapshot) {
              if (impersonationSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return loadingScaffold;
              }

              final impersonationDoc = impersonationSnapshot.data;

              if (impersonationDoc != null && impersonationDoc.exists) {
                final targetUid = impersonationDoc.get('targetUid');
                return _buildUserFlow(targetUid, isImpersonating: true);
              } else {
                return const SuperAdminPage();
              }
            },
          );
        } else {
          return _buildUserFlow(authUser.uid, isImpersonating: false);
        }
      },
    );
  }

  Future<DocumentSnapshot?> _getImpersonationSession(String uid) async {
    if (uid != EnvConfig.superAdminUid) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('impersonation_sessions')
          .doc(uid)
          .get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildUserFlow(String uid, {required bool isImpersonating}) {
    const loadingScaffold = Scaffold(
        body: AppBackground(child: Center(child: CircularProgressIndicator())));

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userDocSnapshot) {
        if (userDocSnapshot.connectionState == ConnectionState.waiting) {
          return loadingScaffold;
        }

        if (userDocSnapshot.hasError ||
            !userDocSnapshot.hasData ||
            !userDocSnapshot.data!.exists) {
          FirebaseAuth.instance.signOut();
          return const LoginPage();
        }

        final userModel = UserModel.fromFirestore(userDocSnapshot.data!);

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('academies')
              .doc(userModel.academyId)
              .get(),
          builder: (context, academySnapshot) {
            if (academySnapshot.connectionState == ConnectionState.waiting) {
              return loadingScaffold;
            }

            if (!academySnapshot.hasData || !academySnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            final academyData =
                academySnapshot.data!.data() as Map<String, dynamic>;
            final academyStatus = academyData['status'] ?? 'active';
            final subscriptionEndDate =
                (academyData['subscriptionEndDate'] as Timestamp?)?.toDate();

            if (academyStatus != 'active') {
              return const SuspendedAcademyPage();
            }

            if (subscriptionEndDate != null &&
                DateTime.now().isAfter(subscriptionEndDate)) {
              return const SuspendedAcademyPage(isSubscriptionExpired: true);
            }

            if (userModel.mustChangePassword) {
              return ChangePasswordPage(isFirstLogin: true, user: userModel);
            }

            switch (userModel.role) {
              case UserRole.manager:
                return ManagerHomePage(
                    user: userModel, isImpersonating: isImpersonating);
              case UserRole.teacher:
                return TeacherHomePage(
                    user: userModel, isImpersonating: isImpersonating);
              case UserRole.student:
                return StudentHomePage(
                    user: userModel, isImpersonating: isImpersonating);
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

class SuspendedAcademyPage extends StatefulWidget {
  final bool isSubscriptionExpired;
  const SuspendedAcademyPage({super.key, this.isSubscriptionExpired = false});

  @override
  State<SuspendedAcademyPage> createState() => _SuspendedAcademyPageState();
}

class _SuspendedAcademyPageState extends State<SuspendedAcademyPage> {
  String? _supportPhoneNumber;
  bool _isLoadingSupportNumber = true;

  @override
  void initState() {
    super.initState();
    _fetchSupportNumber();
  }

  Future<void> _fetchSupportNumber() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('global_settings')
          .doc('support')
          .get();
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _supportPhoneNumber = doc.data()!['whatsapp_number'];
        });
      }
    } catch (e) {
      // Fail silently, the button just won't appear
      debugPrint("Could not fetch support number: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSupportNumber = false;
        });
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    if (_supportPhoneNumber == null || _supportPhoneNumber!.isEmpty) {
      showBjjSnackBar(context, 'Número de suporte não configurado.',
          type: 'error');
      return;
    }
    final message = Uri.encodeComponent(
        'Olá, preciso de ajuda para acessar minha conta no Match BJJ.');
    final whatsappUrl =
        Uri.parse("https://wa.me/${_supportPhoneNumber}?text=$message");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      showBjjSnackBar(context, 'Não foi possível abrir o WhatsApp.',
          type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSubscriptionExpired
        ? 'Assinatura Expirada'
        : 'Acesso Suspenso';
    final message = widget.isSubscriptionExpired
        ? 'A assinatura da sua academia expirou. Por favor, peça ao administrador para regularizar a situação.'
        : 'O acesso para sua academia foi suspenso. Por favor, entre em contato com o suporte para mais informações.';

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 80, color: warningColor),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textHint, fontSize: 16),
                ),
                const SizedBox(height: 32),
                if (!_isLoadingSupportNumber &&
                    _supportPhoneNumber != null &&
                    _supportPhoneNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Falar com o Suporte'),
                      onPressed: _launchWhatsApp,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: successColor,
                        side: const BorderSide(color: successColor),
                      ),
                    ),
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair'),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
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

  Future<void> _resetPassword() async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        bool dialogIsLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Redefinir Senha"),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        "Digite seu e-mail para receber o link de redefinição."),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'E-mail inválido'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancelar"),
                ),
                if (dialogIsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: CircularProgressIndicator(),
                  )
                else
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        setDialogState(() => dialogIsLoading = true);
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(
                              email: emailController.text.trim());
                          if (mounted) {
                            showBjjSnackBar(context,
                                "Link de redefinição enviado para seu e-mail.",
                                type: 'success');
                            Navigator.of(context).pop();
                          }
                        } on FirebaseAuthException catch (e) {
                          String message = 'Ocorreu um erro.';
                          if (e.code == 'user-not-found') {
                            message =
                                'Nenhum usuário encontrado com este e-mail.';
                          }
                          if (mounted) {
                            showBjjSnackBar(context, message, type: 'error');
                          }
                        } finally {
                          if (mounted) {
                            setDialogState(() => dialogIsLoading = false);
                          }
                        }
                      }
                    },
                    child: const Text("Enviar"),
                  ),
              ],
            );
          },
        );
      },
    );
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
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 38)),
                  const SizedBox(height: 8),
                  const Text('Faça o login para continuar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textHint, fontSize: 16)),
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
                    onPressed: _resetPassword,
                    child: const Text('Esqueci minha senha',
                        style: TextStyle(color: textHint)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => const RegisterAcademyPage(),
                      ));
                    },
                    child: const Text(
                        'Não tem uma conta? Cadastre sua academia',
                        style: TextStyle(color: textHint)),
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
  State<RegisterAcademyPage> createState() => _RegisterAcademyPageState();
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
      final managerName = _managerNameController.text.trim().capitalizeWords();

      batch.set(academyRef, {
        'name': _academyNameController.text.trim(),
        'plan': 'premium',
        'ownerId': newUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
        'subscriptionEndDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      batch.set(userRef, {
        'name': managerName,
        'email': newUser.email,
        'academyId': academyRef.id,
        'role': 'manager',
        'faixa': _faixa,
        'graus': _graus,
        'peso': null,
        'mustChangePassword': false,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': newUser.uid,
        'createdByName': managerName,
        'lastUpdatedByUid': newUser.uid,
        'lastUpdatedByName': managerName,
      });

      final historyEntry = GraduationHistory(
        id: '',
        belt: _faixa!,
        degree: _graus,
        date: DateTime.now(),
        promotedByUid: newUser.uid,
        promotedByName: managerName,
      );
      final historyRef = userRef.collection('graduation_history').doc();
      batch.set(historyRef, historyEntry.toMap());

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

class ChangePasswordPage extends StatefulWidget {
  final bool isFirstLogin;
  final UserModel? user;

  const ChangePasswordPage({
    super.key,
    this.isFirstLogin = false,
    this.user,
  });

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
          if (widget.user!.role == UserRole.student) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => EditStudentProfilePage(
                        user: widget.user!,
                        isFirstLogin: true,
                      )),
              (route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => EditUserProfilePage(
                        user: widget.user!,
                        isFirstLogin: true,
                      )),
              (route) => false,
            );
          }
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
                          style: TextStyle(color: textHint),
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
                      decoration:
                          const InputDecoration(labelText: 'Nova Senha'),
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? "Mínimo 6 caracteres"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                          labelText: 'Confirme a Nova Senha'),
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

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    final newEmail = _newEmailController.text.trim();

    if (user == null || user.email == null) {
      if (mounted) {
        showBjjSnackBar(context, "Usuário não encontrado.", type: "error");
      }
      setState(() => _isLoading = false);
      return;
    }

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: _passwordController.text,
    );

    try {
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);

      if (mounted) {
        showBjjSnackBar(context,
            "Link de confirmação enviado para $newEmail. Verifique sua caixa de entrada para finalizar a alteração.",
            type: "success");
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = "Ocorreu um erro.";
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = "A senha atual está incorreta.";
        } else if (e.code == 'email-already-in-use') {
          message = "Este e-mail já está em uso por outra conta.";
        } else if (e.code == 'invalid-email') {
          message = "O novo e-mail fornecido é inválido.";
        } else if (e.code == 'requires-recent-login') {
          message =
              "Esta operação é sensível e requer autenticação recente. Tente fazer login novamente.";
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alterar E-mail de Login"),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Text(
                    "Por segurança, digite sua senha atual para alterar seu e-mail de login. Um link de confirmação será enviado para o novo endereço.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textHint),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _newEmailController,
                    decoration: const InputDecoration(labelText: 'Novo E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? "Insira um e-mail válido"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Senha Atual'),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Campo obrigatório" : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(
                      onPressed: _changeEmail,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50)),
                      child: const Text("Enviar Link de Confirmação"),
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
