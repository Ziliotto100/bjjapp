// lib/manager_module.dart
// ignore_for_file: use_build_context_synchronously, unnecessary_brace_in_string_interps, deprecated_member_use, unused_element, unused_import

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'student_module.dart';
import 'auth_gate.dart';
import 'navigation_service.dart';
import 'app_drawer.dart';
import 'user_card_widget.dart';
import 'graduation_timeline_page.dart';
import 'teacher_module.dart';
import 'manager_units_module.dart';
import 'academy_profile_page.dart'; // NOVO IMPORT

// --- FUNÇÃO DE LOG DE AUDITORIA ---
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

// --- FUNÇÃO AUXILIAR PARA ORDENAÇÃO DE FAIXAS ---
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

// --- LÓGICA DE GERENCIAMENTO DE USUÁRIOS ---
class UserManagementService {
  static Future<void> promoteToTeacher(BuildContext context,
      {required String academyId,
      required Aluno aluno,
      required UserModel manager}) async {
    if (aluno.userId == null) {
      showBjjSnackBar(context,
          "Este aluno não possui um login de acesso para ser promovido.",
          type: 'error');
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final userRef = firestore.collection('users').doc(aluno.userId!);
    batch.update(userRef, {
      'role': 'teacher',
      'faixa': aluno.faixa,
      'graus': aluno.graus,
      'peso': aluno.peso,
      'dataNascimento': aluno.dataNascimento != null
          ? Timestamp.fromDate(aluno.dataNascimento!)
          : null,
      'studentRecordId': FieldValue.delete(),
      'unitId': aluno.unitId,
      'unitName': aluno.unitName,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedByUid': manager.uid,
      'lastUpdatedByName': manager.name,
    });

    final studentDocRef = firestore
        .collection('academies')
        .doc(academyId)
        .collection('students')
        .doc(aluno.id);
    batch.delete(studentDocRef);

    try {
      await batch.commit();

      await _createAuditLog(
        academyId: academyId,
        actor: manager,
        actionType: 'PROMOTE_USER',
        description:
            '${manager.name} promoveu o aluno ${aluno.nome} para professor.',
        targetUid: aluno.userId,
        targetName: aluno.nome,
      );

      showBjjSnackBar(context, '${aluno.nome} foi promovido a professor!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao promover aluno: $e', type: 'error');
    }
  }

  static Future<void> demoteToStudent(BuildContext context,
      {required String academyId,
      required UserModel teacher,
      required UserModel manager}) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final newStudentRef = firestore
        .collection('academies')
        .doc(academyId)
        .collection('students')
        .doc();
    batch.set(newStudentRef, {
      'nome': teacher.name,
      'faixa': teacher.faixa ?? 'Branca',
      'graus': teacher.graus,
      'peso': teacher.peso ?? 0.0,
      'userId': teacher.uid,
      'dataNascimento': teacher.dataNascimento != null
          ? Timestamp.fromDate(teacher.dataNascimento!)
          : null,
      'unitId': teacher.unitId,
      'unitName': teacher.unitName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': manager.uid,
      'createdByName': manager.name,
      'lastUpdatedByUid': manager.uid,
      'lastUpdatedByName': manager.name,
    });

    final userRef = firestore.collection('users').doc(teacher.uid);
    batch.update(userRef, {
      'role': 'student',
      'studentRecordId': newStudentRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedByUid': manager.uid,
      'lastUpdatedByName': manager.name,
    });

    try {
      await batch.commit();

      await _createAuditLog(
        academyId: academyId,
        actor: manager,
        actionType: 'DEMOTE_USER',
        description:
            '${manager.name} reverteu o professor ${teacher.name} para aluno.',
        targetUid: teacher.uid,
        targetName: teacher.name,
      );

      showBjjSnackBar(context, '${teacher.name} agora é um aluno!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao reverter professor: $e', type: 'error');
    }
  }
}

// --- TELA PRINCIPAL DO GERENTE ---
class ManagerHomePage extends StatefulWidget {
  final UserModel user;
  final bool isImpersonating;

  const ManagerHomePage({
    super.key,
    required this.user,
    this.isImpersonating = false,
  });

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
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

  @override
  void initState() {
    super.initState();
    _navService =
        NavigationService(userId: widget.user.uid, userRole: widget.user.role);
    _loadInitialData();
    _listenToSparringState();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
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

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      _teachers = (await firestore
              .collection('users')
              .where('academyId', isEqualTo: widget.user.academyId)
              .where('role', isEqualTo: 'teacher')
              .get())
          .docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      _students = (await firestore
              .collection('academies')
              .doc(widget.user.academyId)
              .collection('students')
              .get())
          .docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

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
    if (module.id == 'teacher_sparring') {
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
    }
    return module.pageBuilder!(widget.user, _teachers, _students);
  }

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

    if (mounted) {
      setState(() {
        _telas = _allPageModules
            .map((module) => _buildPageForModule(module))
            .toList();

        _visibleModules =
            _allPageModules.where((m) => visibleIds.contains(m.id)).toList();

        if (_paginaAtual >= _allPageModules.length) {
          _paginaAtual = 0;
        }

        _isLoading = false;
      });
    }
  }

  void _navigateToModuleId(String moduleId) {
    final newIndex = _allPageModules.indexWhere((m) => m.id == moduleId);
    if (newIndex != -1) {
      setState(() {
        _paginaAtual = newIndex;
      });
    }
  }

  void _onItemTapped(int index) {
    final selectedModuleId = _visibleModules[index].id;
    _navigateToModuleId(selectedModuleId);
  }

  void _navigateToSettings() {
    _settingsSubscription?.pause();
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      Navigator.of(context)
          .push(MaterialPageRoute(
        builder: (_) => ManagerSettingsPage(user: widget.user),
      ))
          .then((_) {
        if (mounted) {
          _settingsSubscription?.resume();
        }
      });
    });
  }

  Widget _buildImpersonationBanner() {
    return Material(
      color: warningColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.black, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Você está vendo como ${widget.user.name}.',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                final superAdminUid = FirebaseAuth.instance.currentUser?.uid;
                if (superAdminUid == null) return;

                await FirebaseFirestore.instance
                    .collection('impersonation_sessions')
                    .doc(superAdminUid)
                    .delete();
                await FirebaseAuth.instance.signOut();
              },
              child: const Text('SAIR',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: AppBackground(child: Center(child: CircularProgressIndicator())),
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
            tooltip: 'Configurações da Academia',
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      drawer: AppDrawer(
        user: widget.user,
        drawerModules: _drawerModules,
        allPageModules: _allPageModules,
        onSelectItem: _navigateToModuleId,
      ),
      body: Column(
        children: [
          if (widget.isImpersonating) _buildImpersonationBanner(),
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
    final currentModuleId = _allPageModules[_paginaAtual].id;

    if (currentModuleId == 'manager_students') {
      return FloatingActionButton(
        heroTag: 'manager_add_student_fab',
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
        child: const Icon(Icons.add_rounded),
      );
    } else if (currentModuleId == 'manager_teachers') {
      return FloatingActionButton(
        heroTag: 'manager_add_teacher_fab',
        onPressed: () async {
          final result = await showDialog<Map<String, String>?>(
            context: context,
            builder: (_) => AdicionarProfessorDialog(
              academyId: widget.user.academyId,
              manager: widget.user,
            ),
          );

          if (result != null && mounted) {
            final name = result['name']!;
            final email = result['email']!;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Professor Criado!"),
                content: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge,
                    children: <TextSpan>[
                      TextSpan(
                          text:
                              'A conta para o professor $name foi criada com sucesso!\n\n'),
                      const TextSpan(
                        text: 'A senha padrão é mudar123\n\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'E-mail de acesso: $email\n\n'),
                      const TextSpan(
                          text:
                              'O professor deverá usar esta senha temporária no primeiro login e será solicitado a criar uma nova senha.'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("OK"))
                ],
              ),
            );
          }
        },
        tooltip: 'Adicionar Professor',
        child: const Icon(Icons.add_rounded),
      );
    }
    return null;
  }
}

// >>>>> INÍCIO DA CORREÇÃO <<<<<
void showCreateAccessDialog(BuildContext context, Aluno aluno, String academyId,
    UserModel manager) async {
  // A função agora é chamada de um contexto que permanecerá válido.
  final result = await showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (_) => CreateStudentAccessDialog(
      academyId: academyId,
      aluno: aluno,
      manager: manager,
    ),
  );

  if (result?['success'] == true && context.mounted) {
    final email = result!['email'];
    // Este showDialog agora usa o contexto válido da página.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Acesso Criado!"),
        content: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge,
            children: <TextSpan>[
              TextSpan(
                  text:
                      'A conta para ${aluno.nome} foi criada com sucesso!\n\n'),
              const TextSpan(
                text: 'A senha padrão é mudar123\n\n',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: 'E-mail de acesso: $email\n\n'),
              const TextSpan(
                  text:
                      'O aluno deverá usar esta senha temporária no primeiro login e será solicitado a criar uma nova senha.'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"))
        ],
      ),
    );
  }
}
// >>>>> FIM DA CORREÇÃO <<<<<

