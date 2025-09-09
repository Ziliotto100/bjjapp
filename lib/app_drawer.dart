// lib/app_drawer.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';
import 'navigation_service.dart';
import 'customize_tabs_page.dart';
import 'app_theme.dart';
import 'auth_gate.dart';

class AppDrawer extends StatelessWidget {
  final UserModel user;
  // --- ATUALIZADO: Recebe as duas listas ---
  final List<AppModule> drawerModules; // Lista hierárquica para desenhar o menu
  final List<AppModule> allPageModules; // Lista plana para encontrar o índice
  final Function(String) onSelectItem; // Agora passa o ID do módulo

  const AppDrawer({
    super.key,
    required this.user,
    required this.drawerModules,
    required this.allPageModules,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    // A lógica de ordenação agora acontece dentro deste widget
    List<AppModule> sortedDrawerModules = _getSortedModules(drawerModules);

    return Drawer(
      backgroundColor: darkScaffoldBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          const Divider(color: borderNormal),

          // Mapeia a lista hierárquica e ordenada
          ...sortedDrawerModules.map((module) {
            // Se o módulo tiver submódulos, cria um ExpansionTile
            if (module.subModules != null && module.subModules!.isNotEmpty) {
              return ExpansionTile(
                leading: Icon(module.icon, color: textSecondary),
                title: Text(module.title,
                    style: const TextStyle(color: textSecondary)),
                children: module.subModules!.map((subModule) {
                  return ListTile(
                    leading:
                        Icon(subModule.icon, color: textSecondary, size: 20),
                    title: Text(subModule.title),
                    contentPadding: const EdgeInsets.only(left: 32.0),
                    onTap: () {
                      Navigator.pop(context);
                      onSelectItem(subModule.id); // Passa o ID do submódulo
                    },
                  );
                }).toList(),
              );
            }

            // Se não, cria um ListTile normal
            return ListTile(
              leading: Icon(module.icon, color: textSecondary),
              title: Text(module.title,
                  style: const TextStyle(color: textSecondary)),
              onTap: () {
                Navigator.pop(context);
                onSelectItem(module.id); // Passa o ID do módulo
              },
            );
          }).toList(),

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
              Navigator.pop(context);
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

              if (confirm == true && context.mounted) {
                await FirebaseAuth.instance.signOut();
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

  // --- FUNÇÃO DE ORDENAÇÃO ATUALIZADA ---
  List<AppModule> _getSortedModules(List<AppModule> modules) {
    AppModule? inicioModule;
    AppModule? financeiroModule;

    try {
      inicioModule = modules.firstWhere((m) => m.title == 'Início');
    } catch (e) {
      inicioModule = null;
    }
    try {
      financeiroModule = modules.firstWhere((m) => m.title == 'Financeiro');
    } catch (e) {
      financeiroModule = null;
    }

    final otherModules = modules
        .where((m) => m.title != 'Início' && m.title != 'Financeiro')
        .toList();
    otherModules.sort((a, b) => a.title.compareTo(b.title));

    final List<AppModule> sortedList = [];
    if (inicioModule != null) sortedList.add(inicioModule);
    if (financeiroModule != null) sortedList.add(financeiroModule);
    sortedList.addAll(otherModules);

    return sortedList;
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
            ? CachedNetworkImageProvider(profileImage)
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
