// lib/app_drawer.dart
// ignore_for_file: unused_import, unnecessary_to_list_in_spreads, use_build_context_synchronously, deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart'; // <<< GARANTIR ESTE IMPORT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'models.dart';
import 'navigation_service.dart';
import 'customize_tabs_page.dart';
import 'app_theme.dart';
import 'auth_gate.dart';
import 'common_widgets.dart';
import 'tutorials_module.dart';

class AppDrawer extends StatefulWidget {
  final UserModel user;
  final SubscriptionPlan? currentPlan;
  final List<AppModule> drawerModules;
  final List<AppModule> allPageModules;
  final Function(String) onSelectItem;

  const AppDrawer({
    super.key,
    required this.user,
    this.currentPlan,
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
  // --- NOVA VARIÁVEL DE ESTADO ---
  String? _academyName;
  // --- FIM DA NOVA VARIÁVEL ---

  @override
  void initState() {
    super.initState();
    _fetchAcademyLogo();
    _loadVersionInfo();
    // --- CHAMADA PARA BUSCAR NOME DA ACADEMIA ---
    _fetchAcademyName();
    // --- FIM DA CHAMADA ---
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

  // --- NOVA FUNÇÃO PARA BUSCAR NOME DA ACADEMIA ---
  Future<void> _fetchAcademyName() async {
    // Não busca se for Super Admin (não tem academia associada)
    if (widget.user.role == UserRole.superAdmin ||
        widget.user.academyId.isEmpty) {
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _academyName = doc.data()?['name'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching academy name: $e");
      // Opcional: definir um nome padrão em caso de erro
      // if (mounted) setState(() => _academyName = "Academia");
    }
  }
  // --- FIM DA NOVA FUNÇÃO ---

  void _copyUserIdToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.user.uid)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID de Usuário copiado!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    List<AppModule> sortedDrawerModules =
        _getSortedModules(widget.drawerModules);

    return Drawer(
      backgroundColor: darkScaffoldBackground,
      child: Column(
        children: [
          // --- HEADER CUSTOMIZADO CHAMADO AQUI ---
          _buildDrawerHeader(context),
          // --- FIM DA CHAMADA ---
          const Divider(color: borderNormal, height: 1), // Linha divisória
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero, // Remove padding padrão do ListView
              children: [
                // Não precisa mais do _buildDrawerHeader aqui dentro
                // A linha divisória já foi adicionada acima

                // ... (Restante dos itens do menu como antes) ...
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
                      builder: (_) => CustomizeTabsPage(
                        user: widget.user,
                        currentPlan: widget.currentPlan,
                      ),
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
    // ...(lógica de ordenação inalterada)...
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

  // --- HEADER DO MENU ATUALIZADO ---
  Widget _buildDrawerHeader(BuildContext context) {
    // Usar DrawerHeader para melhor adaptação à área do cabeçalho
    return DrawerHeader(
      decoration: const BoxDecoration(color: darkSurface),
      padding:
          const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Padding ajustado
      margin: EdgeInsets.zero, // Remove margem padrão
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Alinha verticalmente
        children: [
          // Logo
          CircleAvatar(
            radius: 30, // Raio do círculo do logo
            backgroundColor: Colors.white.withOpacity(0.1), // Fundo suave
            backgroundImage:
                (_academyLogoUrl != null && _academyLogoUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(_academyLogoUrl!)
                    : null,
            child: (_academyLogoUrl == null || _academyLogoUrl!.isEmpty)
                ? Icon(
                    // Ícone fallback (ajustar se necessário)
                    widget.user.role == UserRole.superAdmin
                        ? Icons.shield_outlined
                        : Icons.business,
                    color: textHint,
                    size: 30)
                : null,
          ),
          const SizedBox(width: 16), // Espaçamento entre logo e texto
          // Coluna com Nome do Usuário e Nome da Academia
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center, // Centraliza textos na coluna
              children: [
                // Nome do Usuário
                Text(
                  widget.user.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis, // Evita quebra de linha
                ),
                const SizedBox(height: 4), // Espaço entre os nomes
                // Nome da Academia (se existir)
                if (_academyName != null)
                  Text(
                    _academyName!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: textHint),
                    overflow: TextOverflow.ellipsis, // Evita quebra de linha
                  ),
                const SizedBox(height: 8), // Espaço antes do ID
                // ID do Usuário (com cópia) - Menor e mais discreto
                InkWell(
                  onTap: _copyUserIdToClipboard,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        // Para evitar overflow do ID
                        child: Text(
                          'ID: ${widget.user.uid}',
                          style: const TextStyle(color: textHint, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 10, color: textHint),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // --- FIM DA ATUALIZAÇÃO DO HEADER ---
}
