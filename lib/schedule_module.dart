// lib/schedule_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, prefer_const_constructors, depend_on_referenced_packages, curly_braces_in_flow_control_structures

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';
import 'lesson_planner_module.dart';

// --- TELA PRINCIPAL DA GRADE (VISUALIZAÇÃO COM ABAS) ---
class SchedulePage extends StatefulWidget {
  final UserModel user;
  final List<UserModel> teachers;

  const SchedulePage({
    super.key,
    required this.user,
    required this.teachers,
  });

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Aluno>> _allStudentsFuture;
  List<DocumentSnapshot> _units = [];
  String? _selectedUnitId;
  DateTime _selectedDate = DateTime.now();

  final List<String> _daysOfWeek = [
    'Seg',
    'Ter',
    'Qua',
    'Qui',
    'Sex',
    'Sáb',
    'Dom'
  ];
  final List<String> _daysOfWeekFull = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _allStudentsFuture = _fetchAllStudents();
    _fetchUnits().then((_) {
      final lastUnitId = widget.user.lastSelectedUnitId;
      if (lastUnitId != null && _units.any((u) => u.id == lastUnitId)) {
        _selectedUnitId = lastUnitId;
      } else {
        _selectedUnitId = widget.user.unitId ?? 'all';
      }
      setState(() {});
    });

    _tabController = TabController(length: _daysOfWeek.length, vsync: this);
    _updateTabToSelectedDate();

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      final todayWeekday = _selectedDate.weekday;
      final difference = _tabController.index - (todayWeekday - 1);

