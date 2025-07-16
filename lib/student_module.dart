// lib/student_module.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'scoreboard_module.dart';
import 'study_notebook_module.dart';
import 'auth_gate.dart'; // Import necessário para a navegação

// --- TELAS DO ALUNO ---
class StudentHomePage extends StatefulWidget {
  final UserModel user;
  const StudentHomePage({super.key, required this.user});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _paginaAtual = 0;
  late List<Widget> _telas;
  List<Aluno> _todosOsAlunosDaAcademia = [];
  bool _isLoading = true;

  final List<String> _titulos = const [
    'Meu Perfil',
    'Histórico',
    'Caderno de Estudos',
    'Placar Individual'
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;

      final studentsSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .orderBy('nome')
          .get();
      final studentParticipants = studentsSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      final teachersSnapshot = await firestore
          .collection('users')
          .where('academyId', isEqualTo: academyId)
          .where('role', isEqualTo: 'teacher')
          .get();
      final teacherParticipants = teachersSnapshot.docs
          .map((doc) => Aluno.fromUserModel(UserModel.fromFirestore(doc)))
          .toList();

      final allParticipants = [...studentParticipants, ...teacherParticipants];
      allParticipants.sort((a, b) => a.nome.compareTo(b.nome));

      if (mounted) {
        setState(() {
          _todosOsAlunosDaAcademia = allParticipants;
          _buildScreens();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar dados da academia.',
            type: 'error');
        _buildScreens();
      }
    }
  }

  void _buildScreens() {
    _telas = [
      StudentProfilePage(user: widget.user),
      MyCheckinsPage(user: widget.user),
      StudyNotebookPage(userId: widget.user.uid),
      MatchSetupPage(
          academyId: widget.user.academyId,
          todosAlunosDaAcademia: _todosOsAlunosDaAcademia),
    ];
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
              icon: Icon(Icons.person_rounded), label: 'Meu Perfil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_rounded), label: 'Histórico'),
          BottomNavigationBarItem(
              icon: Icon(Icons.book_rounded), label: 'Estudos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.scoreboard_rounded), label: 'Placar'),
        ],
      ),
    );
  }
}

