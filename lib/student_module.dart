// lib/student_module.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_element, curly_braces_in_flow_control_structures, unused_import

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'auth_gate.dart';
import 'navigation_service.dart';
import 'app_drawer.dart';
import 'graduation_timeline_page.dart';

// --- TELAS DO ALUNO ---
class StudentHomePage extends StatefulWidget {
  final UserModel user;
  final bool isImpersonating;

  const StudentHomePage({
    super.key,
    required this.user,
    this.isImpersonating = false,
  });

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _paginaAtual = 0;
  bool _isLoading = true;

  late final NavigationService _navService;
  List<AppModule> _allPageModules = [];
  List<AppModule> _drawerModules = [];
  List<AppModule> _visibleModules = [];
  List<Widget> _telas = [];

  List<UserModel> _teachers = [];
  List<Aluno> _students = [];
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _settingsSubscription;

  bool _isNotificationDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _navService =
        NavigationService(userId: widget.user.uid, userRole: widget.user.role);
    _loadInitialData();
    _checkForNewNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
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
      if (!mounted || snapshot.docs.isEmpty || _isNotificationDialogShowing) {
        return;
      }

      setState(() {
        _isNotificationDialogShowing = true;
      });

      final notification = NotificationModel.fromFirestore(snapshot.docs.first);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(notification.title),
          content: Text(notification.message),
          actions: [
            TextButton(
              onPressed: () async {
                await _updateLastNotificationCheck();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ).then((_) {
        if (mounted) {
          setState(() {
            _isNotificationDialogShowing = false;
          });
        }
      });
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
            .map((module) =>
                module.pageBuilder!(widget.user, _teachers, _students))
            .toList();

        _visibleModules =
            _allPageModules.where((m) => visibleIds.contains(m.id)).toList();

        int profileIndex =
            _allPageModules.indexWhere((m) => m.id == 'student_profile');
        _paginaAtual = (profileIndex != -1) ? profileIndex : 0;

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
              tooltip: 'Configurações',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsPage(user: widget.user),
                ));
              }),
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
    );
  }
}

class EditStudentProfilePage extends StatefulWidget {
  final UserModel user;
  final bool isFirstLogin;

  const EditStudentProfilePage({
    super.key,
    required this.user,
    this.isFirstLogin = false,
  });

  @override
  State<EditStudentProfilePage> createState() => _EditStudentProfilePageState();
}

