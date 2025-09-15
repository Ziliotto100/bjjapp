// lib/app_drawer.dart
// ignore_for_file: unused_import, unnecessary_to_list_in_spreads

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models.dart';
import 'navigation_service.dart';
import 'customize_tabs_page.dart';
import 'app_theme.dart';
import 'auth_gate.dart';
import 'tutorials_module.dart';

class AppDrawer extends StatefulWidget {
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
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _academyLogoUrl;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _fetchAcademyLogo();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'Versão ${packageInfo.version}';
      });
    }
  }

  Future<void> _fetchAcademyLogo() async {
    if (widget.user.academyId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.user.academyId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _academyLogoUrl = doc.data()?['logoUrl'];
          });
        }
      } catch (e) {
        debugPrint("Error fetching academy logo: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<AppModule> sortedDrawerModules =
        _getSortedModules(widget.drawerModules);

    return Drawer(
      backgroundColor: darkScaffoldBackground,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerHeader(context),
                const Divider(color: borderNormal),
                ...sortedDrawerModules.map((module) {
                  if (module.subModules != null &&
                      module.subModules!.isNotEmpty) {
                    return ExpansionTile(
                      leading: Icon(module.icon, color: textSecondary),
                      title: Text(module.title,
                          style: const TextStyle(color: textSecondary)),
                      children: module.subModules!.map((subModule) {
                        return ListTile(
                          leading: Icon(subModule.icon,
                              color: textSecondary, size: 20),
                          title: Text(subModule.title),
                          contentPadding: const EdgeInsets.only(left: 32.0),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelectItem(subModule.id);
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
                      widget.onSelectItem(module.id);
                    },
                  );
                }).toList(),
                const Divider(color: borderNormal),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded,
                      color: primaryAccent),
                  title: const Text('Ajuda / Tutoriais',
                      style: TextStyle(color: primaryAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TutorialsPage(user: widget.user),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: primaryAccent),
                  title: const Text('Personalizar Abas',
                      style: TextStyle(color: primaryAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CustomizeTabsPage(user: widget.user),
                    ));
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _appVersion,
              style: const TextStyle(color: textHint, fontSize: 12),
            ),
          ),
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
    return UserAccountsDrawerHeader(
      accountName: Text(widget.user.name,
          style: Theme.of(context).textTheme.titleMedium),
      accountEmail:
          Text(widget.user.email, style: const TextStyle(color: textHint)),
      currentAccountPicture: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage:
            (_academyLogoUrl != null && _academyLogoUrl!.isNotEmpty)
                ? CachedNetworkImageProvider(_academyLogoUrl!)
                : null,
        child: (_academyLogoUrl == null || _academyLogoUrl!.isEmpty)
            ? const Icon(Icons.business, color: textHint, size: 30)
            : null,
      ),
      decoration: const BoxDecoration(
        color: darkSurface,
      ),
    );
  }
}
