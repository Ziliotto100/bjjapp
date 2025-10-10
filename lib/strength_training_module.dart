// lib/strength_training_module.dart
// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'strength_stats_page.dart';

// -----------------------------------------------------------------------------
// TELA PRINCIPAL DO MÓDULO (LISTA DE FICHAS)
// -----------------------------------------------------------------------------
class StrengthTrainingPage extends StatefulWidget {
  final UserModel user;
  const StrengthTrainingPage({super.key, required this.user});

  @override
  State<StrengthTrainingPage> createState() => _StrengthTrainingPageState();
}

class _StrengthTrainingPageState extends State<StrengthTrainingPage> {
  Stream<QuerySnapshot> _getRoutinesStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('workout_routines')
        .snapshots();
  }

  Future<void> _navigateToWorkoutSession(WorkoutRoutine? routine) async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkoutSessionPage(
        user: widget.user,
        routine: routine,
      ),
    ));
  }

  void _navigateToEditRoutine([WorkoutRoutine? routine]) {
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => EditWorkoutRoutinePage(
        user: widget.user,
        routine: routine,
      ),
    ))
        .then((_) {
      setState(() {});
    });
  }

  Future<void> _deleteRoutine(WorkoutRoutine routine) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Ficha?'),
        content: Text(
            'Tem certeza que deseja excluir a ficha "${routine.name}" permanentemente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .collection('workout_routines')
            .doc(routine.id)
            .delete();
        if (mounted) {
          showBjjSnackBar(context, 'Ficha de treino excluída!',
              type: 'success');
        }
      } catch (e) {
        if (mounted) {
          showBjjSnackBar(context, 'Erro ao excluir a ficha: $e',
              type: 'error');
        }
      }
    }
  }

  void _navigateToStats() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StrengthProgressPage(user: widget.user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Minhas Fichas',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bar_chart_rounded,
                              color: primaryAccent),
                          onPressed: _navigateToStats,
                          tooltip: 'Ver Meu Progresso',
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: primaryAccent),
                          onPressed: () => _navigateToEditRoutine(),
                          tooltip: 'Nova Ficha',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getRoutinesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const EmptyStateWidget(
                          icon: Icons.error, title: 'Erro ao Carregar Fichas');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.fitness_center,
                        title: 'Nenhuma Ficha de Treino',
                        message:
                            'Clique no botão "+" no canto superior para criar sua primeira rotina.',
                      );
                    }

                    final routines = snapshot.data!.docs
                        .map((doc) => WorkoutRoutine.fromFirestore(doc))
                        .toList();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                      itemCount: routines.length,
                      itemBuilder: (context, index) {
                        final routine = routines[index];
                        return _WorkoutRoutineCard(
                          routine: routine,
                          onStart: () => _navigateToWorkoutSession(routine),
                          onEdit: () => _navigateToEditRoutine(routine),
                          onDelete: () => _deleteRoutine(routine),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToWorkoutSession(null),
        label: const Text('Treino Livre'),
        icon: const Icon(Icons.directions_run),
        heroTag: 'fab_free_workout',
      ),
    );
  }
}