class StudentProfilePage extends StatefulWidget {
  final UserModel user;
  const StudentProfilePage({super.key, required this.user});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  Aluno? _aluno;
  MonthlyFee? _currentMonthFee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (widget.user.studentRecordId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;
      final studentId = widget.user.studentRecordId!;
      final now = DateTime.now();

      final doc = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .doc(studentId)
          .get();

      MonthlyFee? fee;
      final paymentSnapshot = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('monthly_fees')
          .where('studentId', isEqualTo: studentId)
          .where('paymentYear', isEqualTo: now.year)
          .where('paymentMonth', isEqualTo: now.month)
          .limit(1)
          .get();

      if (paymentSnapshot.docs.isNotEmpty) {
        fee = MonthlyFee.fromFirestore(paymentSnapshot.docs.first);
      }

      if (mounted) {
        if (doc.exists) {
          setState(() {
            _aluno = Aluno.fromJson(doc.id, doc.data()!);
            _currentMonthFee = fee;
          });
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar dados do perfil.",
            type: 'error');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_aluno == null) {
      return const EmptyStateWidget(
        icon: Icons.person_add_alt_1_rounded,
        title: "Complete seu Perfil",
        message:
            "Vá para as Configurações para preencher seus dados de aluno e ter acesso a todas as funcionalidades.",
      );
    }

    final bool isPaid = _currentMonthFee != null;

    return RefreshIndicator(
      onRefresh: _loadStudentData,
      child: ListView(
        children: [
          UserProfileHeader(user: widget.user, studentData: _aluno),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: ListTile(
                leading: Icon(
                  isPaid
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: isPaid ? successColor : warningColor,
                  size: 30,
                ),
                title: const Text("Status da Mensalidade",
                    style: TextStyle(color: textHint)),
                subtitle: Text(
                  isPaid
                      ? 'Paga em ${DateFormat.yMd('pt_BR').format(_currentMonthFee!.paymentDate)}'
                      : 'Pendente para este mês',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: textPrimary),
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.fitness_center_rounded,
                    color: primaryAccent, size: 30),
                title: const Text("Peso", style: TextStyle(color: textHint)),
                subtitle: Text(
                  '${_aluno!.peso.toStringAsFixed(1)} kg',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EditStudentProfilePage extends StatefulWidget {
  final UserModel user;
  const EditStudentProfilePage({super.key, required this.user});

  @override
  State<EditStudentProfilePage> createState() => _EditStudentProfilePageState();
}

class _EditStudentProfilePageState extends State<EditStudentProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  String? _faixa;
  int? _graus;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _newProfileImagePath;

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
    _loadStudentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
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

  Future<void> _loadStudentData() async {
    if (widget.user.studentRecordId == null) {
      _nameController.text = widget.user.name;
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .doc(widget.user.studentRecordId)
          .get();

      if (mounted && doc.exists) {
        final aluno = Aluno.fromJson(doc.id, doc.data()!);
        _nameController.text = aluno.nome;
        _weightController.text = aluno.peso.toString();
        _faixa = aluno.faixa;
        _graus = aluno.graus;
        _grausList = _getGrausForFaixa(_faixa);
      } else if (mounted) {
        _nameController.text = widget.user.name;
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar dados do perfil.",
            type: 'error');
        _nameController.text = widget.user.name;
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );

    if (pickedFile != null) {
      setState(() {
        _newProfileImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user.studentRecordId == null) {
      showBjjSnackBar(context,
          "Seu perfil de aluno ainda não foi criado pelo gerente. Contate sua academia.",
          type: 'error');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final studentRef = firestore
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .doc(widget.user.studentRecordId!);

      batch.update(studentRef, {
        'nome': _nameController.text.trim(),
        'peso': double.parse(_weightController.text.replaceAll(',', '.')),
        'faixa': _faixa,
        'graus': _graus,
      });

      final userRef = firestore.collection('users').doc(widget.user.uid);
      final Map<String, dynamic> userUpdateData = {};

      if (_nameController.text.trim() != widget.user.name) {
        userUpdateData['name'] = _nameController.text.trim();
      }

      if (_newProfileImagePath != null) {
        userUpdateData['profileImagePath'] = _newProfileImagePath;
      }

      if (userUpdateData.isNotEmpty) {
        batch.update(userRef, userUpdateData);
      }

      await batch.commit();

      if (mounted) {
        showBjjSnackBar(context, "Perfil atualizado com sucesso!",
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao atualizar perfil: $e", type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Editar Perfil")),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor:
                                      primaryAccent.withOpacity(0.2),
                                  backgroundImage: _newProfileImagePath != null
                                      ? FileImage(File(_newProfileImagePath!))
                                      : (widget.user.profileImagePath != null
                                          ? FileImage(File(
                                              widget.user.profileImagePath!))
                                          : null),
                                  child: _newProfileImagePath == null &&
                                          widget.user.profileImagePath == null
                                      ? const Icon(Icons.person,
                                          size: 60, color: primaryAccent)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    backgroundColor:
                                        Theme.of(context).cardColor,
                                    child: IconButton(
                                      icon:
                                          const Icon(Icons.camera_alt_outlined),
                                      onPressed: _pickImage,
                                      tooltip: 'Alterar foto',
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                                labelText: 'Nome Completo'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Nome não pode ser vazio'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _weightController,
                            decoration:
                                const InputDecoration(labelText: 'Peso (kg)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Peso inválido';
                              }
                              final x = double.tryParse(v.replaceAll(',', '.'));
                              return (x == null || x <= 0)
                                  ? 'Peso inválido (deve ser > 0)'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _faixa,
                            decoration:
                                const InputDecoration(labelText: 'Faixa'),
                            items: _faixasList
                                .map((faixa) => DropdownMenuItem(
                                    value: faixa, child: Text(faixa)))
                                .toList(),
                            onChanged: (value) => setState(() {
                              _faixa = value;
                              _grausList = _getGrausForFaixa(_faixa);
                              _graus = null;
                            }),
                            validator: (value) =>
                                value == null ? 'Selecione sua faixa' : null,
                          ),
                          if (_faixa != null) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              value: _graus,
                              decoration: const InputDecoration(
                                  labelText: 'Graus (opcional)'),
                              items: [
                                const DropdownMenuItem<int>(
                                    value: null, child: Text("Nenhum")),
                                ..._grausList.map((g) => DropdownMenuItem(
                                    value: g, child: Text("$gº Grau"))),
                              ],
                              onChanged: (value) =>
                                  setState(() => _graus = value),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _isSaving
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _updateProfile,
                                  icon: const Icon(Icons.save),
                                  label: const Text("Salvar Alterações"),
                                  style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16)),
                                ),
                        ],
                      ),
                    )
                  ],
                ),
        ),
      ),
    );
  }
}