class ManagerDashboardPage extends StatelessWidget {
  final UserModel user;
  const ManagerDashboardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        UserProfileHeader(user: user),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.business, color: primaryAccent),
            title: const Text("ID da sua Academia"),
            subtitle:
                Text(user.academyId, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class AlunosManagerPage extends StatefulWidget {
  final String academyId;
  final UserModel manager;
  const AlunosManagerPage(
      {super.key, required this.academyId, required this.manager});

  @override
  State<AlunosManagerPage> createState() => _AlunosManagerPageState();
}

class _AlunosManagerPageState extends State<AlunosManagerPage> {
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
                stream: FirebaseFirestore.instance
                    .collection('academies')
                    .doc(widget.academyId)
                    .collection('students')
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

                  List<Aluno> processedAlunos = List.from(allAlunos);

                  if (_searchQuery.isNotEmpty) {
                    processedAlunos = processedAlunos.where((aluno) {
                      return aluno.nome
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase());
                    }).toList();
                  }

                  if (_beltFilter != null) {
                    processedAlunos
                        .retainWhere((aluno) => aluno.faixa == _beltFilter);
                  }

                  if (_unitFilter != null) {
                    processedAlunos
                        .retainWhere((aluno) => aluno.unitId == _unitFilter);
                  }

                  processedAlunos.sort((a, b) {
                    switch (_sortOption) {
                      case 'faixa':
                        return _getBeltIndex(a.faixa)
                            .compareTo(_getBeltIndex(b.faixa));
                      case 'peso':
                        return a.peso.compareTo(b.peso);
                      case 'nome':
                      default:
                        return a.nome
                            .toLowerCase()
                            .compareTo(b.nome.toLowerCase());
                    }
                  });

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
                        currentUser: widget.manager,
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

class ProfessoresManagerPage extends StatefulWidget {
  final String academyId;
  final UserModel manager;
  const ProfessoresManagerPage(
      {super.key, required this.academyId, required this.manager});

  @override
  State<ProfessoresManagerPage> createState() => _ProfessoresManagerPageState();
}

class _ProfessoresManagerPageState extends State<ProfessoresManagerPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
                    labelText: 'Buscar professor por nome...',
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('academyId', isEqualTo: widget.academyId)
                .where('role', isEqualTo: 'teacher')
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
                  icon: Icons.school_outlined,
                  title: 'Nenhum Professor Cadastrado',
                  message:
                      'Clique no botão "+" para adicionar o primeiro professor.',
                );
              }

              final allProfessores = snapshot.data!.docs.map((doc) {
                return UserModel.fromFirestore(doc);
              }).toList();

              List<UserModel> processedProfessores = List.from(allProfessores);

              if (_searchQuery.isNotEmpty) {
                processedProfessores = processedProfessores.where((prof) {
                  return prof.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
                }).toList();
              }

              if (_beltFilter != null) {
                processedProfessores
                    .retainWhere((prof) => prof.faixa == _beltFilter);
              }

              if (_unitFilter != null) {
                processedProfessores
                    .retainWhere((prof) => prof.unitId == _unitFilter);
              }

              processedProfessores.sort((a, b) {
                switch (_sortOption) {
                  case 'faixa':
                    return _getBeltIndex(a.faixa ?? 'Branca')
                        .compareTo(_getBeltIndex(b.faixa ?? 'Branca'));
                  case 'nome':
                  default:
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                }
              });

              if (processedProfessores.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.person_search,
                  title: "Nenhum Professor Encontrado",
                  message:
                      "Nenhum professor corresponde aos filtros selecionados.",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8, 80.0),
                itemCount: processedProfessores.length,
                itemBuilder: (context, index) {
                  final professor = processedProfessores[index];
                  return UserCard(
                    user: professor,
                    academyId: widget.academyId,
                    currentUser: widget.manager,
                    profileImageUrl: professor.profileImagePath,
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

class CreateStudentAccessDialog extends StatefulWidget {
  final String academyId;
  final Aluno aluno;
  final UserModel manager;
  const CreateStudentAccessDialog(
      {super.key,
      required this.academyId,
      required this.aluno,
      required this.manager});

  @override
  State<CreateStudentAccessDialog> createState() =>
      _CreateStudentAccessDialogState();
}

class _CreateStudentAccessDialogState extends State<CreateStudentAccessDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _createAccess() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    const temporaryPassword = 'mudar123';
    final email = _emailController.text.trim();

    try {
      final tempApp = await Firebase.initializeApp(
        name: 'temp_student_creation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: temporaryPassword,
      );
      final newUser = userCredential.user;

      if (newUser == null) {
        await tempApp.delete();
        throw Exception("Falha ao criar a conta de autenticação.");
      }

      final batch = FirebaseFirestore.instance.batch();
      final studentRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .doc(widget.aluno.id);
      batch.update(studentRef, {'userId': newUser.uid});

      final userRef =
          FirebaseFirestore.instance.collection('users').doc(newUser.uid);

      batch.set(userRef, {
        'name': widget.aluno.nome,
        'email': email,
        'academyId': widget.academyId,
        'role': 'student',
        'studentRecordId': widget.aluno.id,
        'mustChangePassword': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.manager.uid,
        'createdByName': widget.manager.name,
        'lastUpdatedByUid': widget.manager.uid,
        'lastUpdatedByName': widget.manager.name,
      });

      await batch.commit();
      await tempApp.delete();

      // **LOG DE AUDITORIA**
      await _createAuditLog(
        academyId: widget.academyId,
        actor: widget.manager,
        actionType: 'CREATE_USER_ACCESS',
        description:
            '${widget.manager.name} criou um acesso de login para o aluno ${widget.aluno.nome}.',
        targetUid: newUser.uid,
        targetName: widget.aluno.nome,
      );

      if (mounted) {
        Navigator.of(context).pop({'success': true, 'email': email});
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao criar acesso.';
      if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está sendo usado por outra conta.';
      }
      if (mounted) showBjjSnackBar(context, message, type: 'error');
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Criar Acesso para ${widget.aluno.nome}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'E-mail do Aluno (para login)',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) =>
              (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _isLoading ? null : _createAccess,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Criar"),
        )
      ],
    );
  }
}

class AdicionarAlunoDialog extends StatefulWidget {
  final Function(Aluno) onAlunoAdicionado;
  final Aluno? alunoParaEditar;
  final String? academyId;
  final UserModel currentUser;

  const AdicionarAlunoDialog(
      {super.key,
      required this.onAlunoAdicionado,
      this.alunoParaEditar,
      this.academyId,
      required this.currentUser});

  @override
  State<AdicionarAlunoDialog> createState() => _AdicionarAlunoDialogState();
}

class _AdicionarAlunoDialogState extends State<AdicionarAlunoDialog> {
  final nC = TextEditingController(),
      pC = TextEditingController(),
      dNascC = TextEditingController(),
      phoneC = TextEditingController(),
      logradouroC = TextEditingController(),
      numeroC = TextEditingController(),
      bairroC = TextEditingController(),
      cidadeC = TextEditingController(),
      cepC = TextEditingController();
  String? fS;
  int? gS;
  String? selectedUnitId;
  String? selectedUnitName;
  List<DocumentSnapshot> units = [];
  bool isLoadingUnits = true;