// Card para exibir uma ficha de treino
class _WorkoutRoutineCard extends StatelessWidget {
  final WorkoutRoutine routine;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorkoutRoutineCard({
    required this.routine,
    required this.onStart,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sortedDays = routine.daysOfWeek
      ..sort((a, b) {
        const order = {
          'Segunda-feira': 1,
          'Terça-feira': 2,
          'Quarta-feira': 3,
          'Quinta-feira': 4,
          'Sexta-feira': 5,
          'Sábado': 6,
          'Domingo': 7
        };
        return (order[a] ?? 8).compareTo(order[b] ?? 8);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routine.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  if (sortedDays.isNotEmpty)
                    Text(sortedDays.join(', '),
                        style: const TextStyle(
                            color: textHint,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  Text('${routine.items.length} exercícios',
                      style: const TextStyle(color: textHint)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
                backgroundColor: successColor,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: textHint),
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA PARA CRIAR E EDITAR UMA FICHA DE TREINO
// -----------------------------------------------------------------------------
class EditWorkoutRoutinePage extends StatefulWidget {
  final UserModel user;
  final WorkoutRoutine? routine;

  const EditWorkoutRoutinePage({super.key, required this.user, this.routine});

  @override
  _EditWorkoutRoutinePageState createState() => _EditWorkoutRoutinePageState();
}

class _EditWorkoutRoutinePageState extends State<EditWorkoutRoutinePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<RoutineItem> _items = [];
  bool _isLoading = false;
  List<String> _selectedDays = [];
  final Set<String> _selectedItemIds = {}; // Para controlar a seleção múltipla

  final List<String> _daysOfWeek = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo'
  ];

  bool get _isEditing => widget.routine != null;
  bool get _isSelectionMode => _selectedItemIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.routine!.name;
      _items = List<RoutineItem>.from(widget.routine!.items);
      _selectedDays = List<String>.from(widget.routine!.daysOfWeek);
    }
  }

  Future<void> _addExercise() async {
    final Exercise? selectedExercise = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ExerciseLibraryPage(user: widget.user)),
    );

    if (selectedExercise == null) return;

    final RoutineItem? newRoutineItem = await showDialog<RoutineItem>(
      context: context,
      builder: (_) => _RoutineItemDialog(exercise: selectedExercise),
    );

    if (newRoutineItem != null) {
      setState(() {
        _items.add(newRoutineItem);
      });
    }
  }

  void _groupSelectedItems() {
    if (_selectedItemIds.length < 2) return;

    final newGroupId = const Uuid().v4();
    setState(() {
      for (var item in _items) {
        if (_selectedItemIds.contains(item.id)) {
          item.groupId = newGroupId;
        }
      }
      _selectedItemIds.clear();
    });
  }

  void _ungroupSelectedItems() {
    final Set<String> groupIdsToClear = {};
    for (var itemId in _selectedItemIds) {
      final item = _items.firstWhereOrNull((it) => it.id == itemId);
      if (item?.groupId != null) {
        groupIdsToClear.add(item!.groupId!);
      }
    }

    setState(() {
      for (var item in _items) {
        if (groupIdsToClear.contains(item.groupId)) {
          item.groupId = null;
        }
      }
      _selectedItemIds.clear();
    });
  }

  void _handleItemTap(RoutineItem item) {
    setState(() {
      if (_isSelectionMode) {
        if (_selectedItemIds.contains(item.id)) {
          _selectedItemIds.remove(item.id);
        } else {
          _selectedItemIds.add(item.id);
        }
      }
    });
  }

  void _handleItemLongPress(RoutineItem item) {
    setState(() {
      if (!_selectedItemIds.contains(item.id)) {
        _selectedItemIds.add(item.id);
      }
    });
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate() || _items.isEmpty) {
      showBjjSnackBar(
          context, 'Preencha o nome e adicione pelo menos um exercício.',
          type: 'error');
      return;
    }
    setState(() => _isLoading = true);

    final routine = WorkoutRoutine(
      id: _isEditing ? widget.routine!.id : '',
      name: _nameController.text.trim(),
      items: _items,
      daysOfWeek: _selectedDays,
    );

    final collectionRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('workout_routines');

    try {
      if (_isEditing) {
        await collectionRef.doc(routine.id).update(routine.toMap());
      } else {
        await collectionRef.add(routine.toMap());
      }
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar a ficha: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool canGroup = _selectedItemIds.length > 1 &&
        _selectedItemIds.every(
            (id) => _items.firstWhere((item) => item.id == id).groupId == null);
    bool canUngroup = _selectedItemIds.isNotEmpty &&
        _selectedItemIds.any(
            (id) => _items.firstWhere((item) => item.id == id).groupId != null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedItemIds.clear()),
              )
            : null,
        title: Text(_isEditing ? 'Editar Ficha' : 'Nova Ficha de Treino'),
        actions: _isSelectionMode
            ? [
                if (canGroup)
                  IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: _groupSelectedItems,
                    tooltip: 'Agrupar (Superset)',
                  ),
                if (canUngroup)
                  IconButton(
                    icon: const Icon(Icons.link_off),
                    onPressed: _ungroupSelectedItems,
                    tooltip: 'Desagrupar',
                  ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _isLoading ? null : _saveRoutine,
                )
              ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration:
                            const InputDecoration(labelText: 'Nome da Ficha'),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'O nome é obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Dias da Semana (Opcional)',
                          style: TextStyle(color: textHint)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _daysOfWeek.map((day) {
                          final isSelected = _selectedDays.contains(day);
                          return FilterChip(
                            label: Text(day),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedDays.add(day);
                                } else {
                                  _selectedDays.remove(day);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(child: _buildItemList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemList() {
    final List<dynamic> groupedItems = [];
    final Set<String> processedGroupIds = {};

    for (var item in _items) {
      if (item.groupId != null) {
        if (!processedGroupIds.contains(item.groupId!)) {
          final group = _items.where((i) => i.groupId == item.groupId).toList();
          groupedItems.add(group);
          processedGroupIds.add(item.groupId!);
        }
      } else {
        groupedItems.add(item);
      }
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: groupedItems.length + 1, // +1 para o botão
      itemBuilder: (context, index) {
        if (index == groupedItems.length) {
          return Padding(
            key: const ValueKey('add_button'),
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: OutlinedButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Exercício'),
            ),
          );
        }

        final item = groupedItems[index];

        if (item is List<RoutineItem>) {
          // É um superset
          return Container(
            key: ValueKey(item.first.groupId),
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            decoration: BoxDecoration(
              border: Border.all(color: primaryAccent.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                children: item.mapIndexed((i, subItem) {
                  return _buildItemCard(
                    subItem,
                    isFirstInGroup: i == 0,
                    isLastInGroup: i == item.length - 1,
                  );
                }).toList(),
              ),
            ),
          );
        } else {
          // É um item individual
          return _buildItemCard(item);
        }
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          if (newIndex >= groupedItems.length) {
            newIndex = groupedItems.length - 1;
          }

          final movedItem = groupedItems.removeAt(oldIndex);
          groupedItems.insert(newIndex, movedItem);

          _items = groupedItems.expand((item) {
            if (item is List<RoutineItem>) {
              return item;
            } else {
              return [item as RoutineItem];
            }
          }).toList();
        });
      },
    );
  }

  Widget _buildItemCard(RoutineItem item,
      {bool isFirstInGroup = false, bool isLastInGroup = false}) {
    final isSelected = _selectedItemIds.contains(item.id);

    return Material(
      color: isSelected
          ? primaryAccent.withOpacity(0.2)
          : darkSurface.withOpacity(0.8),
      child: InkWell(
        onTap: () => _handleItemTap(item),
        onLongPress: () => _handleItemLongPress(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) => _handleItemTap(item),
                )
              else
                ReorderableDragStartListener(
                  index: _items.indexOf(item),
                  child: const Icon(Icons.drag_handle_rounded, color: textHint),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.exerciseName,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _InfoChip(
                            icon: Icons.repeat,
                            text: '${item.series}x ${item.repetitions}'),
                        const SizedBox(width: 8),
                        _InfoChip(
                            icon: Icons.timer_outlined,
                            text: '${item.restTimeInSeconds}s'),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.groupId != null)
                const Icon(Icons.link, color: primaryAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: darkScaffoldBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textHint, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: textHint, fontSize: 12)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// DIÁLOGO PARA CONFIGURAR UM ITEM DA ROTINA (SÉRIES, REPS, ETC.)
// -----------------------------------------------------------------------------
class _RoutineItemDialog extends StatefulWidget {
  final Exercise exercise;
  const _RoutineItemDialog({required this.exercise});

  @override
  __RoutineItemDialogState createState() => __RoutineItemDialogState();
}

class __RoutineItemDialogState extends State<_RoutineItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _seriesController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _restController = TextEditingController(text: '60');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.name),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _seriesController,
                decoration: const InputDecoration(labelText: 'Séries'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v!.isEmpty || int.tryParse(v) == null || int.parse(v) <= 0
                        ? 'Inválido'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _repsController,
                decoration: const InputDecoration(
                    labelText: 'Repetições', hintText: 'Ex: 8-12'),
                validator: (v) => v!.isEmpty ? 'Inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _restController,
                decoration:
                    const InputDecoration(labelText: 'Descanso (segundos)'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    v!.isEmpty || int.tryParse(v) == null ? 'Inválido' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final item = RoutineItem(
                id: const Uuid().v4(),
                exerciseId: widget.exercise.id,
                exerciseName: widget.exercise.name,
                series: int.parse(_seriesController.text),
                repetitions: _repsController.text,
                restTimeInSeconds: int.parse(_restController.text),
              );
              Navigator.of(context).pop(item);
            }
          },
          child: const Text('Adicionar'),
        )
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DA SESSÃO DE TREINO (MODO TREINO)
// -----------------------------------------------------------------------------
class WorkoutSessionPage extends StatefulWidget {
  final UserModel user;
  final WorkoutRoutine? routine;

  const WorkoutSessionPage({
    super.key,
    required this.user,
    required this.routine,
  });

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  late List<LoggedExercise> _loggedExercises;
  bool _isLoading = false;
  PhysicalCondition? _physicalCondition;
  DateTime? _workoutDate;
  bool _isReady = false;

  bool get isFreeWorkout => widget.routine == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showStartWorkoutDialogs();
    });
  }

