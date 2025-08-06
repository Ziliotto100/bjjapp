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
import 'schedule_module.dart';
import 'navigation_service.dart';
import 'app_drawer.dart';
import 'user_card_widget.dart';

// --- TELAS DO PROFESSOR ---
class TeacherHomePage extends StatefulWidget {
  final UserModel user;
  final bool isImpersonating;

  const TeacherHomePage({
    super.key,
    required this.user,
    this.isImpersonating = false,
  });

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _paginaAtual = 0;
  bool _isLoading = true;

  late final NavigationService _navService;
  List<AppModule> _allModules = [];
  List<AppModule> _visibleModules = [];
  List<Widget> _telas = [];

  List<UserModel> _teachers = [];
  List<Aluno> _students = [];

  bool _isSparringMode = false;
  StreamSubscription? _sparringStateSubscription;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _navService =
        NavigationService(userId: widget.user.uid, userRole: widget.user.role);
    _loadInitialData();
    _listenToSparringState();
    _checkForNewNotifications();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    _settingsSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;

      final usersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', isEqualTo: 'teacher')
          .get();
      _teachers = usersSnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      final studentsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .get();
      final studentParticipants = studentsSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();
      final teacherParticipants =
          _teachers.map((user) => Aluno.fromUserModel(user)).toList();
      _students = [...studentParticipants, ...teacherParticipants]
        ..sort((a, b) => a.nome.compareTo(b.nome));