class _EditStudentProfilePageState extends State<EditStudentProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  XFile? _newProfileImageFile;
  String? _currentProfileImageUrl;
  Aluno? _currentAlunoData;

  @override
  void initState() {
    super.initState();
    _currentProfileImageUrl = widget.user.profileImagePath;
    _loadStudentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _dateController.dispose();
    super.dispose();
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
        _currentAlunoData = aluno;
        _nameController.text = aluno.nome;
        _weightController.text = aluno.peso.toString();
        if (aluno.dataNascimento != null) {
          _dateController.text =
              DateFormat('dd/MM/yyyy').format(aluno.dataNascimento!);
        }
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
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);

    if (pickedFile != null) {
      setState(() {
        _newProfileImageFile = pickedFile;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user.studentRecordId == null) {
      showBjjSnackBar(
          context, "Seu perfil de aluno ainda não foi criado pelo gerente.",
          type: 'error');
      return;
    }

    setState(() => _isSaving = true);

    DateTime? dataNascimento;
    if (_dateController.text.isNotEmpty) {
      try {
        dataNascimento =
            DateFormat('dd/MM/yyyy').parseStrict(_dateController.text);
      } catch (e) {
        if (mounted) {
          showBjjSnackBar(context, "Formato de data inválido.", type: 'error');
          setState(() => _isSaving = false);
        }
        return;
      }
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final userRef = firestore.collection('users').doc(widget.user.uid);
      final studentRef = firestore
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('students')
          .doc(widget.user.studentRecordId!);

      final Map<String, dynamic> userUpdateData = {};

      if (_newProfileImageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${widget.user.uid}.jpg');

        if (kIsWeb) {
          await ref.putData(await _newProfileImageFile!.readAsBytes());
        } else {
          await ref.putFile(File(_newProfileImageFile!.path));
        }

        final downloadUrl = await ref.getDownloadURL();
        userUpdateData['profileImagePath'] = downloadUrl;
      }

      batch.update(studentRef, {
        'nome': _nameController.text.trim().capitalizeWords(),
        'peso': double.parse(_weightController.text.replaceAll(',', '.')),
        'dataNascimento':
            dataNascimento != null ? Timestamp.fromDate(dataNascimento) : null,
      });

      if (_nameController.text.trim().capitalizeWords() != widget.user.name) {
        userUpdateData['name'] = _nameController.text.trim().capitalizeWords();
      }

      if (userUpdateData.isNotEmpty) {
        batch.update(userRef, userUpdateData);
      }

      await batch.commit();

      if (mounted) {
        showBjjSnackBar(context, "Perfil atualizado com sucesso!",
            type: 'success');
        if (widget.isFirstLogin) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthGate()),
              (route) => false);
        } else {
          Navigator.of(context).pop();
        }
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
    ImageProvider? backgroundImage;
    if (_newProfileImageFile != null && !kIsWeb) {
      backgroundImage = FileImage(File(_newProfileImageFile!.path));
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_currentProfileImageUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title:
            Text(widget.isFirstLogin ? "Complete seu Perfil" : "Editar Perfil"),
        automaticallyImplyLeading: !widget.isFirstLogin,
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (widget.isFirstLogin)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          "Para começar, por favor, confirme seus dados e adicione uma foto de perfil.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: textHint, fontSize: 16),
                        ),
                      ),
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
                                  backgroundImage: backgroundImage,
                                  child: _newProfileImageFile != null && kIsWeb
                                      ? ClipOval(
                                          child: FutureBuilder<Uint8List>(
                                            future: _newProfileImageFile!
                                                .readAsBytes(),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                  width: 120,
                                                  height: 120,
                                                );
                                              }
                                              return const CircularProgressIndicator();
                                            },
                                          ),
                                        )
                                      : backgroundImage == null
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
                          if (_currentAlunoData?.faixa != null)
                            Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                leading: const Icon(Icons.shield_outlined,
                                    color: textHint),
                                title: const Text("Sua Faixa Atual"),
                                subtitle: Text(
                                  '${_currentAlunoData!.faixa}${_currentAlunoData!.graus != null && _currentAlunoData!.graus! > 0 ? " - ${_currentAlunoData!.graus}º Grau" : ""}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: textPrimary),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
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
                            controller: _dateController,
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
                              if (v == null || v.trim().isEmpty) return null;
                              if (v.length != 10) return 'Data incompleta.';
                              try {
                                DateFormat('dd/MM/yyyy').parseStrict(v);
                                return null;
                              } catch (e) {
                                return 'Data inválida.';
                              }
                            },
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
                          const SizedBox(height: 24),
                          _isSaving
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _updateProfile,
                                  icon: const Icon(Icons.save),
                                  label: Text(widget.isFirstLogin
                                      ? "Confirmar e Continuar"
                                      : "Salvar Alterações"),
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
    final studentId = widget.user.role == UserRole.student
        ? widget.user.studentRecordId
        : widget.user.uid;

    if (studentId == null && widget.user.role == UserRole.student) {
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

        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Treinos em ${DateFormat.yMMMM('pt_BR').format(_focusedDay)}: ${checkinsForFocusedMonth.length}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: primaryAccent),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: TableCalendar<CheckinEntry>(
                  locale: 'pt_BR',
                  firstDay: DateTime.utc(DateTime.now().year - 5, 1, 1),
                  lastDay: DateTime.utc(DateTime.now().year + 5, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Mês',
                  },
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.military_tech_rounded, color: infoColor),
                  title: const Text("Histórico de Graduações"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => GraduationTimelinePage(
                        academyId: widget.user.academyId,
                        user: widget.user,
                        currentUser: widget.user,
                      ),
                    ));
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SettingsPage extends StatefulWidget {
  final UserModel user;

  const SettingsPage({
    super.key,
    required this.user,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
        'Olá, preciso de ajuda com minha conta no Match BJJ.');
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
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text("Editar Perfil"),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  onTap: () {
                    final pageToPush = widget.user.role == UserRole.student
                        ? EditStudentProfilePage(user: widget.user)
                        : EditUserProfilePage(user: widget.user);

                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => pageToPush,
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

class UserProfilePage extends StatefulWidget {
  final UserModel user;
  final bool hasScaffold;

  const UserProfilePage({
    super.key,
    required this.user,
    this.hasScaffold = true,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserModel? _currentUser;
  Aluno? _aluno;
  MonthlyFee? _currentMonthFee;
  int _monthlyCheckins = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final userDoc =
          await firestore.collection('users').doc(widget.user.uid).get();

      if (!userDoc.exists && mounted) {
        showBjjSnackBar(context, "Usuário não encontrado.", type: 'error');
        FirebaseAuth.instance.signOut();
        return;
      }

      final freshUser = UserModel.fromFirestore(userDoc);
      Aluno? freshAluno;
      MonthlyFee? fee;
      int checkins = 0;

      if (freshUser.role == UserRole.student &&
          freshUser.studentRecordId != null) {
        final studentDoc = await firestore
            .collection('academies')
            .doc(freshUser.academyId)
            .collection('students')
            .doc(freshUser.studentRecordId!)
            .get();

        if (studentDoc.exists) {
          freshAluno = Aluno.fromJson(studentDoc.id, studentDoc.data()!);
        }

        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        final paymentSnapshot = await firestore
            .collection('academies')
            .doc(freshUser.academyId)
            .collection('monthly_fees')
            .where('studentId', isEqualTo: freshUser.studentRecordId)
            .where('paymentYear', isEqualTo: now.year)
            .where('paymentMonth', isEqualTo: now.month)
            .limit(1)
            .get();

        if (paymentSnapshot.docs.isNotEmpty) {
          fee = MonthlyFee.fromFirestore(paymentSnapshot.docs.first);
        }

        final checkinsSnapshot = await firestore
            .collection('academies')
            .doc(freshUser.academyId)
            .collection('checkins')
            .where('studentId', isEqualTo: freshUser.studentRecordId)
            .where('date', isGreaterThanOrEqualTo: startOfMonth)
            .where('date', isLessThanOrEqualTo: endOfMonth)
            .get();

        checkins = checkinsSnapshot.docs.length;
      }

      if (mounted) {
        setState(() {
          _currentUser = freshUser;
          _aluno = freshAluno;
          _currentMonthFee = fee;
          _monthlyCheckins = checkins;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar dados do perfil: $e",
            type: 'error');
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToEditPage() {
    final pageToPush = _currentUser!.role == UserRole.student
        ? EditStudentProfilePage(user: _currentUser!)
        : EditUserProfilePage(user: _currentUser!);

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pageToPush))
        .then((_) => _loadProfileData());
  }

  void _showSetGoalDialog() {
    final now = DateTime.now();
    final goalKey = DateFormat('yyyy-MM').format(now);
    final currentGoal = _currentUser?.monthlyTrainingGoals[goalKey] ?? 0;
    final controller = TextEditingController(
        text: currentGoal > 0 ? currentGoal.toString() : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Meta de Treinos Mensal'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantos treinos no mês?',
              hintText: 'Ex: 12',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newGoal = int.tryParse(controller.text) ?? 0;
                if (newGoal > 0) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser!.uid)
                      .update({'monthlyTrainingGoals.$goalKey': newGoal});
                }
                Navigator.of(context).pop();
                _loadProfileData();
              },
              child: const Text('Salvar Meta'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBody = AppBackground(
      child: SafeArea(
        child: _isLoading || _currentUser == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProfileData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: [
                    UserProfileHeader(user: _currentUser!, studentData: _aluno),
                    const SizedBox(height: 8),
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.shield_outlined,
                            color: primaryAccent, size: 30),
                        title: const Text("Graduação",
                            style: TextStyle(color: textHint)),
                        subtitle: Text(
                          _formatGraduation(_currentUser!, _aluno),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: textPrimary),
                        ),
                      ),
                    ),
                    if (_currentUser!.role == UserRole.student)
                      _TrainingGoalCard(
                        currentUser: _currentUser!,
                        monthlyCheckins: _monthlyCheckins,
                        onTap: _showSetGoalDialog,
                      ),
                    if (_currentUser!.role == UserRole.student)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          leading: Icon(
                            _currentMonthFee?.status == PaymentStatus.pago
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                            color:
                                _currentMonthFee?.status == PaymentStatus.pago
                                    ? successColor
                                    : warningColor,
                            size: 30,
                          ),
                          title: const Text("Status da Mensalidade",
                              style: TextStyle(color: textHint)),
                          subtitle: Text(
                            _currentMonthFee?.status == PaymentStatus.pago &&
                                    _currentMonthFee!.paymentDate != null
                                ? 'Paga em ${DateFormat.yMd('pt_BR').format(_currentMonthFee!.paymentDate!)}' // <-- CORREÇÃO AQUI
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
    );

    if (widget.hasScaffold) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Meu Perfil"),
        ),
        body: pageBody,
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToEditPage,
          tooltip: 'Editar Perfil',
          child: const Icon(Icons.edit),
        ),
      );
    } else {
      return pageBody;
    }
  }

  String _formatGraduation(UserModel user, Aluno? aluno) {
    if (user.role == UserRole.manager) return 'N/A';
    String belt = "";
    int? degrees;
    if (user.role == UserRole.student && aluno != null) {
      belt = aluno.faixa;
      degrees = aluno.graus;
    } else {
      belt = user.faixa ?? "Não informada";
      degrees = user.graus;
    }
    if (degrees != null && degrees > 0) return '$belt - $degreesº Grau';
    return belt;
  }
}

