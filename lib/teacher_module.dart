// lib/teacher_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, library_private_types_in_public_api, unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
import 'training_log_module.dart';
import 'sparring_service.dart';

// --- FUNÇÀO DE LOG DE AUDITORIA ---
/// Função auxiliar para criar uma entrada no log de auditoria.
Future<void> _createAuditLog({
  required String academyId,
  required UserModel actor,
  required String actionType,
  required String description,
  String? targetUid,
  String? targetName,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(academyId)
        .collection('audit_log')
        .add({
      'actorUid': actor.uid,
      'actorName': actor.name,
      'actionType': actionType,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'targetUid': targetUid,
      'targetName': targetName,
    });
  } catch (e) {
    debugPrint("Erro ao criar log de auditoria: $e");
  }
}

// --- FUNÇÀO AUXILIAR PARA ORDENAÇÀO DE FAIXAS ---
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
  final index =
      ordemFaixas.indexWhere((f) => f.toLowerCase() == faixa.toLowerCase());
  return index == -1 ? 99 : index; // Retorna um número alto se não encontrar
}

// --- TELAS DO PROFESSOR ---
class TeacherHomePage extends StatefulWidget {
  final UserModel user;
  final bool isImpersonating;
  final SubscriptionPlan? currentPlan; // NOVO PARÀ‚METRO

  const TeacherHomePage({
    super.key,
    required this.user,
    this.isImpersonating = false,
    this.currentPlan, // NOVO PARÀ‚METRO
  });

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  int _paginaAtual = 0;
  bool _isLoading = true;

  late final NavigationService _navService;
  List<AppModule> _allPageModules = [];
  List<AppModule> _drawerModules = [];
  List<AppModule> _visibleModules = [];
  List<Widget> _telas = [];

  List<UserModel> _teachers = [];
  List<Aluno> _students = [];

  bool _isSparringMode = false;
  StreamSubscription? _sparringStateSubscription;
  StreamSubscription? _settingsSubscription;

  // Chave Global para acessar o estado da Dashboard
  final GlobalKey<_TeacherDashboardPageState> _dashboardKey =
      GlobalKey<_TeacherDashboardPageState>();

  @override
  void initState() {
    super.initState();
    // --- ALTERAÇÀO: Passa o plano para o NavigationService ---
    _navService = NavigationService(
      userId: widget.user.uid,
      userRole: widget.user.role,
      currentPlan: widget.currentPlan, // Passando o plano
    );
    _loadInitialData();
    _listenToSparringState();
  }

  @override
  void didUpdateWidget(covariant TeacherHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name ||
        oldWidget.user.profileImagePath != widget.user.profileImagePath) {
      setState(() {});
      if (!_isLoading) _rebuildScreens();
    }
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    _settingsSubscription?.cancel();
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
        if (mounted) {
          _configureNavigation(settingsDoc);
        }
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

      await _createAuditLog(
        academyId: widget.user.academyId,
        actor: widget.user,
        actionType: 'START_SPARRING',
        description:
            '${widget.user.name} iniciou um treino de sparring com ${participants.length} participantes.',
      );
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

      await _createAuditLog(
        academyId: widget.user.academyId,
        actor: widget.user,
        actionType: 'BULK_CHECKIN',
        description:
            '${widget.user.name} fez check-in para $newCheckins alunos.',
      );

