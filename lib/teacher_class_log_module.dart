// lib/teacher_class_log_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

// ─────────────────────────────────────────────────────────────
//  Widget principal – pode ser embutido na TeacherDashboardPage
//  e também aberto pelo Gerente na ProfessorDetailPage.
// ─────────────────────────────────────────────────────────────
class TeacherClassLogWidget extends StatefulWidget {
  /// UID do professor cujos registros serão exibidos/editados.
  final String teacherUid;

  /// ID da academia.
  final String academyId;

  /// Se false, o usuário só visualiza (modo gerente sem edição).
  /// Se true, pode marcar/desmarcar dias.
  final bool canEdit;

  /// Nome do professor (usado apenas para exibição no modo gerente).
  final String? teacherName;

  const TeacherClassLogWidget({
    super.key,
    required this.teacherUid,
    required this.academyId,
    this.canEdit = true,
    this.teacherName,
  });

  @override
  State<TeacherClassLogWidget> createState() => _TeacherClassLogWidgetState();
}

class _TeacherClassLogWidgetState extends State<TeacherClassLogWidget> {
  // Mês exibido no calendário
  DateTime _focusedDay = DateTime.now();

  // Dias marcados como "deu aula" no mês atual (apenas datas, sem hora)
  Set<DateTime> _markedDays = {};

  bool _isLoading = true;
  bool _isToggling = false;

  // Referência ao documento do mês no Firestore
  // Caminho: academies/{academyId}/teacher_class_log/{teacherUid}/months/{yyyy-MM}
  DocumentReference get _monthDoc {
    final monthKey = DateFormat('yyyy-MM').format(_focusedDay);
    return FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('teacher_class_log')
        .doc(widget.teacherUid)
        .collection('months')
        .doc(monthKey);
  }

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  // ── Carrega os dias marcados do mês focado ──────────────────
  Future<void> _loadMonth() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final doc = await _monthDoc.get();
      final days = <DateTime>{};

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> rawDays = data['days'] ?? [];
        for (final d in rawDays) {
          if (d is Timestamp) {
            final dt = d.toDate();
            days.add(DateTime(dt.year, dt.month, dt.day));
          }
        }
      }

      if (mounted) {
        setState(() {
          _markedDays = days;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar registros.', type: 'error');
      }
    }
  }

  // ── Marca ou desmarca um dia ────────────────────────────────
  Future<void> _toggleDay(DateTime day) async {
    if (!widget.canEdit || _isToggling) return;

    // Não permite marcar dias futuros
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (dayOnly.isAfter(todayOnly)) {
      showBjjSnackBar(
        context,
        'Não é possível marcar dias futuros.',
        type: 'error',
      );
      return;
    }

    setState(() => _isToggling = true);

    final isMarked = _markedDays.contains(dayOnly);

    // Atualização otimista na UI
    setState(() {
      if (isMarked) {
        _markedDays.remove(dayOnly);
      } else {
        _markedDays.add(dayOnly);
      }
    });

    try {
      // Reconstrói a lista completa para salvar
      final List<Timestamp> updatedList = _markedDays
          .map((d) => Timestamp.fromDate(d))
          .toList()
        ..sort((a, b) => a.compareTo(b));

      await _monthDoc.set(
        {
          'days': updatedList,
          'teacherUid': widget.teacherUid,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // Reverte se falhou
      if (mounted) {
        setState(() {
          if (isMarked) {
            _markedDays.add(dayOnly);
          } else {
            _markedDays.remove(dayOnly);
          }
        });
        showBjjSnackBar(context, 'Erro ao salvar. Tente novamente.',
            type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  // ── Conta aulas no mês focado ───────────────────────────────
  int get _classesThisMonth {
    return _markedDays
        .where(
            (d) => d.year == _focusedDay.year && d.month == _focusedDay.month)
        .length;
  }

  // ── Helpers ─────────────────────────────────────────────────
  bool _isDayMarked(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    return _markedDays.contains(dayOnly);
  }

  bool _isFutureDay(DateTime day) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(day.year, day.month, day.day);
    return dayOnly.isAfter(todayOnly);
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'pt_BR').format(_focusedDay);
    final capitalizedMonth =
        monthName[0].toUpperCase() + monthName.substring(1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ──────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    color: primaryAccent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.teacherName != null
                        ? 'Aulas de ${widget.teacherName}'
                        : 'Meu Registro de Aulas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),

            if (widget.canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, left: 32.0),
                child: Text(
                  'Toque em um dia para marcar/desmarcar.',
                  style: const TextStyle(color: textHint, fontSize: 12),
                ),
              ),

            const SizedBox(height: 12),

            // ── Calendário ─────────────────────────────────────
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : TableCalendar(
                    locale: 'pt_BR',
                    firstDay: DateTime(2020, 1, 1),
                    lastDay: DateTime(2100, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Mês',
                    },
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      leftChevronIcon:
                          Icon(Icons.chevron_left, color: primaryAccent),
                      rightChevronIcon:
                          Icon(Icons.chevron_right, color: primaryAccent),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekdayStyle: TextStyle(color: textHint, fontSize: 12),
                      weekendStyle:
                          TextStyle(color: primaryAccent, fontSize: 12),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      defaultTextStyle:
                          const TextStyle(color: textSecondary, fontSize: 14),
                      weekendTextStyle:
                          const TextStyle(color: textSecondary, fontSize: 14),
                      disabledTextStyle:
                          TextStyle(color: textHint.withOpacity(0.4)),
                      todayDecoration: BoxDecoration(
                        border: Border.all(color: primaryAccent, width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle:
                          const TextStyle(color: primaryAccent, fontSize: 14),
                      selectedDecoration: const BoxDecoration(
                        color: primaryAccent,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                          color: primaryAccentForeground,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                      markerDecoration: const BoxDecoration(
                        color: successColor,
                        shape: BoxShape.circle,
                      ),
                      cellMargin: const EdgeInsets.all(4),
                    ),
                    // Dias marcados são "selecionados" visualmente
                    selectedDayPredicate: (day) => _isDayMarked(day),
                    // Dias futuros ficam desabilitados
                    enabledDayPredicate: (day) => !_isFutureDay(day),
                    onDaySelected: (selectedDay, focused) {
                      _toggleDay(selectedDay);
                    },
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                      _loadMonth();
                    },
                  ),

            const Divider(height: 24),

            // ── Contador do mês ────────────────────────────────
            _isLoading
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: primaryAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: primaryAccent.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded,
                            color: primaryAccent, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                capitalizedMonth,
                                style: const TextStyle(
                                    color: textHint, fontSize: 12),
                              ),
                              Text(
                                '$_classesThisMonth ${_classesThisMonth == 1 ? 'aula ministrada' : 'aulas ministradas'}',
                                style: const TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Indicador de loading ao fazer toggle
                        if (_isToggling)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Página standalone – usada pelo Gerente ao abrir
//  ProfessorDetailPage e querer ver o registro de aulas.
// ─────────────────────────────────────────────────────────────
class TeacherClassLogPage extends StatelessWidget {
  final UserModel professor;
  final String academyId;
  final bool canEdit;

  const TeacherClassLogPage({
    super.key,
    required this.professor,
    required this.academyId,
    this.canEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Registro de Aulas – ${professor.name}'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            children: [
              const SizedBox(height: 8),
              TeacherClassLogWidget(
                teacherUid: professor.uid,
                academyId: academyId,
                canEdit: canEdit,
                teacherName: professor.name,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
