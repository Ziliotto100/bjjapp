// lib/class_plan_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'lesson_planner_module.dart';
import 'video_library_module.dart';
import 'video_picker_dialog.dart';

// --- TELA PRINCIPAL QUE LISTA OS CURRÍCULOS ---
class ClassPlanPage extends StatefulWidget {
  final UserModel user;

  const ClassPlanPage({super.key, required this.user});

  @override
  State<ClassPlanPage> createState() => _ClassPlanPageState();
}

class _ClassPlanPageState extends State<ClassPlanPage> {
  late final CollectionReference _curriculumsCollection;

  @override
  void initState() {
    super.initState();
    _curriculumsCollection = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('curriculums');
  }

  void _showCurriculumDialog({Curriculum? curriculum}) {
    showDialog(
      context: context,
      builder: (_) => _AddEditCurriculumDialog(
        curriculumsCollection: _curriculumsCollection,
        curriculum: curriculum,
      ),
    );
  }

  Future<void> _deleteCurriculum(Curriculum curriculum) async {
    final inUseCheck = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('schedule')
        .where('curriculumId', isEqualTo: curriculum.id)
        .limit(1)
        .get();

    if (inUseCheck.docs.isNotEmpty) {
      showBjjSnackBar(context,
          'Este currículo está em uso por uma ou mais aulas e não pode ser excluído.',
          type: 'error');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Currículo?'),
        content: Text(
            'Tem certeza que deseja excluir o currículo "${curriculum.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _curriculumsCollection.doc(curriculum.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: _curriculumsCollection.orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyStateWidget(
                icon: Icons.error, title: 'Erro ao Carregar');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.school_outlined,
              title: 'Nenhum Currículo Criado',
              message:
                  'Clique no botão "+" para adicionar o primeiro currículo (ex: Iniciantes, Kids).',
            );
          }

          final curriculums = snapshot.data!.docs
              .map((doc) => Curriculum.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: curriculums.length,
            itemBuilder: (context, index) {
              final curriculum = curriculums[index];
              return Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.menu_book_rounded, color: primaryAccent),
                  title: Text(curriculum.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: curriculum.description.isNotEmpty
                      ? Text(curriculum.description)
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showCurriculumDialog(curriculum: curriculum);
                      } else if (value == 'delete') {
                        _deleteCurriculum(curriculum);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CurriculumDetailPage(
                          user: widget.user, curriculum: curriculum),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCurriculumDialog(),
        tooltip: 'Novo Currículo',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- TELA DE DETALHE DO CURRÍCULO (COM AS ABAS) ---
class CurriculumDetailPage extends StatefulWidget {
  final UserModel user;
  final Curriculum curriculum;

  const CurriculumDetailPage(
      {super.key, required this.user, required this.curriculum});

  @override
  State<CurriculumDetailPage> createState() => _CurriculumDetailPageState();
}

class _CurriculumDetailPageState extends State<CurriculumDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.curriculum.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            color: darkSurface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Plano da Semana'),
                Tab(text: 'Diário de Aulas'),
              ],
            ),
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _WeeklyPlanView(user: widget.user, curriculum: widget.curriculum),
              _DailyLogView(user: widget.user, curriculum: widget.curriculum),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ABA 1: DIÁRIO DE AULAS (REGISTRO DO QUE FOI FEITO) ---
class _DailyLogView extends StatefulWidget {
  final UserModel user;
  final Curriculum curriculum;
  const _DailyLogView({required this.user, required this.curriculum});