  Future<void> _showStartWorkoutDialogs() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );

    if (selectedDate == null) {
      Navigator.of(context).pop();
      return;
    }

    if (!mounted) return;

    final PhysicalCondition? result = await showDialog<PhysicalCondition>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PhysicalConditionDialog(),
    );

    if (result == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _workoutDate = selectedDate;
      _physicalCondition = result;
      if (isFreeWorkout) {
        _loggedExercises = [];
      } else {
        _loggedExercises = widget.routine!.items
            .map((item) => LoggedExercise(
                  exerciseId: item.exerciseId,
                  exerciseName: item.exerciseName,
                  sets: List.generate(item.series,
                      (index) => LoggedSet(weight: 0, repetitions: 0)),
                ))
            .toList();
      }
      _isReady = true;
    });
  }

  Future<void> _addExerciseToSession() async {
    final Exercise? selectedExercise = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ExerciseLibraryPage(user: widget.user)),
    );

    if (selectedExercise != null) {
      setState(() {
        _loggedExercises.add(LoggedExercise(
          exerciseId: selectedExercise.id,
          exerciseName: selectedExercise.name,
          sets: [],
        ));
      });
    }
  }

  Future<void> _finishWorkout() async {
    if (_loggedExercises.isEmpty) {
      showBjjSnackBar(
          context, 'Adicione pelo menos um exercício para salvar o treino.',
          type: 'info');
      return;
    }

    final result = await showDialog<Map<String, int?>>(
      context: context,
      builder: (_) => const _PerformanceRatingDialog(),
    );

    if (result == null || result['rating'] == null) {
      return;
    }
    if (result['duration'] == null) {
      showBjjSnackBar(context, 'Por favor, informe a duração do treino.',
          type: 'error');
      return;
    }

    final confirmedRating = result['rating'];
    final duration = result['duration'];

    setState(() => _isLoading = true);

    final logData = {
      'routineName': isFreeWorkout ? 'Treino Livre' : widget.routine!.name,
      'date': Timestamp.fromDate(_workoutDate!),
      'exercises': _loggedExercises.map((e) => e.toMap()).toList(),
      'performanceRating': confirmedRating,
      'physicalCondition': _physicalCondition != null
          ? physicalConditionToString(_physicalCondition!)
          : null,
      'durationInMinutes': duration,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('workout_logs')
          .add(logData);

      showBjjSnackBar(context, 'Treino salvo com sucesso!', type: 'success');
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar treino: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isFreeWorkout ? 'Treino Livre' : widget.routine!.name),
        actions: [
          TextButton(
            onPressed: (_isLoading || !_isReady) ? null : _finishWorkout,
            child: const Text('Finalizar'),
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !_isReady
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final List<dynamic> items;

    if (isFreeWorkout) {
      items = _loggedExercises;
    } else {
      items = [];
      final Set<String> processedGroupIds = {};
      for (var item in widget.routine!.items) {
        if (item.groupId != null) {
          if (!processedGroupIds.contains(item.groupId!)) {
            final group = widget.routine!.items
                .where((i) => i.groupId == item.groupId)
                .toList();
            items.add(group);
            processedGroupIds.add(item.groupId!);
          }
        } else {
          items.add(item);
        }
      }
    }

    if (items.isEmpty && isFreeWorkout) {
      return Column(
        children: [
          const Expanded(
            child: EmptyStateWidget(
                icon: Icons.add,
                title: 'Inicie seu Treino',
                message: 'Clique em "+ Exercício" para adicionar o primeiro.'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _addExerciseToSession,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Exercício'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: items.length + (isFreeWorkout ? 1 : 0),
      itemBuilder: (context, index) {
        if (isFreeWorkout) {
          if (index == items.length) {
            return Padding(
              key: const ValueKey('add_button'),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: OutlinedButton.icon(
                onPressed: _addExerciseToSession,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Exercício'),
              ),
            );
          }
          return _ExerciseExecutionCard(
            key:
                ValueKey(_loggedExercises[index].exerciseId + index.toString()),
            loggedExercise: _loggedExercises[index],
            user: widget.user,
            isFreeWorkout: true,
          );
        } else {
          final itemOrGroup = items[index];

          if (itemOrGroup is List<RoutineItem>) {
            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: primaryAccent, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: itemOrGroup.map((routineItem) {
                  final loggedExercise = _loggedExercises.firstWhere(
                      (le) => le.exerciseId == routineItem.exerciseId);
                  return _ExerciseExecutionCard(
                    key: ValueKey(routineItem.id),
                    routineItem: routineItem,
                    loggedExercise: loggedExercise,
                    user: widget.user,
                    isFreeWorkout: false,
                    isSuperset: true,
                  );
                }).toList(),
              ),
            );
          } else {
            final routineItem = itemOrGroup as RoutineItem;
            final loggedExercise = _loggedExercises
                .firstWhere((le) => le.exerciseId == routineItem.exerciseId);
            return _ExerciseExecutionCard(
              key: ValueKey(routineItem.id),
              routineItem: routineItem,
              loggedExercise: loggedExercise,
              user: widget.user,
              isFreeWorkout: false,
            );
          }
        }
      },
    );
  }
}

class _PhysicalConditionDialog extends StatelessWidget {
  const _PhysicalConditionDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Como você se sente hoje?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Selecione sua disposição para o treino de hoje.'),
          const SizedBox(height: 24),
          _buildOption(context, 'Disposto(a) 😃', PhysicalCondition.disposto),
          const SizedBox(height: 8),
          _buildOption(context, 'Normal 😐', PhysicalCondition.normal),
          const SizedBox(height: 8),
          _buildOption(context, 'Cansado(a) 😴', PhysicalCondition.cansado),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, String text, PhysicalCondition value) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pop(value),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
      child: Text(text),
    );
  }
}

