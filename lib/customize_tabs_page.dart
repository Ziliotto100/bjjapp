// lib/customize_tabs_page.dart
import 'package:flutter/material.dart';
import 'navigation_service.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

class CustomizeTabsPage extends StatefulWidget {
  final UserModel user;

  const CustomizeTabsPage({super.key, required this.user});

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
    _navService =
        NavigationService(userId: widget.user.uid, userRole: widget.user.role);
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
        // Salva as configurações padrão se for o primeiro acesso
        await _navService.saveTabSettings(
          List<String>.from(settings['order']),
          List<String>.from(settings['visible']),
        );
      }

      final allUserModules = _navService.getModulesForCurrentUser();
      final List<String> savedOrder =
          List<String>.from(settings['order'] ?? []);

      // Garante que todos os módulos do usuário estejam na lista de ordem
      for (var module in allUserModules) {
        if (!savedOrder.contains(module.id)) {
          savedOrder.add(module.id);
        }
      }

      // Remove módulos que não existem mais
      savedOrder.removeWhere((id) => !allUserModules.any((m) => m.id == id));

      if (mounted) {
        setState(() {
          _orderedModules = savedOrder
              .map((id) => allUserModules.firstWhere((m) => m.id == id))
              .toList();
          _visibleModuleIds = List<String>.from(settings['visible'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar configurações.",
            type: 'error');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    final newOrder = _orderedModules.map((m) => m.id).toList();
    await _navService.saveTabSettings(newOrder, _visibleModuleIds);
    if (mounted) {
      showBjjSnackBar(context, "Preferências salvas!", type: 'success');
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
            tooltip: 'Salvar',
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
                        "Use os interruptores para mostrar/ocultar abas na barra inferior. Segure e arraste para reordenar.",
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
                          return Card(
                            key: ValueKey(module.id),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: SwitchListTile(
                              title: Text(module.title),
                              secondary: Icon(module.icon),
                              value: isVisible,
                              onChanged: (bool value) {
                                setState(() {
                                  if (value) {
                                    _visibleModuleIds.add(module.id);
                                  } else {
                                    _visibleModuleIds.remove(module.id);
                                  }
                                });
                              },
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
