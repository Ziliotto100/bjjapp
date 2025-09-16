// lib/training_log_module.dart
// ignore_for_file: use_build_context_synchronously, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';

// --- SERVICE PARA O DIÁRIO DE TREINOS ---
class TrainingLogService {
  final String userId;

  TrainingLogService({required this.userId});

  CollectionReference get _logsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('training_logs');
  CollectionReference get _tagsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('training_tags'); // Tags específicas para treinos

  // --- MÉTODOS DE TAGS (pode ser usado para técnicas no futuro) ---
  Stream<List<String>> getTagsStream() {
    return _tagsCollection.orderBy('name').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc['name'] as String).toList());
  }

  Future<void> addTag(String tagName) async {
    final query = await _tagsCollection
        .where('name', isEqualTo: tagName.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      await _tagsCollection.add({'name': tagName.trim()});
    }
  }

  Future<void> deleteTag(String tagName) async {
    final query =
        await _tagsCollection.where('name', isEqualTo: tagName).limit(1).get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
    }
  }

  // --- MÉTODOS DE LOGS ---
  Stream<QuerySnapshot> getLogsStream() {
    return _logsCollection.orderBy('date', descending: true).snapshots();
  }

  Future<void> saveLog(TrainingLog log) {
    final data = log.toMap();
    if (log.id.isEmpty) {
      // Adicionando novos campos no momento da criação
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      return _logsCollection.add(data).then((_) {});
    } else {
      // Adicionando campo de atualização
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
  final String userId;
  const TrainingLogPage({super.key, required this.userId});

  @override
  State<TrainingLogPage> createState() => _TrainingLogPageState();
}

class _TrainingLogPageState extends State<TrainingLogPage> {
  late final TrainingLogService _logService;

  @override
  void initState() {
    super.initState();
    _logService = TrainingLogService(userId: widget.userId);
  }

  void _navigateToAddEntry({TrainingLog? logToEdit}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EditTrainingLogPage(userId: widget.userId, logToEdit: logToEdit),
    ));
  }

  void _confirmDelete(String logId) {
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
              await _logService.deleteLog(logId);
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _logService.getLogsStream(),
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
                    onTap: () => _navigateToAddEntry(logToEdit: log),
                    onDelete: () => _confirmDelete(log.id),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddEntry(),
        label: const Text('Registrar Treino'),
        icon: const Icon(Icons.add),
      ),
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
                  // +++ INÍCIO DA MODIFICAÇÃO +++
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        onTap(); // A função onTap já navega para a edição
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
                  // +++ FIM DA MODIFICAÇÃO +++
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
  final String userId;
  final TrainingLog? logToEdit;

  const EditTrainingLogPage({super.key, required this.userId, this.logToEdit});

  @override
  State<EditTrainingLogPage> createState() => _EditTrainingLogPageState();
}

class _EditTrainingLogPageState extends State<EditTrainingLogPage> {
  final _formKey = GlobalKey<FormState>();
  late final TrainingLogService _logService;

  // Controladores de formulário
  final _topicController = TextEditingController();
  final _techniquesController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int _performanceRating = 3;
  List<SparringRound> _sparringRounds = [];
  bool _isSaving = false;

  bool get _isEditing => widget.logToEdit != null;

  @override
  void initState() {
    super.initState();
    _logService = TrainingLogService(userId: widget.userId);

    if (_isEditing) {
      final log = widget.logToEdit!;
      _selectedDate = log.date;
      _topicController.text = log.classTopic ?? '';
      _techniquesController.text = log.techniques.join(', ');
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
    _techniquesController.dispose();
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

    final techniques = _techniquesController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final log = TrainingLog(
      id: _isEditing ? widget.logToEdit!.id : '',
      userId: widget.userId,
      date: _selectedDate,
      classTopic: _topicController.text.trim(),
      techniques: techniques,
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
                      // --- SEÇÃO DE INFORMAÇÕES GERAIS ---
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
                      TextFormField(
                        controller: _techniquesController,
                        decoration: const InputDecoration(
                            labelText: 'Técnicas (separadas por vírgula)'),
                      ),
                      const SizedBox(height: 24),

                      // --- SEÇÃO DE ROLAS ---
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

                      // --- SEÇÃO DE REFLEXÃO ---
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