class _PerformanceRatingDialog extends StatefulWidget {
  const _PerformanceRatingDialog();

  @override
  State<_PerformanceRatingDialog> createState() =>
      _PerformanceRatingDialogState();
}

class _PerformanceRatingDialogState extends State<_PerformanceRatingDialog> {
  final _formKey = GlobalKey<FormState>();
  int _rating = 3;
  final _durationController = TextEditingController();

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finalizar e Avaliar Treino'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Como você avalia sua performance geral hoje?'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: primaryAccent,
                      size: 32,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duração do Treino (minutos)',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    (v == null || v.trim().isEmpty || int.tryParse(v) == 0)
                        ? 'Duração é obrigatória'
                        : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final duration = int.tryParse(_durationController.text);
              Navigator.of(context)
                  .pop({'rating': _rating, 'duration': duration});
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ExerciseExecutionCard extends StatefulWidget {
  final RoutineItem? routineItem;
  final LoggedExercise loggedExercise;
  final UserModel user;
  final bool isFreeWorkout;
  final bool isSuperset;

  const _ExerciseExecutionCard({
    super.key,
    this.routineItem,
    required this.loggedExercise,
    required this.user,
    this.isFreeWorkout = false,
    this.isSuperset = false,
  });

  @override
  __ExerciseExecutionCardState createState() => __ExerciseExecutionCardState();
}

class __ExerciseExecutionCardState extends State<_ExerciseExecutionCard> {
  void _addSet() {
    setState(() {
      final lastSet = widget.loggedExercise.sets.isNotEmpty
          ? widget.loggedExercise.sets.last
          : LoggedSet(weight: 0, repetitions: 0);
      widget.loggedExercise.sets.add(
          LoggedSet(weight: lastSet.weight, repetitions: lastSet.repetitions));
    });
  }

