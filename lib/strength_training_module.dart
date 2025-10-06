// lib/strength_training_module.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

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
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );

    if (selectedDate != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WorkoutSessionPage(
          user: widget.user,
          routine: routine,
          workoutDate: selectedDate,
        ),
      ));
    }
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
      // Atualiza a tela após voltar da edição/criação
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
      builder: (_) => StrengthStatsPage(user: widget.user),
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
                    IconButton(
                      icon: const Icon(Icons.bar_chart_rounded,
                          color: primaryAccent),
                      onPressed: _navigateToStats,
                      tooltip: 'Ver Meu Progresso',
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
                            'Clique em "Nova Ficha" para criar sua primeira rotina de musculação.',
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _navigateToWorkoutSession(null),
            label: const Text('Treino Livre'),
            icon: const Icon(Icons.directions_run),
            heroTag: 'fab_free_workout',
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () => _navigateToEditRoutine(),
            label: const Text('Nova Ficha'),
            icon: const Icon(Icons.add),
            heroTag: 'fab_new_routine',
          ),
        ],
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
    // Ordena os dias da semana para exibição consistente
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Ficha' : 'Nova Ficha de Treino'),
        actions: [
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
                Expanded(
                  child: _items.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.list_alt_rounded,
                          title: 'Nenhum Exercício',
                          message: 'Clique em "Adicionar Exercício" abaixo.',
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final subtitle =
                                '${item.series}x ${item.repetitions} reps - ${item.restTimeInSeconds}s rest';

                            return Card(
                              key: ValueKey(item.exerciseId + index.toString()),
                              child: ListTile(
                                leading: const Icon(Icons.fitness_center),
                                title: Text(item.exerciseName),
                                subtitle: Text(subtitle),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: errorColor),
                                  onPressed: () =>
                                      setState(() => _items.removeAt(index)),
                                ),
                              ),
                            );
                          },
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) newIndex -= 1;
                              final item = _items.removeAt(oldIndex);
                              _items.insert(newIndex, item);
                            });
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        label: const Text('Adicionar Exercício'),
        icon: const Icon(Icons.add),
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
  final DateTime workoutDate;

  const WorkoutSessionPage(
      {super.key,
      required this.user,
      required this.routine,
      required this.workoutDate});

  @override
  State<WorkoutSessionPage> createState() => _WorkoutSessionPageState();
}

class _WorkoutSessionPageState extends State<WorkoutSessionPage> {
  late List<LoggedExercise> _loggedExercises;
  bool _isLoading = false;

  bool get isFreeWorkout => widget.routine == null;

  @override
  void initState() {
    super.initState();
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
          sets: [], // Começa sem séries definidas
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
    setState(() => _isLoading = true);

    final log = WorkoutLog(
      id: '',
      routineName: isFreeWorkout ? 'Treino Livre' : widget.routine!.name,
      date: widget.workoutDate,
      exercises: _loggedExercises,
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('workout_logs')
          .add(log.toMap());

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
            onPressed: _isLoading ? null : _finishWorkout,
            child: const Text('Finalizar'),
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ),
      floatingActionButton: isFreeWorkout
          ? FloatingActionButton.extended(
              onPressed: _addExerciseToSession,
              label: const Text('Exercício'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final List<dynamic> items =
        isFreeWorkout ? _loggedExercises : widget.routine!.items;

    if (items.isEmpty) {
      return const EmptyStateWidget(
          icon: Icons.add,
          title: 'Inicie seu Treino',
          message: 'Clique em "+ Exercício" para adicionar o primeiro.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        if (isFreeWorkout) {
          return _ExerciseExecutionCard(
            key:
                ValueKey(_loggedExercises[index].exerciseId + index.toString()),
            loggedExercise: _loggedExercises[index],
            isFreeWorkout: true,
          );
        } else {
          final routineItem = items[index] as RoutineItem;
          return _ExerciseExecutionCard(
            key: ValueKey(routineItem.exerciseId + index.toString()),
            routineItem: routineItem,
            loggedExercise: _loggedExercises[index],
            isFreeWorkout: false,
          );
        }
      },
    );
  }
}

class _ExerciseExecutionCard extends StatefulWidget {
  final RoutineItem? routineItem;
  final LoggedExercise loggedExercise;
  final bool isFreeWorkout;

  const _ExerciseExecutionCard({
    super.key,
    this.routineItem,
    required this.loggedExercise,
    this.isFreeWorkout = false,
  });

  @override
  __ExerciseExecutionCardState createState() => __ExerciseExecutionCardState();
}

class __ExerciseExecutionCardState extends State<_ExerciseExecutionCard> {
  void _addSet() {
    setState(() {
      widget.loggedExercise.sets.add(LoggedSet(weight: 0, repetitions: 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Importante para o ListView
          children: [
            Text(widget.loggedExercise.exerciseName,
                style: Theme.of(context).textTheme.headlineSmall),
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
      ),
    );
  }
}

class _SetInputRow extends StatefulWidget {
  final int setNumber;
  final LoggedSet loggedSet;
  final Function(double weight, int reps) onSetCompleted;
  final VoidCallback? onRemove;

  const _SetInputRow({
    required this.setNumber,
    required this.loggedSet,
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
          const SizedBox(width: 16),
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
              final weight = double.tryParse(_weightController.text) ?? 0;
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
// TELA DE ESTATÍSTICAS DE FORÇA
// -----------------------------------------------------------------------------
class StrengthStatsPage extends StatefulWidget {
  final UserModel user;
  const StrengthStatsPage({super.key, required this.user});

  @override
  State<StrengthStatsPage> createState() => _StrengthStatsPageState();
}

class _StrengthStatsPageState extends State<StrengthStatsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Meu Progresso')),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.user.uid)
                  .collection('workout_logs')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                      icon: Icons.bar_chart_rounded,
                      title: 'Sem Dados',
                      message:
                          'Complete alguns treinos para ver suas estatísticas.');
                }

                final logs = snapshot.data!.docs
                    .map((doc) => WorkoutLog.fromFirestore(doc))
                    .toList();

                // Processamento de dados para os cards
                double totalVolume = 0;
                for (var log in logs) {
                  for (var exercise in log.exercises) {
                    for (var set in exercise.sets) {
                      totalVolume += set.weight * set.repetitions;
                    }
                  }
                }
                final totalWorkouts = logs.length;
                final formatter = NumberFormat.compact(locale: 'pt_BR');

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Visão Geral',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: _buildMetricCard(
                                'Volume Total (kg)',
                                formatter.format(totalVolume),
                                Icons.line_weight,
                                primaryAccent)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildMetricCard(
                                'Treinos Feitos',
                                totalWorkouts.toString(),
                                Icons.calendar_today,
                                infoColor)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _CalendarHeatmap(logs: logs),
                  ],
                );
              }),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.bodyLarge)),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

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
