// lib/manager_module.dart
// ignore_for_file: use_build_context_synchronously, unnecessary_brace_in_string_interps, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'student_module.dart';
import 'auth_gate.dart';
import 'schedule_module.dart'; // Import do novo módulo

// --- LÓGICA DE GERENCIAMENTO DE USUÁRIOS (NOVA) ---
class UserManagementService {
  /// Promove um aluno para o papel de professor.
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

    // 1. Atualiza o documento do usuário na coleção 'users'
    final userRef = firestore.collection('users').doc(aluno.userId!);
    batch.update(userRef, {
      'role': 'teacher',
      'faixa': aluno.faixa,
      'graus': aluno.graus,
      'peso': aluno.peso,
      // [CORREÇÃO] Adiciona a data de nascimento ao promover
      'dataNascimento': aluno.dataNascimento != null
          ? Timestamp.fromDate(aluno.dataNascimento!)
          : null,
      'studentRecordId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastUpdatedByUid': manager.uid,
      'lastUpdatedByName': manager.name,
    });

    // 2. Deleta o registro antigo da subcoleção 'students'
    final studentDocRef = firestore
        .collection('academies')
        .doc(academyId)
        .collection('students')
        .doc(aluno.id);
    batch.delete(studentDocRef);

    try {
      await batch.commit();
      showBjjSnackBar(context, '${aluno.nome} foi promovido a professor!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao promover aluno: $e', type: 'error');
    }
  }

  /// Reverte um professor para o papel de aluno.
  static Future<void> demoteToStudent(BuildContext context,
      {required String academyId,
      required UserModel teacher,
      required UserModel manager}) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Cria um novo registro de aluno na subcoleção 'students'
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
      // [CORREÇÃO] Adiciona a data de nascimento ao reverter
      'dataNascimento': teacher.dataNascimento != null
          ? Timestamp.fromDate(teacher.dataNascimento!)
          : null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': manager.uid,
      'createdByName': manager.name,
      'lastUpdatedByUid': manager.uid,
      'lastUpdatedByName': manager.name,
    });

    // 2. Atualiza o documento do usuário na coleção 'users'
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
      showBjjSnackBar(context, '${teacher.name} agora é um aluno!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao reverter professor: $e', type: 'error');
    }
  }
}

// --- NOVO WIDGET DE CARD DE USUÁRIO ---
class UserCard extends StatelessWidget {
  final dynamic user; // Pode ser Aluno ou UserModel
  final String academyId;
  final UserModel currentUser;