  Future<void> _showHistoryDialog() async {
    final history = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('workout_logs')
        .orderBy('date', descending: true)
        .get();

    final List<Map<String, dynamic>> exerciseHistory = [];

    for (var doc in history.docs) {
      final log = WorkoutLog.fromFirestore(doc);
      final relevantExercises = log.exercises
          .where((ex) => ex.exerciseName == widget.loggedExercise.exerciseName);
      if (relevantExercises.isNotEmpty) {
        exerciseHistory.add({
          'date': log.date,
          'sets': relevantExercises.first.sets,
        });
      }
    }

    showDialog(
        context: context,
        builder: (_) => _ExerciseHistoryDialog(
            exerciseName: widget.loggedExercise.exerciseName,
            history: exerciseHistory));
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.loggedExercise.exerciseName,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton(
                icon: const Icon(Icons.history, color: textHint),
                onPressed: _showHistoryDialog,
                tooltip: 'Ver Histórico de Carga',
              )
            ],
          ),
          const SizedBox(height: 8),
          if (!widget.isFreeWorkout && widget.routineItem != null)
            Text(
              'Meta: ${widget.routineItem!.series}x ${widget.routineItem!.repetitions} reps',
              style: const TextStyle(color: textHint, fontSize: 16),
            ),
          const Divider(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.loggedExercise.sets.length,
            itemBuilder: (context, index) {
              return _SetInputRow(
                setNumber: index + 1,
                loggedSet: widget.loggedExercise.sets[index],
                previousSet:
                    index > 0 ? widget.loggedExercise.sets[index - 1] : null,
                onSetCompleted: (weight, reps) {
                  setState(() {
                    widget.loggedExercise.sets[index] =
                        LoggedSet(weight: weight, repetitions: reps);
                  });
                },
                onRemove: widget.isFreeWorkout
                    ? () {
                        setState(() {
                          widget.loggedExercise.sets.removeAt(index);
                        });
                      }
                    : null,
              );
            },
          ),
          if (widget.isFreeWorkout) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _addSet,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Série'),
              ),
            )
          ]
        ],
      ),
    );

    if (widget.isSuperset) {
      return cardContent;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: cardContent,
    );
  }
}

// ... (Restante do arquivo)

// --- ADICIONE ESTE WIDGET NO FINAL DO ARQUIVO ---
class _ExerciseHistoryDialog extends StatelessWidget {
  final String exerciseName;
  final List<Map<String, dynamic>> history;

  const _ExerciseHistoryDialog(
      {required this.exerciseName, required this.history});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Histórico de: $exerciseName'),
      content: SizedBox(
        width: double.maxFinite,
        child: history.isEmpty
            ? const Center(
                child: Text('Nenhum registro encontrado para este exercício.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final record = history[index];
                  final date = record['date'] as DateTime;
                  final sets = record['sets'] as List<LoggedSet>;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.yMMMEd('pt_BR').format(date),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryAccent),
                        ),
                        const SizedBox(height: 4),
                        ...sets.asMap().entries.map((entry) {
                          int setIndex = entry.key + 1;
                          LoggedSet set = entry.value;
                          return Text(
                              'Série $setIndex: ${set.weight} kg x ${set.repetitions} reps');
                        }),
                        if (index < history.length - 1)
                          const Divider(height: 16),
                      ],
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

class _SetInputRow extends StatefulWidget {
  final int setNumber;
  final LoggedSet loggedSet;
  final LoggedSet? previousSet;
  final Function(double weight, int reps) onSetCompleted;
  final VoidCallback? onRemove;