      _settingsSubscription =
          _navService.getTabSettingsStream().listen((settingsDoc) {
        _configureNavigation(settingsDoc);
      });
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar dados.", type: 'error');
        setState(() => _isLoading = false);
      }
    }
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
          _isSparringMode =
              doc.exists && (doc.data()?['isSparringMode'] ?? false);
          if (!_isLoading) _rebuildScreens();
        });
      }
    });
  }

  void _checkForNewNotifications() {
    final userLastCheck = widget.user.lastNotificationCheck ??
        Timestamp.fromMillisecondsSinceEpoch(0);

    _notificationSubscription = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('notifications')
        .where('createdAt', isGreaterThan: userLastCheck)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && mounted) {
        final latestNotificationDoc = snapshot.docs.first;
        final notification =
            NotificationModel.fromFirestore(latestNotificationDoc);

        if (notification.senderId == widget.user.uid) {
          final timeSinceSent =
              DateTime.now().difference(notification.createdAt.toDate());
          if (timeSinceSent.inSeconds < 10) {
            await _updateLastNotificationCheck();
            return;
          }
        }

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notification.title),
            content: Text(notification.message),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _updateLastNotificationCheck();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  Future<void> _updateLastNotificationCheck() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'lastNotificationCheck': Timestamp.now()});
    } catch (e) {
      debugPrint("Falha ao atualizar o horário de checagem: $e");
    }
  }

  Future<void> _iniciarSparring(List<List<Map<String, String>>> rounds,
      String tipoGeracao, List<Aluno> participants) async {
    if (participants.isEmpty) {
      showBjjSnackBar(context, 'Selecione participantes para o treino.',
          type: 'error');
      return;
    }

    await _checkinAlunos(participants);

    final roundsForFirestore =
        rounds.map((round) => {'fights': round}).toList();

    final stateData = {
      'isSparringMode': true,
      'allRounds': roundsForFirestore,
      'participants': participants.map((p) => p.id).toList(),
      'generationType': tipoGeracao,
      'currentRoundIndex': 1,
      'startedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('state')
          .doc('sparring')
          .set(stateData);
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao iniciar o treino: $e', type: 'error');
      }
    }
  }

  Future<void> _checkinAlunos(List<Aluno> participants) async {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    final checkinRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('checkins');

    final participantIds = participants.map((p) => p.id).toList();
    if (participantIds.isEmpty) return;

    final querySnapshot = await checkinRef
        .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
        .where('studentId', whereIn: participantIds)
        .get();

    final existingCheckinsMap = {
      for (var doc in querySnapshot.docs) doc['studentId'] as String: doc
    };

    final batch = FirebaseFirestore.instance.batch();
    int newCheckins = 0;
    for (final student in participants) {
      if (!existingCheckinsMap.containsKey(student.id)) {
        final newDocRef = checkinRef.doc();
        batch.set(newDocRef, {
          'studentId': student.id,
          'studentName': student.nome,
          'date': Timestamp.fromDate(dateOnly),
          'createdAt': FieldValue.serverTimestamp(),
          'status': checkinStatusToString(CheckinStatus.approved),
        });
        newCheckins++;
      }
    }
    if (newCheckins > 0) {
      await batch.commit();
      if (mounted) {
        showBjjSnackBar(context, '$newCheckins presenças confirmadas!',
            type: 'success');
      }
    }
  }

  void _rebuildScreens() {
    if (_allModules.isEmpty) return;
    setState(() {
      _telas =
          _allModules.map((module) => _buildPageForModule(module)).toList();
    });
  }

  Widget _buildPageForModule(AppModule module) {
    switch (module.id) {
      case 'teacher_dashboard':
        return TeacherDashboardPage(
          user: widget.user,
          isSparringMode: _isSparringMode,
          onNavigateToSparring: () {
            final sparringIndex =
                _allModules.indexWhere((m) => m.id == 'teacher_sparring');
            if (sparringIndex != -1) {
              setState(() => _paginaAtual = sparringIndex);
            }
          },
        );
      case 'teacher_sparring':
        if (_isSparringMode) {
          return SparringTeacherPage(
            academyId: widget.user.academyId,
            todosAlunos: _students,
          );
        }
        return SorteioTeacherPage(
          academyId: widget.user.academyId,
          todosParticipantesDaAcademia: _students,
          isSparringMode: _isSparringMode,
          onIniciarSparring: _iniciarSparring,
          onCheckinAlunos: _checkinAlunos,
        );
      default:
        return module.pageBuilder(widget.user, _teachers, _students);
    }
  }

  void _configureNavigation(DocumentSnapshot? settingsDoc) {
    Map<String, dynamic> settings;
    if (settingsDoc != null && settingsDoc.exists) {
      settings = settingsDoc.data() as Map<String, dynamic>;
    } else {
      settings = _navService.getDefaultTabSettings();
    }

    final allUserModules = _navService.getModulesForCurrentUser();
    final List<String> savedOrder = List<String>.from(settings['order'] ?? []);
    final List<String> visibleIds =
        List<String>.from(settings['visible'] ?? []);

    for (var module in allUserModules) {
      if (!savedOrder.contains(module.id)) {
        savedOrder.add(module.id);
      }
    }
    savedOrder.removeWhere((id) => !allUserModules.any((m) => m.id == id));

    if (mounted) {
      setState(() {
        _allModules = savedOrder
            .map((id) => allUserModules.firstWhere((m) => m.id == id,
                orElse: () => allUserModules.first))
            .toList();

        _visibleModules =
            _allModules.where((m) => visibleIds.contains(m.id)).toList();

        if (_paginaAtual >= _allModules.length) {
          _paginaAtual = 0;
        }
        _rebuildScreens();
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    final selectedModuleId = _visibleModules[index].id;
    final globalIndex = _allModules.indexWhere((m) => m.id == selectedModuleId);
    setState(() {
      _paginaAtual = globalIndex;
    });
  }

  void _onDrawerItemTapped(int index) {
    setState(() {
      _paginaAtual = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppBackground(child: Center(child: CircularProgressIndicator())),
      );
    }

    final currentModule = _allModules[_paginaAtual];
    final currentVisibleIndex =
        _visibleModules.indexWhere((m) => m.id == currentModule.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(currentModule.title),
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
      drawer: AppDrawer(
        user: widget.user,
        allModules: _allModules,
        onSelectItem: _onDrawerItemTapped,
      ),
      body: Column(
        children: [
          if (widget.isImpersonating)
            ImpersonationBanner(userName: widget.user.name),
          Expanded(
            child: AppBackground(
              child: SafeArea(
                top: !widget.isImpersonating,
                child: IndexedStack(index: _paginaAtual, children: _telas),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentVisibleIndex != -1 ? currentVisibleIndex : 0,
        onTap: _onItemTapped,
        items: _visibleModules.map((module) {
          return BottomNavigationBarItem(
            icon: Icon(module.icon),
            label: module.title,
          );
        }).toList(),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    final currentModuleId = _allModules[_paginaAtual].id;
    if (currentModuleId == 'teacher_students') {
      return FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AdicionarAlunoDialog(
                currentUser: widget.user,
                onAlunoAdicionado: (novoAluno) async {
                  try {
                    final studentCollection = FirebaseFirestore.instance
                        .collection('academies')
                        .doc(widget.user.academyId)
                        .collection('students');

                    final docRef =
                        await studentCollection.add(novoAluno.toJson());

                    final historyEntry = GraduationHistory(
                      id: '',
                      belt: novoAluno.faixa,
                      degree: novoAluno.graus,
                      date: DateTime.now(),
                      promotedByUid: widget.user.uid,
                      promotedByName: widget.user.name,
                    );

                    await docRef
                        .collection('graduation_history')
                        .add(historyEntry.toMap());

                    if (mounted) {
                      showBjjSnackBar(
                          context, '${novoAluno.nome} adicionado com sucesso!',
                          type: 'success');
                      _loadInitialData();
                    }
                  } catch (e) {
                    if (mounted) {
                      showBjjSnackBar(context, 'Erro ao adicionar aluno: $e',
                          type: 'error');
                    }
                  }
                }),
          );
        },
        tooltip: 'Adicionar Aluno',
        child: const Icon(Icons.add),
      );
    }
    return null;
  }
}

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
  late Future<Map<String, UserModel>> _usersMapFuture;

  @override
  void initState() {
    super.initState();
    _usersMapFuture = _fetchUsersMap();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<Map<String, UserModel>> _fetchUsersMap() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('academyId', isEqualTo: widget.academyId)
        .get();
    return {
      for (var doc in snapshot.docs) doc.id: UserModel.fromFirestore(doc)
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
          child: FutureBuilder<Map<String, UserModel>>(
            future: _usersMapFuture,
            builder: (context, usersSnapshot) {
              if (usersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (usersSnapshot.hasError) {
                return Center(
                    child: Text(
                        "Erro ao carregar usuários: ${usersSnapshot.error}"));
              }

              final usersMap = usersSnapshot.data ?? {};

              return StreamBuilder<QuerySnapshot>(
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
                          'Clique no botão "+" para adicionar o primeiro aluno.',
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
                    padding: const EdgeInsets.fromLTRB(8, 8.0, 8, 80.0),
                    itemCount: filteredAlunos.length,
                    itemBuilder: (context, index) {
                      final aluno = filteredAlunos[index];
                      final userModel = usersMap[aluno.userId];
                      final imageUrl = userModel?.profileImagePath;

                      return UserCard(
                        user: aluno,
                        academyId: widget.academyId,
                        currentUser: widget.teacher,
                        profileImageUrl: imageUrl,
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

// O restante do arquivo (Checkin, Sorteio, etc.) permanece o mesmo...
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
                const Icon(Icons.checklist_rtl_rounded, color: successColor),
            title: const Text("Fazer Chamada (Presencial)"),
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
                const Icon(Icons.fact_check_outlined, color: primaryAccent),
            title: const Text("Aprovar Check-ins"),
            subtitle: const Text("Ver e aprovar solicitações de hoje"),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ApproveCheckinsPage(academyId: academyId),
              ));
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
            leading: const Icon(Icons.history_rounded, color: textHint),
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
      ],
    );
  }
}

class ApproveCheckinsPage extends StatefulWidget {
  final String academyId;
  const ApproveCheckinsPage({super.key, required this.academyId});

  @override
  State<ApproveCheckinsPage> createState() => _ApproveCheckinsPageState();
}

class _ApproveCheckinsPageState extends State<ApproveCheckinsPage> {
  Stream<QuerySnapshot> _getPendingCheckinsStream() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins')
        .where('date', isEqualTo: Timestamp.fromDate(today))
        .where('status',
            isEqualTo: checkinStatusToString(CheckinStatus.pending))
        .snapshots();
  }

  Future<void> _approveCheckin(String checkinId) async {
    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('checkins')
          .doc(checkinId)
          .update({'status': checkinStatusToString(CheckinStatus.approved)});

      if (mounted) {
        showBjjSnackBar(context, 'Check-in aprovado!', type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao aprovar check-in.', type: 'error');
      }
    }
  }

  Future<void> _denyCheckin(String checkinId) async {
    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('checkins')
          .doc(checkinId)
          .delete();

      if (mounted) {
        showBjjSnackBar(context, 'Solicitação recusada.', type: 'info');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao recusar solicitação.', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Aprovar Check-ins de Hoje'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getPendingCheckinsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                debugPrint(
                    "Erro ao carregar check-ins pendentes: ${snapshot.error}");
                return const Center(
                    child: Text('Erro ao carregar solicitações.'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhuma Solicitação',
                  message: 'Não há check-ins pendentes para hoje.',
                );
              }

              final requests = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: requests.length,
                itemBuilder: (context, index) {
                  final request = requests[index];
                  final data = request.data() as Map<String, dynamic>;
                  final studentName =
                      data['studentName'] ?? 'Aluno desconhecido';
                  final className =
                      data['className'] ?? 'Aula não especificada';

                  return Card(
                    child: ListTile(
                      title: Text(studentName),
                      subtitle: Text(className),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: errorColor),
                            tooltip: 'Recusar',
                            onPressed: () => _denyCheckin(request.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_rounded,
                                color: successColor),
                            tooltip: 'Aprovar',
                            onPressed: () => _approveCheckin(request.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
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
  List<CheckinEntry> _checkedInEntries = [];
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
          .where('status',
              isEqualTo: checkinStatusToString(CheckinStatus.approved))
          .get();

      final entries = snapshot.docs
          .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
          .toList();

      entries.sort((a, b) {
        final nameA = _participantsMap[a.studentId]?.nome ?? '';
        final nameB = _participantsMap[b.studentId]?.nome ?? '';
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _checkedInEntries = entries;
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

  Future<void> _deleteCheckin(String checkinId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Check-in?'),
        content: Text(
            'Tem certeza que deseja remover a presença de $studentName para este dia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.academyId)
            .collection('checkins')
            .doc(checkinId)
            .delete();
        if (mounted) {
          showBjjSnackBar(context, 'Check-in removido.', type: 'success');
          _fetchCheckinsForDay(_selectedDay);
        }
      } catch (e) {
        if (mounted) {
          showBjjSnackBar(context, 'Erro ao remover check-in.', type: 'error');
        }
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
                  "Presentes na data selecionada (${_checkedInEntries.length})",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _checkedInEntries.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.group_off_rounded,
                            title: "Nenhum check-in",
                            message: "Ninguém treinou neste dia.",
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: _checkedInEntries.length,
                            itemBuilder: (context, index) {
                              final entry = _checkedInEntries[index];
                              final student = _participantsMap[entry.studentId];
                              if (student == null) {
                                return const SizedBox.shrink();
                              }

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.check_circle,
                                      color: successColor),
                                  title: Text(student.nome),
                                  subtitle: Text(student.faixa),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: errorColor),
                                    tooltip: 'Remover check-in',
                                    onPressed: () =>
                                        _deleteCheckin(entry.id, student.nome),
                                  ),
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

      final existingCheckinsMap = {
        for (var doc in querySnapshot.docs) doc['studentId'] as String: doc
      };

      final batch = FirebaseFirestore.instance.batch();
      int confirmedCount = 0;

      for (final studentId in _selectedStudentIds) {
        final existingDoc = existingCheckinsMap[studentId];
        final studentName = widget.todosParticipantesDaAcademia
            .firstWhere((p) => p.id == studentId)
            .nome;

        if (existingDoc != null) {
          final data = existingDoc.data() as Map<String, dynamic>?;
          if (data != null &&
              data['status'] == checkinStatusToString(CheckinStatus.pending)) {
            batch.update(existingDoc.reference, {
              'status': checkinStatusToString(CheckinStatus.approved),
              'studentName': studentName,
            });
            confirmedCount++;
          }
        } else {
          final newDocRef = checkinRef.doc();
          batch.set(newDocRef, {
            'studentId': studentId,
            'studentName': studentName,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
            'status': checkinStatusToString(CheckinStatus.approved),
          });
          confirmedCount++;
        }
      }

      if (confirmedCount > 0) {
        await batch.commit();
      }
      if (mounted) {
        Navigator.of(context).pop(confirmedCount);
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

      final existingCheckinsMap = {
        for (var doc in querySnapshot.docs) doc['studentId'] as String: doc
      };

      final batch = FirebaseFirestore.instance.batch();
      int confirmedCount = 0;

      for (final studentId in _selectedStudentIds) {
        final existingDoc = existingCheckinsMap[studentId];
        final studentName = widget.todosParticipantesDaAcademia
            .firstWhere((p) => p.id == studentId)
            .nome;

        if (existingDoc != null) {
          final data = existingDoc.data() as Map<String, dynamic>?;
          if (data != null &&
              data['status'] == checkinStatusToString(CheckinStatus.pending)) {
            batch.update(existingDoc.reference,
                {'status': checkinStatusToString(CheckinStatus.approved)});
            confirmedCount++;
          }
        } else {
          final newDocRef = checkinRef.doc();
          batch.set(newDocRef, {
            'studentId': studentId,
            'studentName': studentName,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
            'status': checkinStatusToString(CheckinStatus.approved),
          });
          confirmedCount++;
        }
      }

      if (confirmedCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        Navigator.of(context).pop(confirmedCount);
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
          .where('status',
              isEqualTo: checkinStatusToString(CheckinStatus.approved))
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
  final Function(List<List<Map<String, String>>>, String, List<Aluno>)
      onIniciarSparring;
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
  List<List<Map<String, String>>> _rodadasGeradas = [];
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
      tempAlunos.add(Aluno.novo(
          id: 'descansa-id', nome: "DESCANSA", faixa: "Branca", peso: 0));
    }
    int numRodadas = tempAlunos.length - 1;
    if (numRodadas <= 0) numRodadas = 1;

    List<List<Map<String, String>>> rodadas = [];
    for (int i = 0; i < numRodadas; i++) {
      List<Map<String, String>> rodadaAtual = [];
      for (int j = 0; j < tempAlunos.length / 2; j++) {
        final aluno1 = tempAlunos[j];
        final aluno2 = tempAlunos[tempAlunos.length - 1 - j];
        rodadaAtual.add({'p1': aluno1.id, 'p2': aluno2.id});
      }
      rodadas.add(rodadaAtual);
      tempAlunos.insert(1, tempAlunos.removeLast());
    }
    setState(() => _rodadasGeradas = rodadas);
  }

  void _gerarRodadasHierarquicas() {
    List<Aluno> tempAlunos = List.from(_alunosParticipantes);
    if (tempAlunos.length % 2 != 0) {
      tempAlunos.add(Aluno.novo(
          id: 'descansa-id', nome: "DESCANSA", faixa: "Branca", peso: 0));
    }

    int numRodadas = tempAlunos.length - 1;
    if (numRodadas <= 0) numRodadas = 1;

    List<List<Luta>> rodadasDeLutas = [];

    // 1. Gera o cronograma completo usando Round Robin
    for (int i = 0; i < numRodadas; i++) {
      List<Luta> rodadaAtual = [];
      for (int j = 0; j < tempAlunos.length / 2; j++) {
        final aluno1 = tempAlunos[j];
        final aluno2 = tempAlunos[tempAlunos.length - 1 - j];
        rodadaAtual.add(Luta(aluno1, aluno2, _calcularCusto(aluno1, aluno2)));
      }
      rodadasDeLutas.add(rodadaAtual);
      // Gira os participantes para a próxima rodada
      tempAlunos.insert(1, tempAlunos.removeLast());
    }

    // 2. Ordena as rodadas com base no custo médio
    rodadasDeLutas.sort((a, b) {
      final lutasReaisA = a.where((l) => l.custo != double.infinity);
      final lutasReaisB = b.where((l) => l.custo != double.infinity);

      if (lutasReaisA.isEmpty) return 1;
      if (lutasReaisB.isEmpty) return -1;

      final custoMedioA =
          lutasReaisA.map((l) => l.custo).reduce((v, e) => v + e) /
              lutasReaisA.length;
      final custoMedioB =
          lutasReaisB.map((l) => l.custo).reduce((v, e) => v + e) /
              lutasReaisB.length;

      return custoMedioA.compareTo(custoMedioB);
    });

    // 3. Converte para o formato de mapa de IDs
    final rodadasFinais = rodadasDeLutas.map((rodada) {
      return rodada.map((luta) {
        return {'p1': luta.aluno1.id, 'p2': luta.aluno2.id};
      }).toList();
    }).toList();

    setState(() => _rodadasGeradas = rodadasFinais);
  }

  double _calcularCusto(Aluno a1, Aluno a2) {
    if (a1.id == 'descansa-id' || a2.id == 'descansa-id') {
      return double.infinity;
    }

    if (_tipoGeracao == 'Por Peso') {
      return (a1.peso - a2.peso).abs();
    } else {
      // 'Por Faixa'
      int indexFaixa1 = _getBeltIndex(a1.faixa);
      int indexFaixa2 = _getBeltIndex(a2.faixa);
      double diffPeso = (a1.peso - a2.peso).abs();
      return ((indexFaixa1 - indexFaixa2).abs() * 1000) + diffPeso;
    }
  }

  int _getBeltIndex(String faixa) {
    const List<String> ordemFaixas = [
      'Branca',
      'Cinza/Branca',
      'Cinza',
      'Cinza/Preta',
      'Amarela/Branca',
      'Amarela',
      'Amarela/Preta',
      'Laranja/Branca',
      'Laranja',
      'Laranja/Preta',
      'Verde/Branca',
      'Verde',
      'Verde/Preta',
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
    final participantsMap = {
      for (var p in widget.todosParticipantesDaAcademia) p.id: p
    };
    participantsMap['descansa-id'] =
        Aluno.novo(id: 'descansa-id', nome: 'DESCANSA', faixa: '', peso: 0);

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
                        children: rodada.map((lutaMap) {
                          final p1 = participantsMap[lutaMap['p1']];
                          final p2 = participantsMap[lutaMap['p2']];
                          String lutaText;
                          if (p1?.nome == 'DESCANSA') {
                            lutaText = '${p2?.nome ?? ''} (descansa)';
                          } else if (p2?.nome == 'DESCANSA') {
                            lutaText = '${p1?.nome ?? ''} (descansa)';
                          } else {
                            lutaText = '${p1?.nome ?? ''} x ${p2?.nome ?? ''}';
                          }
                          return ListTile(title: Text(lutaText));
                        }).toList(),
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
  late Map<String, Aluno> _participantsMap;

  int get _currentRoundIndex => _sparringState['currentRoundIndex'] ?? 0;

  List<List<Map<String, String>>> get _allRounds {
    final dynamic roundsData = _sparringState['allRounds'];
    if (roundsData is List) {
      return roundsData.map<List<Map<String, String>>>((dynamic roundData) {
        if (roundData is Map && roundData['fights'] is List) {
          final fightsList = roundData['fights'] as List;
          return fightsList.map<Map<String, String>>((dynamic fightData) {
            return Map<String, String>.from(fightData as Map);
          }).toList();
        }
        return [];
      }).toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _participantsMap = {for (var p in widget.todosAlunos) p.id: p};
    _participantsMap['descansa-id'] = Aluno.novo(
        id: 'descansa-id', nome: 'DESCANSA', faixa: 'Branca', peso: 0);
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
        setState(() {
          _isLoading = false;
          _sparringState = {};
        });
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
      return const EmptyStateWidget(
        icon: Icons.pause_circle_outline_rounded,
        title: 'Nenhum treino em andamento.',
        message: 'Volte para a tela de sorteio para iniciar um treino.',
      );
    }

    final allRounds = _allRounds;
    List<Map<String, String>> currentRoundFights = [];
    String roundTitle = '';
    bool isLastRound = _currentRoundIndex >= allRounds.length;
    final generationType = _sparringState['generationType'] as String?;

    if (allRounds.isNotEmpty) {
      if (_currentRoundIndex > allRounds.length) {
        currentRoundFights = allRounds.last;
        roundTitle =
            'FIM - Última Rodada (${allRounds.length}/${allRounds.length})';
      } else {
        currentRoundFights = allRounds[_currentRoundIndex - 1];
        roundTitle = 'Rodada $_currentRoundIndex / ${allRounds.length}';
      }
    }

    currentRoundFights.sort((a, b) {
      final aIsResting = _participantsMap[a['p1']]?.nome == 'DESCANSA' ||
          _participantsMap[a['p2']]?.nome == 'DESCANSA';
      final bIsResting = _participantsMap[b['p1']]?.nome == 'DESCANSA' ||
          _participantsMap[b['p2']]?.nome == 'DESCANSA';

      if (aIsResting && !bIsResting) {
        return -1;
      }
      if (!aIsResting && bIsResting) {
        return 1;
      }
      return 0;
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Text(roundTitle, style: Theme.of(context).textTheme.titleLarge),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: currentRoundFights.length,
            itemBuilder: (context, index) {
              final matchData = currentRoundFights[index];
              final p1 = _participantsMap[matchData['p1']];
              final p2 = _participantsMap[matchData['p2']];
              bool isResting = p1?.nome == 'DESCANSA' || p2?.nome == 'DESCANSA';

              if (p1 == null || p2 == null) {
                return const Card(
                    child: ListTile(
                        title: Text('Erro: Participante não encontrado')));
              }

              if (isResting) {
                final restingPlayer = (p1.nome == 'DESCANSA') ? p2 : p1;
                return Card(
                  color: darkSurface.withOpacity(0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('${restingPlayer.nome} (descansa)',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: textHint)),
                    ),
                  ),
                );
              }

              return Card(
                color: darkSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFighterInfo(p1, generationType),
                      const Text('x', style: TextStyle(fontSize: 20)),
                      _buildFighterInfo(p2, generationType),
                    ],
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
                style: ElevatedButton.styleFrom(backgroundColor: errorColor),
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
    );
  }

  Widget _buildFighterInfo(Aluno? aluno, String? generationType) {
    if (aluno == null) return const SizedBox.shrink();

    String subtitle = '';
    if (generationType == 'Por Faixa') {
      subtitle = aluno.faixa;
    } else if (generationType == 'Por Peso') {
      subtitle = '${aluno.peso} kg';
    }

    return Expanded(
      child: Column(
        children: [
          Text(
            aluno.nome,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: textHint),
                textAlign: TextAlign.center,
              ),
            ),
        ],
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