  const UserCard(
      {super.key,
      required this.user,
      required this.academyId,
      required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final bool isStudent = user is Aluno;
    final String name = isStudent ? user.nome : user.name;
    final String? belt = isStudent ? user.faixa : user.faixa;
    final int? degrees = isStudent ? user.graus : user.graus;
    final String roleText;

    if (isStudent) {
      roleText = 'Aluno';
    } else {
      // É UserModel
      if (user.role == UserRole.manager) {
        roleText = 'Gerente (Você)';
      } else {
        roleText = 'Professor';
      }
    }

    String subtitle;
    if (isStudent) {
      // Lógica para Aluno
      subtitle = belt ?? 'Faixa não definida';
      if (degrees != null && degrees > 0) {
        subtitle += ' - $degreesº Grau';
      }
    } else {
      // Lógica para UserModel (Professor ou Gerente)
      if (user.role == UserRole.manager) {
        subtitle = user.email;
      } else {
        // É Professor
        subtitle = belt ?? 'Faixa não definida';
        if (degrees != null && degrees > 0) {
          subtitle += ' - $degreesº Grau';
        }
        subtitle += ' - ${user.email}';
      }
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U'),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('$roleText\n$subtitle'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility_outlined, color: textHint),
              tooltip: 'Ver Detalhes',
              onPressed: () {
                if (isStudent) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StudentDetailPage(
                      academyId: academyId,
                      student: user,
                    ),
                  ));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfessorDetailPage(
                      academyId: academyId,
                      professor: user,
                    ),
                  ));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: primaryAccent),
              tooltip: 'Editar / Gerenciar',
              onPressed: () {
                if (isStudent) {
                  _showEditAlunoDialog(context, user, academyId, currentUser);
                } else {
                  _showEditProfessorDialog(
                      context, user, academyId, currentUser);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELAS DO GERENTE (REFATORADAS) ---

class ManagerHomePage extends StatefulWidget {
  final UserModel user;
  const ManagerHomePage({super.key, required this.user});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  int _paginaAtual = 0;
  bool _isLoading = true;
  late List<Widget> _telas;
  List<UserModel> _teachers = [];

  final List<String> _titulos = const [
    'Painel Principal',
    'Gerenciar Alunos',
    'Gerenciar Professores',
    'Grade de Horários',
    'Mensalidades'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDataAndBuildScreens();
  }

  Future<void> _fetchDataAndBuildScreens() async {
    if (!mounted) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('academyId', isEqualTo: widget.user.academyId)
          .where('role', whereIn: ['teacher', 'manager']).get();

      if (mounted) {
        setState(() {
          _teachers =
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
          _telas = [
            ManagerDashboardPage(user: widget.user),
            AlunosManagerPage(
                academyId: widget.user.academyId, manager: widget.user),
            ProfessoresManagerPage(
                academyId: widget.user.academyId, manager: widget.user),
            SchedulePage(user: widget.user, teachers: _teachers),
            MonthlyFeeManagerPage(academyId: widget.user.academyId),
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, "Erro ao carregar dados.", type: 'error');
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _paginaAtual = index;
    });
  }

  void _onAdicionarAluno() {
    showDialog(
      context: context,
      builder: (_) => AdicionarAlunoDialog(
          currentUser: widget.user,
          onAlunoAdicionado: (novoAluno) async {
            try {
              final data = novoAluno.toJson();
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

  void _onAdicionarProfessor() async {
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
      final temporaryPassword = result['password']!;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Professor Criado!"),
          content: SelectableText(
              "A conta para $name foi criada.\n\nE-mail: $email\nSenha Temporária: $temporaryPassword\n\nPeça para que ele(a) faça o login e altere a senha."),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"))
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: _paginaAtual == 0
            ? StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('academies')
                    .doc(widget.user.academyId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final academyData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    return Text(academyData['name'] ?? 'Painel Principal');
                  }
                  return Text(_titulos[_paginaAtual]);
                },
              )
            : Text(_titulos[_paginaAtual]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações da Academia',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ManagerSettingsPage(user: widget.user),
                ));
              }),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : IndexedStack(index: _paginaAtual, children: _telas),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _paginaAtual,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Alunos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: 'Professores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Grade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_rounded),
            label: 'Mensalidades',
          ),
        ],
      ),
      floatingActionButton: _paginaAtual == 1
          ? FloatingActionButton(
              onPressed: _onAdicionarAluno,
              tooltip: 'Adicionar Aluno',
              child: const Icon(Icons.add_rounded),
            )
          : _paginaAtual == 2
              ? FloatingActionButton(
                  onPressed: _onAdicionarProfessor,
                  tooltip: 'Adicionar Professor',
                  child: const Icon(Icons.add_rounded),
                )
              : null,
    );
  }
}