  @override
  State<_DailyLogView> createState() => _DailyLogViewState();
}

class _DailyLogViewState extends State<_DailyLogView> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(_selectedDate);
    final formattedDay = dayOfWeek[0].toUpperCase() + dayOfWeek.substring(1);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Selecione a Data para Registrar',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                DateFormat.yMMMMEEEEd('pt_BR').format(_selectedDate),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(widget.user.academyId)
                .collection('schedule')
                .where('curriculumId', isEqualTo: widget.curriculum.id)
                .where('dayOfWeek', isEqualTo: formattedDay)
                .orderBy('startTime')
                .snapshots(),
            builder: (context, scheduleSnapshot) {
              if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!scheduleSnapshot.hasData ||
                  scheduleSnapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                    icon: Icons.event_busy,
                    title: 'Nenhuma aula deste currículo no dia');
              }

              final classes = scheduleSnapshot.data!.docs
                  .map((doc) => TrainingClass.fromFirestore(doc))
                  .toList();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('academies')
                    .doc(widget.user.academyId)
                    .collection('lesson_plans')
                    .where('classDate',
                        isEqualTo: Timestamp.fromDate(DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day)))
                    .snapshots(),
                builder: (context, plansSnapshot) {
                  if (plansSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final plans = plansSnapshot.data?.docs
                          .map((doc) => LessonPlan.fromFirestore(doc))
                          .toList() ??
                      [];
                  final plansMap = {for (var p in plans) p.classId: p};

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                    itemCount: classes.length,
                    itemBuilder: (context, index) {
                      final trainingClass = classes[index];
                      final existingPlan = plansMap[trainingClass.id];
                      return _ClassPlanCard(
                        trainingClass: trainingClass,
                        classDate: _selectedDate,
                        currentUser: widget.user,
                        existingPlan: existingPlan,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- ABA 2: PLANO DA SEMANA (RECOMENDAÇÃO DO QUE ENSINAR) ---
class _WeeklyPlanView extends StatefulWidget {
  final UserModel user;
  final Curriculum curriculum;
  const _WeeklyPlanView({required this.user, required this.curriculum});

  @override
  State<_WeeklyPlanView> createState() => _WeeklyPlanViewState();
}

class _WeeklyPlanViewState extends State<_WeeklyPlanView> {
  late DateTime _startOfWeek;

  @override
  void initState() {
    super.initState();
    _setWeek(DateTime.now());
  }

  void _setWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    _startOfWeek =
        normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }

  void _changeWeek(int days) {
    setState(() {
      _startOfWeek = _startOfWeek.add(Duration(days: days));
    });
  }

  void _showEditWeeklyPlanDialog(WeeklyPlan? existingPlan) {
    showDialog(
        context: context,
        builder: (_) => _EditWeeklyPlanDialog(
              user: widget.user,
              weekStartDate: _startOfWeek,
              existingPlan: existingPlan,
              curriculumId: widget.curriculum.id,
            ));
  }

  Future<void> _navigateToVideoPlayer(
      BuildContext context, UserModel user, String videoId) async {
    final videoDoc = await FirebaseFirestore.instance
        .collection('academies')
        .doc(user.academyId)
        .collection('videos')
        .doc(videoId)
        .get();

    if (videoDoc.exists) {
      final videoItem = VideoItem.fromFirestore(videoDoc);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerPage(video: videoItem),
      ));
    } else {
      showBjjSnackBar(context, 'Vídeo não encontrado.', type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final endOfWeek = _startOfWeek.add(const Duration(days: 6));
    final weekFormatter = DateFormat('dd/MM');
    final weekLabel =
        '${weekFormatter.format(_startOfWeek)} - ${weekFormatter.format(endOfWeek)}';

    final startDayName =
        DateFormat.EEEE('pt_BR').format(_startOfWeek).capitalizeWords();
    final endDayName =
        DateFormat.EEEE('pt_BR').format(endOfWeek).capitalizeWords();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('weekly_plans')
          .where('curriculumId', isEqualTo: widget.curriculum.id)
          .where('weekStartDate', isEqualTo: Timestamp.fromDate(_startOfWeek))
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyStateWidget(
              icon: Icons.error, title: 'Erro ao carregar');
        }

        final planDoc = snapshot.data?.docs.firstOrNull;
        final plan = planDoc != null ? WeeklyPlan.fromFirestore(planDoc) : null;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeWeek(-7)),
                    Expanded(
                      child: Column(
                        children: [
                          Text(weekLabel,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            '$startDayName à $endDayName',
                            style:
                                const TextStyle(fontSize: 12, color: textHint),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _changeWeek(7)),
                  ],
                ),
              ),
              Expanded(
                child: plan == null
                    ? const EmptyStateWidget(
                        icon: Icons.view_week_outlined,
                        title: 'Nenhum Plano para esta Semana',
                        message: 'Clique no botão "+" para começar.',
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: _buildTechniquesSection(context,
                                    'Técnicas Recomendadas', plan.techniques),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: _buildObservationsSection(context,
                                    'Observações Gerais', plan.observations),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Última atualização por ${plan.lastUpdatedByName} em ${DateFormat('dd/MM/yy HH:mm').format(plan.lastUpdatedAt.toDate())}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: textHint,
                                  fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showEditWeeklyPlanDialog(plan),
            tooltip: plan == null
                ? 'Definir Plano da Semana'
                : 'Editar Plano da Semana',
            child: const Icon(Icons.edit_note_rounded),
          ),
        );
      },
    );
  }

  Widget _buildTechniquesSection(
      BuildContext context, String title, List<TaughtTechnique> techniques) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Divider(height: 16),
        if (techniques.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Nenhuma técnica recomendada para esta semana.',
                style: TextStyle(color: textHint)),
          )
        else
          ...techniques.map((tech) {
            final hasVideo =
                tech.videoId != null && tech.videoThumbnailUrl != null;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
              leading: Icon(
                  hasVideo
                      ? Icons.play_circle_fill_rounded
                      : Icons.label_important_outline,
                  color: primaryAccent),
              title: Text(tech.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: tech.description.isNotEmpty
                  ? Text(tech.description,
                      style: const TextStyle(color: textSecondary))
                  : null,
              onTap: hasVideo
                  ? () {
                      _navigateToVideoPlayer(
                          context, widget.user, tech.videoId!);
                    }
                  : null,
            );
          }),
      ],
    );
  }

  Widget _buildObservationsSection(
      BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Divider(height: 16),
        content.trim().isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Nenhuma observação adicionada.',
                    style: TextStyle(color: textHint)),
              )
            : Text(content,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.5)),
      ],
    );
  }
}

