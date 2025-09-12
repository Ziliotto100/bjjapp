// lib/app_drawer.dart
// ignore_for_file: unused_import, unnecessary_to_list_in_spreads

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models.dart';
import 'navigation_service.dart';
import 'customize_tabs_page.dart';
import 'app_theme.dart';
import 'auth_gate.dart';
import 'tutorials_module.dart'; // CORREÇÃO: Import que estava faltando

class AppDrawer extends StatelessWidget {
  final UserModel user;
  final List<AppModule> drawerModules;
  final List<AppModule> allPageModules;
  final Function(String) onSelectItem;

  const AppDrawer({
    super.key,
    required this.user,
    required this.drawerModules,
    required this.allPageModules,
    required this.onSelectItem,
  });

  @override
  Widget build(BuildContext context) {
    List<AppModule> sortedDrawerModules = _getSortedModules(drawerModules);

    return Drawer(
      backgroundColor: darkScaffoldBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(context),
          const Divider(color: borderNormal),

          ...sortedDrawerModules.map((module) {
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
                      onSelectItem(subModule.id);
                    },
                  );
                }).toList(),
              );
            }

            return ListTile(
              leading: Icon(module.icon, color: textSecondary),
              title: Text(module.title,
                  style: const TextStyle(color: textSecondary)),
              onTap: () {
                Navigator.pop(context);
                onSelectItem(module.id);
              },
            );
          }).toList(),

          const Divider(color: borderNormal),
          // --- NOVA SEÇÃO DE AJUDA ---
          ListTile(
            leading:
                const Icon(Icons.help_outline_rounded, color: primaryAccent),
            title: const Text('Ajuda / Tutoriais',
                style: TextStyle(color: primaryAccent)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TutorialsPage(user: user),
              ));
            },
          ),
          // --- FIM DA SEÇÃO DE AJUDA ---
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
          // --- BOTÃO SAIR REMOVIDO DAQUI ---
        ],
      ),
    );
  }

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