// O restante do arquivo manager_module.dart permanece o mesmo...
// (ManagerDashboardPage, AlunosManagerPage, ProfessoresManagerPage, etc.)
// --- Restante do arquivo inalterado ---
class ManagerDashboardPage extends StatelessWidget {
  final UserModel user;
  const ManagerDashboardPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        UserProfileHeader(user: user),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.business, color: primaryAccent),
              title: const Text("ID da sua Academia"),
              subtitle:
                  Text(user.academyId, style: const TextStyle(fontSize: 16)),
            ),
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
                  return UserCard(
                      user: aluno,
                      academyId: widget.academyId,
                      currentUser: widget.manager);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('academyId', isEqualTo: widget.academyId)
                // [MELHORIA] Alterado para buscar apenas professores
                .where('role', isEqualTo: 'teacher')
                .orderBy('name')
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

              final filteredProfessores = allProfessores.where((prof) {
                return prof.name
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
              }).toList();

              if (filteredProfessores.isEmpty && _searchQuery.isNotEmpty) {
                return EmptyStateWidget(
                  icon: Icons.person_search,
                  title: "Nenhum Professor Encontrado",
                  message:
                      "Nenhum professor corresponde à sua busca '$_searchQuery'.",
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8, 80.0),
                itemCount: filteredProfessores.length,
                itemBuilder: (context, index) {
                  final professor = filteredProfessores[index];
                  return UserCard(
                      user: professor,
                      academyId: widget.academyId,
                      currentUser: widget.manager);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

void _showEditAlunoDialog(
    BuildContext context, Aluno aluno, String academyId, UserModel manager) {
  showDialog(
    context: context,
    builder: (_) => AdicionarAlunoDialog(
      alunoParaEditar: aluno,
      academyId: academyId,
      currentUser: manager,
      onAlunoAdicionado: (alunoAtualizado) async {
        try {
          final dataToUpdate = {
            'nome': alunoAtualizado.nome,
            'faixa': alunoAtualizado.faixa,
            'peso': alunoAtualizado.peso,
            'graus': alunoAtualizado.graus,
            'dataNascimento': alunoAtualizado.dataNascimento != null
                ? Timestamp.fromDate(alunoAtualizado.dataNascimento!)
                : null,
            'lastUpdatedByUid': manager.uid,
            'lastUpdatedByName': manager.name,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('academies')
              .doc(academyId)
              .collection('students')
              .doc(alunoAtualizado.id)
              .update(dataToUpdate);

          if (alunoAtualizado.userId != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(alunoAtualizado.userId!)
                .update({'name': alunoAtualizado.nome});
          }
          if (context.mounted) {
            showBjjSnackBar(context, 'Aluno atualizado com sucesso!',
                type: 'success');
          }
        } catch (e) {
          if (context.mounted) {
            showBjjSnackBar(context, 'Erro ao atualizar aluno: $e',
                type: 'error');
          }
        }
      },
    ),
  );
}

void _showEditProfessorDialog(BuildContext context, UserModel professor,
    String academyId, UserModel manager) {
  showDialog(
    context: context,
    builder: (_) => EditarProfessorDialog(
        professor: professor, academyId: academyId, manager: manager),
  );
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
      dNascC = TextEditingController();
  String? fS;
  int? gS;
  final List<String> faixasList = [
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
  List<int> grausList = [];
  final formKey = GlobalKey<FormState>();

  bool get isEditing => widget.alunoParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final aluno = widget.alunoParaEditar!;
      nC.text = aluno.nome;
      pC.text = aluno.peso.toString();
      fS = aluno.faixa;
      gS = aluno.graus;
      if (aluno.dataNascimento != null) {
        dNascC.text = DateFormat('dd/MM/yyyy').format(aluno.dataNascimento!);
      }
      grausList = _getGrausForFaixa(fS);
    }
  }

  @override
  void dispose() {
    nC.dispose();
    pC.dispose();
    dNascC.dispose();
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
      title: Text(isEditing ? 'Editar Aluno' : 'Adicionar Novo Aluno'),
      content: SingleChildScrollView(
          child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: nC,
                    decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_add_alt_1_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nome inválido'
                        : null),
                const SizedBox(height: 16),
                // [MELHORIA] CAMPO DE DATA DE NASCIMENTO COM FORMATAÇÃO AUTOMÁTICA
                TextFormField(
                  controller: dNascC,
                  decoration: const InputDecoration(
                    labelText: 'Data de Nascimento',
                    hintText: 'DD/MM/AAAA',
                    prefixIcon: Icon(Icons.cake_rounded),
                    counterText: '', // Esconde o contador de caracteres
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    DateInputFormatter(),
                  ],
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return null; // Campo opcional
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
                    value: fS,
                    isExpanded: true,
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
                        .map((v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)))
                        .toList(),
                    validator: (v) => v == null ? 'Selecione uma faixa' : null),
                if (mostrarGrausDropdown) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                      value: gS,
                      decoration: const InputDecoration(
                          labelText: 'Graus (opcional)',
                          prefixIcon: Icon(Icons.star_outline_rounded)),
                      hint: const Text("Graus (opcional)"),
                      onChanged: (v) => setState(() => gS = v),
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text("Nenhum")),
                        ...grausList.map((v) => DropdownMenuItem<int>(
                            value: v, child: Text('$vº Grau')))
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
                if (isEditing && widget.alunoParaEditar?.userId == null) ...[
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.login_rounded, color: infoColor),
                    label: const Text("Criar Acesso de Login",
                        style: TextStyle(color: infoColor)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showCreateAccessDialog(context, widget.alunoParaEditar!,
                          widget.academyId!, widget.currentUser);
                    },
                  )
                ],
                if (isEditing && widget.alunoParaEditar?.userId != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon:
                        const Icon(Icons.school_rounded, color: primaryAccent),
                    label: const Text("Promover para Professor",
                        style: TextStyle(color: primaryAccent)),
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
                  )
                ]
              ]))),
      actions: [
        if (isEditing)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, color: errorColor),
            label: const Text('Excluir', style: TextStyle(color: errorColor)),
            onPressed: () => _confirmDeleteAluno(widget.alunoParaEditar!),
          ),
        const Spacer(),
        TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop()),
        ElevatedButton.icon(
            icon: Icon(
                isEditing ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
                size: 18),
            label: Text(isEditing ? 'Salvar' : 'Adicionar'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                DateTime? dataNascimento;
                if (dNascC.text.isNotEmpty) {
                  try {
                    dataNascimento =
                        DateFormat('dd/MM/yyyy').parseStrict(dNascC.text);
                  } catch (e) {
                    // O validador já deve ter pego isso, mas é uma segurança extra.
                    showBjjSnackBar(context, 'Formato de data inválido.',
                        type: 'error');
                    return;
                  }
                }

                final double peso = double.parse(pC.text.replaceAll(',', '.'));
                final alunoResult = Aluno(
                    id: isEditing ? widget.alunoParaEditar!.id : '',
                    nome: nC.text.trim(),
                    faixa: fS!,
                    peso: peso,
                    graus: gS,
                    dataNascimento: dataNascimento,
                    userId: isEditing ? widget.alunoParaEditar!.userId : null,
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
            })
      ],
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
  bool _isLoading = false;

  final List<String> _faixasList = [
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
  List<int> _grausList = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.professor.name);
    _pesoController =
        TextEditingController(text: widget.professor.peso?.toString() ?? '');
    _faixa = widget.professor.faixa;
    _graus = widget.professor.graus;
    if (_faixa != null) {
      _grausList = _getGrausForFaixa(_faixa);
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
      'name': _nameController.text.trim(),
      'faixa': _faixa,
      'graus': _graus,
      'peso': pesoStr.isNotEmpty ? double.tryParse(pesoStr) : null,
      'lastUpdatedByUid': widget.manager.uid,
      'lastUpdatedByName': widget.manager.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.professor.uid)
          .update(updatedData);

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
      title: Text(isSelf ? 'Editar Meu Perfil' : 'Editar Professor'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
              // [MELHORIA] Esconde campos de faixa e peso para o gerente
              if (!isSelf) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _faixa,
                  decoration: const InputDecoration(
                      labelText: 'Faixa',
                      prefixIcon: Icon(Icons.shield_outlined)),
                  hint: const Text("Selecione a Faixa"),
                  items: _faixasList
                      .map((faixa) =>
                          DropdownMenuItem(value: faixa, child: Text(faixa)))
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
                    value: _graus,
                    decoration: const InputDecoration(
                        labelText: 'Graus (opcional)',
                        prefixIcon: Icon(Icons.star_outline_rounded)),
                    hint: const Text("Selecione os Graus"),
                    items: [
                      const DropdownMenuItem<int>(
                          value: null, child: Text("Nenhum")),
                      ..._grausList.map((g) =>
                          DropdownMenuItem(value: g, child: Text("$gº Grau"))),
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_remove_outlined,
                      color: warningColor),
                  label: const Text("Reverter para Aluno",
                      style: TextStyle(color: warningColor)),
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
                              Navigator.of(ctx).pop(); // Close confirmation
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
              ]
            ],
          ),
        ),
      ),
      actions: [
        if (!isSelf)
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, color: errorColor),
            label: const Text('Excluir', style: TextStyle(color: errorColor)),
            onPressed: () => _confirmDeleteProfessor(widget.professor),
          ),
        const Spacer(),
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