      if (mounted) {
        showBjjSnackBar(context, '$newCheckins presenças confirmadas!',
            type: 'success');
      }
    }
  }

  void _rebuildScreens() {
    if (_allPageModules.isEmpty) return;
    setState(() {
      _telas =
          _allPageModules.map((module) => _buildPageForModule(module)).toList();
    });
  }

  Widget _buildPageForModule(AppModule module) {
    switch (module.id) {
      case 'teacher_dashboard':
        return TeacherDashboardPage(
          key: _dashboardKey,
          user: widget.user,
          isSparringMode: _isSparringMode,
          onNavigateToSparring: () {
            _navigateToModuleId('teacher_sparring');
          },
          todosParticipantesDaAcademia: _students,
        );
      case 'teacher_sparring':
        if (_isSparringMode) {
          return SparringTeacherPage(
            academyId: widget.user.academyId,
            todosAlunos: _students,
          );
        }
        return SorteioTeacherPage(
          user: widget.user,
          academyId: widget.user.academyId,
          todosParticipantesDaAcademia: _students,
          isSparringMode: _isSparringMode,
          onIniciarSparring: _iniciarSparring,
          onCheckinAlunos: _checkinAlunos,
        );
      default:
        return module.pageBuilder!(
            widget.user, _teachers, _students, widget.currentPlan);
    }
  }

  // --- CORREÇÀO APLICADA AQUI ---
  void _configureNavigation(DocumentSnapshot? settingsDoc) {
    Map<String, dynamic> settings;
    if (settingsDoc != null && settingsDoc.exists) {
      settings = settingsDoc.data() as Map<String, dynamic>;
    } else {
      settings = _navService.getDefaultTabSettings();
    }

    _drawerModules = _navService.getDrawerModulesForCurrentUser();
    _allPageModules = _navService.getFlatPageModulesForCurrentUser();

    final List<String> visibleIds =
        List<String>.from(settings['visible'] ?? []);

    final List<String> savedOrder = List<String>.from(settings['order'] ?? []);

    if (mounted) {
      setState(() {
        // Constrói a lista de telas usando o método interno que passa os callbacks corretos
        _telas = _allPageModules
            .map((module) => _buildPageForModule(module))
            .toList();

        _visibleModules =
            _allPageModules.where((m) => visibleIds.contains(m.id)).toList();

        _visibleModules.sort((a, b) {
          final indexA = savedOrder.indexOf(a.id);
          final indexB = savedOrder.indexOf(b.id);
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });

        int dashboardIndex =
            _allPageModules.indexWhere((m) => m.id == 'teacher_dashboard');
        _paginaAtual = (dashboardIndex != -1) ? dashboardIndex : 0;

        _isLoading = false;
      });
    }
  }

  void _navigateToModuleId(String moduleId) {
    final newIndex = _allPageModules.indexWhere((m) => m.id == moduleId);
    if (newIndex != -1) {
      if (moduleId == 'teacher_dashboard') {
        _dashboardKey.currentState?.refreshData();
      }
      setState(() {
        _paginaAtual = newIndex;
      });
    }
  }

  void _onItemTapped(int index) {
    final selectedModuleId = _visibleModules[index].id;
    _navigateToModuleId(selectedModuleId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppBackground(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_allPageModules.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(widget.user.name)),
        drawer: AppDrawer(
          user: widget.user,
          drawerModules: _drawerModules,
          allPageModules: _allPageModules,
          onSelectItem: _navigateToModuleId,
        ),
        body: AppBackground(
          child: SafeArea(
            child: EmptyStateWidget(
              icon: Icons.lock_outline,
              title: "Nenhum Módulo Disponível",
              message:
                  "Seu plano de assinatura atual pode não incluir módulos visíveis ou ocorreu um erro de configuração.",
            ),
          ),
        ),
      );
    }

    final currentModule = _allPageModules[_paginaAtual];
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
        drawerModules: _drawerModules,
        allPageModules: _allPageModules,
        onSelectItem: _navigateToModuleId,
        currentPlan: widget.currentPlan,
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
      bottomNavigationBar: _visibleModules.length >= 2
          ? BottomNavigationBar(
              currentIndex: currentVisibleIndex != -1 ? currentVisibleIndex : 0,
              onTap: _onItemTapped,
              items: _visibleModules.map((module) {
                return BottomNavigationBarItem(
                  icon: Icon(module.icon),
                  label: module.title,
                );
              }).toList(),
            )
          : null,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_allPageModules.isEmpty) return null;
    final currentModuleId = _allPageModules[_paginaAtual].id;
    if (currentModuleId == 'teacher_students') {
      return FloatingActionButton(
        heroTag: 'teacher_fab_${widget.user.uid}',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AdicionarAlunoDialog(
                currentUser: widget.user,
                academyId: widget.user.academyId,
                onAlunoAdicionado: (novoAluno, newImageFile) async {
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

                    await _createAuditLog(
                      academyId: widget.user.academyId,
                      actor: widget.user,
                      actionType: 'CREATE_STUDENT',
                      description:
                          '${widget.user.name} adicionou o aluno ${novoAluno.nome}.',
                      targetName: novoAluno.nome,
                    );

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

  String? _beltFilter;
  String? _unitFilter;
  String _sortOption = 'nome';
  final List<String> _beltOptions = [
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

  // --- INÀCIO DA OTIMIZAÇÀO ---
  Stream<QuerySnapshot> _buildStudentQuery() {
    Query query = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('students');

    if (_beltFilter != null) {
      query = query.where('faixa', isEqualTo: _beltFilter);
    }
    if (_unitFilter != null) {
      query = query.where('unitId', isEqualTo: _unitFilter);
    }

    if (_sortOption == 'nome') {
      query = query.orderBy('nome');
    } else {
      query = query.orderBy('nome');
    }

    return query.snapshots();
  }
  // --- FIM DA OTIMIZAÇÀO ---

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

  Future<void> _showUnitFilterDialog() async {
    final unitsSnapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('units')
        .orderBy('name')
        .get();
    final units = unitsSnapshot.docs;

    final selectedUnitId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar por Unidade'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: units.length,
            itemBuilder: (context, index) {
              final unit = units[index];
              return ListTile(
                title: Text(unit['name']),
                onTap: () => Navigator.of(context).pop(unit.id),
              );
            },
          ),
        ),
      ),
    );

    if (selectedUnitId != null) {
      setState(() => _unitFilter = selectedUnitId);
    }
  }

  Future<void> _showBeltFilterDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filtrar por Faixa'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _beltOptions.length,
              itemBuilder: (context, index) {
                final belt = _beltOptions[index];
                return ListTile(
                  title: Text(belt),
                  onTap: () {
                    Navigator.of(context).pop(belt);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      setState(() => _beltFilter = selected);
    }
  }

  Widget _buildFilterSortMenu() {
    return PopupMenuButton<String>(
      icon: Icon(Icons.filter_list,
          color: _beltFilter != null || _unitFilter != null
              ? primaryAccent
              : null),
      tooltip: 'Filtrar e Ordenar',
      onSelected: (value) {
        if (value.startsWith('sort_')) {
          setState(() => _sortOption = value.substring(5));
        } else if (value == 'filter_belt') {
          _showBeltFilterDialog();
        } else if (value == 'filter_unit') {
          _showUnitFilterDialog();
        } else if (value == 'clear_filter') {
          setState(() {
            _beltFilter = null;
            _unitFilter = null;
          });
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'sort_nome',
          child: Text('Ordenar por: Nome'),
        ),
        const PopupMenuItem<String>(
          value: 'sort_faixa',
          child: Text('Ordenar por: Faixa'),
        ),
        const PopupMenuItem<String>(
          value: 'sort_peso',
          child: Text('Ordenar por: Peso'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'filter_unit',
          child: Text('Filtrar por Unidade...'),
        ),
        PopupMenuItem<String>(
          value: 'filter_belt',
          child: Text(_beltFilter == null
              ? 'Filtrar por Faixa...'
              : 'Filtrar: $_beltFilter'),
        ),
        if (_beltFilter != null || _unitFilter != null)
          const PopupMenuItem<String>(
            value: 'clear_filter',
            child: Text('Limpar Filtros'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
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
              _buildFilterSortMenu(),
            ],
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
                // --- INÀCIO DA OTIMIZAÇÀO ---
                stream: _buildStudentQuery(),
                // --- FIM DA OTIMIZAÇÀO ---
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

                  List<Aluno> processedAlunos = List.from(allAlunos);

                  if (_searchQuery.isNotEmpty) {
                    processedAlunos = processedAlunos.where((aluno) {
                      return aluno.nome
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                    }).toList();
                  }

                  if (_sortOption != 'nome') {
                    processedAlunos.sort((a, b) {
                      switch (_sortOption) {
                        case 'faixa':
                          return _getBeltIndex(a.faixa)
                              .compareTo(_getBeltIndex(b.faixa));
                        case 'peso':
                          return a.peso.compareTo(b.peso);
                        default:
                          return a.nome
                              .toLowerCase()
                              .compareTo(b.nome.toLowerCase());
                      }
                    });
                  }

                  if (processedAlunos.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.person_search,
                      title: "Nenhum Aluno Encontrado",
                      message:
                          "Nenhum aluno corresponde aos filtros selecionados.",
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 8.0, 8, 80.0),
                    itemCount: processedAlunos.length,
                    itemBuilder: (context, index) {
                      final aluno = processedAlunos[index];
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

class TeacherDashboardPage extends StatefulWidget {
  final UserModel user;
  final bool isSparringMode;
  final VoidCallback onNavigateToSparring;
  final List<Aluno> todosParticipantesDaAcademia;

  const TeacherDashboardPage({
    super.key,
    required this.user,
    required this.isSparringMode,
    required this.onNavigateToSparring,
    required this.todosParticipantesDaAcademia,
  });

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  List<DocumentSnapshot> _units = [];
  bool _isLoadingUnits = true;
  List<TrainingClass> _todayClasses = [];
  bool _isLoadingTodayClasses = true;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  void refreshData() {
    if (mounted) {
      _fetchUnits();
      _fetchTodayClasses();
    }
  }

  Future<void> _fetchUnits() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('units')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _units = snapshot.docs;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnits = false);
      }
    }
  }

  Future<void> _fetchTodayClasses() async {
    if (!mounted) return;
    setState(() => _isLoadingTodayClasses = true);
    try {
      final now = DateTime.now();
      String dayOfWeek = DateFormat('EEEE', 'pt_BR').format(now);
      if (dayOfWeek.isNotEmpty) {
        dayOfWeek = dayOfWeek[0].toUpperCase() + dayOfWeek.substring(1);
      }

      final scheduleSnapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('schedule')
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .orderBy('startTime')
          .get();

      final classes = scheduleSnapshot.docs
          .map((doc) => TrainingClass.fromFirestore(doc))
          .where((c) => c.teacherId == widget.user.uid)
          .toList();

      if (mounted) {
        setState(() {
          _todayClasses = classes;
          _isLoadingTodayClasses = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTodayClasses = false);
      }
      debugPrint("Erro ao buscar as aulas de hoje: $e");
    }
  }

  // --- CORREÇÀO: Lógica de seleção movida para cá ---
  Future<void> _selectClassAndStartCheckin() async {
    final TrainingClass? selectedClass = await showDialog<TrainingClass>(
      context: context,
      builder: (_) => _SelectClassDialog(
        academyId: widget.user.academyId,
        selectedDate: DateTime.now(),
      ),
    );

    if (selectedClass != null && mounted) {
      final checkedInCount = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => BulkCheckinPage(
            academyId: widget.user.academyId,
            todosParticipantesDaAcademia: widget.todosParticipantesDaAcademia,
            user: widget.user,
            units: _units,
            selectedClass: selectedClass,
          ),
        ),
      );

      if (checkedInCount != null && checkedInCount > 0 && mounted) {
        showBjjSnackBar(context, '$checkedInCount presenças confirmadas!',
            type: 'success');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        UserProfileHeader(user: widget.user),
        TodaysBirthdaysCard(academyId: widget.user.academyId),
        if (widget.isSparringMode)
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
                onTap: widget.onNavigateToSparring,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _TodayClassesCard(
                  isLoading: _isLoadingTodayClasses,
                  todayClasses: _todayClasses,
                ),
                const SizedBox(height: 12),
                _DashboardActionCard(
                  icon: Icons.checklist_rtl_rounded,
                  label: 'Fazer Chamada',
                  color: successColor,
                  onTap: _isLoadingUnits ? null : _selectClassAndStartCheckin,
                ),
                _DashboardActionCard(
                  icon: Icons.fact_check_outlined,
                  label: 'Aprovar Check-ins',
                  color: primaryAccent,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ApproveCheckinsPage(academyId: widget.user.academyId),
                    ));
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
      ],
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardActionCard({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, size: 28, color: color),
        title: Text(label, style: Theme.of(context).textTheme.titleSmall),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: textHint),
        dense: true,
      ),
    );
  }
}

class _TodayClassesCard extends StatelessWidget {
  final bool isLoading;
  final List<TrainingClass> todayClasses;

  const _TodayClassesCard({
    required this.isLoading,
    required this.todayClasses,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (todayClasses.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: const ListTile(
          leading: Icon(Icons.check_circle_outline, color: successColor),
          title: Text("Você não tem aulas hoje!"),
          subtitle: Text("Bom descanso."),
          dense: true,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "PRÓXIMAS AULAS",
              style: TextStyle(
                color: textHint,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...todayClasses.map((aula) => _ClassInfoRow(trainingClass: aula)),
          ],
        ),
      ),
    );
  }
}

class _ClassInfoRow extends StatelessWidget {
  final TrainingClass trainingClass;
  const _ClassInfoRow({required this.trainingClass});

  @override
  Widget build(BuildContext context) {
    final isGiClass = trainingClass.modality == TrainingModality.gi;
    final modalityLabel =
        modalityToString(trainingClass.modality).replaceAll('-', ' ');
    final modalityColor = isGiClass ? Colors.blue.shade300 : errorColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 60, // Largura fixa para o container da modalidade
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: modalityColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                modalityLabel,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              '${trainingClass.startTime} - ${trainingClass.endTime}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${trainingClass.unitName ?? ''} - ${trainingClass.audience ?? ''}',
              style: const TextStyle(color: textSecondary, fontSize: 14),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class CheckinTeacherPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;
  final UserModel user;

  const CheckinTeacherPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
    required this.user,
  });

  @override
  State<CheckinTeacherPage> createState() => _CheckinTeacherPageState();
}