      setState(() {
        _selectedDate = _selectedDate.add(Duration(days: difference));
      });
    });
  }

  void _updateTabToSelectedDate() {
    final weekdayIndex = _selectedDate.weekday - 1;
    if (weekdayIndex >= 0 && weekdayIndex < _daysOfWeek.length) {
      _tabController.animateTo(weekdayIndex);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateTabToSelectedDate();
      });
    }
  }

  Future<void> _fetchUnits() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('units')
        .orderBy('name')
        .get();
    if (mounted) {
      setState(() {
        _units = snapshot.docs;
      });
    }
  }

  Future<void> _saveLastSelectedUnit(String? unitId) async {
    if (unitId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'lastSelectedUnitId': unitId});
    } catch (e) {
      debugPrint("Erro ao salvar a preferência de unidade: $e");
    }
  }

  Future<List<Aluno>> _fetchAllStudents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('students')
        .get();
    return snapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildUnitFilter() {
    if (_units.isEmpty || _selectedUnitId == null) {
      return const SizedBox.shrink();
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedUnitId,
        isExpanded: true,
        items: [
          const DropdownMenuItem(
            value: 'all',
            child: Text("Todas as Unidades"),
          ),
          ..._units.map((unit) {
            return DropdownMenuItem(
              value: unit.id,
              child: Text(unit['name']),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _selectedUnitId = value;
          });
          _saveLastSelectedUnit(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isManager = widget.user.role == UserRole.manager;
    final bool isTeacher = widget.user.role == UserRole.teacher;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: _daysOfWeek.map((day) => Tab(text: day)).toList(),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: darkSurface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildUnitFilter(),
                    ),
                    const SizedBox(width: 16),
                    // --- INÍCIO DA ALTERAÇÃO ---
                    // Layout simplificado para mostrar apenas data numérica e ícone
                    InkWell(
                      onTap: _pickDate,
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: textHint, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                            style: const TextStyle(
                                color: textPrimary, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    // --- FIM DA ALTERAÇÃO ---
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('academies')
                      .doc(widget.user.academyId)
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

                    final studentRecordId =
                        widget.user.studentRecordId ?? widget.user.uid;

                    final visibleClasses = allClasses.where((c) {
                      if (_selectedUnitId != 'all' &&
                          c.unitId != _selectedUnitId) {
                        return false;
                      }
                      if (!c.isPrivate) return true;
                      return isManager ||
                          isTeacher ||
                          c.allowedStudentIds.contains(studentRecordId);
                    }).toList();

                    return TabBarView(
                      controller: _tabController,
                      children: _daysOfWeekFull.map((day) {
                        final classesForDay = visibleClasses
                            .where((c) => c.dayOfWeek == day)
                            .toList();
                        if (classesForDay.isEmpty) {
                          return const EmptyStateWidget(
                              icon: Icons.calendar_today_rounded,
                              title: 'Nenhuma aula neste dia');
                        }
                        return FutureBuilder<List<Aluno>>(
                          future: _allStudentsFuture,
                          builder: (context, studentSnapshot) {
                            if (!studentSnapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return _ScheduleDayView(
                              classes: classesForDay,
                              user: widget.user,
                              teachers: widget.teachers,
                              allStudents: studentSnapshot.data ?? [],
                              selectedUnitId: _selectedUnitId,
                              classDate: _selectedDate,
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              heroTag: 'schedule_fab',
              onPressed: () async {
                final students = await _allStudentsFuture;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EditSchedulePage(
                    academyId: widget.user.academyId,
                    teachers: widget.teachers,
                    allStudents: students,
                  ),
                ));
              },
              tooltip: 'Gerenciar Aulas',
              child: const Icon(Icons.edit_calendar),
            )
          : null,
    );
  }
}

// ... O restante do arquivo (diálogos, cards, etc.) permanece exatamente o mesmo ...
class _ScheduleDayView extends StatefulWidget {
  final List<TrainingClass> classes;
  final UserModel user;
  final List<UserModel> teachers;
  final List<Aluno> allStudents;
  final String? selectedUnitId;
  final DateTime classDate;

  const _ScheduleDayView({
    required this.classes,
    required this.user,
    required this.teachers,
    required this.allStudents,
    required this.selectedUnitId,
    required this.classDate,
  });

  @override
  State<_ScheduleDayView> createState() => _ScheduleDayViewState();
}

class _ScheduleDayViewState extends State<_ScheduleDayView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: widget.classes.length,
      itemBuilder: (context, index) {
        final trainingClass = widget.classes[index];
        return _ClassCard(
          trainingClass: trainingClass,
          user: widget.user,
          teachers: widget.teachers,
          allStudents: widget.allStudents,
          selectedUnitId: widget.selectedUnitId,
          classDate: widget.classDate,
        );
      },
    );
  }
}

class _ClassCard extends StatefulWidget {
  final TrainingClass trainingClass;
  final UserModel user;
  final List<UserModel> teachers;
  final List<Aluno> allStudents;
  final String? selectedUnitId;
  final DateTime classDate;

  const _ClassCard({
    required this.trainingClass,
    required this.user,
    required this.teachers,
    required this.allStudents,
    required this.selectedUnitId,
    required this.classDate,
  });

  @override
  State<_ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<_ClassCard> {
  Stream<DocumentSnapshot?>? _checkinStatusStream;
  Stream<DocumentSnapshot?>? _lessonPlanStream;

  @override
  void initState() {
    super.initState();
    if (widget.user.role == UserRole.student &&
        widget.user.studentRecordId != null) {
      _listenToCheckinStatus();
    }
    _listenToLessonPlan();
  }

  @override
  void didUpdateWidget(covariant _ClassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classDate != widget.classDate) {
      if (widget.user.role == UserRole.student &&
          widget.user.studentRecordId != null) {
        _listenToCheckinStatus();
      }
      _listenToLessonPlan();
    }
  }

  void _listenToCheckinStatus() {
    final dateOnly = DateTime(
        widget.classDate.year, widget.classDate.month, widget.classDate.day);
    final studentId = widget.user.studentRecordId;

    setState(() {
      _checkinStatusStream = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('checkins')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .where('classId', isEqualTo: widget.trainingClass.id)
          .limit(1)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
    });
  }

  void _listenToLessonPlan() {
    final dateOnly = DateTime(
        widget.classDate.year, widget.classDate.month, widget.classDate.day);

    setState(() {
      _lessonPlanStream = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('lesson_plans')
          .where('classId', isEqualTo: widget.trainingClass.id)
          .where('classDate', isEqualTo: Timestamp.fromDate(dateOnly))
          .limit(1)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.isNotEmpty ? snapshot.docs.first : null);
    });
  }

  void _showCheckinDialog(BuildContext context) {
    final now = DateTime.now();
    final isToday = widget.classDate.year == now.year &&
        widget.classDate.month == now.month &&
        widget.classDate.day == now.day;

    if (!isToday) {
      showBjjSnackBar(
        context,
        'O check-in só pode ser feito para aulas do dia de hoje.',
        type: 'info',
      );
      return;
    }

    final timeNow = TimeOfDay.now();
    final startTime = TimeOfDay(
      hour: int.parse(widget.trainingClass.startTime.split(':')[0]),
      minute: int.parse(widget.trainingClass.startTime.split(':')[1]),
    );
    final checkinWindowStart = startTime.hour * 60 + startTime.minute - 15;
    final nowInMinutes = timeNow.hour * 60 + timeNow.minute;

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
            Text(
                'Aula: ${widget.trainingClass.level} (${widget.trainingClass.startTime})'),
            const SizedBox(height: 8),
            Text('Professor: ${widget.trainingClass.teacherName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _performCheckin(context);
              Navigator.of(ctx).pop();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _performCheckin(BuildContext context) async {
    final studentId = widget.user.role == UserRole.student
        ? widget.user.studentRecordId
        : widget.user.uid;
    if (studentId == null) {
      showBjjSnackBar(context, 'ID de aluno não encontrado.', type: 'error');
      return;
    }

    final dateOnly = DateTime(
        widget.classDate.year, widget.classDate.month, widget.classDate.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('checkins');

    try {
      final todayTimestamp = Timestamp.fromDate(dateOnly);
      final querySnapshot = await checkinRef
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: todayTimestamp)
          .where('classId', isEqualTo: widget.trainingClass.id)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        showBjjSnackBar(context, 'Você já fez check-in para esta aula!',
            type: 'info');
        return;
      }
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao verificar check-in: $e', type: 'error');
      return;
    }

    await checkinRef.add({
      'studentId': studentId,
      'studentName': widget.user.name,
      'date': Timestamp.fromDate(dateOnly),
      'classId': widget.trainingClass.id,
      'className':
          '${widget.trainingClass.level} (${widget.trainingClass.startTime})',
      'creatorId': widget.user.uid,
      'creatorName': widget.user.name,
      'status': checkinStatusToString(CheckinStatus.pending),
      'createdAt': FieldValue.serverTimestamp(),
    });

    showBjjSnackBar(context, 'Solicitação de check-in enviada!',
        type: 'success');
  }

  Widget _buildCheckinWidget() {
    final now = DateTime.now();
    final isToday = widget.classDate.year == now.year &&
        widget.classDate.month == now.month &&
        widget.classDate.day == now.day;

    if (!isToday || widget.user.role != UserRole.student) {
      return const SizedBox.shrink();
    }

    if (widget.user.studentRecordId == null) {
      return InkWell(
        onTap: () => showBjjSnackBar(
          context,
          'Complete seu perfil na aba "Meu Perfil" para poder fazer check-in.',
          type: 'warning',
        ),
        child: _InfoChip(
            label: 'Fazer Check-in', color: infoColor, icon: Icons.check),
      );
    }

    return StreamBuilder<DocumentSnapshot?>(
      stream: _checkinStatusStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(height: 28);
        }

        if (snapshot.hasData && snapshot.data != null) {
          final checkin = CheckinEntry.fromJson(
              snapshot.data!.id, snapshot.data!.data() as Map<String, dynamic>);

          if (checkin.status == CheckinStatus.approved) {
            return _InfoChip(
                label: 'Check-in Confirmado',
                color: successColor,
                icon: Icons.check_circle_outline,
                textColor: Colors.white);
          } else {
            return _InfoChip(
                label: 'Aguardando Aprovação',
                color: warningColor,
                icon: Icons.hourglass_top_rounded,
                textColor: Colors.black);
          }
        }

        return InkWell(
          onTap: () => _showCheckinDialog(context),
          borderRadius: BorderRadius.circular(20),
          child: _InfoChip(
            label: 'Fazer Check-in',
            color: infoColor,
            icon: Icons.check,
            textColor: Colors.white,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.user.role == UserRole.manager ||
        widget.user.role == UserRole.teacher;
    final isGiClass = widget.trainingClass.modality == TrainingModality.gi;
    final isPrivate = widget.trainingClass.isPrivate;

    final Color borderColor = isPrivate
        ? errorColor
        : (isGiClass ? Colors.blue.shade300 : primaryAccent);
    final String modalityLabel =
        modalityToString(widget.trainingClass.modality).replaceAll('-', ' ');

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (_) =>
              _ClassDetailDialog(trainingClass: widget.trainingClass),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${widget.trainingClass.startTime} - ${widget.trainingClass.endTime}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (canManage)
                    StreamBuilder<DocumentSnapshot?>(
                      stream: _lessonPlanStream,
                      builder: (context, snapshot) {
                        final bool hasPlan =
                            snapshot.hasData && snapshot.data != null;
                        final existingPlan = hasPlan
                            ? LessonPlan.fromFirestore(snapshot.data!)
                            : null;

                        return IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            hasPlan
                                ? Icons.assignment_turned_in_rounded
                                : Icons.assignment_late_outlined,
                            color: hasPlan ? successColor : textHint,
                          ),
                          tooltip: hasPlan
                              ? 'Ver/Editar Plano de Aula'
                              : 'Adicionar Plano de Aula',
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => EditLessonPlanPage(
                                currentUser: widget.user,
                                trainingClass: widget.trainingClass,
                                classDate: widget.classDate,
                                existingPlan: existingPlan,
                              ),
                            ));
                          },
                        );
                      },
                    ),
                  if (canManage)
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.edit_note_rounded, color: textHint),
                        tooltip: 'Editar Horário',
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EditSchedulePage(
                              academyId: widget.user.academyId,
                              teachers: widget.teachers,
                              classToEdit: widget.trainingClass,
                              allStudents: widget.allStudents,
                            ),
                          ));
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _InfoChip(
                      label: modalityLabel,
                      color: isGiClass ? Colors.blue.shade300 : primaryAccent,
                      textColor: Colors.black,
                    ),
                    _InfoChip(
                      label: widget.trainingClass.level,
                    ),
                    if (widget.trainingClass.audience != null)
                      _InfoChip(
                        label: widget.trainingClass.audience!,
                        icon: widget.trainingClass.audience?.toLowerCase() ==
                                'kids'
                            ? Icons.child_care
                            : null,
                      ),
                    if (widget.trainingClass.location != null &&
                        widget.trainingClass.location!.isNotEmpty)
                      _InfoChip(
                        label: widget.trainingClass.location!,
                        icon: Icons.location_on_outlined,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _InfoRow(
                      icon: Icons.person_outline_rounded,
                      text: "Prof. ${widget.trainingClass.teacherName}",
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.selectedUnitId == 'all' &&
                      widget.trainingClass.unitName != null &&
                      widget.trainingClass.unitName!.isNotEmpty)
                    Flexible(
                      child: _InfoChip(
                        label: widget.trainingClass.unitName!,
                        icon: Icons.store_mall_directory_outlined,
                      ),
                    ),
                  if (isPrivate && widget.user.role != UserRole.student)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child:
                          Icon(Icons.lock_person, color: errorColor, size: 24),
                    ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _buildCheckinWidget(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  const _InfoChip({
    required this.label,
    this.icon,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? darkSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 14,
              color: textColor ?? Colors.white,
            ),
          if (icon != null) const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: textSecondary, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassDetailDialog extends StatelessWidget {
  final TrainingClass trainingClass;
  const _ClassDetailDialog({required this.trainingClass});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${trainingClass.startTime} - ${trainingClass.endTime}'),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            if (trainingClass.unitName != null &&
                trainingClass.unitName!.isNotEmpty)
              _buildInfoRow(context, Icons.store_mall_directory_outlined,
                  "Unidade", trainingClass.unitName!),
            _buildInfoRow(context, Icons.shield_outlined, "Categoria",
                trainingClass.level),
            if (trainingClass.audience != null)
              _buildInfoRow(context, Icons.family_restroom_rounded, "Público",
                  trainingClass.audience!),
            if (trainingClass.location != null &&
                trainingClass.location!.isNotEmpty)
              _buildInfoRow(context, Icons.location_on_outlined, "Local",
                  trainingClass.location!),
            _buildInfoRow(context, Icons.person_outline, "Professor",
                trainingClass.teacherName),
            _buildInfoRow(context, Icons.sports_mma_outlined, "Modalidade",
                modalityToString(trainingClass.modality).replaceAll('-', ' ')),
            if (trainingClass.isPrivate)
              _buildInfoRow(
                  context, Icons.lock_person, "Tipo", "Aula Particular"),
            if (trainingClass.description.isNotEmpty) ...[
              const Divider(height: 24),
              Text('Descrição', style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: 8),
              Text(trainingClass.description,
                  style: TextStyle(color: textSecondary)),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Fechar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textHint, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: textHint, fontSize: 13)),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditSchedulePage extends StatefulWidget {
  final String academyId;
  final List<UserModel> teachers;
  final List<Aluno> allStudents;
  final TrainingClass? classToEdit;

  const EditSchedulePage({
    super.key,
    required this.academyId,
    required this.teachers,
    required this.allStudents,
    this.classToEdit,
  });

  @override
  State<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends State<EditSchedulePage> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _selectedDays = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedTeacherId;
  TrainingModality _modality = TrainingModality.gi;
  final _descriptionController = TextEditingController();
  String? _selectedLevel;
  String? _selectedLocation;
  String? _selectedAudience;

  List<String> _classLevels = [];
  bool _isLoadingLevels = true;
  List<String> _classLocations = [];
  bool _isLoadingLocations = true;
  List<String> _classAudiences = [];
  bool _isLoadingAudiences = true;

  bool _isPrivate = false;
  List<String> _selectedStudentIds = [];

  List<DocumentSnapshot> _units = [];
  bool _isLoadingUnits = true;
  String? _selectedUnitId;
  String? _selectedUnitName;

  bool get _isEditing => widget.classToEdit != null;

  final List<String> _daysOfWeek = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.classToEdit!;
      _selectedDays.add(c.dayOfWeek);
      _startTime = TimeOfDay(
          hour: int.parse(c.startTime.split(':')[0]),
          minute: int.parse(c.startTime.split(':')[1]));
      _endTime = TimeOfDay(
          hour: int.parse(c.endTime.split(':')[0]),
          minute: int.parse(c.endTime.split(':')[1]));
      _selectedTeacherId = c.teacherId;
      _modality = c.modality;
      _descriptionController.text = c.description;
      _selectedLevel = c.level;
      _selectedLocation = c.location;
      _selectedAudience = c.audience;
      _isPrivate = c.isPrivate;
      _selectedStudentIds = List<String>.from(c.allowedStudentIds);
      _selectedUnitId = c.unitId;
      _selectedUnitName = c.unitName;
    }
    _fetchDropdownOptions();
  }

  Future<void> _fetchDropdownOptions() async {
    await Future.wait([
      _fetchClassLevels(),
      _fetchClassLocations(),
      _fetchClassAudiences(),
      _fetchUnits(),
    ]);
  }

  Future<void> _fetchUnits() async {
    setState(() => _isLoadingUnits = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('units')
          .orderBy('name')
          .get();
      final List<DocumentSnapshot> fetchedUnits = snapshot.docs;

      if (_isEditing &&
          _selectedUnitId != null &&
          !fetchedUnits.any((u) => u.id == _selectedUnitId)) {
        final missingUnitDoc = await FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.academyId)
            .collection('units')
            .doc(_selectedUnitId)
            .get();
        if (missingUnitDoc.exists) {
          fetchedUnits.insert(0, missingUnitDoc);
        }
      }

      if (mounted) {
        setState(() {
          _units = fetchedUnits;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar unidades.", type: 'error');
        setState(() => _isLoadingUnits = false);
      }
    }
  }

  Future<void> _fetchClassLevels() async {
    setState(() => _isLoadingLevels = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('class_levels')
          .orderBy('name')
          .get();
      final levels =
          snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      if (!mounted) return;
      if (_isEditing &&
          _selectedLevel != null &&
          !levels.contains(_selectedLevel)) {
        levels.add(_selectedLevel!);
      }

      setState(() {
        _classLevels = levels;
        _isLoadingLevels = false;
      });
    } catch (e) {
      if (!mounted) return;
      showBjjSnackBar(context, "Erro ao carregar categorias.", type: 'error');
      setState(() => _isLoadingLevels = false);
    }
  }

  Future<void> _fetchClassLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('class_locations')
          .orderBy('name')
          .get();
      final locations =
          snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      if (!mounted) return;
      if (_isEditing &&
          _selectedLocation != null &&
          !locations.contains(_selectedLocation)) {
        locations.add(_selectedLocation!);
      }

      setState(() {
        _classLocations = locations;
        _isLoadingLocations = false;
      });
    } catch (e) {
      if (!mounted) return;
      showBjjSnackBar(context, "Erro ao carregar locais.", type: 'error');
      setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _fetchClassAudiences() async {
    setState(() => _isLoadingAudiences = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('class_audiences')
          .orderBy('name')
          .get();
      final audiences =
          snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
      if (!mounted) return;
      if (!audiences.contains('Adulto')) audiences.insert(0, 'Adulto');
      if (!audiences.contains('Kids')) audiences.add('Kids');
      if (_isEditing &&
          _selectedAudience != null &&
          !audiences.contains(_selectedAudience)) {
        audiences.add(_selectedAudience!);
      }

      setState(() {
        _classAudiences = audiences;
        _isLoadingAudiences = false;
      });
    } catch (e) {
      if (!mounted) return;
      showBjjSnackBar(context, "Erro ao carregar público-alvo.", type: 'error');
      setState(() => _isLoadingAudiences = false);
    }
  }

  Future<void> _showAddOptionDialog(
      {required String title,
      required String hint,
      required String collection}) async {
    final controller = TextEditingController();
    final newOption = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Nova Opção para $title'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: hint),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar')),
                ElevatedButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(context, controller.text.trim());
                      }
                    },
                    child: Text('Adicionar')),
              ],
            ));
    if (newOption != null) {
      final existingOptions = collection == 'class_levels'
          ? _classLevels
          : (collection == 'class_locations'
              ? _classLocations
              : _classAudiences);
      if (existingOptions
          .any((opt) => opt.toLowerCase() == newOption.toLowerCase())) {
        showBjjSnackBar(context, 'Esta opção já existe.', type: 'info');
        return;
      }

      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection(collection)
          .add({'name': newOption});
      if (collection == 'class_levels') {
        await _fetchClassLevels();
        setState(() => _selectedLevel = newOption);
      } else if (collection == 'class_locations') {
        await _fetchClassLocations();
        setState(() => _selectedLocation = newOption);
      } else {
        await _fetchClassAudiences();
        setState(() => _selectedAudience = newOption);
      }
    }
  }

  Future<void> _showManageOptionsDialog(
      {required String title, required String collection}) async {
    await showDialog(
        context: context,
        builder: (_) => _ManageOptionsDialog(
              academyId: widget.academyId,
              collection: collection,
              title: title,
            )).then((_) {
      if (collection == 'class_levels') {
        _fetchClassLevels();
        setState(() => _selectedLevel = null);
      } else if (collection == 'class_locations') {
        _fetchClassLocations();
        setState(() => _selectedLocation = null);
      } else {
        _fetchClassAudiences();
        setState(() => _selectedAudience = null);
      }
    });
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
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

  Future<void> _showDaysSelectionDialog() async {
    await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Selecione os dias'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _daysOfWeek
                      .map((day) => CheckboxListTile(
                            title: Text(day),
                            value: _selectedDays.contains(day),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedDays.add(day);
                                } else {
                                  _selectedDays.remove(day);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {});
                  },
                ),
              ],
            );
          });
        });
  }

  Future<void> _showStudentSelectionDialog() async {
    final selectedIds = await showDialog<List<String>>(
      context: context,
      builder: (context) => _SelectStudentsDialog(
        allStudents: widget.allStudents,
        initiallySelectedIds: _selectedStudentIds,
      ),
    );
    if (selectedIds != null) {
      setState(() {
        _selectedStudentIds = selectedIds;
      });
    }
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isPrivate && _selectedStudentIds.isEmpty) {
      showBjjSnackBar(
          context, 'Selecione ao menos um aluno para a aula particular.',
          type: 'error');
      return;
    }

    final selectedTeacher =
        widget.teachers.firstWhere((t) => t.uid == _selectedTeacherId);

    final classData = {
      'startTime':
          '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
      'endTime':
          '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
      'teacherId': _selectedTeacherId,
      'teacherName': selectedTeacher.name,
      'modality': modalityToString(_modality),
      'description': _descriptionController.text.trim(),
      'level': _selectedLevel,
      'location': _selectedLocation,
      'audience': _selectedAudience,
      'isPrivate': _isPrivate,
      'allowedStudentIds': _isPrivate ? _selectedStudentIds : [],
      'unitId': _selectedUnitId,
      'unitName': _selectedUnitName,
    };

    final collectionRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('schedule');

    try {
      if (_isEditing) {
        await _handleUpdate(collectionRef, classData);
      } else {
        await _handleCreate(collectionRef, classData);
      }
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar: $e', type: 'error');
    }
  }

  Future<void> _handleCreate(
      CollectionReference ref, Map<String, dynamic> data) async {
    final recurringId = Uuid().v4();
    final batch = FirebaseFirestore.instance.batch();

    for (final day in _selectedDays) {
      final docRef = ref.doc();
      batch.set(docRef, {
        ...data,
        'dayOfWeek': day,
        'recurringId': _selectedDays.length > 1 ? recurringId : null,
      });
    }

    await batch.commit();
    showBjjSnackBar(context, 'Aula(s) adicionada(s) com sucesso!',
        type: 'success');
    Navigator.of(context).pop();
  }

  Future<void> _handleUpdate(
      CollectionReference ref, Map<String, dynamic> data) async {
    final originalClass = widget.classToEdit!;
    if (originalClass.recurringId != null) {
      final choice = await _showRecurringEditDialog();
      if (choice == null) return;

      final batch = FirebaseFirestore.instance.batch();
      if (choice == 'all') {
        final snapshot = await ref
            .where('recurringId', isEqualTo: originalClass.recurringId)
            .get();
        for (final doc in snapshot.docs) {
          batch.update(doc.reference, data);
        }
      } else {
        batch.update(ref.doc(originalClass.id), data);
      }
      await batch.commit();
    } else {
      await ref.doc(originalClass.id).update(data);
    }
    showBjjSnackBar(context, 'Aula atualizada com sucesso!', type: 'success');
    Navigator.of(context).pop();
  }

  Future<String?> _showRecurringEditDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Aula Recorrente'),
        content: const Text(
            'Esta aula se repete em outros dias. Deseja atualizar todas as ocorrências ou apenas esta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop('single'),
              child: const Text('Apenas esta')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop('all'),
              child: const Text('Todas')),
        ],
      ),
    );
  }

  Future<void> _deleteClass() async {
    final originalClass = widget.classToEdit!;
    final collectionRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('schedule');
    String? choice = 'single';
    if (originalClass.recurringId != null) {
      choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir Aula Recorrente'),
          content: const Text(
              'Esta aula se repete em outros dias. Deseja excluir todas as ocorrências ou apenas esta?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop('single'),
                child: const Text('Apenas esta')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop('all'),
                style: ElevatedButton.styleFrom(backgroundColor: errorColor),
                child: const Text('Excluir Todas')),
          ],
        ),
      );
    }

    if (choice == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      if (choice == 'all' && originalClass.recurringId != null) {
        final snapshot = await collectionRef
            .where('recurringId', isEqualTo: originalClass.recurringId)
            .get();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      } else {
        batch.delete(collectionRef.doc(originalClass.id));
      }
      await batch.commit();

      showBjjSnackBar(context, 'Aula(s) removida(s) com sucesso!',
          type: 'success');
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao remover aula.', type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<UserModel> teacherDropdownItems = List.from(widget.teachers);
    if (_isEditing &&
        _selectedTeacherId != null &&
        !teacherDropdownItems.any((t) => t.uid == _selectedTeacherId)) {
      final ghostTeacher = UserModel(
        uid: widget.classToEdit!.teacherId,
        name: '${widget.classToEdit!.teacherName} (Excluído)',
        email: '',
        academyId: '',
        role: UserRole.unknown,
        mustChangePassword: false,
        isActive: false,
      );
      teacherDropdownItems.insert(0, ghostTeacher);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Aula' : 'Adicionar Nova Aula'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: errorColor),
              onPressed: _deleteClass,
              tooltip: 'Excluir Aula',
            )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                if (_isLoadingUnits)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedUnitId,
                    decoration: const InputDecoration(
                      labelText: 'Unidade da Aula',
                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    ),
                    isExpanded: true,
                    hint: const Text("Selecione a Unidade"),
                    items: _units.map((unit) {
                      return DropdownMenuItem<String>(
                        value: unit.id,
                        child: Text(unit['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUnitId = value;
                        _selectedUnitName =
                            _units.firstWhere((u) => u.id == value)['name'];
                      });
                    },
                    validator: (v) =>
                        v == null ? 'Selecione uma unidade' : null,
                  ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _isEditing ? null : _showDaysSelectionDialog,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Dia(s) da Semana',
                      enabled: !_isEditing,
                    ),
                    child: Text(
                      _selectedDays.isEmpty
                          ? 'Clique para selecionar'
                          : _selectedDays.join(', '),
                    ),
                  ),
                ),
                if (_selectedDays.isEmpty && !_isEditing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                    child: Text('Campo obrigatório',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12)),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Início',
                          ),
                          child:
                              Text(_startTime?.format(context) ?? 'Selecionar'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context, false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Fim',
                          ),
                          child:
                              Text(_endTime?.format(context) ?? 'Selecionar'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTeacherId,
                  decoration: const InputDecoration(labelText: 'Professor'),
                  items: teacherDropdownItems
                      .map((teacher) => DropdownMenuItem(
                          value: teacher.uid, child: Text(teacher.name)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedTeacherId = value),
                  validator: (v) => v == null ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Aula Particular'),
                  subtitle:
                      const Text('Visível apenas para alunos selecionados.'),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                      if (!_isPrivate) {
                        _selectedStudentIds.clear();
                      }
                    });
                  },
                  secondary: const Icon(Icons.lock_person),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_isPrivate)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                    child: OutlinedButton.icon(
                      onPressed: _showStudentSelectionDialog,
                      icon: const Icon(Icons.group_add_outlined),
                      label: Text(
                          'Selecionar Alunos (${_selectedStudentIds.length})'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: textHint)),
                    ),
                  ),
                if (_isLoadingAudiences)
                  Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedAudience,
                    decoration:
                        const InputDecoration(labelText: 'Público-Alvo'),
                    items: _classAudiences
                        .map((audience) => DropdownMenuItem(
                            value: audience, child: Text(audience)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedAudience = value),
                    validator: (v) => v == null ? 'Campo obrigatório' : null,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.settings, size: 16),
                      label: Text('Gerenciar'),
                      onPressed: () => _showManageOptionsDialog(
                          title: 'Público-Alvo', collection: 'class_audiences'),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.add_circle_outline, size: 16),
                      label: Text('Adicionar'),
                      onPressed: () => _showAddOptionDialog(
                          title: 'Público-Alvo',
                          hint: 'Ex: Juvenil',
                          collection: 'class_audiences'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoadingLevels)
                  Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedLevel,
                    decoration:
                        const InputDecoration(labelText: 'Categoria da Aula'),
                    items: _classLevels
                        .map((level) =>
                            DropdownMenuItem(value: level, child: Text(level)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedLevel = value),
                    validator: (v) => v == null ? 'Campo obrigatório' : null,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.settings, size: 16),
                      label: Text('Gerenciar'),
                      onPressed: () => _showManageOptionsDialog(
                          title: 'Categorias', collection: 'class_levels'),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.add_circle_outline, size: 16),
                      label: Text('Adicionar'),
                      onPressed: () => _showAddOptionDialog(
                          title: 'Categoria',
                          hint: 'Ex: Gi Fundamentos',
                          collection: 'class_levels'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoadingLocations)
                  Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    value: _selectedLocation,
                    decoration:
                        const InputDecoration(labelText: 'Local da Aula'),
                    items: _classLocations
                        .map((loc) =>
                            DropdownMenuItem(value: loc, child: Text(loc)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedLocation = value),
                    validator: (v) => v == null ? 'Campo obrigatório' : null,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.settings, size: 16),
                      label: Text('Gerenciar'),
                      onPressed: () => _showManageOptionsDialog(
                          title: 'Locais', collection: 'class_locations'),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.add_circle_outline, size: 16),
                      label: Text('Adicionar'),
                      onPressed: () => _showAddOptionDialog(
                          title: 'Local',
                          hint: 'Ex: Tatame Principal',
                          collection: 'class_locations'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Descrição (Opcional)',
                      alignLabelWithHint: true),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                SegmentedButton<TrainingModality>(
                  segments: const [
                    ButtonSegment(
                        value: TrainingModality.gi, label: Text('Gi')),
                    ButtonSegment(
                        value: TrainingModality.nogi, label: Text('No Gi')),
                  ],
                  selected: {_modality},
                  onSelectionChanged: (newSelection) {
                    setState(() => _modality = newSelection.first);
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _saveClass,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                      _isEditing ? 'Salvar Alterações' : 'Adicionar Aula(s)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageOptionsDialog extends StatefulWidget {
  final String academyId;
  final String collection;
  final String title;

  const _ManageOptionsDialog({
    required this.academyId,
    required this.collection,
    required this.title,
  });

  @override
  State<_ManageOptionsDialog> createState() => _ManageOptionsDialogState();
}

class _ManageOptionsDialogState extends State<_ManageOptionsDialog> {
  late Stream<QuerySnapshot> _optionsStream;

  @override
  void initState() {
    super.initState();
    _optionsStream = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection(widget.collection)
        .orderBy('name')
        .snapshots();
  }

  Future<void> _editOption(String id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Editar ${widget.title}'),
              content: TextField(controller: controller, autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar')),
                ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: Text('Salvar')),
              ],
            ));

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      final ref = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId);
      final batch = FirebaseFirestore.instance.batch();

      batch
          .update(ref.collection(widget.collection).doc(id), {'name': newName});

      final fieldToUpdate = widget.collection == 'class_levels'
          ? 'level'
          : (widget.collection == 'class_locations' ? 'location' : 'audience');
      final scheduleSnapshot = await ref
          .collection('schedule')
          .where(fieldToUpdate, isEqualTo: currentName)
          .get();
      for (final doc in scheduleSnapshot.docs) {
        batch.update(doc.reference, {fieldToUpdate: newName});
      }

      await batch.commit();
      showBjjSnackBar(context, 'Opção atualizada com sucesso!',
          type: 'success');
    }
  }

  Future<void> _deleteOption(String id, String name) async {
    final fieldToCheck = widget.collection == 'class_levels'
        ? 'level'
        : (widget.collection == 'class_locations' ? 'location' : 'audience');
    final scheduleSnapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('schedule')
        .where(fieldToCheck, isEqualTo: name)
        .limit(1)
        .get();

    if (scheduleSnapshot.docs.isNotEmpty) {
      showBjjSnackBar(context,
          'Esta opção não pode ser excluída pois está em uso por uma ou mais aulas.',
          type: 'error');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${widget.title}?'),
        content: Text('Tem certeza que deseja excluir "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: errorColor),
              child: Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection(widget.collection)
          .doc(id)
          .delete();
      showBjjSnackBar(context, 'Opção excluída!', type: 'success');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Gerenciar ${widget.title}'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<QuerySnapshot>(
          stream: _optionsStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return Center(child: CircularProgressIndicator());
            if (snapshot.data!.docs.isEmpty)
              return Center(child: Text('Nenhuma opção cadastrada.'));

            return ListView.builder(
              shrinkWrap: true,
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final name = doc['name'] as String;
                return ListTile(
                  title: Text(name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: Icon(Icons.edit_outlined),
                          onPressed: () => _editOption(doc.id, name)),
                      IconButton(
                          icon: Icon(Icons.delete_outline, color: errorColor),
                          onPressed: () => _deleteOption(doc.id, name)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text('Fechar')),
      ],
    );
  }
}

class _SelectStudentsDialog extends StatefulWidget {
  final List<Aluno> allStudents;
  final List<String> initiallySelectedIds;

  const _SelectStudentsDialog({
    required this.allStudents,
    required this.initiallySelectedIds,
  });

  @override
  State<_SelectStudentsDialog> createState() => _SelectStudentsDialogState();
}

class _SelectStudentsDialogState extends State<_SelectStudentsDialog> {
  late Set<String> _selectedIds;
  final _searchController = TextEditingController();
  List<Aluno> _filteredStudents = [];

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.initiallySelectedIds);
    _filteredStudents = widget.allStudents;
    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredStudents = widget.allStudents
            .where((s) => s.nome.toLowerCase().contains(query))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecionar Alunos'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar aluno...',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filteredStudents.length,
                itemBuilder: (context, index) {
                  final student = _filteredStudents[index];
                  final isSelected = _selectedIds.contains(student.id);
                  return CheckboxListTile(
                    title: Text(student.nome),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(student.id);
                        } else {
                          _selectedIds.remove(student.id);
                        }
                      });
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
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedIds.toList());
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
