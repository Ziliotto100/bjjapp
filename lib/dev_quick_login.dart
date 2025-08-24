// lib/dev_quick_login.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'auth_gate.dart';
import 'common_widgets.dart';

/// PÁGINA DE LOGIN RÁPIDO - APENAS PARA DESENVOLVIMENTO
class DevQuickLoginPage extends StatefulWidget {
  const DevQuickLoginPage({super.key});

  @override
  State<DevQuickLoginPage> createState() => _DevQuickLoginPageState();
}

class _DevQuickLoginPageState extends State<DevQuickLoginPage> {
  bool _isLoading = false;

  final Map<String, Map<String, String>> _testAccounts = {
    'Super Admin': {
      'email': 'ziliottosmartdev@gmail.com',
      'password': '123456',
    },
    'Gerente': {
      'email': 'gerente@matchbjj.com',
      'password': '123456',
    },
    'Professor': {
      'email': 'professor1@matchbjj.com',
      'password': '123456',
    },
    'Aluno': {
      'email': 'aluno2@matchbjj.com',
      'password': '123456',
    },
  };

  Future<void> _loginAs(String role) async {
    if (_isLoading) return;

    final account = _testAccounts[role];
    if (account == null || account['email']!.isEmpty) {
      showBjjSnackBar(context,
          'Credenciais para "$role" não configuradas no arquivo dev_quick_login.dart',
          type: 'error');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Garante que qualquer sessão anterior seja encerrada
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: account['email']!,
        password: account['password']!,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao fazer login como $role.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'E-mail ou senha incorretos para a conta de $role.';
      }
      showBjjSnackBar(context, message, type: 'error');
    } catch (e) {
      showBjjSnackBar(context, 'Ocorreu um erro inesperado.', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.developer_mode,
                    size: 60, color: primaryAccent),
                const SizedBox(height: 16),
                Text(
                  'Acesso Rápido (Dev)',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Esta tela só aparece em modo de desenvolvimento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textHint),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._testAccounts.keys.map(
                    (role) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _loginAs(role),
                        child: Text('Entrar como $role'),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Divider(),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: const Text('Ir para a página de login normal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
