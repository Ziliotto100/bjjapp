// lib/customize_tabs_page.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // Import para ListEquality
import 'navigation_service.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

class CustomizeTabsPage extends StatefulWidget {
  final UserModel user;
  final SubscriptionPlan? currentPlan; // NOVO PARÂMETRO

  const CustomizeTabsPage({
    super.key,
    required this.user,
    this.currentPlan, // ADICIONADO AO CONSTRUTOR
  });

  @override
  State<CustomizeTabsPage> createState() => _CustomizeTabsPageState();
}

class _CustomizeTabsPageState extends State<CustomizeTabsPage> {
  late final NavigationService _navService;
  List<AppModule> _orderedModules = [];
  List<String> _visibleModuleIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // --- CORREÇÃO APLICADA AQUI ---
    // Agora o NavigationService é inicializado com o plano atual do usuário.
    _navService = NavigationService(
      userId: widget.user.uid,
      userRole: widget.user.role,
      currentPlan: widget.currentPlan,
    );
    // --- FIM DA CORREÇÃO ---
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _navService.getTabSettingsStream().first;
      Map<String, dynamic> settings;

      if (doc.exists && doc.data() != null) {
        settings = doc.data() as Map<String, dynamic>;
      } else {
        settings = _navService.getDefaultTabSettings();
        await _navService.saveTabSettings(
          _navService
              .getFlatPageModulesForCurrentUser()
              .map((m) => m.id)
              .toList(),
          List<String>.from(settings['visible']),
        );
      }

      final allUserModules = _navService.getFlatPageModulesForCurrentUser();
      final List<String> savedOrder =
          List<String>.from(settings['order'] ?? []);

      // Garante que novos módulos sejam adicionados à lista de ordenação
      for (var module in allUserModules) {
        if (!savedOrder.contains(module.id)) {
          savedOrder.add(module.id);
        }
      }
      // Remove módulos antigos que não existem mais para o usuário
      savedOrder.removeWhere((id) => !allUserModules.any((m) => m.id == id));

      if (mounted) {
        setState(() {
          _orderedModules = savedOrder
              .map((id) => allUserModules.firstWhere((m) => m.id == id,
                  orElse: () => allUserModules
                      .first)) // Fallback para evitar erros graves
              .toList();

          _visibleModuleIds = List<String>.from(settings['visible'] ?? []);
          _sortModules();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar configurações: $e",
            type: 'error');
        setState(() => _isLoading = false);
      }
    }
  }

  void _sortModules() {
    final visibleSet = _visibleModuleIds.toSet();
    _orderedModules.sort((a, b) {
      final aIsVisible = visibleSet.contains(a.id);
      final bIsVisible = visibleSet.contains(b.id);

      if (aIsVisible && !bIsVisible) return -1;
      if (!aIsVisible && bIsVisible) return 1;

      // Se ambos são visíveis, ordena pela ordem em _visibleModuleIds
      if (aIsVisible && bIsVisible) {
        return _visibleModuleIds
            .indexOf(a.id)
            .compareTo(_visibleModuleIds.indexOf(b.id));
      }

      // Se ambos não são visíveis, mantém a ordem atual (não muda nada)
      return 0;
    });
  }

  Future<void> _saveSettings() async {
    final newOrder = _orderedModules.map((m) => m.id).toList();
    final newVisible = _orderedModules
        .where((m) => _visibleModuleIds.contains(m.id))
        .map((m) => m.id)
        .toList();

    await _navService.saveTabSettings(newOrder, newVisible);
    if (mounted) {
      showBjjSnackBar(context, "Preferências salvas!", type: 'success');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Personalizar Abas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Salvar e Sair',
            onPressed: _isLoading ? null : _saveSettings,
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "O número indica a posição na barra inferior. Use os interruptores para ativar e segure para arrastar e reordenar.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textHint),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: _orderedModules.length,
                        itemBuilder: (context, index) {
                          final module = _orderedModules[index];
                          final isVisible =
                              _visibleModuleIds.contains(module.id);
                          final visibleIndex =
                              _visibleModuleIds.indexOf(module.id);

                          return Card(
                            key: ValueKey(module.id),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    width: 56,
                                    height: 68,
                                    alignment: Alignment.center,
                                    child: isVisible
                                        ? CircleAvatar(
                                            radius: 14,
                                            backgroundColor: primaryAccent,
                                            child: Text(
                                              '${visibleIndex + 1}',
                                              style: const TextStyle(
                                                color: primaryAccentForeground,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.drag_handle_rounded,
                                            color: textHint,
                                          ),
                                  ),
                                ),
                                Expanded(
                                  child: SwitchListTile(
                                    title: Text(module.title),
                                    secondary: Icon(module.icon),
                                    value: isVisible,
                                    onChanged: (bool value) {
                                      setState(() {
                                        if (value) {
                                          if (_visibleModuleIds.length < 5) {
                                            _visibleModuleIds.add(module.id);
                                          } else {
                                            showBjjSnackBar(context,
                                                "Você pode selecionar no máximo 5 abas.",
                                                type: 'info');
                                            return; // Retorna para não mudar o estado do switch
                                          }
                                        } else {
                                          _visibleModuleIds.remove(module.id);
                                        }
                                        _sortModules();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onReorder: (int oldIndex, int newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final AppModule item =
                                _orderedModules.removeAt(oldIndex);
                            _orderedModules.insert(newIndex, item);

                            // Atualiza a ordem da lista de visíveis para corresponder à nova ordem geral
                            final visibleSet = _visibleModuleIds.toSet();
                            _visibleModuleIds = _orderedModules
                                .where((m) => visibleSet.contains(m.id))
                                .map((m) => m.id)
                                .toList();
                          });
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
