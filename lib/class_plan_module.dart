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

// --- TELA PRINCIPAL DO PLANEJAMENTO (COM ABAS) ---
class ClassPlanPage extends StatefulWidget {
  final UserModel user;

  const ClassPlanPage({super.key, required this.user});

  @override
  State<ClassPlanPage> createState() => _ClassPlanPageState();
}

class _ClassPlanPageState extends State<ClassPlanPage>
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
    return Column(
      children: [
        Container(
          color: darkSurface,
          child: TabBar(
            controller: _tabController,
            // --- INÍCIO DA ALTERAÇÃO ---
            // Removemos os ícones para uma barra mais compacta e elegante.
            tabs: const [
              Tab(text: 'Diário de Aulas'),
              Tab(text: 'Plano da Semana'),
            ],
            // --- FIM DA ALTERAÇÃO ---
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DailyLogView(user: widget.user),
              _WeeklyPlanView(user: widget.user),
            ],
          ),
        ),
      ],
    );
  }
}

// --- ABA 1: DIÁRIO DE AULAS (REGISTRO DO QUE FOI FEITO) ---
class _DailyLogView extends StatefulWidget {
  final UserModel user;
  const _DailyLogView({required this.user});

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
                    icon: Icons.event_busy, title: 'Nenhuma aula neste dia');
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
  const _WeeklyPlanView({required this.user});

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
            ));
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
          ...techniques.map((tech) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                leading: const Icon(Icons.label_important_outline,
                    color: primaryAccent),
                title: Text(tech.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: tech.description.isNotEmpty
                    ? Text(tech.description,
                        style: const TextStyle(color: textSecondary))
                    : null,
              )),
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

// ... O restante do arquivo (diálogos, cards, etc.) permanece exatamente o mesmo ...
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

  const _EditWeeklyPlanDialog({
    required this.user,
    required this.weekStartDate,
    this.existingPlan,
  });

  @override
  State<_EditWeeklyPlanDialog> createState() => _EditWeeklyPlanDialogState();
}

class _EditWeeklyPlanDialogState extends State<_EditWeeklyPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _observationsController = TextEditingController();
  List<TaughtTechnique> _techniques = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _techniques = List<TaughtTechnique>.from(widget.existingPlan!.techniques
          .map((t) =>
              TaughtTechnique(name: t.name, description: t.description)));
      _observationsController.text = widget.existingPlan!.observations;
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

      final weekId = DateFormat('yyyy-MM-dd').format(widget.weekStartDate);

      await collectionRef.doc(weekId).set(data);

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
                    key: ValueKey(entry.key),
                    technique: entry.value,
                    onRemove: () => _removeTechnique(entry.key),
                    onSaved: (updated) => _techniques[entry.key] = updated,
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
              ? const CircularProgressIndicator(strokeWidth: 2)
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

  const _TechniqueEditCard({
    super.key,
    required this.technique,
    required this.onRemove,
    required this.onSaved,
  });

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
          ],
        ),
      ),
    );
  }
}
