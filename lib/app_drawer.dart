// lib/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';
import 'navigation_service.dart';
import 'customize_tabs_page.dart';
import 'app_theme.dart';
import 'auth_gate.dart';

class AppDrawer extends StatelessWidget {
  final UserModel user;
  final List<AppModule> allModules;
  final Function(int) onSelectItem;

  const AppDrawer({
    super.key,
    required this.user,
    required this.allModules,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: darkScaffoldBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          const Divider(color: borderNormal),
          ...allModules.map((module) {
            final index = allModules.indexOf(module);
            return ListTile(
              leading: Icon(module.icon, color: textSecondary),
              title: Text(module.title,
                  style: const TextStyle(color: textSecondary)),
              onTap: () {
                Navigator.pop(context); // Fecha o drawer
                onSelectItem(index); // Navega para a tela selecionada
              },
            );
          }),
          const Divider(color: borderNormal),
          ListTile(
            leading: const Icon(Icons.tune_rounded, color: primaryAccent),
            title: const Text('Personalizar Abas',
                style: TextStyle(color: primaryAccent)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CustomizeTabsPage(user: user),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: errorColor),
            title: const Text('Sair', style: TextStyle(color: errorColor)),
            onTap: () async {
              // --- INÍCIO DA CORREÇÃO ---
              Navigator.pop(context); // Fecha o drawer primeiro
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirmar Saída'),
                  content:
                      const Text('Tem certeza que deseja sair do aplicativo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );

              // Garante que o contexto ainda é válido após o dialog
              if (confirm == true && context.mounted) {
                await FirebaseAuth.instance.signOut();
                // Navega para a AuthGate e remove todas as telas anteriores da pilha
                // ignore: use_build_context_synchronously
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                  (route) => false,
                );
              }
              // --- FIM DA CORREÇÃO ---
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final profileImage = user.profileImagePath;
    return UserAccountsDrawerHeader(
      accountName:
          Text(user.name, style: Theme.of(context).textTheme.titleMedium),
      accountEmail: Text(user.email, style: const TextStyle(color: textHint)),
      currentAccountPicture: CircleAvatar(
        backgroundColor: primaryAccent,
        backgroundImage: (profileImage != null && profileImage.isNotEmpty)
            ? NetworkImage(profileImage)
            : null,
        child: (profileImage == null || profileImage.isEmpty)
            ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                    fontSize: 40.0, color: primaryAccentForeground),
              )
            : null,
      ),
      decoration: const BoxDecoration(
        color: darkSurface,
      ),
    );
  }
}