  final List<String> faixasList = [
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
  List<int> grausList = [];
  final formKey = GlobalKey<FormState>();

  bool get isEditing => widget.alunoParaEditar != null;

  @override
  void initState() {
    super.initState();
    _fetchUnits();
    if (isEditing) {
      final aluno = widget.alunoParaEditar!;
      nC.text = aluno.nome;
      pC.text = aluno.peso.toString();
      fS = aluno.faixa;
      gS = aluno.graus;
      phoneC.text = aluno.phoneNumber ?? '';
      if (aluno.address != null) {
        logradouroC.text = aluno.address!['logradouro'] ?? '';
        numeroC.text = aluno.address!['numero'] ?? '';
        bairroC.text = aluno.address!['bairro'] ?? '';
        cidadeC.text = aluno.address!['cidade'] ?? '';
        cepC.text = aluno.address!['cep'] ?? '';
      }
      selectedUnitId = aluno.unitId;
      selectedUnitName = aluno.unitName;
      if (aluno.dataNascimento != null) {
        dNascC.text = DateFormat('dd/MM/yyyy').format(aluno.dataNascimento!);
      }
      grausList = _getGrausForFaixa(fS);
    }
  }

  Future<void> _fetchUnits() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.currentUser.academyId)
          .collection('units')
          .orderBy('name')
          .get();
      if (mounted) {
        setState(() {
          units = snapshot.docs;
          isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingUnits = false);
        showBjjSnackBar(context, 'Erro ao carregar unidades.', type: 'error');
      }
    }
  }

  @override
  void dispose() {
    nC.dispose();
    pC.dispose();
    dNascC.dispose();
    phoneC.dispose();
    logradouroC.dispose();
    numeroC.dispose();
    bairroC.dispose();
    cidadeC.dispose();
    cepC.dispose();
    super.dispose();
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') return List.generate(10, (i) => i + 1);
    if (faixa != null) return [1, 2, 3, 4];
    return [];
  }

  Future<void> _deleteAluno(Aluno aluno) async {
    Navigator.of(context).pop();
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final studentDocRef = firestore
          .collection('academies')
          .doc(widget.academyId!)
          .collection('students')
          .doc(aluno.id);
      batch.delete(studentDocRef);

      if (aluno.userId != null) {
        final userDocRef = firestore.collection('users').doc(aluno.userId);
        batch.delete(userDocRef);
      }
      await batch.commit();

      await _createAuditLog(
        academyId: widget.academyId!,
        actor: widget.currentUser,
        actionType: 'DELETE_STUDENT',
        description:
            '${widget.currentUser.name} excluiu o aluno ${aluno.nome}.',
        targetName: aluno.nome,
        targetUid: aluno.userId,
      );

      if (mounted) {
        showBjjSnackBar(context, 'Aluno ${aluno.nome} excluído com sucesso.',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao excluir aluno: $e', type: 'error');
      }
    }
  }

  void _confirmDeleteAluno(Aluno aluno) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente o aluno ${aluno.nome}? Esta ação removerá o aluno da lista e também seu acesso de login, caso exista. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: errorColor, foregroundColor: Colors.white),
            child: const Text("Excluir"),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteAluno(aluno);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool mostrarGrausDropdown = fS != null;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(isEditing ? 'Editar Aluno' : 'Adicionar Novo Aluno')),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: nC,
                  decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon: Icon(Icons.person_add_alt_1_rounded)),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nome inválido' : null),
              const SizedBox(height: 16),
              if (isLoadingUnits)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: selectedUnitId,
                  decoration: const InputDecoration(
                    labelText: 'Unidade (Matriz/Filial)',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  ),
                  isExpanded: true,
                  hint: const Text("Selecione a Unidade"),
                  items: units.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit.id,
                      child: Text(unit['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUnitId = value;
                      selectedUnitName =
                          units.firstWhere((u) => u.id == value)['name'];
                    });
                  },
                  validator: (v) => v == null ? 'Selecione uma unidade' : null,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneC,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  PhoneInputFormatter(),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: dNascC,
                decoration: const InputDecoration(
                  labelText: 'Data de Nascimento',
                  hintText: 'DD/MM/AAAA',
                  prefixIcon: Icon(Icons.cake_rounded),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  DateInputFormatter(),
                ],
                maxLength: 10,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null;
                  }
                  if (v.length != 10) {
                    return 'Data incompleta.';
                  }
                  try {
                    DateFormat('dd/MM/yyyy').parseStrict(v);
                    return null;
                  } catch (e) {
                    return 'Data inválida.';
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: fS,
                  decoration: const InputDecoration(
                      labelText: 'Faixa',
                      prefixIcon: Icon(Icons.shield_outlined)),
                  hint: const Text("Selecione a Faixa"),
                  onChanged: (v) => setState(() {
                        fS = v;
                        grausList = _getGrausForFaixa(fS);
                        gS = null;
                      }),
                  items: faixasList
                      .map((v) => DropdownMenuItem<String>(
                          value: v,
                          child: Text(v, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  validator: (v) => v == null ? 'Selecione uma faixa' : null),
              if (mostrarGrausDropdown) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: gS,
                    decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Graus',
                        prefixIcon: Icon(Icons.star_outline_rounded)),
                    hint: const Text("Graus (opcional)"),
                    onChanged: (v) => setState(() => gS = v),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text("Nenhum")),
                      ...grausList.map((v) => DropdownMenuItem<int>(
                          value: v,
                          child: Text('$vº Grau',
                              overflow: TextOverflow.ellipsis)))
                    ].toList())
              ],
              const SizedBox(height: 16),
              TextFormField(
                  controller: pC,
                  decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      prefixIcon: Icon(Icons.fitness_center_rounded)),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Peso inválido';
                    final x = double.tryParse(v.replaceAll(',', '.'));
                    return (x == null || x <= 0)
                        ? 'Peso inválido (deve ser > 0)'
                        : null;
                  }),
              const SizedBox(height: 24),
              Text("Endereço", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: logradouroC,
                decoration:
                    const InputDecoration(labelText: 'Logradouro (Rua, Av...)'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: numeroC,
                      decoration: const InputDecoration(labelText: 'Nº'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: bairroC,
                      decoration: const InputDecoration(labelText: 'Bairro'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: cidadeC,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: cepC,
                      decoration: const InputDecoration(labelText: 'CEP'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CepInputFormatter(),
                      ],
                    ),
                  ),
                ],
              ),
              if (isEditing && widget.alunoParaEditar?.userId == null) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.login_rounded, color: infoColor),
                  label: const Text("Criar Acesso de Login",
                      style: TextStyle(color: infoColor)),
                  onPressed: () async {
                    final currentContext = context;
                    Navigator.of(currentContext).pop();
                    // CORREÇÃO: Chamando a função pública global
                    showCreateAccessDialog(
                        currentContext,
                        widget.alunoParaEditar!,
                        widget.academyId!,
                        widget.currentUser);
                  },
                )
              ],
              if (isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.alunoParaEditar?.userId != null &&
                        widget.currentUser.role == UserRole.manager)
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.school_rounded, size: 18),
                          label: const Text("Promover"),
                          style: TextButton.styleFrom(
                              foregroundColor: primaryAccent,
                              textStyle: const TextStyle(
                                  fontSize: 14)), // Reduzindo a fonte
                          onPressed: () {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirmar Promoção'),
                                content: Text(
                                    'Você tem certeza que deseja promover ${widget.alunoParaEditar!.nome} para Professor?'),
                                actions: [
                                  TextButton(
                                    child: const Text('Cancelar'),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                  ElevatedButton(
                                    child: const Text('Promover'),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      UserManagementService.promoteToTeacher(
                                        context,
                                        academyId: widget.academyId!,
                                        aluno: widget.alunoParaEditar!,
                                        manager: widget.currentUser,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    if (widget.alunoParaEditar?.userId != null &&
                        widget.currentUser.role == UserRole.manager)
                      const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.military_tech_rounded, size: 18),
                        label: const Text("Graduar"),
                        style: TextButton.styleFrom(
                            foregroundColor: successColor,
                            textStyle: const TextStyle(
                                fontSize: 14)), // Reduzindo a fonte
                        onPressed: () {
                          Navigator.of(context).pop(); // Close current dialog
                          showDialog(
                            context: context,
                            builder: (_) => GraduationDialog(
                              academyId: widget.academyId!,
                              user: widget.alunoParaEditar!,
                              currentUser: widget.currentUser,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isEditing && widget.currentUser.role == UserRole.manager)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: errorColor),
                      label: const Text('Excluir',
                          style: TextStyle(color: errorColor)),
                      onPressed: () =>
                          _confirmDeleteAluno(widget.alunoParaEditar!),
                    )
                  else
                    const SizedBox(),
                  ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(isEditing ? 'Salvar' : 'Adicionar'),
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          DateTime? dataNascimento;
                          if (dNascC.text.isNotEmpty) {
                            try {
                              dataNascimento = DateFormat('dd/MM/yyyy')
                                  .parseStrict(dNascC.text);
                            } catch (e) {
                              showBjjSnackBar(
                                  context, 'Formato de data inválido.',
                                  type: 'error');
                              return;
                            }
                          }

                          final double peso =
                              double.parse(pC.text.replaceAll(',', '.'));
                          final alunoResult = Aluno(
                              id: isEditing ? widget.alunoParaEditar!.id : '',
                              nome: nC.text.trim().capitalizeWords(),
                              faixa: fS!,
                              peso: peso,
                              graus: gS,
                              dataNascimento: dataNascimento,
                              phoneNumber: phoneC.text.trim(),
                              address: {
                                'logradouro': logradouroC.text.trim(),
                                'numero': numeroC.text.trim(),
                                'bairro': bairroC.text.trim(),
                                'cidade': cidadeC.text.trim(),
                                'cep': cepC.text.trim(),
                              },
                              userId: isEditing
                                  ? widget.alunoParaEditar!.userId
                                  : null,
                              unitId: selectedUnitId,
                              unitName: selectedUnitName,
                              createdByUid: isEditing
                                  ? widget.alunoParaEditar!.createdByUid
                                  : widget.currentUser.uid,
                              createdByName: isEditing
                                  ? widget.alunoParaEditar!.createdByName
                                  : widget.currentUser.name,
                              lastUpdatedByUid: widget.currentUser.uid,
                              lastUpdatedByName: widget.currentUser.name);

                          widget.onAlunoAdicionado(alunoResult);
                          Navigator.of(context).pop();
                        }
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditarProfessorDialog extends StatefulWidget {
  final UserModel professor;
  final String academyId;
  final UserModel manager;
  const EditarProfessorDialog(
      {super.key,
      required this.professor,
      required this.academyId,
      required this.manager});

  @override
  State<EditarProfessorDialog> createState() => _EditarProfessorDialogState();
}

class _EditarProfessorDialogState extends State<EditarProfessorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _pesoController;
  String? _faixa;
  int? _graus;
  String? selectedUnitId;
  String? selectedUnitName;
  List<DocumentSnapshot> units = [];
  bool isLoadingUnits = true;
  bool _isLoading = false;

  final List<String> _faixasList = [
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
  List<int> _grausList = [];

  @override
  void initState() {
    super.initState();
    _fetchUnits();
    _nameController = TextEditingController(text: widget.professor.name);
    _pesoController =
        TextEditingController(text: widget.professor.peso?.toString() ?? '');
    _faixa = widget.professor.faixa;
    _graus = widget.professor.graus;
    selectedUnitId = widget.professor.unitId;
    selectedUnitName = widget.professor.unitName;
    if (_faixa != null) {
      _grausList = _getGrausForFaixa(_faixa);
    }
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
          units = snapshot.docs;
          isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingUnits = false);
        showBjjSnackBar(context, 'Erro ao carregar unidades.', type: 'error');
      }
    }
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') return List.generate(10, (i) => i + 1);
    if (faixa != null) return [1, 2, 3, 4];
    return [];
  }

  Future<void> _deleteProfessor(UserModel professor) async {
    Navigator.of(context).pop();
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(professor.uid)
          .delete();

      if (mounted) {
        showBjjSnackBar(
            context, 'Professor ${professor.name} excluído com sucesso.',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao excluir professor: $e',
            type: 'error');
      }
    }
  }

  void _confirmDeleteProfessor(UserModel professor) {
    if (professor.uid == widget.manager.uid) {
      showBjjSnackBar(
          context, "Você não pode excluir sua própria conta de gerente.",
          type: 'error');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente o professor ${professor.name}? Esta ação removerá seu acesso de login. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: errorColor, foregroundColor: Colors.white),
            child: const Text("Excluir"),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteProfessor(professor);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final pesoStr = _pesoController.text.replaceAll(',', '.');
    final Map<String, dynamic> updatedData = {
      'name': _nameController.text.trim().capitalizeWords(),
      'faixa': _faixa,
      'graus': _graus,
      'peso': pesoStr.isNotEmpty ? double.tryParse(pesoStr) : null,
      'unitId': selectedUnitId,
      'unitName': selectedUnitName,
      'lastUpdatedByUid': widget.manager.uid,
      'lastUpdatedByName': widget.manager.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.professor.uid)
          .update(updatedData);

      // **LOG DE AUDITORIA**
      await _createAuditLog(
        academyId: widget.academyId,
        actor: widget.manager,
        actionType: 'UPDATE_TEACHER',
        description:
            '${widget.manager.name} editou os dados do professor ${widget.professor.name}.',
        targetUid: widget.professor.uid,
        targetName: widget.professor.name,
      );

      if (mounted) {
        showBjjSnackBar(context, 'Professor atualizado com sucesso!',
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao atualizar: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelf = widget.professor.uid == widget.manager.uid;
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(isSelf ? 'Editar Meu Perfil' : 'Editar Professor')),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome inválido' : null,
              ),
              const SizedBox(height: 16),
              if (isLoadingUnits)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: selectedUnitId,
                  decoration: const InputDecoration(
                    labelText: 'Unidade (Matriz/Filial)',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  ),
                  isExpanded: true,
                  hint: const Text("Selecione a Unidade"),
                  items: units.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit.id,
                      child: Text(unit['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUnitId = value;
                      selectedUnitName =
                          units.firstWhere((u) => u.id == value)['name'];
                    });
                  },
                  validator: (v) => v == null ? 'Selecione uma unidade' : null,
                ),
              if (!isSelf) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _faixa,
                  decoration: const InputDecoration(
                      labelText: 'Faixa',
                      prefixIcon: Icon(Icons.shield_outlined)),
                  hint: const Text("Selecione a Faixa"),
                  items: _faixasList
                      .map((faixa) => DropdownMenuItem(
                          value: faixa,
                          child: Text(faixa, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _faixa = value;
                    _grausList = _getGrausForFaixa(_faixa);
                    _graus = null;
                  }),
                  validator: (value) =>
                      value == null ? 'Selecione a faixa' : null,
                ),
                if (_faixa != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _graus,
                    decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Graus',
                        prefixIcon: Icon(Icons.star_outline_rounded)),
                    hint: const Text("Selecione os Graus"),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text("Nenhum")),
                      ..._grausList.map((g) => DropdownMenuItem(
                          value: g,
                          child: Text("$gº Grau",
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (value) => setState(() => _graus = value),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pesoController,
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    prefixIcon: Icon(Icons.fitness_center_rounded),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final x = double.tryParse(v.replaceAll(',', '.'));
                    return (x == null || x <= 0)
                        ? 'Peso inválido (deve ser > 0)'
                        : null;
                  },
                ),
              ],
              if (!isSelf) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon:
                            const Icon(Icons.person_remove_outlined, size: 18),
                        label: const Text("Reverter"),
                        style: TextButton.styleFrom(
                            foregroundColor: warningColor,
                            textStyle: const TextStyle(fontSize: 14)),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close edit dialog
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmar Reversão'),
                              content: Text(
                                  'Tem certeza que deseja reverter ${widget.professor.name} para a função de Aluno?'),
                              actions: [
                                TextButton(
                                  child: const Text('Cancelar'),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                                ElevatedButton(
                                  child: const Text('Confirmar'),
                                  onPressed: () {
                                    Navigator.of(ctx)
                                        .pop(); // Close confirmation
                                    UserManagementService.demoteToStudent(
                                      context,
                                      academyId: widget.academyId,
                                      teacher: widget.professor,
                                      manager: widget.manager,
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.military_tech_rounded, size: 18),
                        label: const Text("Graduar"),
                        style: TextButton.styleFrom(
                            foregroundColor: successColor,
                            textStyle: const TextStyle(fontSize: 14)),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close current dialog
                          showDialog(
                            context: context,
                            builder: (_) => GraduationDialog(
                              academyId: widget.academyId,
                              user: widget.professor,
                              currentUser: widget.manager,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24), // Espaço antes dos botões
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isSelf)
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: errorColor),
                      label: const Text('Excluir',
                          style: TextStyle(color: errorColor)),
                      onPressed: () =>
                          _confirmDeleteProfessor(widget.professor),
                    )
                  else
                    const SizedBox(), // Placeholder
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    primaryAccentForeground)))
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Salvar'),
                            ],
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdicionarProfessorDialog extends StatefulWidget {
  final String academyId;
  final UserModel manager;
  const AdicionarProfessorDialog(
      {super.key, required this.academyId, required this.manager});

  @override
  State<AdicionarProfessorDialog> createState() =>
      _AdicionarProfessorDialogState();
}

