// lib/training_log_module.dart
// ignore_for_file: use_build_context_synchronously, prefer_final_fields, unused_element, unused_import, unnecessary_brace_in_string_interps, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
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

  Future<List<Map<String, dynamic>>> getSparringHistoryWithPartner(
      String partnerName) async {
    final List<Map<String, dynamic>> history = [];
    final snapshot =
        await _logsCollection.orderBy('date', descending: true).get();

    for (var doc in snapshot.docs) {
      final log = TrainingLog.fromFirestore(doc);
      for (var round in log.sparringRounds) {
        if (round.partnerName == partnerName) {
          history.add({'date': log.date, 'round': round});
        }
      }
    }
    return history;
  }

  Future<List<String>> getLatestSparringSessionPartners(
      String academyId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(academyId)
        .collection('training_history')
        .orderBy('startedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return [];
    }

    final session = SparringSession.fromFirestore(snapshot.docs.first);
    return List<String>.from(session.participantIds);
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
    int submissionsFor = 0;
    int submissionsAgainst = 0;
    for (var round in log.sparringRounds) {
      for (var event in round.events) {
        if (event.type == SparringEventType.finalizacao) {
          if (event.wasSuccessful) {
            submissionsFor++;
          } else {
            submissionsAgainst++;
          }
        }
      }
    }

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
                      value: submissionsFor.toString(),
                      color: successColor),
                  _StatChip(
                      label: 'Finalizado',
                      value: submissionsAgainst.toString(),
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

class _SparringRoundSummaryCard extends StatelessWidget {
  final SparringRound round;
  final int roundNumber;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _SparringRoundSummaryCard({
    required this.round,
    required this.roundNumber,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    int submissionsFor = round.events
        .where(
            (e) => e.type == SparringEventType.finalizacao && e.wasSuccessful)
        .length;
    int submissionsAgainst = round.events
        .where(
            (e) => e.type == SparringEventType.finalizacao && !e.wasSuccessful)
        .length;
    int sweeps = round.events
        .where((e) => e.type == SparringEventType.raspagem && e.wasSuccessful)
        .length;
    int passes = round.events
        .where((e) => e.type == SparringEventType.passagem && e.wasSuccessful)
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round $roundNumber: ${round.partnerName.isNotEmpty ? round.partnerName : "Sem Parceiro"}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: textHint),
                      onPressed: onEdit,
                      tooltip: 'Editar Round',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: errorColor),
                      onPressed: onRemove,
                      tooltip: 'Remover Round',
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            if (round.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(round.notes,
                    style: const TextStyle(color: textSecondary)),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (submissionsFor > 0)
                  _StatChip(
                      label: 'Finalizações',
                      value: submissionsFor.toString(),
                      color: successColor),
                if (submissionsAgainst > 0)
                  _StatChip(
                      label: 'Finalizado',
                      value: submissionsAgainst.toString(),
                      color: errorColor),
                if (sweeps > 0)
                  _StatChip(
                      label: 'Raspagens',
                      value: sweeps.toString(),
                      color: infoColor),
                if (passes > 0)
                  _StatChip(
                      label: 'Passagens',
                      value: passes.toString(),
                      color: primaryAccent),
                _StatChip(
                    label: 'Intensidade',
                    value: '${round.rating}/5',
                    color: warningColor),
              ],
            ),
          ],
        ),
      ),
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
  final _durationController = TextEditingController();
  final _injuriesController = TextEditingController();

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
      _durationController.text = log.durationInMinutes?.toString() ?? '';
      _injuriesController.text = log.injuriesOrPains ?? '';
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    _injuriesController.dispose();
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

  Future<void> _manageSparringRound({SparringRound? round, int? index}) async {
    final result = await Navigator.of(context).push<SparringRound>(
      MaterialPageRoute(
        builder: (_) => EditSparringRoundPage(
          logService: _logService,
          round: round,
          user: widget.user,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _sparringRounds[index] = result;
        } else {
          _sparringRounds.add(result);
        }
      });
    }
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
      durationInMinutes: int.tryParse(_durationController.text),
      injuriesOrPains: _injuriesController.text.trim(),
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
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: _pickDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Data do Treino',
                                ),
                                child: Text(
                                  DateFormat.yMMMEd('pt_BR')
                                      .format(_selectedDate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _durationController,
                              decoration: const InputDecoration(
                                labelText: 'Duração (min)',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _topicController,
                        decoration: const InputDecoration(
                            labelText: 'Tópico Principal da Aula'),
                      ),
                      const SizedBox(height: 16),
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
                      if (_sparringRounds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Text("Nenhum round de sparring adicionado.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textHint)),
                        ),
                      ..._sparringRounds.asMap().entries.map((entry) {
                        int index = entry.key;
                        SparringRound round = entry.value;
                        return _SparringRoundSummaryCard(
                          round: round,
                          roundNumber: index + 1,
                          onEdit: () =>
                              _manageSparringRound(round: round, index: index),
                          onRemove: () => _removeSparringRound(index),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _manageSparringRound(),
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
                      TextFormField(
                        controller: _injuriesController,
                        decoration: const InputDecoration(
                            labelText: 'Lesões ou Dores (Opcional)'),
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
            const Text('Como você avalia sua performance geral hoje?'),
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

class EditSparringRoundPage extends StatefulWidget {
  final TrainingLogService logService;
  final SparringRound? round;
  final UserModel user;

  const EditSparringRoundPage({
    super.key,
    required this.logService,
    this.round,
    required this.user,
  });

  @override
  State<EditSparringRoundPage> createState() => _EditSparringRoundPageState();
}

class _EditSparringRoundPageState extends State<EditSparringRoundPage> {
  late SparringRound _currentRound;
  final _partnerController = TextEditingController();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();
  PhysicalCondition _physicalCondition = PhysicalCondition.normal;
  late Future<List<Aluno>> _participantsFuture;

  @override
  void initState() {
    super.initState();
    _currentRound = widget.round != null
        ? SparringRound.fromMap(widget.round!.toMap())
        : SparringRound();
    _partnerController.text = _currentRound.partnerName;
    _notesController.text = _currentRound.notes;
    _durationController.text =
        _currentRound.durationInMinutes?.toString() ?? '';
    _physicalCondition =
        _currentRound.physicalCondition ?? PhysicalCondition.normal;
    _participantsFuture = _fetchParticipants();
  }

  Future<List<Aluno>> _fetchParticipants() async {
    final firestore = FirebaseFirestore.instance;
    final academyId = widget.user.academyId;

    final studentsSnapshot = await firestore
        .collection('academies')
        .doc(academyId)
        .collection('students')
        .get();
    final students = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();

    final teachersSnapshot = await firestore
        .collection('users')
        .where('academyId', isEqualTo: academyId)
        .where('role', whereIn: ['teacher', 'manager']).get();
    final teachers = teachersSnapshot.docs
        .map((doc) => Aluno.fromUserModel(UserModel.fromFirestore(doc)))
        .toList();

    final allParticipants = [...students, ...teachers];
    allParticipants
        .sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return allParticipants;
  }

  @override
  void dispose() {
    _partnerController.dispose();
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _showPartnerSelectionDialog() async {
    final participants = await _participantsFuture;
    final String? selectedName = await showDialog<String>(
      context: context,
      builder: (_) => _PartnerSelectionDialog(
        participants: participants,
      ),
    );

    if (selectedName != null) {
      setState(() {
        _partnerController.text = selectedName;
      });
    }
  }

  Future<void> _showLastSparringPartners() async {
    final partnerIds = await widget.logService
        .getLatestSparringSessionPartners(widget.user.academyId);
    if (partnerIds.isEmpty) {
      showBjjSnackBar(
          context, 'Nenhum treino em grupo encontrado no histórico.',
          type: 'info');
      return;
    }

    final allParticipants = await _participantsFuture;
    final Map<String, String> idToNameMap = {
      for (var p in allParticipants) p.id: p.nome
    };

    final partnerNames = partnerIds
        .where(
            (id) => id != widget.user.uid && id != widget.user.studentRecordId)
        .map((id) => idToNameMap[id])
        .where((name) => name != null)
        .cast<String>()
        .toList();

    if (partnerNames.isEmpty) {
      showBjjSnackBar(
          context, 'Não foram encontrados parceiros no último treino.',
          type: 'info');
      return;
    }

    final String? selectedName = await showDialog<String>(
      context: context,
      builder: (_) => _LastSparringPartnersDialog(
        partnerNames: partnerNames,
      ),
    );

    if (selectedName != null) {
      setState(() {
        _partnerController.text = selectedName;
      });
    }
  }

  Future<void> _addOrEditEvent({SparringEvent? event, int? index}) async {
    final SparringEvent? result = await showDialog<SparringEvent>(
      context: context,
      builder: (_) => _AddEditSparringEventDialog(
        logService: widget.logService,
        event: event,
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _currentRound.events[index] = result;
        } else {
          _currentRound.events.add(result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.round == null ? 'Novo Round' : 'Editar Round'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Salvar Round',
            onPressed: () {
              _currentRound.partnerName = _partnerController.text.trim();
              _currentRound.notes = _notesController.text.trim();
              _currentRound.durationInMinutes =
                  int.tryParse(_durationController.text);
              _currentRound.physicalCondition = _physicalCondition;
              Navigator.of(context).pop(_currentRound);
            },
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _partnerController,
                      decoration: InputDecoration(
                        labelText: 'Parceiro de Treino',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.history),
                              onPressed: _showLastSparringPartners,
                              tooltip: 'Ver Parceiros do Último Treino',
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_search),
                              onPressed: _showPartnerSelectionDialog,
                              tooltip: 'Buscar em Alunos',
                            ),
                          ],
                        ),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duração (min)',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildPhysicalConditionSelector(),
              const SizedBox(height: 16),
              _buildRatingSelector(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Eventos do Round',
                      style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: primaryAccent),
                    onPressed: () => _addOrEditEvent(),
                  ),
                ],
              ),
              const Divider(),
              if (_currentRound.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text('Nenhum evento adicionado.',
                        style: TextStyle(color: textHint)),
                  ),
                ),
              ..._currentRound.events.asMap().entries.map((entry) {
                int index = entry.key;
                SparringEvent event = entry.value;
                return _SparringEventCard(
                  event: event,
                  onEdit: () => _addOrEditEvent(event: event, index: index),
                  onDelete: () =>
                      setState(() => _currentRound.events.removeAt(index)),
                );
              }),
              const SizedBox(height: 24),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                    labelText: 'Anotações sobre o round (opcional)',
                    alignLabelWithHint: true),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhysicalConditionSelector() {
    return Column(
      children: [
        const Text('Sua Condição Física neste Round'),
        const SizedBox(height: 8),
        SegmentedButton<PhysicalCondition>(
          segments: const [
            ButtonSegment(
              value: PhysicalCondition.disposto,
              label: Text('Disposto'),
              icon: Text('😃'),
            ),
            ButtonSegment(
              value: PhysicalCondition.normal,
              label: Text('Normal'),
              icon: Text('😐'),
            ),
            ButtonSegment(
              value: PhysicalCondition.cansado,
              label: Text('Cansado'),
              icon: Text('😴'),
            ),
          ],
          selected: {_physicalCondition},
          onSelectionChanged: (newSelection) {
            setState(() {
              _physicalCondition = newSelection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRatingSelector() {
    return Column(
      children: [
        const Text('Intensidade / Performance do Round'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < _currentRound.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: warningColor,
                size: 32,
              ),
              onPressed: () {
                setState(() {
                  _currentRound.rating = index + 1;
                });
              },
            );
          }),
        ),
      ],
    );
  }
}

class _SparringEventCard extends StatelessWidget {
  final SparringEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SparringEventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: darkSurface.withOpacity(0.7),
      child: ListTile(
        leading: Icon(
          event.wasSuccessful ? Icons.arrow_upward : Icons.arrow_downward,
          color: event.wasSuccessful ? successColor : errorColor,
        ),
        title: Text(event.technique.capitalizeWords()),
        subtitle: Text(getSparringEventTypeName(event.type)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit, color: textHint),
                onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.close, color: errorColor),
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _AddEditSparringEventDialog extends StatefulWidget {
  final TrainingLogService logService;
  final SparringEvent? event;

  const _AddEditSparringEventDialog({
    required this.logService,
    this.event,
  });

  @override
  State<_AddEditSparringEventDialog> createState() =>
      _AddEditSparringEventDialogState();
}

class _AddEditSparringEventDialogState
    extends State<_AddEditSparringEventDialog> {
  final _formKey = GlobalKey<FormState>();
  SparringEventType? _selectedType;
  String? _selectedTechnique;
  bool _wasSuccessful = true; // Padrão 'Eu fiz'

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _selectedType = widget.event!.type;
      _selectedTechnique =
          widget.event!.technique.isNotEmpty ? widget.event!.technique : null;
      _wasSuccessful = widget.event!.wasSuccessful;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Adicionar Evento' : 'Editar Evento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<SparringEventType>(
                value: _selectedType,
                hint: const Text('Tipo de Evento'),
                items: SparringEventType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(getSparringEventTypeName(type)),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedType = value),
                validator: (v) => v == null ? 'Selecione um tipo' : null,
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<String>>(
                stream: widget.logService.getTechniquesStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<String>(
                    value: _selectedTechnique,
                    // +++ ALTERAÇÃO AQUI +++
                    decoration:
                        const InputDecoration(labelText: 'Técnica (Opcional)'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("Nenhuma / Apenas Posição",
                            style: TextStyle(fontStyle: FontStyle.italic)),
                      ),
                      ...snapshot.data!.map((tech) => DropdownMenuItem(
                            value: tech,
                            child: Text(tech, overflow: TextOverflow.ellipsis),
                          ))
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedTechnique = value),
                    // validator removido para tornar opcional
                  );
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('A Favor'),
                      icon: Icon(Icons.arrow_upward, color: successColor)),
                  ButtonSegment(
                      value: false,
                      label: Text('Contra'),
                      icon: Icon(Icons.arrow_downward, color: errorColor)),
                ],
                selected: {_wasSuccessful},
                onSelectionChanged: (newSelection) {
                  setState(() => _wasSuccessful = newSelection.first);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newEvent = SparringEvent(
                type: _selectedType!,
                // +++ ALTERAÇÃO AQUI +++
                technique:
                    _selectedTechnique ?? '', // Salva string vazia se for nulo
                wasSuccessful: _wasSuccessful,
              );
              Navigator.of(context).pop(newEvent);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _PartnerSelectionDialog extends StatefulWidget {
  final List<Aluno> participants;
  const _PartnerSelectionDialog({required this.participants});

  @override
  State<_PartnerSelectionDialog> createState() =>
      _PartnerSelectionDialogState();
}

class _PartnerSelectionDialogState extends State<_PartnerSelectionDialog> {
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];

  @override
  void initState() {
    super.initState();
    _filteredParticipants = widget.participants;
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants = widget.participants
          .where((p) => p.nome.toLowerCase().contains(query))
          .toList();
    });
  }

  void _addCustomPartner() {
    final customName = _searchController.text.trim();
    if (customName.isNotEmpty) {
      Navigator.of(context).pop(customName.capitalizeWords());
    } else {
      showBjjSnackBar(context, 'Digite o nome do parceiro.', type: 'info');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar Parceiro'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Buscar ou digitar nome...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _addCustomPartner,
                  tooltip: 'Adicionar como parceiro não cadastrado',
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredParticipants.length,
                itemBuilder: (context, index) {
                  final participant = _filteredParticipants[index];
                  return ListTile(
                    title: Text(participant.nome),
                    onTap: () {
                      Navigator.of(context).pop(participant.nome);
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _LastSparringPartnersDialog extends StatelessWidget {
  final List<String> partnerNames;

  const _LastSparringPartnersDialog({required this.partnerNames});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Parceiros do Último Treino'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: partnerNames.length,
          itemBuilder: (context, index) {
            final name = partnerNames[index];
            return ListTile(
              title: Text(name),
              onTap: () {
                Navigator.of(context).pop(name);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _SparringHistoryDialog extends StatelessWidget {
  final String partnerName;
  final List<Map<String, dynamic>> history;

  const _SparringHistoryDialog({
    required this.partnerName,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Histórico com ${partnerName.capitalizeWords()}'),
      content: SizedBox(
        width: double.maxFinite,
        child: history.isEmpty
            ? const Center(
                child: Text('Nenhum treino anterior encontrado.'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final date = item['date'] as DateTime;
                  final round = item['round'] as SparringRound;
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.yMMMEd('pt_BR').format(date),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryAccent),
                          ),
                          const Divider(),
                          ...round.events.map((event) => Text(
                              '• ${event.technique} (${getSparringEventTypeName(event.type)}) - ${event.wasSuccessful ? "A favor" : "Contra"}')),
                          if (round.notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Anotações: ${round.notes}',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: textHint)),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
