// lib/app_drawer.dart
import 'package:cached_network_image/cached_network_image.dart'; // NOVO IMPORT
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
    // --- LÓGICA DE ORDENAÇÃO ADICIONADA AQUI ---
    AppModule? inicioModule;
    try {
      // Encontra o módulo "Início"
      inicioModule = allModules.firstWhere((m) => m.title == 'Início');
    } catch (e) {
      // Caso não encontre, continua sem ele
      inicioModule = null;
    }

    // Cria uma lista com os outros módulos
    final otherModules = allModules.where((m) => m.title != 'Início').toList();

    // Ordena os outros módulos em ordem alfabética
    otherModules.sort((a, b) => a.title.compareTo(b.title));

    // Junta as listas, com "Início" no topo (se existir)
    final sortedModules =
        (inicioModule != null) ? [inicioModule, ...otherModules] : otherModules;
    // --- FIM DA LÓGICA DE ORDENAÇÃO ---

    return Drawer(
      backgroundColor: darkScaffoldBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          const Divider(color: borderNormal),
          // Mapeia a lista já ordenada para criar os itens do menu
          ...sortedModules.map((module) {
            // Pega o índice original do módulo para a navegação não quebrar
            final originalIndex = allModules.indexOf(module);
            return ListTile(
              leading: Icon(module.icon, color: textSecondary),
              title: Text(module.title,
                  style: const TextStyle(color: textSecondary)),
              onTap: () {
                Navigator.pop(context); // Fecha o drawer
                onSelectItem(originalIndex); // Navega usando o índice correto
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
        // --- ALTERAÇÃO AQUI ---
        backgroundImage: (profileImage != null && profileImage.isNotEmpty)
            ? CachedNetworkImageProvider(profileImage)
            : null,
        // --- FIM DA ALTERAÇÃO ---
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
