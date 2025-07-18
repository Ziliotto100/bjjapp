// lib/teacher_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, library_private_types_in_public_api, unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'manager_module.dart';
import 'scoreboard_module.dart';
import 'student_module.dart';
import 'study_notebook_module.dart';
import 'auth_gate.dart';
import 'schedule_module.dart'; // Import do novo módulo

// --- TELAS DO PROFESSOR ---
class TeacherHomePage extends StatefulWidget {
  final UserModel user;
  const TeacherHomePage({super.key, required this.user});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _paginaAtual = 0;
  List<Widget> _telas = [];
  bool _isLoading = true;
  List<Aluno> _todosParticipantesDaAcademia = [];
  List<UserModel> _teachers = [];
  Map<String, dynamic> _sparringState = {};
  StreamSubscription? _sparringStateSubscription;
  bool get _isSparringMode => _sparringState['isSparringMode'] ?? false;

  final List<String> _titulos = const [
    'Painel do Professor',
    'Grade de Horários',
    'Gerenciar Alunos',
    'Check-in',
    'Sorteio',
    'Caderno de Estudos',
    'Placar'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDataAndBuildScreens();
    _listenToSparringState();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchDataAndBuildScreens() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;

      // Fetch all participants (students and teachers) as Aluno objects for sparring/matchmaking
      final studentsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .orderBy('nome')
          .get();
      final studentParticipants = studentsSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      final usersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', whereIn: ['teacher', 'manager']).get();

      final teacherAndManagerUsers = usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      final userParticipants = teacherAndManagerUsers
          .map((user) => Aluno.fromUserModel(user))
          .toList();

      final allParticipants = [...studentParticipants, ...userParticipants];
      allParticipants.sort((a, b) => a.nome.compareTo(b.nome));

      if (mounted) {
        _todosParticipantesDaAcademia = allParticipants;
        _teachers = teacherAndManagerUsers; // Use this for the schedule page
        _buildScreens();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar dados da academia.',
            type: 'error');
        _buildScreens(); // Build with empty data to avoid crash
      }
    }
  }

  void _buildScreens() {
    _telas = [
      TeacherDashboardPage(
        user: widget.user,
        isSparringMode: _isSparringMode,
        onNavigateToSparring: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SparringTeacherPage(
                  academyId: widget.user.academyId,
                  todosAlunos: _todosParticipantesDaAcademia)));
        },
      ),
      SchedulePage(user: widget.user, teachers: _teachers),
      AlunosTeacherPage(academyId: widget.user.academyId, teacher: widget.user),
      CheckinTeacherPage(
          academyId: widget.user.academyId,
          todosParticipantesDaAcademia: _todosParticipantesDaAcademia),
      SorteioTeacherPage(
          academyId: widget.user.academyId,
          todosParticipantesDaAcademia: _todosParticipantesDaAcademia,
          isSparringMode: _isSparringMode,
          onIniciarSparring: _startSparring,
          onCheckinAlunos: _checkinStudents),
      StudyNotebookPage(userId: widget.user.uid),
      MatchSetupPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosParticipantesDaAcademia),
    ];
  }

  void _listenToSparringState() {
    _sparringStateSubscription = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('state')
        .doc('sparring')
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _sparringState = doc.exists ? doc.data()! : {};
          _buildScreens();
        });
      }
    });
  }

  Future<void> _startSparring(List<List<String>> rounds, String generationType,
      List<Aluno> participants) async {
    final newState = {
      'isSparringMode': true,
      'currentRoundIndex': 1,
      'allRounds': rounds.map((round) => {'fights': round}).toList(),
      'generationType': generationType,
      'participantIds': participants.map((p) => p.id).toList(),
    };
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('state')
        .doc('sparring')
        .set(newState);

    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SparringTeacherPage(
            academyId: widget.user.academyId,
            todosAlunos: _todosParticipantesDaAcademia)));
  }

  Future<void> _checkinStudents(List<Aluno> studentsToCheckin) async {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('checkins');
    final batch = FirebaseFirestore.instance.batch();
    int count = 0;
    for (var student in studentsToCheckin) {
      batch.set(checkinRef.doc(), {
        'studentId': student.id,
        'date': Timestamp.fromDate(dateOnly),
      });
      count++;
    }
    await batch.commit();
    if (mounted) {
      showBjjSnackBar(context, '$count check-ins confirmados!',
          type: 'success');
    }
  }

  void _onAdicionarAluno() {
    showDialog(
      context: context,
      builder: (_) => AdicionarAlunoDialog(
          currentUser: widget.user,
          onAlunoAdicionado: (novoAluno) async {
            try {
              final data = novoAluno.toJson();
              data.removeWhere((key, value) => value == null);
              data['createdAt'] = FieldValue.serverTimestamp();
              data['updatedAt'] = FieldValue.serverTimestamp();

              await FirebaseFirestore.instance
                  .collection('academies')
                  .doc(widget.user.academyId)
                  .collection('students')
                  .add(data);

              if (mounted) {
                showBjjSnackBar(
                    context, '${novoAluno.nome} adicionado com sucesso!',
                    type: 'success');
                _fetchDataAndBuildScreens();
              }
            } catch (e) {
              if (mounted) {
                showBjjSnackBar(context, 'Erro ao adicionar aluno: $e',
                    type: 'error');
              }
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_titulos[_paginaAtual]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    user: widget.user,
                  ),
                ));
              }),
        ],
      ),
      body: AppBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: IndexedStack(index: _paginaAtual, children: _telas),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: (index) => setState(() => _paginaAtual = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Grade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Alunos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline_rounded),
            label: 'Check-in',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shuffle_rounded),
            label: 'Sorteio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_rounded),
            label: 'Estudos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.scoreboard_rounded),
            label: 'Placar',
          ),
        ],
      ),
      floatingActionButton: _paginaAtual == 2
          ? FloatingActionButton(
              onPressed: _onAdicionarAluno,
              tooltip: 'Adicionar Aluno',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// O restante do arquivo teacher_module.dart permanece o mesmo...
// (AlunosTeacherPage, TeacherDashboardPage, etc.)
// --- Restante do arquivo inalterado ---
class AlunosTeacherPage extends StatefulWidget {
  final String academyId;
  final UserModel teacher;
  const AlunosTeacherPage(
      {super.key, required this.academyId, required this.teacher});

  @override
  State<AlunosTeacherPage> createState() => _AlunosTeacherPageState();
}

class _AlunosTeacherPageState extends State<AlunosTeacherPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _editAluno(Aluno aluno) {
    showDialog(
      context: context,
      builder: (_) => AdicionarAlunoDialog(
        alunoParaEditar: aluno,
        academyId: widget.academyId,
        currentUser: widget.teacher,
        onAlunoAdicionado: (alunoEditado) async {
          try {
            final dataToUpdate = {
              'nome': alunoEditado.nome,
              'faixa': alunoEditado.faixa,
              'peso': alunoEditado.peso,
              'graus': alunoEditado.graus,
              'lastUpdatedByUid': widget.teacher.uid,
              'lastUpdatedByName': widget.teacher.name,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            await FirebaseFirestore.instance
                .collection('academies')
                .doc(widget.academyId)
                .collection('students')
                .doc(alunoEditado.id)
                .update(dataToUpdate);

            if (mounted) {
              showBjjSnackBar(
                  context, '${alunoEditado.nome} atualizado com sucesso!',
                  type: 'success');
            }
          } catch (e) {
            if (mounted) {
              showBjjSnackBar(context, 'Erro ao atualizar aluno: $e',
                  type: 'error');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar aluno por nome...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(widget.academyId)
                .collection('students')
                .orderBy('nome')
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
                  icon: Icons.no_accounts_rounded,
                  title: 'Nenhum Aluno Cadastrado',
                  message:
                      'Clique no botão "+" para adicionar o primeiro aluno da sua academia.',
                );
              }

              final allAlunos = snapshot.data!.docs.map((doc) {
                return Aluno.fromJson(
                    doc.id, doc.data() as Map<String, dynamic>);
              }).toList();

              final filteredAlunos = allAlunos.where((aluno) {
                return aluno.nome
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
              }).toList();

              if (filteredAlunos.isEmpty && _searchQuery.isNotEmpty) {
                return EmptyStateWidget(
                  icon: Icons.person_search,
                  title: "Nenhum Aluno Encontrado",
                  message:
                      "Nenhum aluno corresponde à sua busca '$_searchQuery'.",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                itemCount: filteredAlunos.length,
                itemBuilder: (context, index) {
                  final aluno = filteredAlunos[index];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StudentDetailPage(
                          academyId: widget.academyId,
                          student: aluno,
                        ),
                      )),
                      title: Text(aluno.nome,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                          '${aluno.faixa}${aluno.graus != null ? ' - ${aluno.graus}º' : ''} - ${aluno.peso}kg'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: primaryAccent),
                        onPressed: () => _editAluno(aluno),
                        tooltip: 'Editar Aluno',
                      ),
                    ),
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

class TeacherDashboardPage extends StatelessWidget {
  final UserModel user;
  final bool isSparringMode;
  final VoidCallback onNavigateToSparring;

  const TeacherDashboardPage(
      {super.key,
      required this.user,
      required this.isSparringMode,
      required this.onNavigateToSparring});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        UserProfileHeader(user: user),
        if (isSparringMode)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: primaryAccent, width: 2),
              ),
              child: InkWell(
                onTap: onNavigateToSparring,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_kabaddi_rounded,
                          color: primaryAccent, size: 30),
                      const SizedBox(width: 16),
                      Text("Ver Treino em Andamento",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: primaryAccent)),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text(
              'Use a barra de navegação abaixo para gerenciar suas turmas e aulas.',
              style: TextStyle(color: textHint, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class CheckinTeacherPage extends StatelessWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;
  const CheckinTeacherPage(
      {super.key,
      required this.academyId,
      required this.todosParticipantesDaAcademia});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.checklist_rtl_rounded, color: primaryAccent),
            title: const Text("Fazer Chamada"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () async {
              final checkedInCount = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => BulkCheckinPage(
                    academyId: academyId,
                    todosParticipantesDaAcademia: todosParticipantesDaAcademia,
                  ),
                ),
              );

              if (checkedInCount != null &&
                  checkedInCount > 0 &&
                  context.mounted) {
                showBjjSnackBar(
                    context, '$checkedInCount presenças confirmadas!',
                    type: 'success');
              }
            },
          ),
        ),
        Card(
          child: ListTile(
            leading:
                const Icon(Icons.edit_calendar_rounded, color: warningColor),
            title: const Text("Lançar Retroativo"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () async {
              final checkedInCount = await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) => RetroactiveCheckinPage(
                    academyId: academyId,
                    todosParticipantesDaAcademia: todosParticipantesDaAcademia,
                  ),
                ),
              );

              if (checkedInCount != null && context.mounted) {
                if (checkedInCount > 0) {
                  showBjjSnackBar(context,
                      '$checkedInCount presenças retroativas confirmadas!',
                      type: 'success');
                } else {
                  showBjjSnackBar(
                      context, 'Nenhuma presença nova foi registrada.',
                      type: 'info');
                }
              }
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.leaderboard_rounded, color: infoColor),
            title: const Text("Ranking de Presença"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              if (todosParticipantesDaAcademia.isEmpty) {
                showBjjSnackBar(context, 'Cadastre participantes primeiro.',
                    type: 'info');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RankingTeacherPage(academyId: academyId),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history_rounded, color: successColor),
            title: const Text("Histórico de Check-in"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CheckinHistoryPage(
                  academyId: academyId,
                  allParticipants: todosParticipantesDaAcademia,
                ),
              ));
            },
          ),
        ),
      ],
    );
  }
}

class CheckinHistoryPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> allParticipants;

  const CheckinHistoryPage({
    super.key,
    required this.academyId,
    required this.allParticipants,
  });

  @override
  State<CheckinHistoryPage> createState() => _CheckinHistoryPageState();
}

class _CheckinHistoryPageState extends State<CheckinHistoryPage> {
  late final Map<String, Aluno> _participantsMap;
  DateTime _selectedDay = DateTime.now();
  List<Aluno> _checkedInStudents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _participantsMap = {for (var p in widget.allParticipants) p.id: p};
    _fetchCheckinsForDay(_selectedDay);
  }

  Future<void> _fetchCheckinsForDay(DateTime day) async {
    setState(() => _isLoading = true);
    final dateOnly = DateTime(day.year, day.month, day.day);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('checkins')
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .get();

      final studentIds =
          snapshot.docs.map((doc) => doc['studentId'] as String).toList();
      final students = studentIds
          .map((id) => _participantsMap[id])
          .whereType<Aluno>()
          .toList();
      students.sort((a, b) => a.nome.compareTo(b.nome));

      if (mounted) {
        setState(() {
          _checkedInStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, "Erro ao buscar presenças.", type: 'error');
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDay) {
      setState(() {
        _selectedDay = picked;
      });
      _fetchCheckinsForDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Histórico de Check-in"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12.0),
                child: ListTile(
                  leading:
                      const Icon(Icons.calendar_today, color: primaryAccent),
                  title: const Text("Data Selecionada"),
                  subtitle: Text(
                    DateFormat.yMMMMd('pt_BR').format(_selectedDay),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  onTap: _pickDate,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  "Presentes na data selecionada (${_checkedInStudents.length})",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _checkedInStudents.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.group_off_rounded,
                            title: "Nenhum check-in",
                            message: "Ninguém treinou neste dia.",
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: _checkedInStudents.length,
                            itemBuilder: (context, index) {
                              final student = _checkedInStudents[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.check_circle,
                                      color: successColor),
                                  title: Text(student.nome),
                                  subtitle: Text(student.faixa),
                                ),
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

class BulkCheckinPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;

  const BulkCheckinPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
  });

  @override
  State<BulkCheckinPage> createState() => _BulkCheckinPageState();
}

class _BulkCheckinPageState extends State<BulkCheckinPage> {
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];

  @override
  void initState() {
    super.initState();
    _filteredParticipants = widget.todosParticipantesDaAcademia;
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterParticipants);
    _searchController.dispose();
    super.dispose();
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.todosParticipantesDaAcademia.where((aluno) {
        return aluno.nome.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _saveBulkCheckin() async {
    if (_selectedStudentIds.isEmpty) {
      showBjjSnackBar(context, 'Nenhum participante selecionado.',
          type: 'warning');
      return;
    }
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins');

    try {
      final querySnapshot = await checkinRef
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .where('studentId', whereIn: _selectedStudentIds.toList())
          .get();
      final alreadyCheckedInIds =
          querySnapshot.docs.map((doc) => doc['studentId'] as String).toSet();
      final batch = FirebaseFirestore.instance.batch();
      int newCheckinsCount = 0;
      for (final studentId in _selectedStudentIds) {
        if (!alreadyCheckedInIds.contains(studentId)) {
          final newDoc = checkinRef.doc();
          batch.set(newDoc, {
            'studentId': studentId,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
          });
          newCheckinsCount++;
        }
      }

      if (newCheckinsCount > 0) {
        await batch.commit();
      }
      if (mounted) {
        Navigator.of(context).pop(newCheckinsCount);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar presenças: $e', type: 'error');
      }
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
        title: const Text("Chamada da Turma"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nome...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: _filteredParticipants.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.person_off,
                        title: "Nenhum Participante Encontrado",
                        message: _searchController.text.isNotEmpty
                            ? "Verifique o nome digitado."
                            : "Adicione alunos ou professores para fazer a chamada.",
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                        itemCount: _filteredParticipants.length,
                        itemBuilder: (context, index) {
                          final aluno = _filteredParticipants[index];
                          final isSelected =
                              _selectedStudentIds.contains(aluno.id);
                          return Card(
                            child: CheckboxListTile(
                              title: Text(aluno.nome),
                              subtitle: Text(aluno.faixa),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedStudentIds.add(aluno.id);
                                  } else {
                                    _selectedStudentIds.remove(aluno.id);
                                  }
                                });
                              },
                              secondary: const Icon(Icons.person_outline),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: primaryAccentForeground),
            )
          : FloatingActionButton.extended(
              onPressed: _saveBulkCheckin,
              label: Text("Confirmar (${_selectedStudentIds.length})"),
              icon: const Icon(Icons.check_circle_outline),
            ),
    );
  }
}

class RetroactiveCheckinPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;

  const RetroactiveCheckinPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
  });

  @override
  State<RetroactiveCheckinPage> createState() => _RetroactiveCheckinPageState();
}

