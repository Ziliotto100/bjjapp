// lib/common_widgets.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'models.dart';
import 'user_card_widget.dart';
import 'auth_gate.dart'; // Import necessário para a navegação

// --- WIDGETS COMUNS REUTILIZÁVEIS ---

/// Plano de fundo padrão para a maioria das telas do aplicativo.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/planofundo.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

/// Exibe uma SnackBar (mensagem temporária) customizada na parte inferior da tela.
void showBjjSnackBar(BuildContext context, String message,
    {String type = 'info'}) {
  Color backgroundColor;
  IconData icon;

  switch (type) {
    case 'success':
      backgroundColor = successColor;
      icon = Icons.check_circle_outline;
      break;
    case 'error':
      backgroundColor = errorColor;
      icon = Icons.error_outline;
      break;
    case 'warning':
      backgroundColor = warningColor;
      icon = Icons.warning_amber_rounded;
      break;
    default: // info
      backgroundColor = infoColor;
      icon = Icons.info_outline;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ),
  );
}

/// Widget exibido quando uma lista ou conteúdo está vazio.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const EmptyStateWidget(
      {super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      // --- CORREÇÃO APLICADA AQUI ---
      // Adicionado SingleChildScrollView para evitar overflow em telas pequenas.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: textHint),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: textHint, fontSize: 16),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPER E WIDGET DE PERFIL ---

/// Retorna o caminho do asset da imagem da faixa com base no nome da faixa.
String getBeltImagePath(String? beltName) {
  if (beltName == null || beltName.isEmpty) {
    return 'assets/images/faixas/branca.png';
  }

  const Map<String, String> beltToFileMap = {
    'Branca': 'branca',
    'Cinza/Branca': 'cinza_branco',
    'Cinza': 'cinza',
    'Cinza/Preta': 'cinza_preto',
    'Amarela/Branca': 'amarela_branco',
    'Amarela': 'amarela',
    'Amarela/Preta': 'amarela_preto',
    'Laranja/Branca': 'laranja_branco',
    'Laranja': 'laranja',
    'Laranja/Preta': 'laranja_preto',
    'Verde/Branca': 'verde_branco',
    'Verde': 'verde',
    'Verde/Preta': 'verde_preto',
    'Azul': 'azul',
    'Roxa': 'roxa',
    'Marrom': 'marrom',
    'Preta': 'preta',
  };

  final fileName = beltToFileMap[beltName];

  if (fileName != null) {
    return 'assets/images/faixas/$fileName.png';
  }

  return 'assets/images/faixas/branca.png';
}

/// Cabeçalho de perfil reutilizável.
class UserProfileHeader extends StatelessWidget {
  final UserModel user;
  final Aluno? studentData;

  const UserProfileHeader({
    super.key,
    required this.user,
    this.studentData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileImagePath = user.profileImagePath;
    final heroTag = 'profile_pic_header_${user.uid}';

    final beltName = (user.role == UserRole.student && studentData != null)
        ? studentData!.faixa
        : user.faixa;

    final beltImagePath = getBeltImagePath(beltName);
    final bool showBelt = user.role != UserRole.manager;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () {
                    if (profileImagePath != null &&
                        profileImagePath.isNotEmpty) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PhotoViewPage(
                          imageUrl: profileImagePath,
                          heroTag: heroTag,
                        ),
                      ));
                    }
                  },
                  child: Hero(
                    tag: heroTag,
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: primaryAccent.withOpacity(0.2),
                      backgroundImage: (profileImagePath != null &&
                              profileImagePath.isNotEmpty)
                          ? CachedNetworkImageProvider(profileImagePath)
                          : null,
                      child:
                          (profileImagePath == null || profileImagePath.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 80, color: primaryAccent)
                              : null,
                    ),
                  ),
                ),
                if (showBelt)
                  Positioned(
                    bottom: -57,
                    child: SizedBox(
                      width: 90,
                      height: 100,
                      child: Image.asset(
                        beltImagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Tooltip(
                            message: 'Imagem da faixa não encontrada',
                            child: Icon(Icons.error_outline, color: textHint),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: showBelt ? 50 : 16),
            Text(
              'Bem-vindo(a),',
              style: theme.textTheme.titleMedium?.copyWith(color: textHint),
            ),
            const SizedBox(height: 4),
            Text(
              user.name,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Formatador de texto para datas no formato DD/MM/AAAA.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String newText = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formattedText = '';

    if (newText.length > 8) {
      newText = newText.substring(0, 8);
    }

    if (newText.length > 4) {
      formattedText =
          '${newText.substring(0, 2)}/${newText.substring(2, 4)}/${newText.substring(4)}';
    } else if (newText.length > 2) {
      formattedText = '${newText.substring(0, 2)}/${newText.substring(2)}';
    } else {
      formattedText = newText;
    }

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

/// Banner de aviso para o modo de personificação.
class ImpersonationBanner extends StatelessWidget {
  final String userName;

  const ImpersonationBanner({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: warningColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Você está vendo como $userName.',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                final superAdminUid = FirebaseAuth.instance.currentUser?.uid;
                if (superAdminUid == null) return;

                await FirebaseFirestore.instance
                    .collection('impersonation_sessions')
                    .doc(superAdminUid)
                    .delete();
                await FirebaseAuth.instance.signOut();

                // Navega para a AuthGate e limpa a pilha de telas
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                    (route) => false,
                  );
                }
              },
              child: const Text('SAIR',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