  const _SetInputRow({
    required this.setNumber,
    required this.loggedSet,
    this.previousSet,
    required this.onSetCompleted,
    this.onRemove,
  });

  @override
  __SetInputRowState createState() => __SetInputRowState();
}

class __SetInputRowState extends State<_SetInputRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _isCompleted =
        widget.loggedSet.weight > 0 || widget.loggedSet.repetitions > 0;
    _weightController =
        TextEditingController(text: widget.loggedSet.weight.toString());
    _repsController =
        TextEditingController(text: widget.loggedSet.repetitions.toString());
  }

  @override
  void didUpdateWidget(covariant _SetInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Atualiza os controladores se o objeto LoggedSet mudar externamente
    if (widget.loggedSet != oldWidget.loggedSet) {
      _weightController.text = widget.loggedSet.weight.toString();
      _repsController.text = widget.loggedSet.repetitions.toString();
      _isCompleted =
          widget.loggedSet.weight > 0 || widget.loggedSet.repetitions > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          widget.onRemove != null
              ? IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: errorColor),
                  onPressed: widget.onRemove,
                )
              : CircleAvatar(
                  backgroundColor: _isCompleted ? successColor : darkSurface,
                  child: Text(
                    widget.setNumber.toString(),
                    style: TextStyle(
                        color: _isCompleted ? Colors.white : textPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
          const SizedBox(width: 8),
          if (widget.setNumber > 1 && widget.previousSet != null)
            IconButton(
              icon: const Icon(Icons.content_copy, color: textHint),
              tooltip: 'Copiar série anterior',
              onPressed: () {
                setState(() {
                  _weightController.text =
                      widget.previousSet!.weight.toString();
                  _repsController.text =
                      widget.previousSet!.repetitions.toString();
                  _isCompleted = true;
                });
                widget.onSetCompleted(widget.previousSet!.weight,
                    widget.previousSet!.repetitions);
                FocusScope.of(context).unfocus();
              },
            ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _repsController,
              decoration: const InputDecoration(labelText: 'Reps'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
                _isCompleted ? Icons.check_circle : Icons.check_circle_outline),
            color: successColor,
            iconSize: 30,
            onPressed: () {
              final weight = double.tryParse(
                      _weightController.text.replaceAll(',', '.')) ??
                  0;
              final reps = int.tryParse(_repsController.text) ?? 0;
              setState(() {
                _isCompleted = true;
              });
              widget.onSetCompleted(weight, reps);
              FocusScope.of(context).unfocus();
            },
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DA BIBLIOTECA DE EXERCÍCIOS
// -----------------------------------------------------------------------------
class ExerciseLibraryPage extends StatefulWidget {
  final UserModel user;
  const ExerciseLibraryPage({super.key, required this.user});

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  final _searchController = TextEditingController();
  String _selectedMuscleGroup = 'Todos';

  static final List<Exercise> _predefinedExercises = [
    Exercise(id: 'predef_1', name: 'Supino Reto (Barra)', muscleGroup: 'Peito'),
    Exercise(
        id: 'predef_2',
        name: 'Agachamento Livre (Barra)',
        muscleGroup: 'Pernas'),
    Exercise(id: 'predef_3', name: 'Levantamento Terra', muscleGroup: 'Costas'),
    Exercise(
        id: 'predef_4',
        name: 'Desenvolvimento (Halteres)',
        muscleGroup: 'Ombros'),
    Exercise(
        id: 'predef_5', name: 'Puxada Frontal (Pulley)', muscleGroup: 'Costas'),
    Exercise(
        id: 'predef_6', name: 'Rosca Direta (Barra)', muscleGroup: 'Bíceps'),
    Exercise(
        id: 'predef_7',
        name: 'Tríceps Testa (Barra W)',
        muscleGroup: 'Tríceps'),
    Exercise(id: 'predef_8', name: 'Leg Press 45', muscleGroup: 'Pernas'),
    Exercise(
        id: 'predef_9',
        name: 'Elevação Lateral (Halteres)',
        muscleGroup: 'Ombros'),
    Exercise(
        id: 'predef_10', name: 'Remada Curvada (Barra)', muscleGroup: 'Costas'),
    Exercise(
        id: 'predef_11',
        name: 'Flexão de Braço',
        muscleGroup: 'Peito',
        equipment: 'Peso do Corpo'),
    Exercise(
        id: 'predef_12',
        name: 'Barra Fixa',
        muscleGroup: 'Costas',
        equipment: 'Peso do Corpo'),
  ];

  static final List<String> _muscleGroups = [
    'Todos',
    'Peito',
    'Costas',
    'Pernas',
    'Ombros',
    'Bíceps',
    'Tríceps',
    'Abdômen',
    'Outro',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditExerciseDialog({Exercise? exercise}) {
    showDialog(
      context: context,
      builder: (_) => _AddEditExerciseDialog(
        user: widget.user,
        exercise: exercise,
        muscleGroups: _muscleGroups.where((g) => g != 'Todos').toList(),
      ),
    ).then((_) => setState(() {}));
  }

  void _deleteExercise(Exercise exercise) {
    if (exercise.id.startsWith('predef_')) {
      showBjjSnackBar(context, 'Você não pode excluir os exercícios padrão.',
          type: 'info');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Exercício?'),
        content: Text(
            'Tem certeza que deseja excluir "${exercise.name}" da sua biblioteca?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .collection('exercises')
                  .doc(exercise.id)
                  .delete();
              Navigator.of(ctx).pop();
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
      appBar: AppBar(title: const Text('Biblioteca de Exercícios')),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar exercício...',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _muscleGroups.length,
                  itemBuilder: (context, index) {
                    final group = _muscleGroups[index];
                    final isSelected = _selectedMuscleGroup == group;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(group),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedMuscleGroup = group);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.user.uid)
                      .collection('exercises')
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final userExercises = snapshot.hasData
                        ? snapshot.data!.docs
                            .map((doc) => Exercise.fromFirestore(doc))
                            .toList()
                        : <Exercise>[];

                    final allExercises = [
                      ..._predefinedExercises,
                      ...userExercises
                    ];
                    final uniqueExercises =
                        {for (var e in allExercises) e.name: e}.values.toList();
                    uniqueExercises.sort((a, b) => a.name.compareTo(b.name));

                    if (uniqueExercises.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.fitness_center,
                        title: 'Nenhum Exercício Criado',
                        message:
                            'Clique no botão "+" para adicionar seus exercícios personalizados.',
                      );
                    }

                    final searchQuery = _searchController.text.toLowerCase();
                    final filteredExercises = uniqueExercises.where((ex) {
                      final nameMatches =
                          ex.name.toLowerCase().contains(searchQuery);
                      final groupMatches = _selectedMuscleGroup == 'Todos' ||
                          ex.muscleGroup == _selectedMuscleGroup;
                      return nameMatches && groupMatches;
                    }).toList();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                      itemCount: filteredExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = filteredExercises[index];
                        final isPredefined = exercise.id.startsWith('predef_');

                        return Card(
                          child: ListTile(
                            title: Text(exercise.name),
                            subtitle: Text(exercise.muscleGroup),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showAddEditExerciseDialog(
                                      exercise: exercise);
                                } else if (value == 'delete') {
                                  _deleteExercise(exercise);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Editar')),
                                if (!isPredefined)
                                  const PopupMenuItem(
                                      value: 'delete', child: Text('Excluir')),
                              ],
                            ),
                            onTap: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop(exercise);
                              } else {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      ExerciseDetailPage(exercise: exercise),
                                ));
                              }
                            },
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditExerciseDialog(),
        tooltip: 'Novo Exercício',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NOVO DIÁLOGO PARA ADICIONAR/EDITAR EXERCÍCIO
// -----------------------------------------------------------------------------
class _AddEditExerciseDialog extends StatefulWidget {
  final UserModel user;
  final Exercise? exercise;
  final List<String> muscleGroups;

  const _AddEditExerciseDialog(
      {required this.user, this.exercise, required this.muscleGroups});

  @override
  State<_AddEditExerciseDialog> createState() => _AddEditExerciseDialogState();
}

class _AddEditExerciseDialogState extends State<_AddEditExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _instructionsController = TextEditingController();
  String? _selectedMuscleGroup;
  bool _isLoading = false;

  bool get _isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final ex = widget.exercise!;
      _nameController.text = ex.name;
      _equipmentController.text = ex.equipment ?? '';
      _instructionsController.text = ex.instructions ?? '';
      _selectedMuscleGroup = ex.muscleGroup;
    }
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final exerciseData = {
      'name': _nameController.text.trim(),
      'muscleGroup': _selectedMuscleGroup,
      'equipment': _equipmentController.text.trim(),
      'instructions': _instructionsController.text.trim(),
    };

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('exercises');

    try {
      if (_isEditing && !widget.exercise!.id.startsWith('predef_')) {
        await collection.doc(widget.exercise!.id).update(exerciseData);
      } else {
        await collection.add(exerciseData);
      }
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar exercício: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Exercício' : 'Novo Exercício'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => v!.isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMuscleGroup,
                decoration: const InputDecoration(labelText: 'Grupo Muscular'),
                items: widget.muscleGroups
                    .map((group) =>
                        DropdownMenuItem(value: group, child: Text(group)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedMuscleGroup = value),
                validator: (v) => v == null ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _equipmentController,
                decoration:
                    const InputDecoration(labelText: 'Equipamento (opcional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instructionsController,
                decoration:
                    const InputDecoration(labelText: 'Instruções (opcional)'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveExercise,
          child: const Text('Salvar'),
        )
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DE DETALHES DO EXERCÍCIO
// -----------------------------------------------------------------------------
class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;
  const ExerciseDetailPage({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(exercise.name)),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Placeholder para a animação/vídeo
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: darkSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Icon(Icons.videocam_outlined,
                        size: 60, color: textHint)),
              ),
              const SizedBox(height: 24),
              _buildInfoRow(context, 'Grupo Muscular', exercise.muscleGroup),
              if (exercise.equipment != null)
                _buildInfoRow(context, 'Equipamento', exercise.equipment!),
              const Divider(height: 32),
              Text('Instruções', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                exercise.instructions ?? 'Instruções não disponíveis.',
                style: const TextStyle(
                    fontSize: 16, height: 1.5, color: textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text('$label:',
              style: const TextStyle(color: textHint, fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TELA DE ESTATÍSTICAS DE FORÇA (COM ABAS)
// -----------------------------------------------------------------------------
class StrengthProgressPage extends StatefulWidget {
  final UserModel user;
  const StrengthProgressPage({super.key, required this.user});

  @override
  State<StrengthProgressPage> createState() => _StrengthProgressPageState();
}

class _StrengthProgressPageState extends State<StrengthProgressPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
        title: const Text('Meu Progresso'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Estatísticas'),
            Tab(text: 'Histórico de Treinos'),
          ],
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              StrengthStatisticsPage(user: widget.user),
              _HistoryTab(user: widget.user),
            ],
          ),
        ),
      ),
    );
  }
}

// ABA "HISTÓRICO DE TREINOS"
class _HistoryTab extends StatelessWidget {
  final UserModel user;
  const _HistoryTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workout_logs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
              icon: Icons.history,
              title: 'Nenhum Treino Registrado',
              message: 'Seus treinos salvos aparecerão aqui.');
        }

        final logs = snapshot.data!.docs
            .map((doc) => WorkoutLog.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _WorkoutLogCard(log: log, user: user);
          },
        );
      },
    );
  }
}