class _CheckinTeacherPageState extends State<CheckinTeacherPage> {
  List<DocumentSnapshot> _units = [];
  bool _isLoadingUnits = true;

  @override
  void initState() {
    super.initState();
    _fetchUnits();
  }

  Future<void> _fetchUnits() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('units')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          _units = snapshot.docs;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnits = false);
        showBjjSnackBar(context, 'Erro ao carregar unidades.', type: 'error');
      }
    }
  }

  // --- ALTERAÇÀO AQUI: LÀ“GICA DE SELEÇÀO DE AULA ---
  Future<void> _selectClassAndStartCheckin() async {
    final TrainingClass? selectedClass = await showDialog<TrainingClass>(
      context: context,
      builder: (_) => _SelectClassDialog(
        academyId: widget.academyId,
        selectedDate: DateTime.now(),
      ),
    );

    if (selectedClass != null && mounted) {
      final checkedInCount = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => BulkCheckinPage(
            academyId: widget.academyId,
            todosParticipantesDaAcademia: widget.todosParticipantesDaAcademia,
            user: widget.user,
            units: _units,
            selectedClass: selectedClass,
          ),
        ),
      );

      if (checkedInCount != null && checkedInCount > 0 && mounted) {
        showBjjSnackBar(context, '$checkedInCount presenças confirmadas!',
            type: 'success');
      }
    }
  }

  // --- ALTERAÇÀO AQUI: LÀ“GICA DE SELEÇÀO DE DATA E AULA ---
  Future<void> _selectDateAndClassForRetroactiveCheckin() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate == null) return;

    final TrainingClass? selectedClass = await showDialog<TrainingClass>(
      context: context,
      builder: (_) => _SelectClassDialog(
        academyId: widget.academyId,
        selectedDate: pickedDate,
      ),
    );

    if (selectedClass != null && mounted) {
      final checkedInCount = await Navigator.of(context).push<int>(
        MaterialPageRoute(
          builder: (_) => RetroactiveCheckinPage(
            academyId: widget.academyId,
            todosParticipantesDaAcademia: widget.todosParticipantesDaAcademia,
            user: widget.user,
            selectedClass: selectedClass,
            selectedDate: pickedDate,
          ),
        ),
      );

      if (checkedInCount != null && mounted) {
        if (checkedInCount > 0) {
          showBjjSnackBar(
              context, '$checkedInCount presenças retroativas confirmadas!',
              type: 'success');
        } else {
          showBjjSnackBar(context, 'Nenhuma presença nova foi registrada.',
              type: 'info');
        }
      }
    }
  }

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
            trailing: _isLoadingUnits
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _isLoadingUnits ? null : _selectClassAndStartCheckin,
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
                builder: (_) =>
                    ApproveCheckinsPage(academyId: widget.academyId),
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
            onTap: _selectDateAndClassForRetroactiveCheckin,
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
                  academyId: widget.academyId,
                  allParticipants: widget.todosParticipantesDaAcademia,
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
              if (widget.todosParticipantesDaAcademia.isEmpty) {
                showBjjSnackBar(context, 'Cadastre participantes primeiro.',
                    type: 'info');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RankingTeacherPage(academyId: widget.academyId),
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

// --- PÀGINA DE HISTÀ“RICO DE CHECK-IN (COM ALTERAÇÕES) ---
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

      // Ordena primeiro pelo nome do aluno, depois pelo horário do check-in
      entries.sort((a, b) {
        final nameA = _participantsMap[a.studentId]?.nome ?? '';
        final nameB = _participantsMap[b.studentId]?.nome ?? '';
        final dateA = a.createdAt.toDate();
        final dateB = b.createdAt.toDate();

        int nameCompare = nameA.compareTo(nameB);
        if (nameCompare != 0) {
          return nameCompare;
        }
        return dateA.compareTo(dateB);
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

                              String subtitleText = student.faixa;
                              final checkinTime = entry.createdAt.toDate();
                              if (entry.className != null &&
                                  entry.className!.isNotEmpty) {
                                subtitleText = entry.className!;
                              } else {
                                subtitleText =
                                    'Check-in À s ${DateFormat.Hm().format(checkinTime)}';
                              }

                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.check_circle,
                                      color: successColor),
                                  title: Text(student.nome),
                                  subtitle: Text(subtitleText),
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
  final UserModel user;
  final List<DocumentSnapshot> units;
  final TrainingClass selectedClass;

  const BulkCheckinPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
    required this.user,
    required this.units,
    required this.selectedClass,
  });

  @override
  State<BulkCheckinPage> createState() => _BulkCheckinPageState();
}

