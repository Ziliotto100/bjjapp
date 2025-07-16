// lib/manager_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'student_module.dart';
import 'auth_gate.dart'; // Import adicionado para ChangePasswordPage e ChangeEmailPage

// --- TELAS DO GERENTE ---
class ManagerHomePage extends StatefulWidget {
  final UserModel user;
  const ManagerHomePage({super.key, required this.user});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  int _paginaAtual = 0;
  late final List<Widget> _telas;
  final List<String> _titulos = const [
    'Painel Principal',
    'Gerenciar Alunos',
    'Gerenciar Professores',
    'Mensalidades'
  ];

  @override
  void initState() {
    super.initState();
    _telas = [
      ManagerDashboardPage(user: widget.user),
      AlunosManagerPage(academyId: widget.user.academyId),
      ProfessoresManagerPage(academyId: widget.user.academyId),
      MonthlyFeeManagerPage(academyId: widget.user.academyId),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _paginaAtual = index;
    });
  }

  void _onAdicionarAluno() {
    showDialog(
      context: context,
      builder: (_) =>
          AdicionarAlunoDialog(onAlunoAdicionado: (novoAluno) async {
        try {
          await FirebaseFirestore.instance
              .collection('academies')
              .doc(widget.user.academyId)
              .collection('students')
              .add(novoAluno.toJson());

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
        title: Text(_titulos[_paginaAtual]),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configurações',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    user: widget.user,
                    onGoToChangePassword: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ));
                    },
                    onGoToChangeEmail: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ChangeEmailPage(),
                      ));
                    },
                  ),
                ));
              }),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: IndexedStack(index: _paginaAtual, children: _telas),
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
  const AlunosManagerPage({super.key, required this.academyId});

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

  Future<void> _updateAluno(Aluno aluno) async {
    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('students')
          .doc(aluno.id)
          .update(aluno.toJson());

      if (aluno.userId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(aluno.userId!)
            .update({'name': aluno.nome});
      }

      if (mounted) {
        showBjjSnackBar(context, 'Aluno atualizado com sucesso!',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao atualizar aluno: $e', type: 'error');
      }
    }
  }

  void _showEditAlunoDialog(Aluno aluno) {
    showDialog(
      context: context,
      builder: (_) => AdicionarAlunoDialog(
        alunoParaEditar: aluno,
        onAlunoAdicionado: _updateAluno,
      ),
    );
  }

  Future<void> _deleteAluno(Aluno aluno) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final studentDocRef = firestore
          .collection('academies')
          .doc(widget.academyId)
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
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente o aluno ${aluno.nome}? Esta ação removerá o aluno da lista e também seu acesso de login, caso exista. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: errorColor, foregroundColor: Colors.white),
            child: const Text("Excluir"),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAluno(aluno);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateAccessDialog(Aluno aluno) async {
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => CreateStudentAccessDialog(
        academyId: widget.academyId,
        aluno: aluno,
      ),
    );

    if (result?['success'] == true && mounted) {
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
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(aluno.nome,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 2),
                                    Text('${aluno.faixa} - ${aluno.peso}kg',
                                        style:
                                            const TextStyle(color: textHint)),
                                  ],
                                ),
                              ),
                              if (aluno.userId != null)
                                const Tooltip(
                                  message: "Acesso de aluno já criado",
                                  child: Icon(Icons.check_circle,
                                      color: successColor),
                                ),
                            ],
                          ),
                          const Divider(height: 16, color: borderNormal),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 20, color: textHint),
                                label: const Text("Ver",
                                    style: TextStyle(color: textHint)),
                                onPressed: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                  builder: (_) => StudentDetailPage(
                                    academyId: widget.academyId,
                                    student: aluno,
                                  ),
                                )),
                              ),
                              if (aluno.userId == null)
                                TextButton.icon(
                                  icon:
                                      const Icon(Icons.login_rounded, size: 20),
                                  label: const Text("Criar Acesso"),
                                  onPressed: () =>
                                      _showCreateAccessDialog(aluno),
                                ),
                              const Spacer(),
                              Tooltip(
                                message: 'Editar Aluno',
                                child: IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showEditAlunoDialog(aluno),
                                ),
                              ),
                              Tooltip(
                                message: 'Excluir Aluno',
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: errorColor),
                                  onPressed: () => _confirmDeleteAluno(aluno),
                                ),
                              ),
                            ],
                          )
                        ],
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