class _WorkoutLogCard extends StatelessWidget {
  final WorkoutLog log;
  final UserModel user;

  const _WorkoutLogCard({required this.log, required this.user});

  @override
  Widget build(BuildContext context) {
    double totalVolume = 0;
    for (var exercise in log.exercises) {
      for (var set in exercise.sets) {
        totalVolume += set.weight * set.repetitions;
      }
    }
    final formatter = NumberFormat.compact(locale: 'pt_BR');

    String subtitle =
        DateFormat('dd/MM/yyyy HH:mm').format(log.createdAt.toDate());
    if (log.durationInMinutes != null && log.durationInMinutes! > 0) {
      subtitle += ' • Duração: ${log.durationInMinutes} min';
    }

    return Card(
      child: ListTile(
        title: Text(log.routineName),
        subtitle: Text(subtitle),
        leading: const Icon(Icons.fitness_center, color: primaryAccent),
        trailing: Text(
          '${formatter.format(totalVolume)} kg',
          style: const TextStyle(
              color: textHint, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => WorkoutLogDetailPage(log: log, user: user),
          ));
        },
      ),
    );
  }
}

class WorkoutLogDetailPage extends StatelessWidget {
  final WorkoutLog log;
  final UserModel user;

  const WorkoutLogDetailPage(
      {super.key, required this.log, required this.user});