class _AdicionarProfessorDialogState extends State<AdicionarProfessorDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _faixa;
  int? _graus;
  String? selectedUnitId;
  String? selectedUnitName;
  List<DocumentSnapshot> units = [];
  bool isLoadingUnits = true;
  final List<String> _faixasList = [
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
  List<int> _grausList = [];

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
          units = snapshot.docs;
          isLoadingUnits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingUnits = false);
        showBjjSnackBar(context, 'Erro ao carregar unidades.', type: 'error');
      }
    }
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') return List.generate(10, (i) => i + 1);
    if (faixa != null) return [1, 2, 3, 4];
    return [];
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    const temporaryPassword = 'mudar123';
    final name = _nameController.text.trim().capitalizeWords();
    final email = _emailController.text.trim();

    try {
      final tempApp = await Firebase.initializeApp(
        name: 'temp_teacher_creation_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);

      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: temporaryPassword,
      );
      final newUser = userCredential.user;

      if (newUser == null) {
        await tempApp.delete();
        throw Exception("Falha ao criar a conta de autenticação.");
      }

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(newUser.uid);

      batch.set(userRef, {
        'name': name,
        'email': email,
        'academyId': widget.academyId,
        'role': 'teacher',
        'faixa': _faixa,
        'graus': _graus,
        'peso': null,
        'unitId': selectedUnitId,
        'unitName': selectedUnitName,
        'mustChangePassword': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.manager.uid,
        'createdByName': widget.manager.name,
        'lastUpdatedByUid': widget.manager.uid,
        'lastUpdatedByName': widget.manager.name,
      });

      final historyEntry = GraduationHistory(
        id: '',
        belt: _faixa!,
        degree: _graus,
        date: DateTime.now(),
        promotedByUid: widget.manager.uid,
        promotedByName: widget.manager.name,
      );
      final historyRef = userRef.collection('graduation_history').doc();
      batch.set(historyRef, historyEntry.toMap());

      await batch.commit();

      await tempApp.delete();

      // **LOG DE AUDITORIA**
      await _createAuditLog(
        academyId: widget.academyId,
        actor: widget.manager,
        actionType: 'CREATE_TEACHER',
        description: '${widget.manager.name} adicionou o professor $name.',
        targetUid: newUser.uid,
        targetName: name,
      );

      if (mounted) {
        Navigator.of(context).pop({
          'name': name,
          'email': email,
        });
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Erro ao criar professor.';
      if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está sendo usado por outra conta.';
      } else if (e.code == 'invalid-email') {
        message = 'O e-mail fornecido é inválido.';
      }
      if (mounted) showBjjSnackBar(context, message, type: 'error');
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado: $e',
            type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar Novo Professor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Professor',
                  prefixIcon: Icon(Icons.person_add_alt_1_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail (para login)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'E-mail inválido' : null,
              ),
              const SizedBox(height: 16),
              if (isLoadingUnits)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  value: selectedUnitId,
                  decoration: const InputDecoration(
                    labelText: 'Unidade (Matriz/Filial)',
                    prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  ),
                  isExpanded: true,
                  hint: const Text("Selecione a Unidade"),
                  items: units.map((unit) {
                    return DropdownMenuItem<String>(
                      value: unit.id,
                      child: Text(unit['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedUnitId = value;
                      selectedUnitName =
                          units.firstWhere((u) => u.id == value)['name'];
                    });
                  },
                  validator: (v) => v == null ? 'Selecione uma unidade' : null,
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _faixa,
                decoration: const InputDecoration(
                    labelText: 'Faixa',
                    prefixIcon: Icon(Icons.shield_outlined)),
                hint: const Text("Selecione a Faixa"),
                items: _faixasList
                    .map((faixa) => DropdownMenuItem(
                        value: faixa,
                        child: Text(faixa, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _faixa = value;
                  _grausList = _getGrausForFaixa(_faixa);
                  _graus = null;
                }),
                validator: (value) =>
                    value == null ? 'Selecione a faixa' : null,
              ),
              if (_faixa != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _graus,
                  decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Graus',
                      prefixIcon: Icon(Icons.star_outline_rounded)),
                  hint: const Text("Selecione os Graus"),
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text("Nenhum")),
                    ..._grausList.map((g) => DropdownMenuItem(
                        value: g,
                        child:
                            Text("$gº Grau", overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => setState(() => _graus = value),
                ),
              ],
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
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Adicionar'),
        ),
      ],
    );
  }
}

