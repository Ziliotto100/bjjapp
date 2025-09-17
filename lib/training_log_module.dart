// lib/training_log_module.dart
// ignore_for_file: use_build_context_synchronously, prefer_final_fields

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'training_stats_page.dart';

// --- SERVICE PARA O DIÁRIO DE TREINOS ---
class TrainingLogService {
  final String userId;

  TrainingLogService({required this.userId});

  CollectionReference get _logsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('training_logs');

  CollectionReference get _techniquesCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('training_techniques');

  Stream<List<String>> getTechniquesStream() {
    return _techniquesCollection.orderBy('name').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc['name'] as String).toList());
  }

  Future<void> addTechnique(String techniqueName) async {
    final query = await _techniquesCollection
        .where('name', isEqualTo: techniqueName.trim().capitalizeWords())
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      await _techniquesCollection
          .add({'name': techniqueName.trim().capitalizeWords()});
    }
  }

  Future<void> deleteTechnique(String techniqueName) async {
    final query = await _techniquesCollection
        .where('name', isEqualTo: techniqueName)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
    }
  }

  Stream<QuerySnapshot> getLogsStream() {
    return _logsCollection.orderBy('date', descending: true).snapshots();
  }

  Future<void> saveLog(TrainingLog log) {
    final data = log.toMap();
    if (log.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      return _logsCollection.add(data).then((_) {});
    } else {
      data['updatedAt'] = FieldValue.serverTimestamp();
      return _logsCollection.doc(log.id).update(data);
    }
  }

  Future<void> deleteLog(String logId) async {
    await _logsCollection.doc(logId).delete();
  }
}

// --- TELA PRINCIPAL DO DIÁRIO ---
class TrainingLogPage extends StatefulWidget {
  final UserModel user;
  const TrainingLogPage({super.key, required this.user});

  @override
  State<TrainingLogPage> createState() => _TrainingLogPageState();
}

class _TrainingLogPageState extends State<TrainingLogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(() {});
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAddEntry({TrainingLog? logToEdit}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EditTrainingLogPage(user: widget.user, logToEdit: logToEdit),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.book_outlined), text: 'Diário'),
          Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Estatísticas'),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TrainingLogListView(
                user: widget.user,
                onEdit: (log) => _navigateToAddEntry(logToEdit: log),
              ),
              TrainingStatsPage(user: widget.user),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToAddEntry(),
              label: const Text('Registrar Treino'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// --- WIDGET PARA A LISTA DE TREINOS ---
class _TrainingLogListView extends StatelessWidget {
  final UserModel user;
  final Function(TrainingLog) onEdit;
  const _TrainingLogListView({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final logService = TrainingLogService(userId: user.uid);

    void confirmDelete(String logId) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir Registro?'),
          content: const Text(
              'Tem certeza que deseja excluir este registro de treino?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await logService.deleteLog(logId);
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: errorColor),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: logService.getLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyStateWidget(
              icon: Icons.error, title: 'Erro ao carregar diário');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.auto_stories_outlined,
            title: 'Diário Vazio',
            message:
                'Clique no botão "+" para registrar seu primeiro treino e acompanhar sua evolução.',
          );
        }

        final logs = snapshot.data!.docs
            .map((doc) => TrainingLog.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _TrainingLogCard(
              log: log,
              onTap: () => onEdit(log),
              onDelete: () => confirmDelete(log.id),
            );
          },
        );
      },
    );
  }
}

// --- CARD PARA CADA REGISTRO NA LISTA ---
class _TrainingLogCard extends StatelessWidget {
  final TrainingLog log;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TrainingLogCard(
      {required this.log, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    int totalSubmissionsFor =
        log.sparringRounds.fold(0, (sum, r) => sum + r.submissionsFor);
    int totalSubmissionsAgainst =
        log.sparringRounds.fold(0, (sum, r) => sum + r.submissionsAgainst);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.yMMMEd('pt_BR').format(log.date),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: primaryAccent),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onTap();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (log.classTopic != null && log.classTopic!.isNotEmpty)
                _InfoRow(
                    icon: Icons.bookmark_border,
                    label: 'Tópico da Aula:',
                    value: log.classTopic!),
              if (log.techniques.isNotEmpty)
                _InfoRow(
                    icon: Icons.list_alt,
                    label: 'Técnicas:',
                    value: log.techniques.join(', ')),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(
                      label: 'Finalizações',
                      value: totalSubmissionsFor.toString(),
                      color: successColor),
                  _StatChip(
                      label: 'Finalizado',
                      value: totalSubmissionsAgainst.toString(),
                      color: errorColor),
                  _StatChip(
                      label: 'Performance',
                      value: '${log.performanceRating}/5',
                      color: infoColor),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES PARA O CARD ---
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textHint),
          const SizedBox(width: 8),
          Text('$label ', style: const TextStyle(color: textHint)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: textSecondary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: textHint, fontSize: 12)),
      ],
    );
  }
}