void _showCreateAccessDialog(BuildContext context, Aluno aluno,
    String academyId, UserModel manager) async {
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
    const temporaryPassword = 'mudar123';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Acesso Criado!"),
        content: SelectableText(
            "A conta para ${aluno.nome} foi criada.\n\nE-mail: $email\nSenha Temporária: $temporaryPassword\n\nPeça para que ele(a) faça o login e altere a senha."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"))
        ],
      ),
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
        throw Exception("Falha ao criar la cuenta de autenticação.");
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
  final List<String> _faixasList = [
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
  List<int> _grausList = [];

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') return List.generate(10, (i) => i + 1);
    if (faixa != null) return [1, 2, 3, 4];
    return [];
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    const temporaryPassword = 'mudar123';
    final name = _nameController.text.trim();
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
        throw Exception("Falha ao criar la cuenta de autenticação.");
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUser.uid)
          .set({
        'name': name,
        'email': email,
        'academyId': widget.academyId,
        'role': 'teacher',
        'faixa': _faixa,
        'graus': _graus,
        'peso': null,
        'mustChangePassword': true,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdByUid': widget.manager.uid,
        'createdByName': widget.manager.name,
        'lastUpdatedByUid': widget.manager.uid,
        'lastUpdatedByName': widget.manager.name,
      });

      await tempApp.delete();

      if (mounted) {
        Navigator.of(context).pop({
          'name': name,
          'email': email,
          'password': temporaryPassword,
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
              DropdownButtonFormField<String>(
                value: _faixa,
                decoration: const InputDecoration(
                    labelText: 'Faixa',
                    prefixIcon: Icon(Icons.shield_outlined)),
                hint: const Text("Selecione a Faixa"),
                items: _faixasList
                    .map((faixa) =>
                        DropdownMenuItem(value: faixa, child: Text(faixa)))
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
                  value: _graus,
                  decoration: const InputDecoration(
                      labelText: 'Graus (opcional)',
                      prefixIcon: Icon(Icons.star_outline_rounded)),
                  hint: const Text("Selecione os Graus"),
                  items: [
                    const DropdownMenuItem<int>(
                        value: null, child: Text("Nenhum")),
                    ..._grausList.map((g) =>
                        DropdownMenuItem(value: g, child: Text("$gº Grau"))),
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
        .orderBy('nome')
        .get();
    final students = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();

    final paymentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('paymentYear', isEqualTo: now.year)
        .where('paymentMonth', isEqualTo: now.month)
        .get();

    final paidStudentIds =
        paymentsSnapshot.docs.map((doc) => doc['studentId'] as String).toSet();

    for (var student in students) {
      if (paidStudentIds.contains(student.id)) {
        student.paymentStatus = PaymentStatus.pago;
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
  late Future<Map<int, List<MonthlyFee>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchPaymentHistory();
  }

  Future<Map<int, List<MonthlyFee>>> _fetchPaymentHistory() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('monthly_fees')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('paymentDate', descending: true)
        .get();

    final payments =
        snapshot.docs.map((doc) => MonthlyFee.fromFirestore(doc)).toList();

    final Map<int, List<MonthlyFee>> groupedByYear = {};
    for (var payment in payments) {
      groupedByYear.putIfAbsent(payment.paymentYear, () => []).add(payment);
    }
    return groupedByYear;
  }

  String _getMonthName(int month) {
    return DateFormat.MMMM('pt_BR').format(DateTime(0, month)).capitalize();
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
          child: FutureBuilder<Map<int, List<MonthlyFee>>>(
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
                          title: Text(_getMonthName(payment.paymentMonth)),
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
    final newPayment = MonthlyFee(
      id: '',
      studentId: widget.student.id,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      paymentDate: now,
      paymentMethod: _paymentMethod!,
      paymentYear: now.year,
      paymentMonth: now.month,
    );

    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('monthly_fees')
          .add(newPayment.toMap());

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

  const StudentDetailPage(
      {super.key, required this.academyId, required this.student});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  late Future<Map<String, List<CheckinEntry>>> _checkinsFuture;

  @override
  void initState() {
    super.initState();
    _checkinsFuture = _fetchAndGroupCheckins();
  }

  // [MELHORIA] CORREÇÃO DE CRASH
  // Adicionado try-catch para evitar que um documento malformado no Firestore
  // cause o travamento do aplicativo.
  Future<Map<String, List<CheckinEntry>>> _fetchAndGroupCheckins() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('date', descending: true)
        .get();

    final List<CheckinEntry> checkins = [];
    for (final doc in snapshot.docs) {
      try {
        // Tenta converter o documento. Se falhar, o erro é capturado e o loop continua.
        checkins.add(CheckinEntry.fromJson(doc.id, doc.data()));
      } catch (e, s) {
        // Imprime o erro no console para depuração.
        // Em um app de produção, isso poderia ser enviado para um serviço de log.
        debugPrint('Error parsing check-in document ${doc.id}: $e');
        debugPrintStack(stackTrace: s);
      }
    }

    final Map<String, List<CheckinEntry>> groupedByMonth = {};
    for (var checkin in checkins) {
      String monthKey =
          DateFormat.yMMMM('pt_BR').format(checkin.date).capitalize();
      groupedByMonth.putIfAbsent(monthKey, () => []).add(checkin);
    }
    return groupedByMonth;
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
                      Text("Informações do Aluno",
                          style: theme.textTheme.titleLarge),
                      const Divider(height: 20),
                      _buildInfoRow(context, Icons.shield_outlined, "Faixa",
                          widget.student.faixa),
                      if (widget.student.graus != null &&
                          widget.student.graus! > 0)
                        _buildInfoRow(context, Icons.star_outline_rounded,
                            "Graus", '${widget.student.graus}º Grau'),
                      _buildInfoRow(context, Icons.fitness_center_rounded,
                          "Peso", '${widget.student.peso} kg'),
                      // [MELHORIA] Exibe a idade do aluno se a data de nascimento existir
                      if (widget.student.dataNascimento != null)
                        _buildInfoRow(context, Icons.cake_rounded, "Idade",
                            '${widget.student.idade} anos'),
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
              Text("Histórico de Treinos", style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<Map<String, List<CheckinEntry>>>(
                future: _checkinsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Text(
                            "Erro ao carregar treinos: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.calendar_month_outlined,
                      title: 'Nenhum Treino Registrado',
                      message: 'Este aluno ainda não possui check-ins.',
                    );
                  }

                  final groupedCheckins = snapshot.data!;
                  final months = groupedCheckins.keys.toList();

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      final month = months[index];
                      final checkinsInMonth = groupedCheckins[month]!;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ExpansionTile(
                          title: Text(
                              "$month (${checkinsInMonth.length} treinos)"),
                          leading: const Icon(Icons.calendar_today_rounded),
                          initiallyExpanded: index == 0,
                          children: checkinsInMonth.map((checkin) {
                            return ListTile(
                              title: Text(DateFormat.yMMMEd('pt_BR')
                                  .format(checkin.date)),
                              leading:
                                  const Icon(Icons.check, color: successColor),
                            );
                          }).toList(),
                        ),
                      );
                    },
                  );
                },
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

class ProfessorDetailPage extends StatelessWidget {
  final String academyId;
  final UserModel professor;

  const ProfessorDetailPage(
      {super.key, required this.academyId, required this.professor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final createdAt = professor.createdAt?.toDate();
    final updatedAt = professor.updatedAt?.toDate();
    final isManager = professor.role == UserRole.manager;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(professor.name),
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
                            professor.faixa ?? 'Não informada'),
                        if (professor.graus != null && professor.graus! > 0)
                          _buildInfoRow(context, Icons.star_outline_rounded,
                              "Graus", '${professor.graus}º Grau'),
                        if (professor.peso != null)
                          _buildInfoRow(context, Icons.fitness_center_rounded,
                              "Peso", '${professor.peso} kg'),
                      ],
                      _buildInfoRow(context, Icons.email_outlined,
                          "E-mail de Login", professor.email),
                      // [MELHORIA] Exibe a idade do professor se a data de nascimento existir
                      if (professor.dataNascimento != null &&
                          professor.idade != null)
                        _buildInfoRow(context, Icons.cake_rounded, "Idade",
                            '${professor.idade} anos'),
                      const Divider(height: 20),
                      if (professor.createdByName != null && createdAt != null)
                        _buildInfoRow(
                            context,
                            Icons.person_add_alt_1_outlined,
                            "Criado por",
                            '${professor.createdByName} em ${DateFormat.yMd('pt_BR').format(createdAt)}'),
                      if (professor.lastUpdatedByName != null &&
                          updatedAt != null)
                        _buildInfoRow(
                            context,
                            Icons.edit_note_rounded,
                            "Última Edição",
                            '${professor.lastUpdatedByName} em ${DateFormat.yMd('pt_BR').format(updatedAt)}'),
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

// NOVA PÁGINA DE CONFIGURAÇÕES DO GERENTE
class ManagerSettingsPage extends StatelessWidget {
  final UserModel user;
  const ManagerSettingsPage({super.key, required this.user});

  void _showChangeAcademyNameDialog(BuildContext context) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Alterar Nome da Academia'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Novo nome'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'O nome não pode ser vazio.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newName = nameController.text.trim();
                  try {
                    await FirebaseFirestore.instance
                        .collection('academies')
                        .doc(user.academyId)
                        .update({'name': newName});
                    Navigator.of(context).pop();
                    showBjjSnackBar(context, 'Nome da academia atualizado!',
                        type: 'success');
                  } catch (e) {
                    showBjjSnackBar(context, 'Erro ao atualizar nome.',
                        type: 'error');
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Configurações da Academia"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business_rounded),
                  title: const Text("Alterar Nome da Academia"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () => _showChangeAcademyNameDialog(context),
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
                      builder: (_) => EditUserProfilePage(user: user),
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
                    if (confirm == true) {
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