  Future<void> _deleteLog(BuildContext context) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Excluir Treino?'),
              content: const Text(
                  'Tem certeza que deseja excluir este registro de treino?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: errorColor),
                  child: const Text('Excluir'),
                )
              ],
            ));

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('workout_logs')
          .doc(log.id)
          .delete();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(log.routineName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: errorColor),
            onPressed: () => _deleteLog(context),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: log.exercises.length,
            itemBuilder: (context, index) {
              final exercise = log.exercises[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.exerciseName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const Divider(),
                      ...exercise.sets.asMap().entries.map((entry) {
                        final setIndex = entry.key + 1;
                        final set = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                              'Série $setIndex: ${set.weight} kg x ${set.repetitions} reps'),
                        );
                      })
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// O restante do arquivo (CalendarHeatmap, etc) permanece o mesmo
class _CalendarHeatmap extends StatefulWidget {
  final List<WorkoutLog> logs;
  const _CalendarHeatmap({required this.logs});

  @override
  State<_CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<_CalendarHeatmap> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final workoutEvents = {
      for (var log in widget.logs)
        DateTime.utc(log.date.year, log.date.month, log.date.day)
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          locale: 'pt_BR',
          focusedDay: _focusedDay,
          firstDay: DateTime.utc(2020),
          lastDay: DateTime.utc(2099),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              border: Border.all(color: primaryAccent, width: 2),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: primaryAccent,
              shape: BoxShape.circle,
            ),
          ),
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (workoutEvents
                  .contains(DateTime.utc(date.year, date.month, date.day))) {
                return Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: successColor,
                    ),
                  ),
                );
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