class _RetroactiveCheckinPageState extends State<RetroactiveCheckinPage> {
  final Set<String> _selectedStudentIds = {};
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];

  @override
  void initState() {
    super.initState();
    _filteredParticipants = widget.todosParticipantesDaAcademia;
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterParticipants);
    _searchController.dispose();
    super.dispose();
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.todosParticipantesDaAcademia.where((aluno) {
        return aluno.nome.toLowerCase().contains(query);
      }).toList();
    });
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

  Future<void> _saveRetroactiveCheckin() async {
    if (_selectedStudentIds.isEmpty) {
      showBjjSnackBar(context, 'Nenhum participante selecionado.',
          type: 'warning');
      return;
    }

    setState(() => _isLoading = true);

    final dateOnly =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins');

    try {
      final querySnapshot = await checkinRef
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .where('studentId', whereIn: _selectedStudentIds.toList())
          .get();

      final alreadyCheckedInIds =
          querySnapshot.docs.map((doc) => doc['studentId'] as String).toSet();

      final batch = FirebaseFirestore.instance.batch();
      int newCheckinsCount = 0;

      for (final studentId in _selectedStudentIds) {
        if (!alreadyCheckedInIds.contains(studentId)) {
          final newDoc = checkinRef.doc();
          batch.set(newDoc, {
            'studentId': studentId,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
          });
          newCheckinsCount++;
        }
      }

      if (newCheckinsCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        Navigator.of(context).pop(newCheckinsCount);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar presenças: $e', type: 'error');
      }
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
        title: const Text("Check-in Retroativo"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: ListTile(
                  leading:
                      const Icon(Icons.calendar_month, color: primaryAccent),
                  title: const Text("Data do Check-in"),
                  subtitle:
                      Text(DateFormat.yMMMMd('pt_BR').format(_selectedDate)),
                  onTap: _pickDate,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nome...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: _filteredParticipants.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.person_search,
                        title: "Nenhum Participante Encontrado")
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                        itemCount: _filteredParticipants.length,
                        itemBuilder: (context, index) {
                          final aluno = _filteredParticipants[index];
                          final isSelected =
                              _selectedStudentIds.contains(aluno.id);
                          return Card(
                            child: CheckboxListTile(
                              title: Text(aluno.nome),
                              subtitle: Text(aluno.faixa),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedStudentIds.add(aluno.id);
                                  } else {
                                    _selectedStudentIds.remove(aluno.id);
                                  }
                                });
                              },
                              secondary: const Icon(Icons.person_outline),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoading
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(color: primaryAccentForeground),
            )
          : FloatingActionButton.extended(
              onPressed: _saveRetroactiveCheckin,
              label: Text("Confirmar (${_selectedStudentIds.length})"),
              icon: const Icon(Icons.check_circle_outline),
            ),
    );
  }
}