class AdicionarAlunoDialog extends StatefulWidget {
  final Function(Aluno) onAlunoAdicionado;
  final Aluno? alunoParaEditar;
  const AdicionarAlunoDialog(
      {super.key, required this.onAlunoAdicionado, this.alunoParaEditar});
  @override
  State<AdicionarAlunoDialog> createState() => _AdicionarAlunoDialogState();
}

class _AdicionarAlunoDialogState extends State<AdicionarAlunoDialog> {
  final nC = TextEditingController(), pC = TextEditingController();
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
      grausList = _getGrausForFaixa(fS);
    }
  }

  List<int> _getGrausForFaixa(String? faixa) {
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
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
              ]))),
      actions: [
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
                final double peso = double.parse(pC.text.replaceAll(',', '.'));
                final alunoResult = Aluno(
                  id: isEditing ? widget.alunoParaEditar!.id : '',
                  nome: nC.text.trim(),
                  faixa: fS!,
                  peso: peso,
                  graus: gS,
                  userId: isEditing ? widget.alunoParaEditar!.userId : null,
                );

                widget.onAlunoAdicionado(alunoResult);
                Navigator.of(context).pop();
              }
            })
      ],
    );
  }
}

class CreateStudentAccessDialog extends StatefulWidget {
  final String academyId;
  final Aluno aluno;
  const CreateStudentAccessDialog(
      {super.key, required this.academyId, required this.aluno});

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
        'createdAt': FieldValue.serverTimestamp(),
        'mustChangePassword': true,
        'isActive': true,
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

class ProfessoresManagerPage extends StatefulWidget {
  final String academyId;
  const ProfessoresManagerPage({super.key, required this.academyId});

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

  void _showEditProfessorDialog(UserModel professor) {
    showDialog(
      context: context,
      builder: (_) => EditarProfessorDialog(professor: professor),
    );
  }

  Future<void> _deleteProfessor(UserModel professor) async {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente o professor ${professor.name}? Esta ação removerá seu acesso de login. Esta ação não pode ser desfeita."),
        actions: [
          TextButton(
            child: const Text("Cancelar"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: errorColor, foregroundColor: Colors.white),
            child: const Text("Excluir"),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteProfessor(professor);
            },
          ),
        ],
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
                padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                itemCount: filteredProfessores.length,
                itemBuilder: (context, index) {
                  final professor = filteredProfessores[index];
                  return Card(
                    child: ListTile(
                      leading:
                          const CircleAvatar(child: Icon(Icons.school_rounded)),
                      title: Text(professor.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                          "${professor.faixa ?? 'Faixa não definida'} - ${professor.email}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _showEditProfessorDialog(professor),
                            tooltip: 'Editar Professor',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: errorColor),
                            onPressed: () => _confirmDeleteProfessor(professor),
                            tooltip: 'Excluir Professor',
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
      ],
    );
  }
}

class AdicionarProfessorDialog extends StatefulWidget {
  final String academyId;
  const AdicionarProfessorDialog({super.key, required this.academyId});

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
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
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
        'createdAt': FieldValue.serverTimestamp(),
        'mustChangePassword': true,
        'isActive': true,
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

class EditarProfessorDialog extends StatefulWidget {
  final UserModel professor;
  const EditarProfessorDialog({super.key, required this.professor});

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

  final List<String> _faixasList = ['Azul', 'Roxa', 'Marrom', 'Preta'];
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
    if (faixa == 'Preta') {
      return List.generate(10, (i) => i + 1);
    }
    if (faixa != null) {
      return [1, 2, 3, 4];
    }
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    final pesoStr = _pesoController.text.replaceAll(',', '.');
    final Map<String, dynamic> updatedData = {
      'name': _nameController.text.trim(),
      'faixa': _faixa,
      'graus': _graus,
      'peso': pesoStr.isNotEmpty ? double.tryParse(pesoStr) : null,
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar Professor ${widget.professor.name}'),
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
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome inválido' : null,
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
              : const Text('Salvar'),
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

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
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
    if (!_formKey.currentState!.validate()) {
      return;
    }
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

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao registrar pagamento: $e",
            type: 'error');
        Navigator.of(context).pop(false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  Future<Map<String, List<CheckinEntry>>> _fetchAndGroupCheckins() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('checkins')
        .where('studentId', isEqualTo: widget.student.id)
        .orderBy('date', descending: true)
        .get();

    final checkins = snapshot.docs
        .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
        .toList();

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
          Icon(icon, color: primaryAccent, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: textHint, fontSize: 13)),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