class MonthlyFeeManagerPage extends StatefulWidget {
  final String academyId;
  const MonthlyFeeManagerPage({super.key, required this.academyId});

  @override
  State<MonthlyFeeManagerPage> createState() => _MonthlyFeeManagerPageState();
}

class _MonthlyFeeManagerPageState extends State<MonthlyFeeManagerPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Aluno> _allStudentsWithStatus = [];
  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _fetchStudentsWithPaymentStatus();
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

  Future<void> _fetchStudentsWithPaymentStatus() async {
    setState(() => _isLoading = true);
    final now = DateTime.now();
    final firestore = FirebaseFirestore.instance;

    final studentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .orderBy('nome')
        .get();
    final students = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();

    final feesSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('paymentYear', isEqualTo: now.year)
        .where('paymentMonth', isEqualTo: now.month)
        .get();

    final feesMap = {
      for (var doc in feesSnapshot.docs)
        doc['studentId']: MonthlyFee.fromFirestore(doc)
    };

    for (var student in students) {
      final fee = feesMap[student.id];
      if (fee != null) {
        student.paymentStatus = fee.status;
      } else {
        student.paymentStatus =
            (now.day > 10) ? PaymentStatus.atrasado : PaymentStatus.pendente;
      }
    }

    if (mounted) {
      setState(() {
        _allStudentsWithStatus = students;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateMonthlyFees() async {
    setState(() => _isGenerating = true);
    final now = DateTime.now();
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    int generatedCount = 0;

    // Pega as mensalidades já geradas este mês para não duplicar
    final feesSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('paymentYear', isEqualTo: now.year)
        .where('paymentMonth', isEqualTo: now.month)
        .get();
    final existingFeeStudentIds =
        feesSnapshot.docs.map((doc) => doc['studentId']).toSet();

    for (final student in _allStudentsWithStatus) {
      if (!existingFeeStudentIds.contains(student.id)) {
        final newFeeRef = firestore
            .collection('academies')
            .doc(widget.academyId)
            .collection('monthly_fees')
            .doc();

        final fee = MonthlyFee(
          id: newFeeRef.id,
          studentId: student.id,
          studentName: student.nome,
          amount: 0, // ou um valor padrão
          paymentYear: now.year,
          paymentMonth: now.month,
          status: PaymentStatus.pendente,
        );
        batch.set(newFeeRef, fee.toMap());
        generatedCount++;
      }
    }

    if (generatedCount > 0) {
      await batch.commit();
      showBjjSnackBar(context,
          '$generatedCount novas mensalidades foram geradas para este mês!',
          type: 'success');
      _fetchStudentsWithPaymentStatus(); // Atualiza a lista
    } else {
      showBjjSnackBar(context,
          'Todos os alunos ativos já possuem mensalidades geradas para este mês.',
          type: 'info');
    }

    setState(() => _isGenerating = false);
  }

  void _showAddPaymentDialog(Aluno student) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AddPaymentDialog(academyId: widget.academyId, student: student),
    );

    if (success == true) {
      showBjjSnackBar(context, "Pagamento registrado com sucesso!",
          type: 'success');
      _fetchStudentsWithPaymentStatus();
    }
  }

  void _navigateToHistory(Aluno student) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudentPaymentHistoryPage(
          academyId: widget.academyId, student: student),
    ));
  }

  Widget _buildStatusChip(PaymentStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case PaymentStatus.pago:
        color = successColor;
        label = "Em dia";
        icon = Icons.check_circle_rounded;
        break;
      case PaymentStatus.pendente:
        color = warningColor;
        label = "Pendente";
        icon = Icons.hourglass_empty_rounded;
        break;
      case PaymentStatus.atrasado:
        color = errorColor;
        label = "Atrasado";
        icon = Icons.error_rounded;
        break;
    }

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _allStudentsWithStatus.where((student) {
      return student.nome.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ElevatedButton.icon(
            icon: _isGenerating
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryAccentForeground,
                  )
                : Icon(Icons.add_card),
            label: Text('Gerar Mensalidades do Mês'),
            onPressed: _isGenerating ? null : _generateMonthlyFees,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allStudentsWithStatus.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.no_accounts_rounded,
                      title: 'Nenhum Aluno Cadastrado',
                      message: 'Adicione alunos na aba "Gerenciar Alunos".',
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchStudentsWithPaymentStatus,
                      child: filteredStudents.isEmpty && _searchQuery.isNotEmpty
                          ? EmptyStateWidget(
                              icon: Icons.person_search,
                              title: "Nenhum Aluno Encontrado",
                              message:
                                  "Nenhum aluno corresponde à sua busca '$_searchQuery'.",
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  8.0, 8.0, 8.0, 80.0),
                              itemCount: filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = filteredStudents[index];
                                final bool isPaid =
                                    student.paymentStatus == PaymentStatus.pago;
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(student.nome,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        const Divider(
                                            height: 16, color: borderNormal),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildStatusChip(
                                                student.paymentStatus),
                                            Wrap(
                                              spacing: 0,
                                              runSpacing: 4,
                                              alignment: WrapAlignment.end,
                                              children: [
                                                if (!isPaid)
                                                  TextButton(
                                                    child:
                                                        const Text("Registrar"),
                                                    onPressed: () =>
                                                        _showAddPaymentDialog(
                                                            student),
                                                  ),
                                                TextButton(
                                                  child: const Text("Histórico",
                                                      style: TextStyle(
                                                          color: textHint)),
                                                  onPressed: () =>
                                                      _navigateToHistory(
                                                          student),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}

class StudentPaymentHistoryPage extends StatefulWidget {
  final String academyId;
  final Aluno student;
  const StudentPaymentHistoryPage(
      {super.key, required this.academyId, required this.student});

  @override
  State<StudentPaymentHistoryPage> createState() =>
      _StudentPaymentHistoryPageState();
}

class _StudentPaymentHistoryPageState extends State<StudentPaymentHistoryPage> {
  late Future<Map<int, List<PaymentRecord>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchPaymentHistory();
  }

  Future<Map<int, List<PaymentRecord>>> _fetchPaymentHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('payment_history')
        .orderBy('paymentDate', descending: true)
        .get();

    final payments = snapshot.docs
        .map((doc) => PaymentRecord.fromFirestore(doc))
        // Filtra para garantir que a nota contenha o nome do aluno
        .where((p) => p.notes?.contains(widget.student.nome) ?? false)
        .toList();

    final Map<int, List<PaymentRecord>> groupedByYear = {};
    for (var payment in payments) {
      final year = payment.paymentDate.year;
      groupedByYear.putIfAbsent(year, () => []).add(payment);
    }
    return groupedByYear;
  }

  String _getMonthName(int month) {
    return DateFormat.MMMM('pt_BR').format(DateTime(0, month));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Histórico de ${widget.student.nome}"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<Map<int, List<PaymentRecord>>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Erro: ${snapshot.error}"));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.receipt_long_rounded,
                  title: 'Nenhum Pagamento Registrado',
                  message:
                      'Este aluno ainda não possui um histórico de pagamentos.',
                );
              }

              final history = snapshot.data!;
              final years = history.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final paymentsForYear = history[year]!;

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: ExpansionTile(
                      initiallyExpanded: year == DateTime.now().year,
                      title: Text(year.toString(),
                          style: Theme.of(context).textTheme.titleLarge),
                      children: paymentsForYear.map((payment) {
                        return ListTile(
                          leading: const Icon(Icons.check_circle,
                              color: successColor),
                          title: Text(_getMonthName(payment.paymentDate.month)),
                          subtitle: Text(
                              'Pago em: ${DateFormat.yMd('pt_BR').format(payment.paymentDate)} - ${payment.paymentMethod}'),
                          trailing: Text(
                            'R\$ ${payment.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
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

class AddPaymentDialog extends StatefulWidget {
  final String academyId;
  final Aluno student;

  const AddPaymentDialog(
      {super.key, required this.academyId, required this.student});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _paymentMethod;
  bool _isLoading = false;

  final List<String> _paymentMethods = [
    'Dinheiro',
    'Pix',
    'Cartão de Débito',
    'Cartão de Crédito'
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    final batch = FirebaseFirestore.instance.batch();

    // 1. Adiciona ao histórico de pagamentos
    final newPaymentRecordRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('payment_history')
        .doc();

    batch.set(newPaymentRecordRef, {
      'amount': amount,
      'paymentDate': Timestamp.fromDate(now),
      'paymentMethod': _paymentMethod!,
      'notes': 'Mensalidade de ${widget.student.nome}',
      'recordedByUid': FirebaseAuth.instance.currentUser?.uid ?? 'manager',
    });

    // 2. Atualiza (ou cria) o registro de mensalidade do mês
    final feeQuery = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('studentId', isEqualTo: widget.student.id)
        .where('paymentYear', isEqualTo: now.year)
        .where('paymentMonth', isEqualTo: now.month)
        .limit(1)
        .get();

    if (feeQuery.docs.isNotEmpty) {
      // Atualiza a mensalidade existente
      final feeDocRef = feeQuery.docs.first.reference;
      batch.update(feeDocRef, {
        'status': PaymentStatus.pago.name,
        'paymentDate': Timestamp.fromDate(now),
        'paymentMethod': _paymentMethod!,
        'amount': amount,
      });
    } else {
      // Cria uma nova mensalidade se não existir (caso de pagamento adiantado)
      final newFeeRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('monthly_fees')
          .doc();
      final fee = MonthlyFee(
          id: newFeeRef.id,
          studentId: widget.student.id,
          studentName: widget.student.nome,
          amount: amount,
          paymentDate: now,
          paymentMethod: _paymentMethod,
          paymentYear: now.year,
          paymentMonth: now.month,
          status: PaymentStatus.pago);
      batch.set(newFeeRef, fee.toMap());
    }

    try {
      await batch.commit();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao registrar pagamento: $e",
            type: 'error');
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Registrar Pagamento para ${widget.student.nome}"),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Valor inválido';
                  final x = double.tryParse(v.replaceAll(',', '.'));
                  return (x == null || x <= 0)
                      ? 'O valor deve ser positivo'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Método de Pagamento',
                  prefixIcon: Icon(Icons.payment_rounded),
                ),
                hint: const Text("Selecione o método"),
                items: _paymentMethods
                    .map((method) =>
                        DropdownMenuItem(value: method, child: Text(method)))
                    .toList(),
                onChanged: (value) => setState(() => _paymentMethod = value),
                validator: (v) => v == null ? 'Selecione um método' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar")),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitPayment,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Confirmar"),
        ),
      ],
    );
  }
}

class StudentDetailPage extends StatefulWidget {
  final String academyId;
  final Aluno student;
  final UserModel currentUser;

  const StudentDetailPage(
      {super.key,
      required this.academyId,
      required this.student,
      required this.currentUser});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late Future<Map<String, dynamic>> _detailsFuture;
  UserModel? _studentUserModel;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchAllDetails();
  }

  Future<Map<String, dynamic>> _fetchAllDetails() async {
    final checkinsSnapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('date', descending: true)
        .get();

    final List<CheckinEntry> checkins = [];
    for (final doc in checkinsSnapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          checkins.add(CheckinEntry.fromJson(doc.id, data));
        }
      } catch (e, s) {
        debugPrint('Error parsing check-in document ${doc.id}: $e');
        debugPrintStack(stackTrace: s);
      }
    }

    final Map<String, List<CheckinEntry>> groupedByMonth = {};
    for (var checkin in checkins) {
      String monthKey = DateFormat.yMMMM('pt_BR').format(checkin.date);
      groupedByMonth.putIfAbsent(monthKey, () => []).add(checkin);
    }

    UserModel? studentUser;
    if (widget.student.userId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.student.userId!)
          .get();
      if (userDoc.exists) {
        studentUser = UserModel.fromFirestore(userDoc);
      }
    }

    return {
      'groupedCheckins': groupedByMonth,
      'studentUser': studentUser,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = widget.student.createdAt?.toDate();
    final updatedAt = widget.student.updatedAt?.toDate();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.student.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_rounded),
            tooltip: 'Histórico de Graduações',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GraduationTimelinePage(
                  academyId: widget.academyId,
                  user: widget.student,
                  currentUser: widget.currentUser,
                ),
              ));
            },
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _detailsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child:
                        Text("Erro ao carregar detalhes: ${snapshot.error}"));
              }
              if (!snapshot.hasData) {
                return const EmptyStateWidget(
                    icon: Icons.person_off, title: "Aluno não encontrado");
              }

              final details = snapshot.data!;
              final groupedCheckins =
                  details['groupedCheckins'] as Map<String, List<CheckinEntry>>;
              _studentUserModel = details['studentUser'] as UserModel?;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Informações do Aluno",
                              style: theme.textTheme.titleLarge),
                          const Divider(height: 20),
                          if (_studentUserModel != null)
                            _buildInfoRow(context, Icons.email_outlined,
                                "Email", _studentUserModel!.email),
                          if (widget.student.dataNascimento != null)
                            _buildInfoRow(
                                context,
                                Icons.cake_rounded,
                                "Aniversário",
                                '${DateFormat('dd/MM/yyyy').format(widget.student.dataNascimento!)} (${widget.student.idade} anos)'),
                          _buildInfoRow(context, Icons.shield_outlined, "Faixa",
                              widget.student.faixa),
                          if (widget.student.graus != null &&
                              widget.student.graus! > 0)
                            _buildInfoRow(context, Icons.star_outline_rounded,
                                "Graus", '${widget.student.graus}º Grau'),
                          _buildInfoRow(context, Icons.fitness_center_rounded,
                              "Peso", '${widget.student.peso} kg'),
                          const Divider(height: 20),
                          if (widget.student.createdByName != null &&
                              createdAt != null)
                            _buildInfoRow(
                                context,
                                Icons.person_add_alt_1_outlined,
                                "Criado por",
                                '${widget.student.createdByName} em ${DateFormat.yMd('pt_BR').format(createdAt)}'),
                          if (widget.student.lastUpdatedByName != null &&
                              updatedAt != null)
                            _buildInfoRow(
                                context,
                                Icons.edit_note_rounded,
                                "Última Edição",
                                '${widget.student.lastUpdatedByName} em ${DateFormat.yMd('pt_BR').format(updatedAt)}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Histórico de Treinos",
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (groupedCheckins.isEmpty)
                    const EmptyStateWidget(
                      icon: Icons.calendar_month_outlined,
                      title: 'Nenhum Treino Registrado',
                      message: 'Este aluno ainda não possui check-ins.',
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupedCheckins.keys.length,
                      itemBuilder: (context, index) {
                        final month = groupedCheckins.keys.toList()[index];
                        final checkinsInMonth = groupedCheckins[month]!;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ExpansionTile(
                            title: Text(
                                "$month (${checkinsInMonth.length} treinos)"),
                            leading: const Icon(Icons.calendar_today_rounded),
                            initiallyExpanded: index == 0,
                            children: checkinsInMonth.map((checkin) {
                              final titleText =
                                  checkin.className ?? 'Check-in Aprovado';

                              return ListTile(
                                title: Text(titleText),
                                subtitle: Text(DateFormat.yMMMEd('pt_BR')
                                    .format(checkin.date)),
                                leading: const Icon(Icons.check,
                                    color: successColor),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: textHint, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: textHint, fontSize: 13)),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfessorDetailPage extends StatefulWidget {
  final String academyId;
  final UserModel professor;
  final UserModel currentUser;

  const ProfessorDetailPage(
      {super.key,
      required this.academyId,
      required this.professor,
      required this.currentUser});

  @override
  State<ProfessorDetailPage> createState() => _ProfessorDetailPageState();
}

class _ProfessorDetailPageState extends State<ProfessorDetailPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = widget.professor.createdAt?.toDate();
    final updatedAt = widget.professor.updatedAt?.toDate();
    final isManager = widget.professor.role == UserRole.manager;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.professor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.military_tech_rounded),
            tooltip: 'Histórico de Graduações',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => GraduationTimelinePage(
                  academyId: widget.academyId,
                  user: widget.professor,
                  currentUser: widget.currentUser,
                ),
              ));
            },
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isManager
                              ? "Informações do Gerente"
                              : "Informações do Professor",
                          style: theme.textTheme.titleLarge),
                      const Divider(height: 20),
                      if (!isManager) ...[
                        _buildInfoRow(context, Icons.shield_outlined, "Faixa",
                            widget.professor.faixa ?? 'Não informada'),
                        if (widget.professor.graus != null &&
                            widget.professor.graus! > 0)
                          _buildInfoRow(context, Icons.star_outline_rounded,
                              "Graus", '${widget.professor.graus}º Grau'),
                        if (widget.professor.peso != null)
                          _buildInfoRow(context, Icons.fitness_center_rounded,
                              "Peso", '${widget.professor.peso} kg'),
                      ],
                      _buildInfoRow(context, Icons.email_outlined,
                          "E-mail de Login", widget.professor.email),
                      if (widget.professor.dataNascimento != null &&
                          widget.professor.idade != null)
                        _buildInfoRow(context, Icons.cake_rounded, "Idade",
                            '${widget.professor.idade} anos'),
                      const Divider(height: 20),
                      if (widget.professor.createdByName != null &&
                          createdAt != null)
                        _buildInfoRow(
                            context,
                            Icons.person_add_alt_1_outlined,
                            "Criado por",
                            '${widget.professor.createdByName} em ${DateFormat.yMd('pt_BR').format(createdAt)}'),
                      if (widget.professor.lastUpdatedByName != null &&
                          updatedAt != null)
                        _buildInfoRow(
                            context,
                            Icons.edit_note_rounded,
                            "Última Edição",
                            '${widget.professor.lastUpdatedByName} em ${DateFormat.yMd('pt_BR').format(updatedAt)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: textHint, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: textHint, fontSize: 13)),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerSettingsPage extends StatefulWidget {
  final UserModel user;
  const ManagerSettingsPage({super.key, required this.user});

  @override
  State<ManagerSettingsPage> createState() => _ManagerSettingsPageState();
}