class MyCheckinsPage extends StatefulWidget {
  final UserModel user;
  const MyCheckinsPage({super.key, required this.user});

  @override
  State<MyCheckinsPage> createState() => _MyCheckinsPageState();
}

class _MyCheckinsPageState extends State<MyCheckinsPage> {
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final studentId = widget.user.studentRecordId;
    if (studentId == null) {
      return const EmptyStateWidget(
          icon: Icons.link_off,
          title: "Perfil não vinculado",
          message:
              "Seu login não está vinculado a um registro de aluno. Complete seu perfil na primeira aba.");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('checkins')
          .where('studentId', isEqualTo: studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allCheckins = snapshot.data?.docs
                .map((doc) => CheckinEntry.fromJson(
                    doc.id, doc.data() as Map<String, dynamic>))
                .toList() ??
            [];

        final eventosAgrupados = <DateTime, List<CheckinEntry>>{};
        for (var checkin in allCheckins) {
          final dataNormalizada = DateTime.utc(
              checkin.date.year, checkin.date.month, checkin.date.day);
          eventosAgrupados.putIfAbsent(dataNormalizada, () => []).add(checkin);
        }

        final checkinsForFocusedMonth = allCheckins.where((checkin) {
          return checkin.date.month == _focusedDay.month &&
              checkin.date.year == _focusedDay.year;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Treinos em ${DateFormat.yMMMM('pt_BR').format(_focusedDay)}: ${checkinsForFocusedMonth.length}',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: primaryAccent),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Card(
                  child: TableCalendar<CheckinEntry>(
                    locale: 'pt_BR',
                    firstDay: DateTime.utc(DateTime.now().year - 5, 1, 1),
                    lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: CalendarFormat.month,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    eventLoader: (day) =>
                        eventosAgrupados[
                            DateTime.utc(day.year, day.month, day.day)] ??
                        [],
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isNotEmpty) {
                          return Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: successColor),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      todayDecoration: BoxDecoration(
                          color: primaryAccent.withOpacity(0.3),
                          shape: BoxShape.circle),
                      selectedDecoration: const BoxDecoration(
                          color: primaryAccent, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class SettingsPage extends StatelessWidget {
  final UserModel user;
  final VoidCallback onGoToChangePassword;
  final VoidCallback onGoToChangeEmail;

  const SettingsPage({
    super.key,
    required this.user,
    required this.onGoToChangePassword,
    required this.onGoToChangeEmail,
  });

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
              if (user.role == UserRole.student ||
                  user.role == UserRole.teacher ||
                  user.role == UserRole.manager)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text("Meu Perfil"),
                    trailing:
                        const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UserProfilePage(user: user),
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
                  onTap: onGoToChangePassword,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("Alterar E-mail"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: onGoToChangeEmail,
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

class UserProfilePage extends StatefulWidget {
  final UserModel user;
  const UserProfilePage({super.key, required this.user});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Aluno? _aluno;
  MonthlyFee? _currentMonthFee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (widget.user.role == UserRole.student &&
        widget.user.studentRecordId != null) {
      try {
        final firestore = FirebaseFirestore.instance;
        final academyId = widget.user.academyId;
        final studentId = widget.user.studentRecordId!;
        final now = DateTime.now();

        final doc = await firestore
            .collection('academies')
            .doc(academyId)
            .collection('students')
            .doc(studentId)
            .get();

        if (doc.exists) {
          _aluno = Aluno.fromJson(doc.id, doc.data()!);
        }

        final paymentSnapshot = await firestore
            .collection('academies')
            .doc(academyId)
            .collection('monthly_fees')
            .where('studentId', isEqualTo: studentId)
            .where('paymentYear', isEqualTo: now.year)
            .where('paymentMonth', isEqualTo: now.month)
            .limit(1)
            .get();

        if (paymentSnapshot.docs.isNotEmpty) {
          _currentMonthFee =
              MonthlyFee.fromFirestore(paymentSnapshot.docs.first);
        }
      } catch (e) {
        if (mounted) {
          showBjjSnackBar(context, "Erro ao carregar dados do perfil.",
              type: 'error');
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToEditPage() {
    if (widget.user.role == UserRole.student) {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => EditStudentProfilePage(user: widget.user),
          ))
          .then((_) => _loadProfileData());
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(
            builder: (_) => EditUserProfilePage(user: widget.user),
          ))
          .then((_) => _loadProfileData());
    }
  }

  String _formatRole(UserRole role) {
    switch (role) {
      case UserRole.student:
        return "Aluno";
      case UserRole.teacher:
        return "Professor";
      case UserRole.manager:
        return "Gerente";
      default:
        return "N/D";
    }
  }

  String _formatGraduation(UserModel user, Aluno? aluno) {
    String belt = "";
    int? degrees;

    if (user.role == UserRole.student && aluno != null) {
      belt = aluno.faixa;
      degrees = aluno.graus;
    } else {
      belt = user.faixa ?? "Não informada";
      degrees = user.graus;
    }

    if (degrees != null && degrees > 0) {
      return '$belt - $degreesº Grau';
    }
    return belt;
  }

  String _formatWeight(UserModel user, Aluno? aluno) {
    double? weight;
    if (user.role == UserRole.student && aluno != null) {
      weight = aluno.peso;
    } else {
      weight = user.peso;
    }

    if (weight != null) {
      return '${weight.toStringAsFixed(1)} kg';
    }
    return 'Não informado';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text("Meu Perfil"),
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadProfileData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: primaryAccent.withOpacity(0.2),
                          backgroundImage: widget.user.profileImagePath !=
                                      null &&
                                  widget.user.profileImagePath!.isNotEmpty
                              ? FileImage(File(widget.user.profileImagePath!))
                              : null,
                          child: widget.user.profileImagePath == null ||
                                  widget.user.profileImagePath!.isEmpty
                              ? const Icon(Icons.account_circle,
                                  size: 100, color: primaryAccent)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          widget.user.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Chip(
                          avatar: const Icon(Icons.verified_user_outlined,
                              size: 18),
                          label: Text(_formatRole(widget.user.role)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.email_outlined,
                              color: primaryAccent, size: 30),
                          title: const Text("E-mail de Login",
                              style: TextStyle(color: textHint)),
                          subtitle: Text(
                            widget.user.email,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: textPrimary),
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.shield_outlined,
                              color: primaryAccent, size: 30),
                          title: const Text("Graduação",
                              style: TextStyle(color: textHint)),
                          subtitle: Text(
                            _formatGraduation(widget.user, _aluno),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: textPrimary),
                          ),
                        ),
                      ),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.fitness_center_rounded,
                              color: primaryAccent, size: 30),
                          title: const Text("Peso",
                              style: TextStyle(color: textHint)),
                          subtitle: Text(
                            _formatWeight(widget.user, _aluno),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: textPrimary),
                          ),
                        ),
                      ),
                      if (widget.user.role == UserRole.student)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              _currentMonthFee != null
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.error_outline_rounded,
                              color: _currentMonthFee != null
                                  ? successColor
                                  : warningColor,
                              size: 30,
                            ),
                            title: const Text("Status da Mensalidade",
                                style: TextStyle(color: textHint)),
                            subtitle: Text(
                              _currentMonthFee != null
                                  ? 'Paga em ${DateFormat.yMd('pt_BR').format(_currentMonthFee!.paymentDate)}'
                                  : 'Pendente para este mês',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: textPrimary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToEditPage,
        tooltip: 'Editar Perfil',
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class EditUserProfilePage extends StatefulWidget {
  final UserModel user;
  const EditUserProfilePage({super.key, required this.user});

  @override
  State<EditUserProfilePage> createState() => _EditUserProfilePageState();
}

class _EditUserProfilePageState extends State<EditUserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  String? _faixa;
  int? _graus;
  bool _isSaving = false;
  String? _newProfileImagePath;

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
    _nameController.text = widget.user.name;
    _weightController.text = widget.user.peso?.toString() ?? '';
    _faixa = widget.user.faixa;
    _graus = widget.user.graus;
    _grausList = _getGrausForFaixa(_faixa);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 600,
    );

    if (pickedFile != null) {
      setState(() {
        _newProfileImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

      final updateData = {
        'name': _nameController.text.trim(),
        'peso': double.tryParse(_weightController.text.replaceAll(',', '.')) ??
            widget.user.peso,
        'faixa': _faixa,
        'graus': _graus,
      };

      if (_newProfileImagePath != null) {
        updateData['profileImagePath'] = _newProfileImagePath;
      }

      await userRef.update(updateData);

      if (mounted) {
        showBjjSnackBar(context, "Perfil atualizado com sucesso!",
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao atualizar perfil: $e", type: 'error');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Editar Perfil")),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: primaryAccent.withOpacity(0.2),
                            backgroundImage: _newProfileImagePath != null
                                ? FileImage(File(_newProfileImagePath!))
                                : (widget.user.profileImagePath != null &&
                                        widget.user.profileImagePath!.isNotEmpty
                                    ? FileImage(
                                        File(widget.user.profileImagePath!))
                                    : null),
                            child: _newProfileImagePath == null &&
                                    (widget.user.profileImagePath == null ||
                                        widget.user.profileImagePath!.isEmpty)
                                ? const Icon(Icons.person,
                                    size: 60, color: primaryAccent)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              backgroundColor: Theme.of(context).cardColor,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt_outlined),
                                onPressed: _pickImage,
                                tooltip: 'Alterar foto',
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Nome Completo'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nome não pode ser vazio'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Peso inválido';
                        final x = double.tryParse(v.replaceAll(',', '.'));
                        return (x == null || x <= 0)
                            ? 'Peso inválido (deve ser > 0)'
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _faixa,
                      decoration: const InputDecoration(labelText: 'Faixa'),
                      items: _faixasList
                          .map((faixa) => DropdownMenuItem(
                              value: faixa, child: Text(faixa)))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _faixa = value;
                        _grausList = _getGrausForFaixa(_faixa);
                        _graus = null;
                      }),
                      validator: (value) =>
                          value == null ? 'Selecione sua faixa' : null,
                    ),
                    if (_faixa != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _graus,
                        decoration: const InputDecoration(
                            labelText: 'Graus (opcional)'),
                        items: [
                          const DropdownMenuItem<int>(
                              value: null, child: Text("Nenhum")),
                          ..._grausList.map((g) => DropdownMenuItem(
                              value: g, child: Text("$gº Grau"))),
                        ],
                        onChanged: (value) => setState(() => _graus = value),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _updateProfile,
                            icon: const Icon(Icons.save),
                            label: const Text("Salvar Alterações"),
                            style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16)),
                          ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