// --- INÍCIO DA CORREÇÃO: Adiciona o diálogo que estava faltando ---
class _AddEditCurriculumDialog extends StatefulWidget {
  final CollectionReference curriculumsCollection;
  final Curriculum? curriculum;

  const _AddEditCurriculumDialog(
      {required this.curriculumsCollection, this.curriculum});

  @override
  State<_AddEditCurriculumDialog> createState() =>
      _AddEditCurriculumDialogState();
}

class _AddEditCurriculumDialogState extends State<_AddEditCurriculumDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.curriculum != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.curriculum!.name;
      _descriptionController.text = widget.curriculum!.description;
    }
  }

  Future<void> _saveCurriculum() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      if (_isEditing) {
        await widget.curriculumsCollection
            .doc(widget.curriculum!.id)
            .update(data);
      } else {
        await widget.curriculumsCollection.add(data);
      }
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar currículo.', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Currículo' : 'Novo Currículo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Nome do Currículo'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'O nome é obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Descrição (Opcional)'),
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
          onPressed: _isLoading ? null : _saveCurriculum,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
// --- FIM DA CORREÇÃO ---

class _ClassPlanCard extends StatelessWidget {
  final TrainingClass trainingClass;
  final DateTime classDate;
  final UserModel currentUser;
  final LessonPlan? existingPlan;

  const _ClassPlanCard({
    required this.trainingClass,
    required this.classDate,
    required this.currentUser,
    this.existingPlan,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPlan = existingPlan != null;
    return Card(
      child: ListTile(
        leading: Icon(
          hasPlan
              ? Icons.assignment_turned_in_rounded
              : Icons.assignment_late_outlined,
          color: hasPlan ? successColor : textHint,
        ),
        title: Text('${trainingClass.level} (${trainingClass.startTime})'),
        subtitle: Text('Prof. ${trainingClass.teacherName}'),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EditLessonPlanPage(
              currentUser: currentUser,
              trainingClass: trainingClass,
              classDate:
                  DateTime(classDate.year, classDate.month, classDate.day),
              existingPlan: existingPlan,
            ),
          ));
        },
      ),
    );
  }
}

class _EditWeeklyPlanDialog extends StatefulWidget {
  final UserModel user;
  final DateTime weekStartDate;
  final WeeklyPlan? existingPlan;
  final String curriculumId;

  const _EditWeeklyPlanDialog({
    required this.user,
    required this.weekStartDate,
    this.existingPlan,
    required this.curriculumId,
  });

  @override
  State<_EditWeeklyPlanDialog> createState() => _EditWeeklyPlanDialogState();
}

