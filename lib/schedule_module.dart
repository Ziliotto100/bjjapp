// lib/schedule_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

// --- MODELOS DE DADOS (UNIFICADOS NESTE ARQUIVO) ---

// Enum para a modalidade do treino
enum TrainingModality {
  gi, // Com Kimono
  nogi, // Sem Kimono
}

// Helper para converter String para Enum e vice-versa
String modalityToString(TrainingModality modality) {
  return modality == TrainingModality.gi ? 'Gi' : 'No-Gi';
}

TrainingModality modalityFromString(String? modalityString) {
  if (modalityString == 'No-Gi') {
    return TrainingModality.nogi;
  }
  return TrainingModality.gi; // Padrão
}

/// Representa uma única aula na grade de horários.
class TrainingClass {
  final String id;
  final String dayOfWeek; // Ex: "Segunda-feira"
  final String startTime; // Formato "HH:mm"
  final String endTime; // Formato "HH:mm"
  final String teacherId;
  final String teacherName;
  final TrainingModality modality;

  TrainingClass({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.teacherId,
    required this.teacherName,
    required this.modality,
  });

  // Cria um objeto TrainingClass a partir de um DocumentSnapshot do Firestore
  factory TrainingClass.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingClass(
      id: doc.id,
      dayOfWeek: data['dayOfWeek'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      modality: modalityFromString(data['modality']),
    );
  }
}

// --- TELA PRINCIPAL DA GRADE (VISUALIZAÇÃO) ---
class SchedulePage extends StatelessWidget {
  final UserModel user;
  final List<UserModel> teachers;

  const SchedulePage({
    super.key,
    required this.user,
    required this.teachers,
  });

  @override
  Widget build(BuildContext context) {
    final bool isManager = user.role == UserRole.manager;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(user.academyId)
                .collection('schedule')
                .orderBy('startTime')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Erro: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.event_note_rounded,
                  title: 'Grade de Horários Vazia',
                  message:
                      'O gerente ainda não configurou os horários de treino.',
                );
              }

              final allClasses = snapshot.data!.docs
                  .map((doc) => TrainingClass.fromFirestore(doc))
                  .toList();

              return _ScheduleView(
                classes: allClasses,
                user: user,
              );
            },
          ),
        ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EditSchedulePage(
                    academyId: user.academyId,
                    teachers: teachers,
                  ),
                ));
              },
              tooltip: 'Editar Grade',
              child: const Icon(Icons.edit_calendar_rounded),
            )
          : null,
    );
  }
}

// --- WIDGET DE VISUALIZAÇÃO DA GRADE (LAYOUT CORRIGIDO) ---
class _ScheduleView extends StatelessWidget {
  final List<TrainingClass> classes;
  final UserModel user;

  const _ScheduleView({required this.classes, required this.user});

