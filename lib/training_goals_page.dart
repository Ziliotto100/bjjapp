// lib/training_goals_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <<< CORREÇÃO APLICADA AQUI
import 'package:intl/intl.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

/// Tela para gerenciar as metas de treino do usuário.
class TrainingGoalsPage extends StatefulWidget {
  final String userId;
  const TrainingGoalsPage({super.key, required this.userId});

  @override
  State<TrainingGoalsPage> createState() => _TrainingGoalsPageState();
}

class _TrainingGoalsPageState extends State<TrainingGoalsPage> {
  late final CollectionReference _goalsCollection;

  @override
  void initState() {
    super.initState();
    _goalsCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('training_goals');
  }

  void _showGoalDialog({TrainingGoal? goalToEdit}) {
    showDialog(
      context: context,
      builder: (_) => _AddEditGoalDialog(
        goalsCollection: _goalsCollection,
        goalToEdit: goalToEdit,
      ),
    );
  }

  Future<void> _deleteGoal(String goalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Meta?'),
        content: const Text('Tem certeza que deseja excluir esta meta?'),
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
      await _goalsCollection.doc(goalId).delete();
    }
  }

  Future<void> _toggleGoalStatus(TrainingGoal goal) async {
    final newStatus = goal.status == GoalStatus.pending
        ? GoalStatus.completed
        : GoalStatus.pending;
    await _goalsCollection.doc(goal.id).update({
      'status': goalStatusToString(newStatus),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Minhas Metas'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _goalsCollection
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const EmptyStateWidget(
                    icon: Icons.error, title: 'Erro ao carregar metas');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.flag_outlined,
                  title: 'Nenhuma Meta Definida',
                  message:
                      'Clique no botão "+" para adicionar sua primeira meta e focar na sua evolução.',
                );
              }

              final goals = snapshot.data!.docs
                  .map((doc) => TrainingGoal.fromFirestore(doc))
                  .toList();

              final pendingGoals =
                  goals.where((g) => g.status == GoalStatus.pending).toList();
              final completedGoals =
                  goals.where((g) => g.status == GoalStatus.completed).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                children: [
                  if (pendingGoals.isNotEmpty) ...[
                    _buildSectionHeader('Metas Ativas'),
                    ...pendingGoals.map((goal) => _GoalCard(
                          goal: goal,
                          onToggleStatus: () => _toggleGoalStatus(goal),
                          onEdit: () => _showGoalDialog(goalToEdit: goal),
                          onDelete: () => _deleteGoal(goal.id),
                        )),
                  ],
                  if (completedGoals.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: _buildSectionHeader('Metas Concluídas'),
                    ),
                    ...completedGoals.map((goal) => _GoalCard(
                          goal: goal,
                          onToggleStatus: () => _toggleGoalStatus(goal),
                          onEdit: () => _showGoalDialog(goalToEdit: goal),
                          onDelete: () => _deleteGoal(goal.id),
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalDialog(),
        tooltip: 'Nova Meta',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Card que exibe uma meta.
class _GoalCard extends StatelessWidget {
  final TrainingGoal goal;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = goal.status == GoalStatus.pending;
    final bool isOverdue = goal.deadline != null &&
        goal.deadline!.isBefore(DateTime.now()) &&
        isPending;

    return Card(
      color: isPending ? darkSurface : darkSurface.withOpacity(0.5),
      child: ListTile(
        leading: IconButton(
          icon: Icon(
            isPending ? Icons.radio_button_unchecked : Icons.check_circle,
            color: isPending ? primaryAccent : successColor,
          ),
          onPressed: onToggleStatus,
        ),
        title: Text(
          goal.description,
          style: TextStyle(
            decoration:
                isPending ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
        subtitle: goal.deadline != null
            ? Text(
                'Prazo: ${DateFormat.yMd('pt_BR').format(goal.deadline!)}',
                style: TextStyle(color: isOverdue ? errorColor : textHint),
              )
            : null,
        trailing: PopupMenuButton<String>(
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
      ),
    );
  }
}

/// Diálogo para adicionar ou editar uma meta.
class _AddEditGoalDialog extends StatefulWidget {
  final CollectionReference goalsCollection;
  final TrainingGoal? goalToEdit;

  const _AddEditGoalDialog({required this.goalsCollection, this.goalToEdit});

  @override
  State<_AddEditGoalDialog> createState() => _AddEditGoalDialogState();
}

class _AddEditGoalDialogState extends State<_AddEditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDeadline;
  bool _isLoading = false;

  bool get _isEditing => widget.goalToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _descriptionController.text = widget.goalToEdit!.description;
      _selectedDeadline = widget.goalToEdit!.deadline;
    }
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'description': _descriptionController.text.trim(),
      'deadline': _selectedDeadline != null
          ? Timestamp.fromDate(_selectedDeadline!)
          : null,
      'status': _isEditing
          ? goalStatusToString(widget.goalToEdit!.status)
          : 'pending',
      'createdAt': _isEditing
          ? widget.goalToEdit!.createdAt
          : FieldValue.serverTimestamp(),
    };

    try {
      if (_isEditing) {
        await widget.goalsCollection.doc(widget.goalToEdit!.id).update(data);
      } else {
        await widget.goalsCollection.add(data);
      }
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar a meta.', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Meta' : 'Nova Meta'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descriptionController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Descrição da Meta',
                  hintText: 'Ex: Treinar 3x por semana',
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? 'A descrição é obrigatória' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDeadline,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Prazo (Opcional)',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDeadline != null
                        ? DateFormat.yMd('pt_BR').format(_selectedDeadline!)
                        : 'Sem prazo definido',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
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
          onPressed: _isLoading ? null : _saveGoal,
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator())
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