class _EditWeeklyPlanDialogState extends State<_EditWeeklyPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _observationsController = TextEditingController();
  List<TaughtTechnique> _techniques = [];
  bool _isLoading = false;
  bool _hasVideoAccess = false;

  @override
  void initState() {
    super.initState();
    _checkVideoAccess();
    if (widget.existingPlan != null) {
      _techniques = List<TaughtTechnique>.from(widget.existingPlan!.techniques
          .map((t) => TaughtTechnique(
              name: t.name,
              description: t.description,
              videoId: t.videoId,
              videoTitle: t.videoTitle,
              videoThumbnailUrl: t.videoThumbnailUrl)));
      _observationsController.text = widget.existingPlan!.observations;
    }
  }

  Future<void> _checkVideoAccess() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _hasVideoAccess = doc.data()!['hasVideoLibraryAccess'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao verificar acesso à videoteca: $e");
    }
  }

  void _addTechnique() {
    setState(() {
      _techniques.add(TaughtTechnique(name: '', description: ''));
    });
  }

  void _removeTechnique(int index) {
    setState(() {
      _techniques.removeAt(index);
    });
  }

  Future<void> _saveWeeklyPlan() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final data = {
      'academyId': widget.user.academyId,
      'curriculumId': widget.curriculumId,
      'weekStartDate': Timestamp.fromDate(widget.weekStartDate),
      'techniques': _techniques.map((t) => t.toMap()).toList(),
      'observations': _observationsController.text.trim(),
      'lastUpdatedByUid': widget.user.uid,
      'lastUpdatedByName': widget.user.name,
      'lastUpdatedAt': Timestamp.now(),
    };

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('weekly_plans');

      final docId =
          '${widget.curriculumId}_${DateFormat('yyyy-MM-dd').format(widget.weekStartDate)}';

      await collectionRef.doc(docId).set(data);

      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Definir Plano da Semana'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Técnicas Recomendadas',
                        style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: primaryAccent),
                      onPressed: _addTechnique,
                    )
                  ],
                ),
                const Divider(),
                if (_techniques.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Nenhuma técnica adicionada.')),
                  ),
                ..._techniques.asMap().entries.map((entry) {
                  return _TechniqueEditCard(
                    key: ValueKey('${entry.value.name}-${entry.key}'),
                    technique: entry.value,
                    onRemove: () => _removeTechnique(entry.key),
                    onSaved: (updated) => _techniques[entry.key] = updated,
                    hasVideoAccess: _hasVideoAccess,
                    academyId: widget.user.academyId,
                    onVideoChanged: (video) {
                      setState(() {
                        _techniques[entry.key].videoId = video.id;
                        _techniques[entry.key].videoTitle = video.title;
                        _techniques[entry.key].videoThumbnailUrl =
                            video.thumbnailUrl;
                      });
                    },
                    onVideoRemoved: () {
                      setState(() {
                        _techniques[entry.key].videoId = null;
                        _techniques[entry.key].videoTitle = null;
                        _techniques[entry.key].videoThumbnailUrl = null;
                      });
                    },
                  );
                }),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _observationsController,
                  decoration: const InputDecoration(
                    labelText: 'Observações Gerais (Opcional)',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveWeeklyPlan,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _TechniqueEditCard extends StatelessWidget {
  final TaughtTechnique technique;
  final VoidCallback onRemove;
  final ValueSetter<TaughtTechnique> onSaved;
  final bool hasVideoAccess;
  final String academyId;
  final ValueSetter<VideoItem> onVideoChanged;
  final VoidCallback onVideoRemoved;

  const _TechniqueEditCard({
    super.key,
    required this.technique,
    required this.onRemove,
    required this.onSaved,
    required this.hasVideoAccess,
    required this.academyId,
    required this.onVideoChanged,
    required this.onVideoRemoved,
  });

  Future<void> _selectVideo(BuildContext context) async {
    final VideoItem? selectedVideo = await showDialog<VideoItem>(
      context: context,
      builder: (_) => VideoPickerDialog(academyId: academyId),
    );

    if (selectedVideo != null) {
      onVideoChanged(selectedVideo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Técnica', style: Theme.of(context).textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: errorColor),
                  onPressed: onRemove,
                )
              ],
            ),
            TextFormField(
              initialValue: technique.name,
              decoration: const InputDecoration(labelText: 'Nome da Técnica'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'O nome é obrigatório'
                  : null,
              onSaved: (value) => technique.name = value ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: technique.description,
              decoration:
                  const InputDecoration(labelText: 'Descrição (opcional)'),
              maxLines: 2,
              onSaved: (value) => technique.description = value ?? '',
            ),
            if (hasVideoAccess) ...[
              const SizedBox(height: 12),
              if (technique.videoId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Image.network(technique.videoThumbnailUrl!,
                      width: 56, fit: BoxFit.cover),
                  title: const Text("Vídeo Anexado"),
                  subtitle: Text(technique.videoTitle ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: errorColor),
                    onPressed: onVideoRemoved,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _selectVideo(context),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Anexar Vídeo'),
                ),
            ]
          ],
        ),
      ),
    );
  }
}