  void _showCheckinDialog(BuildContext context, TrainingClass trainingClass) {
    final now = TimeOfDay.now();
    final startTime = TimeOfDay(
      hour: int.parse(trainingClass.startTime.split(':')[0]),
      minute: int.parse(trainingClass.startTime.split(':')[1]),
    );

    // Permite check-in 15 minutos antes do início da aula
    final checkinWindowStart = startTime.hour * 60 + startTime.minute - 15;
    final nowInMinutes = now.hour * 60 + now.minute;

    if (nowInMinutes < checkinWindowStart) {
      showBjjSnackBar(
        context,
        'Check-in disponível 15 minutos antes do início da aula.',
        type: 'info',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Check-in?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${trainingClass.dayOfWeek} - ${trainingClass.startTime}'),
            const SizedBox(height: 8),
            Text('Professor: ${trainingClass.teacherName}'),
            const SizedBox(height: 8),
            Chip(
              label: Text(modalityToString(trainingClass.modality)),
              backgroundColor: trainingClass.modality == TrainingModality.gi
                  ? primaryAccent
                  : infoColor,
              labelStyle: const TextStyle(color: primaryAccentForeground),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _performCheckin(context, trainingClass);
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performCheckin(
      BuildContext context, TrainingClass trainingClass) async {
    final studentId =
        user.role == UserRole.student ? user.studentRecordId : user.uid;
    if (studentId == null) {
      showBjjSnackBar(context, 'ID de aluno não encontrado.', type: 'error');
      return;
    }

    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);

    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(user.academyId)
        .collection('checkins');

    final existingCheckin = await checkinRef
        .where('studentId', isEqualTo: studentId)
        .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
        .limit(1)
        .get();

    if (existingCheckin.docs.isNotEmpty) {
      showBjjSnackBar(context, 'Você já fez check-in hoje!', type: 'warning');
      return;
    }

    await checkinRef.add({
      'studentId': studentId,
      'studentName': user.name,
      'date': Timestamp.fromDate(dateOnly),
      'classId': trainingClass.id,
      'className': '${trainingClass.dayOfWeek} ${trainingClass.startTime}',
      'creatorId': user.uid,
      'creatorName': user.name,
    });

    showBjjSnackBar(context, 'Check-in realizado com sucesso!',
        type: 'success');
  }

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];

    final groupedClasses = <String, List<TrainingClass>>{};
    for (var day in daysOfWeek) {
      final classesForDay = classes.where((c) => c.dayOfWeek == day).toList();
      if (classesForDay.isNotEmpty) {
        groupedClasses[day] = classesForDay;
      }
    }
    final today = DateFormat('EEEE', 'pt_BR').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: groupedClasses.keys.map((day) {
        final classesForDay = groupedClasses[day]!;
        final isToday = day.toLowerCase() == today.toLowerCase();
        return Card(
          elevation: isToday ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday
                ? const BorderSide(color: primaryAccent, width: 2)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: isToday ? primaryAccent : textPrimary),
                ),
                const Divider(height: 20),
                ...classesForDay.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Horário
                            Column(
                              children: [
                                Text(
                                  item.startTime,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  item.endTime,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: textHint),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Chips
                            Wrap(
                              spacing: 8.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  label: Text(modalityToString(item.modality)),
                                  backgroundColor:
                                      item.modality == TrainingModality.gi
                                          ? primaryAccent.withOpacity(0.8)
                                          : infoColor.withOpacity(0.8),
                                  labelStyle: const TextStyle(
                                      color: primaryAccentForeground,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (isToday && user.role == UserRole.student)
                                  ActionChip(
                                    avatar: const Icon(Icons.check,
                                        size: 16, color: Colors.white),
                                    label: const Text('Check-in'),
                                    onPressed: () =>
                                        _showCheckinDialog(context, item),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    backgroundColor:
                                        successColor.withOpacity(0.9),
                                    labelStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 16, color: textHint),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text("Professor: ${item.teacherName}",
                                    style: TextStyle(color: textSecondary))),
                          ],
                        )
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --- TELA DE EDIÇÃO DA GRADE (GERENTE - COM VALIDAÇÃO) ---
class EditSchedulePage extends StatefulWidget {
  final String academyId;
  final List<UserModel> teachers;

  const EditSchedulePage(
      {super.key, required this.academyId, required this.teachers});

  @override
  State<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends State<EditSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedTeacherId;
  TrainingModality _modality = TrainingModality.gi;

  final List<String> _daysOfWeek = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo'
  ];

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _addClass() async {
    // Adiciona validação para os horários antes de validar o form
    if (_startTime == null || _endTime == null) {
      showBjjSnackBar(context, 'Por favor, selecione horário de início e fim.',
          type: 'error');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final selectedTeacher =
        widget.teachers.firstWhere((t) => t.uid == _selectedTeacherId);

    final newClass = {
      'dayOfWeek': _selectedDay,
      'startTime':
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
      'endTime':
          '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      'teacherId': _selectedTeacherId,
      'teacherName': selectedTeacher.name,
      'modality': modalityToString(_modality),
    };

    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('schedule')
        .add(newClass);

    showBjjSnackBar(context, 'Aula adicionada com sucesso!', type: 'success');
    _formKey.currentState?.reset();
    setState(() {
      _selectedDay = null;
      _startTime = null;
      _endTime = null;
      _selectedTeacherId = null;
    });
  }

  Future<void> _deleteClass(String classId) async {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('schedule')
        .doc(classId)
        .delete();
    showBjjSnackBar(context, 'Aula removida com sucesso!', type: 'success');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Editar Grade de Horários')),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Formulário para adicionar nova aula
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Adicionar Nova Aula',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedDay,
                        decoration:
                            const InputDecoration(labelText: 'Dia da Semana'),
                        items: _daysOfWeek
                            .map((day) =>
                                DropdownMenuItem(value: day, child: Text(day)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedDay = value),
                        validator: (v) =>
                            v == null ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FormField<TimeOfDay>(
                              validator: (value) {
                                if (_startTime == null) return 'Obrigatório';
                                return null;
                              },
                              builder: (field) {
                                return InkWell(
                                  onTap: () => _selectTime(context, true),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Início',
                                      errorText: field.errorText,
                                    ),
                                    child: Text(_startTime?.format(context) ??
                                        'Selecionar'),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FormField<TimeOfDay>(
                              validator: (value) {
                                if (_endTime == null) return 'Obrigatório';
                                return null;
                              },
                              builder: (field) {
                                return InkWell(
                                  onTap: () => _selectTime(context, false),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Fim',
                                      errorText: field.errorText,
                                    ),
                                    child: Text(_endTime?.format(context) ??
                                        'Selecionar'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedTeacherId,
                        decoration:
                            const InputDecoration(labelText: 'Professor'),
                        items: widget.teachers
                            .map((teacher) => DropdownMenuItem(
                                value: teacher.uid, child: Text(teacher.name)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedTeacherId = value),
                        validator: (v) =>
                            v == null ? 'Campo obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<TrainingModality>(
                        segments: const [
                          ButtonSegment(
                              value: TrainingModality.gi, label: Text('Gi')),
                          ButtonSegment(
                              value: TrainingModality.nogi,
                              label: Text('No-Gi')),
                        ],
                        selected: {_modality},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _modality = newSelection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addClass,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Adicionar Aula'),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 20),
              // Lista de aulas existentes
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('academies')
                      .doc(widget.academyId)
                      .collection('schedule')
                      .orderBy('dayOfWeek')
                      .orderBy('startTime')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final classes = snapshot.data!.docs;
                    if (classes.isEmpty) {
                      return const Center(
                          child: Text('Nenhuma aula cadastrada.'));
                    }
                    return ListView.builder(
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final trainingClass =
                            TrainingClass.fromFirestore(classes[index]);
                        return ListTile(
                          title: Text(
                              '${trainingClass.dayOfWeek} - ${trainingClass.startTime}'),
                          subtitle: Text(
                              '${trainingClass.teacherName} (${modalityToString(trainingClass.modality)})'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: errorColor),
                            onPressed: () => _deleteClass(trainingClass.id),
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
    );
  }
}