class _TrainingGoalCard extends StatelessWidget {
  final UserModel currentUser;
  final int monthlyCheckins;
  final VoidCallback onTap;

  const _TrainingGoalCard({
    required this.currentUser,
    required this.monthlyCheckins,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final goalKey = DateFormat('yyyy-MM').format(now);
    final goal = currentUser.monthlyTrainingGoals[goalKey] ?? 0;
    final progress =
        (goal > 0) ? (monthlyCheckins / goal).clamp(0.0, 1.0) : 0.0;

    String title;
    if (goal == 0) {
      title = 'Definir meta de treinos';
    } else if (monthlyCheckins >= goal) {
      title = 'Meta alcançada!';
    } else {
      title = 'Meta de Treinos do Mês';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    monthlyCheckins >= goal && goal > 0
                        ? Icons.star_rounded
                        : Icons.flag_rounded,
                    color: primaryAccent,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (goal > 0)
                          Text(
                            '$monthlyCheckins de $goal treinos',
                            style:
                                const TextStyle(color: textHint, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_note_rounded, color: textHint),
                ],
              ),
              if (goal > 0) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: darkSurface,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(primaryAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditUserProfilePage extends StatefulWidget {
  final UserModel user;
  final bool isFirstLogin;

  const EditUserProfilePage({
    super.key,
    required this.user,
    this.isFirstLogin = false,
  });

  @override
  State<EditUserProfilePage> createState() => _EditUserProfilePageState();
}

class _EditUserProfilePageState extends State<EditUserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _dateController = TextEditingController();
  bool _isSaving = false;
  XFile? _newProfileImageFile;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _currentProfileImageUrl = widget.user.profileImagePath;
    _nameController.text = widget.user.name;
    _weightController.text = widget.user.peso?.toString() ?? '';
    if (widget.user.dataNascimento != null) {
      _dateController.text =
          DateFormat('dd/MM/yyyy').format(widget.user.dataNascimento!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);

    if (pickedFile != null) {
      setState(() {
        _newProfileImageFile = pickedFile;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    DateTime? dataNascimento;
    if (_dateController.text.isNotEmpty) {
      try {
        dataNascimento =
            DateFormat('dd/MM/yyyy').parseStrict(_dateController.text);
      } catch (e) {
        if (mounted) {
          showBjjSnackBar(context, "Formato de data inválido.", type: 'error');
          setState(() => _isSaving = false);
        }
        return;
      }
    }

    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.user.uid);

      final Map<String, dynamic> updateData = {
        'name': _nameController.text.trim().capitalizeWords(),
        'peso': double.tryParse(_weightController.text.replaceAll(',', '.')) ??
            widget.user.peso,
        'dataNascimento':
            dataNascimento != null ? Timestamp.fromDate(dataNascimento) : null,
      };

      if (_newProfileImageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${widget.user.uid}.jpg');

        if (kIsWeb) {
          await ref.putData(await _newProfileImageFile!.readAsBytes());
        } else {
          await ref.putFile(File(_newProfileImageFile!.path));
        }

        final downloadUrl = await ref.getDownloadURL();
        updateData['profileImagePath'] = downloadUrl;
      }

      await userRef.update(updateData);

      if (mounted) {
        showBjjSnackBar(context, "Perfil atualizado com sucesso!",
            type: 'success');
        if (widget.isFirstLogin) {
          Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const AuthGate()),
              (route) => false);
        } else {
          Navigator.of(context).pop();
        }
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
    final bool isManager = widget.user.role == UserRole.manager;

    ImageProvider? backgroundImage;
    if (_newProfileImageFile != null && !kIsWeb) {
      backgroundImage = FileImage(File(_newProfileImageFile!.path));
    } else if (_currentProfileImageUrl != null &&
        _currentProfileImageUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_currentProfileImageUrl!);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title:
            Text(widget.isFirstLogin ? "Complete seu Perfil" : "Editar Perfil"),
        automaticallyImplyLeading: !widget.isFirstLogin,
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (widget.isFirstLogin)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24.0),
                  child: Text(
                    "Para começar, por favor, confirme seus dados e adicione uma foto de perfil.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textHint, fontSize: 16),
                  ),
                ),
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
                            backgroundImage: backgroundImage,
                            child: _newProfileImageFile != null && kIsWeb
                                ? ClipOval(
                                    child: FutureBuilder<Uint8List>(
                                      future:
                                          _newProfileImageFile!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                            width: 120,
                                            height: 120,
                                          );
                                        }
                                        return const CircularProgressIndicator();
                                      },
                                    ),
                                  )
                                : backgroundImage == null
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
                    if (!isManager && widget.user.faixa != null)
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: const Icon(Icons.shield_outlined,
                              color: textHint),
                          title: const Text("Sua Faixa Atual"),
                          subtitle: Text(
                            '${widget.user.faixa}${widget.user.graus != null && widget.user.graus! > 0 ? " - ${widget.user.graus}º Grau" : ""}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: textPrimary),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
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
                      controller: _dateController,
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
                        if (v == null || v.trim().isEmpty) return null;
                        if (v.length != 10) return 'Data incompleta.';
                        try {
                          DateFormat('dd/MM/yyyy').parseStrict(v);
                          return null;
                        } catch (e) {
                          return 'Data inválida.';
                        }
                      },
                    ),
                    if (!isManager) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _weightController,
                        decoration:
                            const InputDecoration(labelText: 'Peso (kg)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Peso inválido';
                          final x = double.tryParse(v.replaceAll(',', '.'));
                          return (x == null || x <= 0)
                              ? 'Peso inválido (deve ser > 0)'
                              : null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _updateProfile,
                            icon: const Icon(Icons.save),
                            label: Text(widget.isFirstLogin
                                ? "Confirmar e Continuar"
                                : "Salvar Alterações"),
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