class _BulkCheckinPageState extends State<BulkCheckinPage> {
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];
  String? _selectedUnitId;

  @override
  void initState() {
    super.initState();
    final lastUnitId = widget.user.lastSelectedUnitId;
    if (lastUnitId != null && widget.units.any((u) => u.id == lastUnitId)) {
      _selectedUnitId = lastUnitId;
    } else {
      _selectedUnitId = widget.user.unitId ?? 'all';
    }
    _filterParticipants();
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterParticipants);
    _searchController.dispose();
    super.dispose();
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

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.todosParticipantesDaAcademia.where((aluno) {
        final nameMatches = aluno.nome.toLowerCase().contains(query);
        final unitMatches =
            _selectedUnitId == 'all' || aluno.unitId == _selectedUnitId;
        return nameMatches && unitMatches;
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
              'classId': widget.selectedClass.id,
              'className':
                  '${widget.selectedClass.level} (${widget.selectedClass.startTime})',
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
            'classId': widget.selectedClass.id,
            'className':
                '${widget.selectedClass.level} (${widget.selectedClass.startTime})',
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
        title: Text(
            "Chamada - ${widget.selectedClass.level} (${widget.selectedClass.startTime})"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedUnitId,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text("Todas as Unidades"),
                        ),
                        ...widget.units.map((unit) {
                          return DropdownMenuItem(
                            value: unit.id,
                            child: Text(unit['name']),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedUnitId = value;
                          _filterParticipants();
                        });
                        _saveLastSelectedUnit(value);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Filtrar Unidade'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
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
                  ],
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
  final UserModel user;
  final TrainingClass selectedClass;
  final DateTime selectedDate;

  const RetroactiveCheckinPage({
    super.key,
    required this.academyId,
    required this.todosParticipantesDaAcademia,
    required this.user,
    required this.selectedClass,
    required this.selectedDate,
  });

  @override
  State<RetroactiveCheckinPage> createState() => _RetroactiveCheckinPageState();
}

class _RetroactiveCheckinPageState extends State<RetroactiveCheckinPage> {
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<Aluno> _filteredParticipants = [];
  List<DocumentSnapshot> _units = [];
  String? _selectedUnitId;
  bool _isLoadingUnits = true;

  @override
  void initState() {
    super.initState();
    _fetchUnits().then((_) {
      final lastUnitId = widget.user.lastSelectedUnitId;
      if (lastUnitId != null && _units.any((u) => u.id == lastUnitId)) {
        _selectedUnitId = lastUnitId;
      } else {
        _selectedUnitId = widget.user.unitId ?? 'all';
      }
      _filterParticipants();
      setState(() {});
    });
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterParticipants);
    _searchController.dispose();
    super.dispose();
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
      if (mounted) {
        setState(() {
          _units = snapshot.docs;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnits = false);
      }
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

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredParticipants =
          widget.todosParticipantesDaAcademia.where((aluno) {
        final nameMatches = aluno.nome.toLowerCase().contains(query);
        final unitMatches =
            _selectedUnitId == 'all' || aluno.unitId == _selectedUnitId;
        return nameMatches && unitMatches;
      }).toList();
    });
  }

  Future<void> _saveRetroactiveCheckin() async {
    if (_selectedStudentIds.isEmpty) {
      showBjjSnackBar(context, 'Nenhum participante selecionado.',
          type: 'warning');
      return;
    }

    setState(() => _isLoading = true);

    final dateOnly = DateTime(widget.selectedDate.year,
        widget.selectedDate.month, widget.selectedDate.day);
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

        if (existingDoc == null) {
          final newDocRef = checkinRef.doc();
          batch.set(newDocRef, {
            'studentId': studentId,
            'studentName': studentName,
            'date': Timestamp.fromDate(dateOnly),
            'createdAt': FieldValue.serverTimestamp(),
            'status': checkinStatusToString(CheckinStatus.approved),
            'classId': widget.selectedClass.id,
            'className':
                '${widget.selectedClass.level} (${widget.selectedClass.startTime})',
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
        title: Text(
            "Check-in: ${DateFormat('dd/MM/yy').format(widget.selectedDate)}"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    if (_isLoadingUnits)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedUnitId,
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
                            _filterParticipants();
                          });
                          _saveLastSelectedUnit(value);
                        },
                        decoration:
                            const InputDecoration(labelText: 'Filtrar Unidade'),
                      ),
                    const SizedBox(height: 12),
                    TextField(
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
                  ],
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

  // 'mes_atual', 'ano', 'total', ou 'mes_YYYY-MM' para mês específico
  String _filter = 'mes_atual';

  // Para o filtro de mês específico
  DateTime _mesSelecionado = DateTime.now();
  bool _showMonthPicker = false;

  // Lista de meses disponíveis (gerada a partir dos checkins)
  List<DateTime> _mesesDisponiveis = [];

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

      // Buscar data de início do sistema
      DateTime? systemStartDate;
      try {
        final academyDoc =
            await firestore.collection('academies').doc(academyId).get();
        final data = academyDoc.data();
        if (data != null && data['systemStartDate'] != null) {
          final ts = data['systemStartDate'] as Timestamp;
          final d = ts.toDate();
          systemStartDate = DateTime(d.year, d.month, d.day);
        }
      } catch (_) {}

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
      final rawCheckins = checkinsSnapshot.docs
          .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
          .toList();

      // Filtrar pela data de início do sistema
      final allCheckins = systemStartDate == null
          ? rawCheckins
          : rawCheckins
              .where((c) => !c.date.isBefore(systemStartDate!))
              .toList();

      // Gerar lista de meses disponíveis (únicos, ordenados do mais recente)
      final mesesSet = <String>{};
      for (var c in allCheckins) {
        mesesSet
            .add('${c.date.year}-${c.date.month.toString().padLeft(2, '0')}');
      }
      final mesesDisponiveis = mesesSet.map((s) {
        final parts = s.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]));
      }).toList()
        ..sort((a, b) => b.compareTo(a));

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
          case 'mes_atual':
            shouldCount = checkin.date.month == now.month &&
                checkin.date.year == now.year;
            break;
          case 'ano':
            shouldCount = checkin.date.year == now.year;
            break;
          default:
            // Mês específico: 'mes_YYYY-MM'
            if (_filter.startsWith('mes_') && _filter.length > 8) {
              shouldCount = checkin.date.month == _mesSelecionado.month &&
                  checkin.date.year == _mesSelecionado.year;
            }
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
          _mesesDisponiveis = mesesDisponiveis;
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

  void _onFilterChanged(String newFilter) {
    setState(() => _filter = newFilter);
    _fetchRankingData();
  }

  String get _filterLabel {
    switch (_filter) {
      case 'mes_atual':
        return 'Mês Atual';
      case 'ano':
        return 'Este Ano';
      case 'total':
        return 'Total';
      default:
        return DateFormat('MMM/yyyy', 'pt_BR').format(_mesSelecionado);
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

    final top3 = rankedParticipantes.take(3).toList();
    final restante = rankedParticipantes.length > 3
        ? rankedParticipantes.sublist(3)
        : <Aluno>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Ranking de Presença')),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Filtros principais ────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mes_atual', label: Text('Mês Atual')),
                    ButtonSegment(value: 'ano', label: Text('Este Ano')),
                    ButtonSegment(value: 'total', label: Text('Total')),
                  ],
                  selected: {
                    ['mes_atual', 'ano', 'total'].contains(_filter)
                        ? _filter
                        : 'mes_atual'
                  },
                  onSelectionChanged: (s) => _onFilterChanged(s.first),
                ),
              ),

              // ── Botão mês específico ──────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _showMonthPicker = !_showMonthPicker);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (!['mes_atual', 'ano', 'total'].contains(_filter))
                          ? primaryAccent.withOpacity(0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color:
                            (!['mes_atual', 'ano', 'total'].contains(_filter))
                                ? primaryAccent
                                : textHint.withOpacity(0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 16, color: primaryAccent),
                        const SizedBox(width: 6),
                        Text(
                          (!['mes_atual', 'ano', 'total'].contains(_filter))
                              ? _filterLabel
                              : 'Mês específico',
                          style: TextStyle(
                            color: (!['mes_atual', 'ano', 'total']
                                    .contains(_filter))
                                ? primaryAccent
                                : textHint,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showMonthPicker
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: primaryAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Dropdown de meses ─────────────────────────────
              if (_showMonthPicker && _mesesDisponiveis.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: primaryAccent.withOpacity(0.3), width: 1),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mesesDisponiveis.length,
                    itemBuilder: (ctx, i) {
                      final mes = _mesesDisponiveis[i];
                      final key =
                          'mes_${mes.year}-${mes.month.toString().padLeft(2, '0')}';
                      final isSelected = _filter == key;
                      final label =
                          DateFormat('MMMM yyyy', 'pt_BR').format(mes);
                      final capitalizado =
                          label[0].toUpperCase() + label.substring(1);
                      return ListTile(
                        dense: true,
                        title: Text(capitalizado,
                            style: TextStyle(
                              color: isSelected ? primaryAccent : textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            )),
                        trailing: isSelected
                            ? const Icon(Icons.check,
                                color: primaryAccent, size: 16)
                            : null,
                        onTap: () {
                          setState(() {
                            _mesSelecionado = mes;
                            _filter = key;
                            _showMonthPicker = false;
                          });
                          _fetchRankingData();
                        },
                      );
                    },
                  ),
                ),

              // ── Conteúdo ──────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : rankedParticipantes.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.group_off_rounded,
                            title: 'Nenhum participante encontrado.')
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                            children: [
                              // ── Pódio ─────────────────────────
                              if (top3.isNotEmpty) _buildPodium(top3),

                              const SizedBox(height: 8),

                              // ── Restante da lista ─────────────
                              ...restante.asMap().entries.map((entry) {
                                final index = entry.key;
                                final aluno = entry.value;
                                final count = _checkinCounts[aluno.id] ?? 0;
                                final rank = index + 4;
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: darkSurface,
                                      child: Text(
                                        '$rank',
                                        style: const TextStyle(
                                          color: textHint,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    title: Text(aluno.nome,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    subtitle: Text(aluno.faixa ?? '',
                                        style: const TextStyle(
                                            color: textHint, fontSize: 12)),
                                    trailing: Text(
                                      '$count ${count == 1 ? 'treino' : 'treinos'}',
                                      style: const TextStyle(
                                        color: primaryAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<Aluno> top3) {
    // Ordem visual do pódio: 2º, 1º, 3º
    final podiumOrder = <int>[];
    if (top3.length == 1) {
      podiumOrder.add(0);
    } else if (top3.length == 2) {
      podiumOrder.addAll([1, 0]);
    } else {
      podiumOrder.addAll([1, 0, 2]);
    }

    const goldColor = primaryAccent;
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);
    final podiumColors = [goldColor, silverColor, bronzeColor];
    final podiumHeights = [90.0, 65.0, 50.0];
    final podiumLabels = ['🥇', '🥈', '🥉'];
    final podiumSizes = [52.0, 44.0, 40.0];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: podiumOrder.map((i) {
                  if (i >= top3.length) return const SizedBox.shrink();
                  final aluno = top3[i];
                  final count = _checkinCounts[aluno.id] ?? 0;
                  final color = podiumColors[i];
                  final height = podiumHeights[i];
                  final avatarSize = podiumSizes[i];
                  final label = podiumLabels[i];
                  final firstName = aluno.nome.split(' ').first;

                  return Expanded(
                    child: Column(
                      children: [
                        // Emoji do lugar
                        Text(label, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        // Avatar
                        CircleAvatar(
                          radius: avatarSize / 2,
                          backgroundColor: color.withOpacity(0.2),
                          child: Text(
                            aluno.nome.isNotEmpty
                                ? aluno.nome[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: avatarSize * 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Nome
                        Text(
                          firstName,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: i == 0 ? 14 : 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Contagem
                        Text(
                          '$count ${count == 1 ? 'treino' : 'treinos'}',
                          style: const TextStyle(color: textHint, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        // Base do pódio
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            border: Border(
                              top: BorderSide(color: color, width: 2),
                              left: BorderSide(
                                  color: color.withOpacity(0.3), width: 1),
                              right: BorderSide(
                                  color: color.withOpacity(0.3), width: 1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}°',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: i == 0 ? 22 : 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SorteioTeacherPage extends StatefulWidget {
  final UserModel user;
  final String academyId;
  final List<Aluno> todosParticipantesDaAcademia;
  final bool isSparringMode;
  final Function(List<List<Map<String, String>>>, String, List<Aluno>)
      onIniciarSparring;
  final Function(List<Aluno>) onCheckinAlunos;

  const SorteioTeacherPage({
    super.key,
    required this.user,
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
  List<DocumentSnapshot> _units = [];
  String? _selectedUnitId;
  bool _isLoadingUnits = true;

  @override
  void initState() {
    super.initState();
    _fetchUnits().then((_) {
      final lastUnitId = widget.user.lastSelectedUnitId;
      if (lastUnitId != null && _units.any((u) => u.id == lastUnitId)) {
        _selectedUnitId = lastUnitId;
      } else {
        _selectedUnitId = widget.user.unitId ?? 'all';
      }
      setState(() {});
    });
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
      if (mounted) {
        setState(() {
          _units = snapshot.docs;
          _isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUnits = false);
      }
    }
  }

  void _atualizarAlunosParticipantes(List<Aluno> novosParticipantes) {
    setState(() {
      _alunosParticipantes = novosParticipantes;
      _rodadasGeradas = [];
    });
  }

  Future<void> _navegarParaSelecaoAlunos() async {
    final alunosDaUnidade = widget.todosParticipantesDaAcademia.where((aluno) {
      return _selectedUnitId == 'all' || aluno.unitId == _selectedUnitId;
    }).toList();

    final List<Aluno>? r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SelecaoAlunosTeacherPage(
        todosOsAlunos: alunosDaUnidade,
        alunosSelecionadosIniciais: _alunosParticipantes,
      ),
    ));
    if (r != null) {
      _atualizarAlunosParticipantes(r);
    }
  }

  Future<void> _carregarUltimosParticipantes() async {
    final logService = TrainingLogService(userId: widget.user.uid);
    final ultimosIds = await logService
        .getLatestSparringSessionPartners(widget.user.academyId);

    if (ultimosIds.isEmpty) {
      showBjjSnackBar(
          context, 'Nenhum treino em grupo anterior encontrado no histórico.',
          type: 'info');
      return;
    }

    final todosDaUnidade = widget.todosParticipantesDaAcademia.where((aluno) {
      return _selectedUnitId == 'all' || aluno.unitId == _selectedUnitId;
    }).toList();

    final ultimosParticipantes =
        todosDaUnidade.where((aluno) => ultimosIds.contains(aluno.id)).toList();

    if (ultimosParticipantes.isEmpty && ultimosIds.isNotEmpty) {
      showBjjSnackBar(context,
          'Os participantes do último treino não pertencem À  unidade selecionada.',
          type: 'warning');
    }

    // Abre a tela de seleção já com os últimos participantes marcados.
    final List<Aluno>? r = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => SelecaoAlunosTeacherPage(
        todosOsAlunos: todosDaUnidade,
        alunosSelecionadosIniciais: ultimosParticipantes,
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

    final sparringService = SparringService(
      participantes: _alunosParticipantes,
      tipoGeracao: _tipoGeracao,
    );

    final rodadas = sparringService.gerarRodadas();

    setState(() {
      _rodadasGeradas = rodadas;
    });
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _isLoadingUnits
                            ? const LinearProgressIndicator()
                            : DropdownButtonFormField<String>(
                                value: _selectedUnitId,
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
                                onChanged: widget.isSparringMode
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedUnitId = value;
                                          _alunosParticipantes.clear();
                                          _rodadasGeradas.clear();
                                        });
                                      },
                                decoration: const InputDecoration(
                                    labelText: 'Filtrar Unidade'),
                              ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon:
                            const Icon(Icons.history_rounded, color: textHint),
                        tooltip: 'Histórico de Treinos',
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SparringHistoryListPage(
                              academyId: widget.academyId,
                              allParticipants:
                                  widget.todosParticipantesDaAcademia,
                            ),
                          ));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.group_add_outlined),
                          label: Text(
                              'Selecionar (${_alunosParticipantes.length})'),
                          onPressed: widget.isSparringMode
                              ? null
                              : _navegarParaSelecaoAlunos,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.replay_rounded),
                        tooltip: 'Repetir Àšltima Seleção',
                        onPressed: widget.isSparringMode
                            ? null
                            : _carregarUltimosParticipantes,
                      ),
                    ],
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
    final sparringStateDoc = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('state')
        .doc('sparring')
        .get();

    if (sparringStateDoc.exists) {
      final data = sparringStateDoc.data()!;
      final currentUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('training_history')
          .add({
        'startedAt': data['startedAt'] ?? FieldValue.serverTimestamp(),
        'generationType': data['generationType'],
        'participants': data['participants'],
        'allRounds': data['allRounds'],
        'createdByUid': currentUser?.uid,
        'createdByName': currentUser?.displayName ?? 'Professor',
      });
    }

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
            'FIM - Àšltima Rodada (${allRounds.length}/${allRounds.length})';
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
  final _searchController = TextEditingController();
  List<Aluno> _filteredAthletes = [];

  @override
  void initState() {
    super.initState();
    _alunosAtuaisSelecionados =
        Set<Aluno>.from(widget.alunosSelecionadosIniciais);
    _filteredAthletes = widget.todosOsAlunos;
    _searchController.addListener(_filterAthletes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterAthletes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAthletes = widget.todosOsAlunos.where((athlete) {
        return athlete.nome.toLowerCase().contains(query);
      }).toList();
    });
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nome...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: widget.todosOsAlunos.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.person_search_rounded,
                        title: 'Nenhum Participante Cadastrado')
                    : _filteredAthletes.isEmpty
                        ? const Center(child: Text("Nenhum atleta encontrado."))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                            itemCount: _filteredAthletes.length,
                            itemBuilder: (context, index) {
                              final a = _filteredAthletes[index];
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
                                    _searchController.clear();
                                  }),
                                  secondary: const Icon(Icons.person),
                                ),
                              );
                            }),
              ),
            ],
          ),
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

// --- TELA DE LISTA DE HISTÀ“RICO DE TREINOS ---
class SparringHistoryListPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> allParticipants;

  const SparringHistoryListPage({
    super.key,
    required this.academyId,
    required this.allParticipants,
  });

  @override
  State<SparringHistoryListPage> createState() =>
      _SparringHistoryListPageState();
}

class _SparringHistoryListPageState extends State<SparringHistoryListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Histórico de Treinos'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(widget.academyId)
                .collection('training_history')
                .orderBy('startedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.history_rounded,
                  title: 'Nenhum Treino no Histórico',
                  message:
                      'Os treinos de sparring finalizados aparecerão aqui.',
                );
              }

              final sessions = snapshot.data!.docs
                  .map((doc) => SparringSession.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.event_note_rounded,
                          color: primaryAccent),
                      title: Text(
                          'Treino de ${DateFormat('dd/MM/yyyy \'À s\' HH:mm').format(session.startedAt.toDate())}'),
                      subtitle: Text(
                          '${session.participantIds.length} participantes'),
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SparringHistoryDetailPage(
                            session: session,
                            allParticipants: widget.allParticipants,
                          ),
                        ));
                      },
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