class _ManagerSettingsPageState extends State<ManagerSettingsPage> {
  String? _supportPhoneNumber;
  bool _isLoadingSupportNumber = true;

  @override
  void initState() {
    super.initState();
    _fetchSupportNumber();
  }

  Future<void> _fetchSupportNumber() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('global_settings')
          .doc('support')
          .get();
      if (mounted && doc.exists && doc.data() != null) {
        setState(() {
          _supportPhoneNumber = doc.data()!['whatsapp_number'];
        });
      }
    } catch (e) {
      debugPrint("Could not fetch support number: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSupportNumber = false;
        });
      }
    }
  }

  Future<void> _launchWhatsApp() async {
    if (_supportPhoneNumber == null || _supportPhoneNumber!.isEmpty) {
      showBjjSnackBar(context, 'Número de suporte não configurado.',
          type: 'error');
      return;
    }
    final message = Uri.encodeComponent(
        'Olá, preciso de ajuda com a minha conta de gerente no Match BJJ.');
    final whatsappUrl =
        Uri.parse("https://wa.me/$_supportPhoneNumber?text=$message");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      showBjjSnackBar(context, 'Não foi possível abrir o WhatsApp.',
          type: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Configurações"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text("Perfil da Academia"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          AcademyProfilePage(academyId: widget.user.academyId),
                    ));
                  },
                ),
              ),
              const Divider(),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: const Text("Meu Perfil de Gerente"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EditUserProfilePage(user: widget.user),
                    ));
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text("Alterar Senha"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ));
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("Alterar E-mail"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ChangeEmailPage(),
                    ));
                  },
                ),
              ),
              if (!_isLoadingSupportNumber && _supportPhoneNumber != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.support_agent_rounded,
                        color: infoColor),
                    title: const Text("Falar com o Suporte"),
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: _launchWhatsApp,
                  ),
                ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: errorColor),
                  title: const Text("Sair (Deslogar)",
                      style: TextStyle(color: errorColor)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar Saída'),
                        content: const Text(
                            'Tem certeza que deseja sair do aplicativo?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await FirebaseAuth.instance.signOut();
                      Navigator.of(context, rootNavigator: true)
                          .pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const AuthGate()),
                        (route) => false,
                      );
                    }
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