// --- TELA DE EDIÇÃO/CRIAÇÃO DE REGISTRO ---
class EditTrainingLogPage extends StatefulWidget {
  final UserModel user;
  final TrainingLog? logToEdit;

  const EditTrainingLogPage({super.key, required this.user, this.logToEdit});

  @override
  State<EditTrainingLogPage> createState() => _EditTrainingLogPageState();
}

class _EditTrainingLogPageState extends State<EditTrainingLogPage> {
  final _formKey = GlobalKey<FormState>();
  late final TrainingLogService _logService;

  final _topicController = TextEditingController();
  final _notesController = TextEditingController();
  List<String> _selectedTechniques = [];

  DateTime _selectedDate = DateTime.now();
  int _performanceRating = 3;
  List<SparringRound> _sparringRounds = [];
  bool _isSaving = false;

  bool get _isEditing => widget.logToEdit != null;

  @override
  void initState() {
    super.initState();
    _logService = TrainingLogService(userId: widget.user.uid);

    if (_isEditing) {
      final log = widget.logToEdit!;
      _selectedDate = log.date;
      _topicController.text = log.classTopic ?? '';
      _selectedTechniques = List<String>.from(log.techniques);
      _notesController.text = log.generalNotes;
      _performanceRating = log.performanceRating;
      _sparringRounds = log.sparringRounds
          .map((r) => SparringRound.fromMap(r.toMap()))
          .toList();
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _addSparringRound() {
    setState(() {
      _sparringRounds.add(SparringRound());
    });
  }

  void _removeSparringRound(int index) {
    setState(() {
      _sparringRounds.removeAt(index);
    });
  }

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    final log = TrainingLog(
      id: _isEditing ? widget.logToEdit!.id : '',
      userId: widget.user.uid,
      date: _selectedDate,
      classTopic: _topicController.text.trim(),
      techniques: _selectedTechniques,
      generalNotes: _notesController.text.trim(),
      performanceRating: _performanceRating,
      sparringRounds: _sparringRounds,
      createdAt: _isEditing ? widget.logToEdit!.createdAt : Timestamp.now(),
      updatedAt: Timestamp.now(),
    );

    try {
      await _logService.saveLog(log);
      if (mounted) {
        showBjjSnackBar(context, 'Registro de treino salvo!', type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar: $e', type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Registro' : 'Registrar Treino'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isSaving ? null : _saveLog,
            tooltip: 'Salvar',
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildSectionHeader('Detalhes da Aula'),
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data do Treino',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat.yMMMEd('pt_BR').format(_selectedDate),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _topicController,
                        decoration: const InputDecoration(
                            labelText: 'Tópico Principal da Aula'),
                      ),
                      const SizedBox(height: 16),
                      // +++ CAMPO DE TÉCNICAS ATUALIZADO +++
                      _TechniquesInputField(
                        logService: _logService,
                        initialTechniques: _selectedTechniques,
                        onChanged: (newTechniques) {
                          setState(() {
                            _selectedTechniques = newTechniques;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Sparring (Rolas)'),
                      ..._sparringRounds.asMap().entries.map((entry) {
                        int index = entry.key;
                        return _SparringRoundCard(
                          key: ValueKey('sparring_$index'),
                          round: entry.value,
                          roundNumber: index + 1,
                          onRemove: () => _removeSparringRound(index),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addSparringRound,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Adicionar Rola'),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Reflexão Pessoal'),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText:
                              'Anotações (O que funcionou? Dificuldades?)',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                      ),
                      const SizedBox(height: 16),
                      _buildPerformanceRating(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildPerformanceRating() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text('Como você avalia sua performance hoje?'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _performanceRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: primaryAccent,
                  ),
                  onPressed: () {
                    setState(() {
                      _performanceRating = index + 1;
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CARD PARA CADA ROLA DENTRO DA TELA DE EDIÇÃO ---
class _SparringRoundCard extends StatefulWidget {
  final SparringRound round;
  final int roundNumber;
  final VoidCallback onRemove;

  const _SparringRoundCard({
    super.key,
    required this.round,
    required this.roundNumber,
    required this.onRemove,
  });

  @override
  State<_SparringRoundCard> createState() => _SparringRoundCardState();
}

class _SparringRoundCardState extends State<_SparringRoundCard> {
  late final TextEditingController _partnerController;

  @override
  void initState() {
    super.initState();
    _partnerController = TextEditingController(text: widget.round.partnerName);
    _partnerController.addListener(() {
      widget.round.partnerName = _partnerController.text;
    });
  }

  @override
  void dispose() {
    _partnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Rola ${widget.roundNumber}',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: errorColor),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            TextFormField(
              controller: _partnerController,
              decoration:
                  const InputDecoration(labelText: 'Parceiro(a) de Treino'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Counter(
                  label: 'Finalizei',
                  value: widget.round.submissionsFor,
                  onChanged: (newValue) =>
                      setState(() => widget.round.submissionsFor = newValue),
                ),
                _Counter(
                  label: 'Fui Finalizado',
                  value: widget.round.submissionsAgainst,
                  onChanged: (newValue) => setState(
                      () => widget.round.submissionsAgainst = newValue),
                ),
                _Counter(
                  label: 'Raspei',
                  value: widget.round.sweepsFor,
                  onChanged: (newValue) =>
                      setState(() => widget.round.sweepsFor = newValue),
                ),
                _Counter(
                  label: 'Passei',
                  value: widget.round.passesFor,
                  onChanged: (newValue) =>
                      setState(() => widget.round.passesFor = newValue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET DE CONTADOR (+/-) ---
class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: textHint)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
            ),
            Text('$value', style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }
}

// +++ INÍCIO DOS NOVOS WIDGETS PARA SELEÇÃO DE TÉCNICAS +++

class _TechniquesInputField extends StatefulWidget {
  final TrainingLogService logService;
  final List<String> initialTechniques;
  final ValueChanged<List<String>> onChanged;

  const _TechniquesInputField({
    required this.logService,
    required this.initialTechniques,
    required this.onChanged,
  });

  @override
  State<_TechniquesInputField> createState() => _TechniquesInputFieldState();
}

class _TechniquesInputFieldState extends State<_TechniquesInputField> {
  late List<String> _selectedTechniques;

  @override
  void initState() {
    super.initState();
    _selectedTechniques = List<String>.from(widget.initialTechniques);
  }

  void _showTechniqueSelectionDialog() async {
    final List<String>? result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _TechniqueSelectionDialog(
        logService: widget.logService,
        initiallySelected: _selectedTechniques,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedTechniques = result;
      });
      widget.onChanged(_selectedTechniques);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Técnicas',
            contentPadding: EdgeInsets.fromLTRB(12, 12, 12, 0),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _selectedTechniques.map((tech) {
              return Chip(
                label: Text(tech),
                onDeleted: () {
                  setState(() {
                    _selectedTechniques.remove(tech);
                  });
                  widget.onChanged(_selectedTechniques);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showTechniqueSelectionDialog,
          icon: const Icon(Icons.list_alt_rounded),
          label: const Text('Selecionar / Adicionar Técnicas'),
        ),
      ],
    );
  }
}

class _TechniqueSelectionDialog extends StatefulWidget {
  final TrainingLogService logService;
  final List<String> initiallySelected;

  const _TechniqueSelectionDialog({
    required this.logService,
    required this.initiallySelected,
  });

  @override
  State<_TechniqueSelectionDialog> createState() =>
      _TechniqueSelectionDialogState();
}

class _TechniqueSelectionDialogState extends State<_TechniqueSelectionDialog> {
  late Set<String> _selectedInDialog;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedInDialog = Set<String>.from(widget.initiallySelected);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddTechniqueDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Técnica Pessoal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Ex: Passagem de guarda...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final newTech = controller.text.trim().capitalizeWords();
                widget.logService.addTechnique(newTech);
                setState(() {
                  _selectedInDialog.add(newTech);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String techniqueName) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Excluir Técnica?'),
              content: Text(
                  'Tem certeza que deseja excluir "${techniqueName}" da sua lista pessoal?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    widget.logService.deleteTechnique(techniqueName);
                    setState(() {
                      _selectedInDialog.remove(techniqueName);
                    });
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: errorColor),
                  child: const Text('Excluir'),
                ),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecione as Técnicas'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar técnica...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: widget.logService.getTechniquesStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('Nenhuma técnica cadastrada.'));
                  }
                  final filteredTechniques = snapshot.data!
                      .where(
                          (tech) => tech.toLowerCase().contains(_searchQuery))
                      .toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filteredTechniques.length,
                    itemBuilder: (context, index) {
                      final tech = filteredTechniques[index];
                      final isSelected = _selectedInDialog.contains(tech);
                      return CheckboxListTile(
                        title: Text(tech),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedInDialog.add(tech);
                            } else {
                              _selectedInDialog.remove(tech);
                            }
                          });
                        },
                        secondary: IconButton(
                          icon:
                              const Icon(Icons.delete_outline, color: textHint),
                          onPressed: () => _confirmDelete(tech),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _showAddTechniqueDialog,
          child: const Text('Nova Técnica'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedInDialog.toList());
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