// --- TELA DE DETALHES DO HISTÀ“RICO DE TREINO ---
class SparringHistoryDetailPage extends StatelessWidget {
  final SparringSession session;
  final List<Aluno> allParticipants;

  const SparringHistoryDetailPage({
    super.key,
    required this.session,
    required this.allParticipants,
  });

  @override
  Widget build(BuildContext context) {
    final participantsMap = {
      for (var p in allParticipants) p.id: p.nome,
      'descansa-id': 'DESCANSA' // Adiciona o participante fantasma
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalhes do Treino'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: session.allRounds.length,
            itemBuilder: (context, index) {
              final roundData = session.allRounds[index];
              final fights = (roundData['fights'] as List)
                  .map((fight) => Map<String, String>.from(fight as Map))
                  .toList();
              return Card(
                child: ExpansionTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('Rodada ${index + 1}'),
                  initiallyExpanded: index == 0,
                  children: fights.map((fight) {
                    final p1Name =
                        participantsMap[fight['p1']] ?? 'Desconhecido';
                    final p2Name =
                        participantsMap[fight['p2']] ?? 'Desconhecido';
                    String fightText;
                    if (p1Name == 'DESCANSA') {
                      fightText = '$p2Name (descansa)';
                    } else if (p2Name == 'DESCANSA') {
                      fightText = '$p1Name (descansa)';
                    } else {
                      fightText = '$p1Name x $p2Name';
                    }
                    return ListTile(title: Text(fightText));
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SelectClassDialog extends StatelessWidget {
  final String academyId;
  final DateTime selectedDate;

  const _SelectClassDialog({
    required this.academyId,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = DateFormat('EEEE', 'pt_BR').format(selectedDate);
    final formattedDay = dayOfWeek[0].toUpperCase() + dayOfWeek.substring(1);

    return AlertDialog(
      title: const Text('Selecione a Turma'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('academies')
              .doc(academyId)
              .collection('schedule')
              .where('dayOfWeek', isEqualTo: formattedDay)
              .orderBy('startTime')
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text('Nenhuma aula encontrada para este dia.'),
              );
            }
            final classes = snapshot.data!.docs
                .map((doc) => TrainingClass.fromFirestore(doc))
                .toList();

            return ListView.builder(
              shrinkWrap: true,
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final trainingClass = classes[index];
                return ListTile(
                  title: Text(
                      '${trainingClass.level} (${trainingClass.startTime})'),
                  subtitle: Text('Prof. ${trainingClass.teacherName}'),
                  onTap: () {
                    Navigator.of(context).pop(trainingClass);
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