class GraduationDialog extends StatefulWidget {
  final String academyId;
  final dynamic user; // Pode ser Aluno ou UserModel
  final UserModel currentUser;

  const GraduationDialog({
    super.key,
    required this.academyId,
    required this.user,
    required this.currentUser,
  });

  @override
  State<GraduationDialog> createState() => _GraduationDialogState();
}

class _GraduationDialogState extends State<GraduationDialog> {
  // Lists of belts and degrees
  final List<String> _faixasList = [
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
  List<int> _grausList = [];

  // Selected values
  String? _selectedFaixa;
  int? _selectedGrau;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFaixa = widget.user.faixa;
    _selectedGrau = widget.user.graus;
    _grausList = _getGrausForFaixa(_selectedFaixa);
  }

  // Helper to get degrees for a given belt
  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') return List.generate(10, (i) => i + 1);
    if (faixa != null) return [1, 2, 3, 4];
    return [];
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateGraduation() async {
    setState(() => _isLoading = true);
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final dataToUpdate = {
      'faixa': _selectedFaixa,
      'graus': _selectedGrau,
      'lastUpdatedByUid': widget.currentUser.uid,
      'lastUpdatedByName': widget.currentUser.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    DocumentReference mainDocRef;
    CollectionReference historyCollectionRef;

    if (widget.user is Aluno) {
      mainDocRef = firestore
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .doc(widget.user.id);
      historyCollectionRef = mainDocRef.collection('graduation_history');
    } else {
      mainDocRef = firestore.collection('users').doc(widget.user.uid);
      historyCollectionRef = mainDocRef.collection('graduation_history');
    }

    batch.update(mainDocRef, dataToUpdate);

    final historyEntry = GraduationHistory(
      id: '',
      belt: _selectedFaixa!,
      degree: _selectedGrau,
      date: _selectedDate,
      promotedByUid: widget.currentUser.uid,
      promotedByName: widget.currentUser.name,
    );
    batch.set(historyCollectionRef.doc(), historyEntry.toMap());

    try {
      await batch.commit();
      if (mounted) {
        showBjjSnackBar(context, 'Graduação atualizada!', type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao atualizar graduação: $e',
            type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user is Aluno) ? widget.user.nome : widget.user.name;
    return AlertDialog(
      title: Text('Graduar $name'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedFaixa,
              decoration: const InputDecoration(labelText: 'Faixa'),
              items: _faixasList
                  .map((faixa) => DropdownMenuItem(
                      value: faixa,
                      child: Text(faixa, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedFaixa = value;
                  _grausList = _getGrausForFaixa(value);
                  _selectedGrau = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedFaixa != null)
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedGrau,
                decoration: const InputDecoration(labelText: 'Graus'),
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text("Nenhum")),
                  ..._grausList.map((g) => DropdownMenuItem(
                      value: g,
                      child:
                          Text("$gº Grau", overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGrau = value;
                  });
                },
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da Graduação',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat.yMd('pt_BR').format(_selectedDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
          onPressed: _isLoading ? null : _updateGraduation,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class EditGraduationDialog extends StatefulWidget {
  final String academyId;
  final dynamic user;
  final UserModel currentUser;
  final GraduationHistory historyEntry;

  const EditGraduationDialog({
    super.key,
    required this.academyId,
    required this.user,
    required this.currentUser,
    required this.historyEntry,
  });

  @override
  State<EditGraduationDialog> createState() => _EditGraduationDialogState();
}

class _EditGraduationDialogState extends State<EditGraduationDialog> {
  final List<String> _faixasList = [
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
  List<int> _grausList = [];

  String? _selectedFaixa;
  int? _selectedGrau;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFaixa = widget.historyEntry.belt;
    _selectedGrau = widget.historyEntry.degree;
    _selectedDate = widget.historyEntry.date;
    _grausList = _getGrausForFaixa(_selectedFaixa);
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') return List.generate(10, (i) => i + 1);
    if (faixa != null) return [1, 2, 3, 4];
    return [];
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  CollectionReference _getHistoryCollection() {
    final userObject = widget.user;
    if (userObject is Aluno) {
      return FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .doc(userObject.id)
          .collection('graduation_history');
    } else {
      final userModel = userObject as UserModel;
      if (userModel.role == UserRole.student) {
        return FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.academyId)
            .collection('students')
            .doc(userModel.studentRecordId)
            .collection('graduation_history');
      } else {
        return FirebaseFirestore.instance
            .collection('users')
            .doc(userModel.uid)
            .collection('graduation_history');
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      await _getHistoryCollection().doc(widget.historyEntry.id).update({
        'belt': _selectedFaixa,
        'degree': _selectedGrau,
        'date': Timestamp.fromDate(_selectedDate),
        'promotedByName': widget.currentUser.name,
        'promotedByUid': widget.currentUser.uid,
      });

      if (mounted) {
        showBjjSnackBar(context, 'Registro atualizado!', type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text(
            "Tem certeza que deseja excluir este registro do histórico? Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _getHistoryCollection().doc(widget.historyEntry.id).delete();
      if (mounted) {
        showBjjSnackBar(context, 'Registro excluído!', type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao excluir: $e', type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Registro de Graduação'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedFaixa,
              decoration: const InputDecoration(labelText: 'Faixa'),
              items: _faixasList
                  .map((faixa) => DropdownMenuItem(
                      value: faixa,
                      child: Text(faixa, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) => setState(() {
                _selectedFaixa = value;
                _grausList = _getGrausForFaixa(value);
                _selectedGrau = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_selectedFaixa != null)
              DropdownButtonFormField<int>(
                isExpanded: true,
                value: _selectedGrau,
                decoration: const InputDecoration(labelText: 'Graus'),
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text("Nenhum")),
                  ..._grausList.map((g) => DropdownMenuItem(
                      value: g,
                      child:
                          Text("$gº Grau", overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) => setState(() => _selectedGrau = value),
              ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da Graduação',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat.yMd('pt_BR').format(_selectedDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isLoading ? null : _deleteEntry,
          icon: const Icon(Icons.delete_outline, color: errorColor),
          label: const Text('Excluir', style: TextStyle(color: errorColor)),
        ),
        const Spacer(),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