class RankingTeacherPage extends StatefulWidget {
  final String academyId;
  const RankingTeacherPage({super.key, required this.academyId});

  @override
  State<RankingTeacherPage> createState() => _RankingTeacherPageState();
}

class _RankingTeacherPageState extends State<RankingTeacherPage> {
  Map<String, int> _checkinCounts = {};
  List<Aluno> _todosParticipantes = [];
  bool _isLoading = true;
  String _filter = 'total';

  @override
  void initState() {
    super.initState();
    _fetchRankingData();
  }

  Future<void> _fetchRankingData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.academyId;

      final alunosSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .get();
      final fetchedAlunos = alunosSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      final usersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', isEqualTo: 'teacher')
          .get();
      final fetchedUsersAsAlunos = usersSnapshot.docs
          .map((doc) => Aluno.fromUserModel(UserModel.fromFirestore(doc)))
          .toList();

      final allParticipants = [...fetchedAlunos, ...fetchedUsersAsAlunos];

      final checkinsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('checkins')
          .get();
      final allCheckins = checkinsSnapshot.docs
          .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
          .toList();

      final now = DateTime.now();
      final Map<String, int> counts = {
        for (var participant in allParticipants) participant.id: 0
      };

      for (var checkin in allCheckins) {
        bool shouldCount = false;
        switch (_filter) {
          case 'total':
            shouldCount = true;
            break;
          case 'mes':
            if (checkin.date.month == now.month &&
                checkin.date.year == now.year) {
              shouldCount = true;
            }
            break;
          case 'ano':
            if (checkin.date.year == now.year) {
              shouldCount = true;
            }
            break;
        }
        if (shouldCount) {
          counts.update(checkin.studentId, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }

      if (mounted) {
        setState(() {
          _todosParticipantes = allParticipants;
          _checkinCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar o ranking.", type: "error");
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedParticipantes = List<Aluno>.from(_todosParticipantes);
    rankedParticipantes.sort((a, b) {
      final countA = _checkinCounts[a.id] ?? 0;
      final countB = _checkinCounts[b.id] ?? 0;
      return countB.compareTo(countA) != 0
          ? countB.compareTo(countA)
          : a.nome.compareTo(b.nome);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Ranking de Presença')),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                        value: 'mes', label: Text('Mês Atual')),
                    ButtonSegment<String>(
                        value: 'ano', label: Text('Este Ano')),
                    ButtonSegment<String>(value: 'total', label: Text('Total')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (newSelection) {
                    setState(() => _filter = newSelection.first);
                    _fetchRankingData();
                  },
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : rankedParticipantes.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.group_off_rounded,
                            title: "Nenhum participante encontrado.")
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(8.0, 0, 8.0, 16.0),
                            itemCount: rankedParticipantes.length,
                            itemBuilder: (context, index) {
                              final aluno = rankedParticipantes[index];
                              final count = _checkinCounts[aluno.id] ?? 0;
                              final rank = index + 1;
                              Widget leadingIcon;
                              if (rank == 1) {
                                leadingIcon = const Icon(Icons.emoji_events,
                                    color: primaryAccent, size: 30);
                              } else if (rank == 2) {
                                leadingIcon = const Icon(Icons.emoji_events,
                                    color: Color(0xFFC0C0C0), size: 28);
                              } else if (rank == 3) {
                                leadingIcon = const Icon(Icons.emoji_events,
                                    color: Color(0xFFCD7F32), size: 26);
                              } else {
                                leadingIcon = CircleAvatar(
                                    radius: 14,
                                    backgroundColor: darkSurface,
                                    child: Text('$rank',
                                        style: const TextStyle(
                                            color: textHint,
                                            fontWeight: FontWeight.bold)));
                              }

                              return Card(
                                child: ListTile(
                                  leading: leadingIcon,
                                  title: Text(aluno.nome,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  trailing: Text('$count treinos',
                                      style: const TextStyle(
                                          color: primaryAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
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

class SorteioTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;
  final bool isSparringMode;
  final Function(List<List<String>>, String, List<Aluno>) onIniciarSparring;
  final Function(List<Aluno>) onCheckinAlunos;

  const SorteioTeacherPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
    required this.isSparringMode,
    required this.onIniciarSparring,
    required this.onCheckinAlunos,
  });

  @override
  State<SorteioTeacherPage> createState() => _SorteioTeacherPageState();
}

class _SorteioTeacherPageState extends State<SorteioTeacherPage> {
  List<Aluno> _alunosParticipantes = [];
  List<List<String>> _rodadasGeradas = [];
  String _tipoGeracao = 'Aleatório';
  final List<String> _opcoesGeracao = ['Aleatório', 'Por Faixa', 'Por Peso'];

  void _atualizarAlunosParticipantes(List<Aluno> novosParticipantes) {
    setState(() {
      _alunosParticipantes = novosParticipantes;
      _rodadasGeradas = [];
    });
  }

  Future<void> _navegarParaSelecaoAlunos() async {
    final List<Aluno>? r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SelecaoAlunosTeacherPage(
        todosOsAlunos: widget.todosParticipantesDaAcademia,
        alunosSelecionadosIniciais: _alunosParticipantes,
      ),
    ));
    if (r != null) {
      _atualizarAlunosParticipantes(r);
    }
  }

  void _gerarRodadasClicado() {
    if (widget.isSparringMode) {
      showBjjSnackBar(context, 'Finalize o treino atual primeiro.',
          type: 'warning');
      return;
    }
    if (_alunosParticipantes.length < 2) {
      showBjjSnackBar(context, 'Selecione pelo menos 2 participantes.',
          type: 'error');
      return;
    }
    setState(() => _rodadasGeradas = []);
    if (_tipoGeracao == 'Aleatório') {
      _gerarRodadasAleatorias();
    } else {
      _gerarRodadasHierarquicas();
    }
  }

  void _gerarRodadasAleatorias() {
    List<Aluno> tempAlunos = List.from(_alunosParticipantes);
    tempAlunos.shuffle();

    if (tempAlunos.length % 2 != 0) {
      tempAlunos.add(Aluno.novo(nome: "DESCANSA", faixa: "", peso: 0));
    }
    int numRodadas = tempAlunos.length - 1;
    if (numRodadas <= 0) numRodadas = 1;

    List<List<String>> rodadas = [];
    for (int i = 0; i < numRodadas; i++) {
      List<String> rodadaAtual = [];
      for (int j = 0; j < tempAlunos.length / 2; j++) {
        final aluno1 = tempAlunos[j];
        final aluno2 = tempAlunos[tempAlunos.length - 1 - j];
        if (aluno1.nome == "DESCANSA") {
          rodadaAtual.add('${aluno2.nome} (descansa)');
        } else if (aluno2.nome == "DESCANSA") {
          rodadaAtual.add('${aluno1.nome} (descansa)');
        } else {
          rodadaAtual.add('${aluno1.nome} x ${aluno2.nome}');
        }
      }
      rodadas.add(rodadaAtual);
      tempAlunos.insert(1, tempAlunos.removeLast());
    }
    setState(() => _rodadasGeradas = rodadas);
  }

  void _gerarRodadasHierarquicas() {
    List<Aluno> tempAlunos = List.from(_alunosParticipantes);
    List<Luta> todasLutasPossiveis = [];

    for (int i = 0; i < tempAlunos.length; i++) {
      for (int j = i + 1; j < tempAlunos.length; j++) {
        double custo;
        if (_tipoGeracao == 'Por Peso') {
          custo = (tempAlunos[i].peso - tempAlunos[j].peso).abs();
        } else {
          int indexFaixa1 = _getBeltIndex(tempAlunos[i].faixa);
          int indexFaixa2 = _getBeltIndex(tempAlunos[j].faixa);
          double diffPeso = (tempAlunos[i].peso - tempAlunos[j].peso).abs();
          custo =
              (indexFaixa1 - indexFaixa2).abs().toDouble() + (diffPeso * 0.01);
        }
        todasLutasPossiveis.add(Luta(tempAlunos[i], tempAlunos[j], custo));
      }
    }
    todasLutasPossiveis.sort((a, b) => a.custo.compareTo(b.custo));

    List<List<String>> rodadasConstruidas = [];
    Set<String> lutasJaRealizadasGlobal = {};
    int maxRodadasPossiveis = tempAlunos.length - 1;

    for (int i = 0; i < maxRodadasPossiveis; i++) {
      List<String> rodadaAtual = [];
      Set<String> alunosNestaRodada = {};

      for (var luta in todasLutasPossiveis) {
        String parId1 = '${luta.aluno1.id}-${luta.aluno2.id}';
        String parId2 = '${luta.aluno2.id}-${luta.aluno1.id}';

        if (!lutasJaRealizadasGlobal.contains(parId1) &&
            !alunosNestaRodada.contains(luta.aluno1.id) &&
            !alunosNestaRodada.contains(luta.aluno2.id)) {
          rodadaAtual.add('${luta.aluno1.nome} x ${luta.aluno2.nome}');
          alunosNestaRodada.add(luta.aluno1.id);
          alunosNestaRodada.add(luta.aluno2.id);
          lutasJaRealizadasGlobal.add(parId1);
          lutasJaRealizadasGlobal.add(parId2);
        }
      }

      if (alunosNestaRodada.length < tempAlunos.length) {
        final alunoDescanso = tempAlunos
            .firstWhereOrNull((aluno) => !alunosNestaRodada.contains(aluno.id));
        if (alunoDescanso != null) {
          rodadaAtual.add('${alunoDescanso.nome} (descansa)');
        }
      }

      if (rodadaAtual.isNotEmpty) {
        rodadasConstruidas.add(rodadaAtual);
      } else {
        break;
      }
    }
    setState(() => _rodadasGeradas = rodadasConstruidas);
  }

  int _getBeltIndex(String faixa) {
    const List<String> ordemFaixas = [
      'Branca',
      'Cinza com Ponta Branca',
      'Cinza',
      'Cinza com Ponta Preta',
      'Amarela com Ponta Branca',
      'Amarela',
      'Amarela com Ponta Preta',
      'Laranja com Ponta Branca',
      'Laranja',
      'Laranja com Ponta Preta',
      'Verde com Ponta Branca',
      'Verde',
      'Verde com Ponta Preta',
      'Azul',
      'Roxa',
      'Marrom',
      'Preta'
    ];
    final faixaPrincipal = faixa.split(" ")[0].trim();
    final index = ordemFaixas
        .indexWhere((f) => f.toLowerCase() == faixaPrincipal.toLowerCase());
    return index == -1 ? 0 : index;
  }

  void _iniciarSparringClicado() {
    if (_rodadasGeradas.isEmpty) {
      showBjjSnackBar(context, 'Gere as rodadas primeiro.', type: 'error');
      return;
    }
    widget.onIniciarSparring(
        _rodadasGeradas, _tipoGeracao, _alunosParticipantes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(
                        'Selecionar Participantes (${_alunosParticipantes.length})'),
                    onPressed: widget.isSparringMode
                        ? null
                        : _navegarParaSelecaoAlunos,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _tipoGeracao,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de Sorteio'),
                    items: _opcoesGeracao
                        .map((String value) => DropdownMenuItem<String>(
                            value: value, child: Text(value)))
                        .toList(),
                    onChanged: widget.isSparringMode
                        ? null
                        : (v) => setState(() {
                              _tipoGeracao = v!;
                              _rodadasGeradas = [];
                            }),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Gerar Rodadas'),
                    onPressed:
                        widget.isSparringMode || _alunosParticipantes.length < 2
                            ? null
                            : _gerarRodadasClicado,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_rodadasGeradas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Iniciar Treino'),
              onPressed: _iniciarSparringClicado,
              style: ElevatedButton.styleFrom(
                backgroundColor: successColor,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        Expanded(
          child: _rodadasGeradas.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.list_alt_rounded,
                  title: "Nenhuma Rodada Gerada",
                  message:
                      "Selecione os participantes e gere as rodadas acima.")
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  itemCount: _rodadasGeradas.length,
                  itemBuilder: (context, index) {
                    final rodada = _rodadasGeradas[index];
                    return Card(
                      child: ExpansionTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text('Rodada ${index + 1}'),
                        children: rodada
                            .map((luta) => ListTile(title: Text(luta)))
                            .toList(),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class SparringTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosAlunos;

  const SparringTeacherPage(
      {super.key, required this.academyId, required this.todosAlunos});

  @override
  State<SparringTeacherPage> createState() => _SparringTeacherPageState();
}

class _SparringTeacherPageState extends State<SparringTeacherPage> {
  Map<String, dynamic> _sparringState = {};
  bool _isLoading = true;
  StreamSubscription? _sparringStateSubscription;

  int get _currentRoundIndex => _sparringState['currentRoundIndex'] ?? 0;
  List<List<String>> get _allRounds {
    final dynamic roundsData = _sparringState['allRounds'];
    if (roundsData is List) {
      return roundsData.map<List<String>>((item) {
        if (item is Map &&
            item.containsKey('fights') &&
            item['fights'] is List) {
          return List<String>.from(item['fights']);
        }
        return <String>[];
      }).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    super.dispose();
  }

  void _loadState() {
    _sparringStateSubscription = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _sparringState = doc.data()!;
          _isLoading = false;
        });
      } else {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _updateSparringState(Map<String, dynamic> update) async {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .update(update);
  }

  Future<void> _finishSparring() async {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .delete();
  }

  void _nextRound() {
    final newIndex = _currentRoundIndex + 1;
    _updateSparringState({'currentRoundIndex': newIndex});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Colors.transparent,
          body:
              AppBackground(child: Center(child: CircularProgressIndicator())));
    }

    bool isSparringMode = _sparringState['isSparringMode'] ?? false;
    if (!isSparringMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text("Treino")),
        body: const AppBackground(
          child: EmptyStateWidget(
            icon: Icons.pause_circle_outline_rounded,
            title: 'Nenhum treino em andamento.',
            message: 'Volte para a tela de sorteio para iniciar um treino.',
          ),
        ),
      );
    }

    List<String> currentRoundFights = [];
    String roundTitle = '';
    bool isLastRound = _currentRoundIndex > _allRounds.length;

    if (_allRounds.isNotEmpty) {
      if (isLastRound) {
        currentRoundFights = _allRounds.last;
        roundTitle =
            'FIM - Última Rodada (${_allRounds.length}/${_allRounds.length})';
      } else {
        currentRoundFights = _allRounds[_currentRoundIndex - 1];
        roundTitle = 'Rodada $_currentRoundIndex / ${_allRounds.length}';
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(roundTitle)),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: currentRoundFights.length,
                  itemBuilder: (context, index) {
                    final matchText = currentRoundFights[index];
                    bool isResting = matchText.contains('(descansa)');

                    return Card(
                      color: isResting
                          ? darkSurface.withOpacity(0.5)
                          : darkSurface,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(matchText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color:
                                          isResting ? textHint : textPrimary)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop_circle_rounded),
                      onPressed: _finishSparring,
                      label: const Text('Finalizar'),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: errorColor),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: isLastRound ? null : _nextRound,
                      label: const Text('Próxima'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelecaoAlunosTeacherPage extends StatefulWidget {
  final List<Aluno> todosOsAlunos;
  final List<Aluno> alunosSelecionadosIniciais;
  const SelecaoAlunosTeacherPage(
      {super.key,
      required this.todosOsAlunos,
      required this.alunosSelecionadosIniciais});
  @override
  _SelecaoAlunosTeacherPageState createState() =>
      _SelecaoAlunosTeacherPageState();
}

class _SelecaoAlunosTeacherPageState extends State<SelecaoAlunosTeacherPage> {
  late Set<Aluno> _alunosAtuaisSelecionados;

  @override
  void initState() {
    super.initState();
    _alunosAtuaisSelecionados =
        Set<Aluno>.from(widget.alunosSelecionadosIniciais);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Selecionar Participantes'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: widget.todosOsAlunos.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.person_search_rounded,
                  title: 'Nenhum Participante Cadastrado na Academia')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: widget.todosOsAlunos.length,
                  itemBuilder: (context, index) {
                    final a = widget.todosOsAlunos[index];
                    final s = _alunosAtuaisSelecionados.contains(a);
                    return Card(
                      child: CheckboxListTile(
                        title: Text(a.nome),
                        subtitle: Text('${a.faixa} - ${a.peso}kg'),
                        value: s,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _alunosAtuaisSelecionados.add(a);
                          } else {
                            _alunosAtuaisSelecionados.remove(a);
                          }
                        }),
                        secondary: const Icon(Icons.person),
                      ),
                    );
                  }),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () =>
              Navigator.of(context).pop(_alunosAtuaisSelecionados.toList()),
          label: Text('Confirmar (${_alunosAtuaisSelecionados.length})'),
          icon: const Icon(Icons.check_circle_outline_rounded)),
    );
  }
}
