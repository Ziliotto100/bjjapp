// lib/super_admin_module.dart
// ignore_for_file: use_build_context_synchronously, prefer_final_fields, unnecessary_to_list_in_spreads, unnecessary_cast

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_dashboard_module.dart';
import 'admin_financial_page.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';
import 'auth_gate.dart';
import 'manager_module.dart';
import 'video_library_module.dart';

// --- TELA CONTAINER DO SUPER ADMIN COM NAVEGAÇÃO ---
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const AdminDashboardPage(),
    const AdminFinancialPage(),
    const AcademyListPage(),
    const VideoAuditPage(),
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Financeiro',
    'Academias',
    'Vídeos',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_pageTitles[_currentIndex]),
        actions: [
          // BOTÃO DE CONFIGURAÇÕES NA BARRA SUPERIOR
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurações',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
              );
            },
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on_outlined),
            label: 'Financeiro',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_rounded),
            label: 'Academias',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_outlined),
            label: 'Vídeos',
          ),
        ],
      ),
    );
  }
}

// --- NOVA TELA DE CONFIGURAÇÕES ---
class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _whatsappController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSupportNumber();
  }

  Future<void> _loadSupportNumber() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('global_settings')
          .doc('support')
          .get();
      if (doc.exists && doc.data() != null) {
        _whatsappController.text = doc.data()!['whatsapp_number'] ?? '';
      }
    } catch (e) {
      // It's okay if it fails, maybe the document doesn't exist yet.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSupportNumber() async {
    final number = _whatsappController.text.trim();
    if (number.isEmpty) {
      showBjjSnackBar(context, 'O número não pode estar vazio.', type: 'error');
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('global_settings')
          .doc('support')
          .set({'whatsapp_number': number});
      showBjjSnackBar(context, 'Número do suporte salvo com sucesso!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar o número: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Configurações de Suporte',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            const Text(
                              'Insira o número de WhatsApp que será exibido para os usuários em telas de bloqueio.',
                              style: TextStyle(color: textHint),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _whatsappController,
                              decoration: const InputDecoration(
                                labelText: 'Número do WhatsApp para Suporte',
                                hintText: 'Ex: 5511999998888',
                                prefixIcon: Icon(Icons.support_agent),
                              ),
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _saveSupportNumber,
                              child: const Text('Salvar Número'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: errorColor),
                        title: const Text('Sair',
                            style: TextStyle(color: errorColor)),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
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

// --- WIDGET PARA A LISTA DE ACADEMIAS ---
class AcademyListPage extends StatefulWidget {
  const AcademyListPage({super.key});

  @override
  State<AcademyListPage> createState() => _AcademyListPageState();
}

class _AcademyListPageState extends State<AcademyListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('academies')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.business_center,
              title: 'Nenhuma Academia Cadastrada',
            );
          }
          final academies = snapshot.data!.docs;
          return ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.history_edu_rounded,
                      color: primaryAccent),
                  title: const Text("Ver Avisos Enviados"),
                  subtitle:
                      const Text("Gerenciar avisos globais que você enviou"),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminSentNotificationsPage(),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              ...academies.map((academyDoc) {
                final data = academyDoc.data() as Map<String, dynamic>;
                final academyName = data['name'] ?? 'Nome não encontrado';

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: darkSurface,
                      child: Icon(Icons.business, color: textHint),
                    ),
                    title: Text(academyName),
                    subtitle: const Text('Toque para gerenciar'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AcademyDetailPage(academyDoc: academyDoc),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'super_admin_fab',
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const _SendGlobalNotificationDialog(),
          );
        },
        tooltip: 'Enviar Aviso Global',
        child: const Icon(Icons.campaign_rounded),
      ),
    );
  }
}

// --- TELA DE DETALHES DA ACADEMIA ---
class AcademyDetailPage extends StatefulWidget {
  final DocumentSnapshot academyDoc;
  const AcademyDetailPage({super.key, required this.academyDoc});

  @override
  State<AcademyDetailPage> createState() => _AcademyDetailPageState();
}

class _AcademyDetailPageState extends State<AcademyDetailPage> {
  late Future<List<UserModel>> _usersFuture;
  late Future<String> _dataUsageFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
    _dataUsageFuture = _fetchDataUsage();
  }

  Future<String> _fetchDataUsage() async {
    try {
      final videosSnapshot = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyDoc.id)
          .collection('videos')
          .where('videoType', isEqualTo: 'uploaded')
          .get();

      if (videosSnapshot.docs.isEmpty) {
        return "0 MB";
      }

      double totalBytes = 0;

      for (var doc in videosSnapshot.docs) {
        final video = VideoItem.fromFirestore(doc);
        if (video.fileSizeBytes != null && video.fileSizeBytes! > 0) {
          int totalViews = 0;
          video.watchedBy.forEach((key, value) {
            if (value is Map && value.containsKey('count')) {
              totalViews += (value['count'] as num).toInt();
            }
          });
          totalBytes += (video.fileSizeBytes! * totalViews);
        }
      }

      if (totalBytes == 0) {
        return "0 MB";
      }

      final megabytes = totalBytes / (1024 * 1024);
      if (megabytes < 1024) {
        return "${megabytes.toStringAsFixed(2)} MB";
      } else {
        final gigabytes = megabytes / 1024;
        return "${gigabytes.toStringAsFixed(2)} GB";
      }
    } catch (e) {
      debugPrint("Erro ao calcular uso de dados: $e");
      return "Erro";
    }
  }

  Future<List<UserModel>> _fetchUsers() async {
    final academyId = widget.academyDoc.id;
    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('academyId', isEqualTo: academyId)
        .get();

    final users =
        usersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    users.sort((a, b) => a.name.compareTo(b.name));
    return users;
  }

  Future<void> _startImpersonation(String targetUid) async {
    final superAdminUid = FirebaseAuth.instance.currentUser?.uid;
    if (superAdminUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('impersonation_sessions')
          .doc(superAdminUid)
          .set({'targetUid': targetUid});
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao iniciar a personificação: $e',
            type: 'error');
      }
    }
  }

  void _showAcademyInfoDialog(BuildContext context, UserModel? manager) {
    showDialog(
      context: context,
      builder: (_) => _AcademyInfoDialog(
        academyDoc: widget.academyDoc,
        manager: manager,
        dataUsageFuture: _dataUsageFuture,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final academyName =
        (widget.academyDoc.data() as Map<String, dynamic>)['name'] ??
            'Academia';
    final academyId = widget.academyDoc.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(academyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_toggle_off_rounded),
            tooltip: 'Histórico de Atividades',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AcademyAuditLogPage(
                  academyId: academyId,
                  academyName: academyName,
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: successColor),
            tooltip: 'Histórico de Pagamentos',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AcademyPaymentHistoryPage(
                    academyId: academyId, academyName: academyName),
              ));
            },
          ),
          FutureBuilder<List<UserModel>>(
              future: _usersFuture,
              builder: (context, userSnapshot) {
                final manager = userSnapshot.data?.firstWhere(
                    (u) => u.role == UserRole.manager,
                    orElse: () => UserModel(
                        uid: '',
                        name: '',
                        email: '',
                        academyId: '',
                        role: UserRole.unknown,
                        mustChangePassword: true,
                        isActive: false));
                return IconButton(
                  icon: const Icon(Icons.info_outline, color: infoColor),
                  tooltip: 'Ver Informações',
                  onPressed: () => _showAcademyInfoDialog(context, manager),
                );
              }),
          IconButton(
            icon: const Icon(Icons.edit_note, color: primaryAccent),
            tooltip: 'Editar Assinatura',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => EditAcademySubscriptionDialog(
                    academyDoc: widget.academyDoc),
              );
            },
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<List<UserModel>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const EmptyStateWidget(
                    icon: Icons.error, title: 'Erro ao carregar usuários');
              }
              final users = snapshot.data!;
              final manager = users.firstWhere(
                  (u) => u.role == UserRole.manager,
                  orElse: () => UserModel(
                      uid: '',
                      name: '',
                      email: '',
                      academyId: '',
                      role: UserRole.unknown,
                      mustChangePassword: true,
                      isActive: false));
              final teachers =
                  users.where((u) => u.role == UserRole.teacher).toList();
              final students =
                  users.where((u) => u.role == UserRole.student).toList();

              return ListView(
                children: [
                  _buildUserSection("Gerente", [manager]),
                  if (teachers.isNotEmpty)
                    _buildUserSection("Professores", teachers),
                  if (students.isNotEmpty)
                    _buildUserSection("Alunos", students),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(String title, List<UserModel> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: (user.profileImagePath != null &&
                          user.profileImagePath!.isNotEmpty)
                      ? CachedNetworkImageProvider(user.profileImagePath!)
                      : null,
                  child: (user.profileImagePath == null ||
                          user.profileImagePath!.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user.name),
                subtitle: Text(
                  user.role == UserRole.manager
                      ? 'Gerente'
                      : user.role == UserRole.teacher
                          ? 'Professor'
                          : 'Aluno',
                  style: const TextStyle(color: textHint),
                ),
                trailing: SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: 'Permitir Anexar Vídeos nos Estudos',
                        child: Switch(
                          value: user.canUploadStudyVideos,
                          onChanged: (bool value) async {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .update({'canUploadStudyVideos': value});
                            setState(() {
                              _usersFuture = _fetchUsers();
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.theater_comedy_outlined,
                            color: warningColor),
                        tooltip: 'Entrar como ${user.name}',
                        onPressed: () => _startImpersonation(user.uid),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// --- TELA DE LOG DE AUDITORIA ---
class AcademyAuditLogPage extends StatelessWidget {
  final String academyId;
  final String academyName;

  const AcademyAuditLogPage({
    super.key,
    required this.academyId,
    required this.academyName,
  });

  IconData _getIconForAction(String actionType) {
    if (actionType.contains('CREATE')) return Icons.add_circle_outline;
    if (actionType.contains('DELETE')) return Icons.remove_circle_outline;
    if (actionType.contains('UPDATE')) return Icons.edit_note_rounded;
    return Icons.info_outline;
  }

  Color _getColorForAction(String actionType) {
    if (actionType.contains('CREATE')) return successColor;
    if (actionType.contains('DELETE')) return errorColor;
    if (actionType.contains('UPDATE')) return warningColor;
    return textHint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Histórico de $academyName'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(academyId)
                .collection('audit_log')
                .orderBy('timestamp', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const EmptyStateWidget(
                  icon: Icons.error,
                  title: 'Erro ao carregar histórico',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.history,
                  title: 'Nenhuma Atividade Registrada',
                  message:
                      'As ações realizadas nesta academia aparecerão aqui.',
                );
              }

              final logs = snapshot.data!.docs
                  .map((doc) => AuditLogEntry.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        _getIconForAction(log.actionType),
                        color: _getColorForAction(log.actionType),
                      ),
                      title: Text(log.description),
                      subtitle: Text(
                        'Por: ${log.actorName} em ${DateFormat.yMd('pt_BR').add_Hm().format(log.timestamp.toDate())}',
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

// --- WIDGET DE DIÁLOGO PARA EDITAR USUÁRIO (COM BOTÃO DE RESET) ---
class _EditUserDialog extends StatefulWidget {
  final dynamic user;

  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = true;
  String _userName = '';
  String _targetUid = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    String? currentEmail;
    if (widget.user is Aluno) {
      final aluno = widget.user as Aluno;
      _userName = aluno.nome;
      if (aluno.userId != null) {
        _targetUid = aluno.userId!;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_targetUid)
            .get();
        if (userDoc.exists) {
          currentEmail = userDoc.data()?['email'];
        }
      }
    } else if (widget.user is UserModel) {
      final userModel = widget.user as UserModel;
      _userName = userModel.name;
      _targetUid = userModel.uid;
      currentEmail = userModel.email;
    }

    if (mounted) {
      setState(() {
        _emailController.text = currentEmail ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetUid.isEmpty) {
      showBjjSnackBar(context, 'Este usuário não possui um login para editar.',
          type: 'error');
      return;
    }

    setState(() => _isLoading = true);
    final newEmail = _emailController.text.trim();

    try {
      await FirebaseFirestore.instance
          .collection('emailChangeRequests')
          .add({'targetUid': _targetUid, 'newEmail': newEmail});

      Navigator.of(context).pop();
      showBjjSnackBar(context,
          'Solicitação de alteração de e-mail enviada! Pode levar um minuto.',
          type: 'success');
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao solicitar alteração: $e',
            type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Reset de Senha'),
        content: Text(
            'Tem certeza que deseja resetar a senha de $_userName? A nova senha será "mudar123" e ele(a) será forçado(a) a alterá-la no próximo login.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: warningColor),
            child: const Text('Resetar Senha',
                style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('passwordResetRequests')
          .add({'targetUid': _targetUid});

      Navigator.of(context).pop();
      showBjjSnackBar(context,
          'Solicitação de reset de senha enviada! Pode levar um minuto.',
          type: 'success');
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao solicitar reset: $e', type: 'error');
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
      title: Text('Gerenciar Acesso de $_userName'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _emailController,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'E-mail de Acesso'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'E-mail inválido'
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon:
                      const Icon(Icons.lock_reset_rounded, color: warningColor),
                  label: const Text('Resetar Senha do Usuário',
                      style: TextStyle(color: warningColor)),
                  onPressed: _isLoading ? null : _resetPassword,
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveEmail,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar E-mail'),
        ),
      ],
    );
  }
}

class AdminSentNotificationsPage extends StatelessWidget {
  const AdminSentNotificationsPage({super.key});

  Future<void> _confirmDelete(
      BuildContext context, NotificationModel notification) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
            'Tem certeza que deseja excluir este aviso permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('academies')
            .doc(notification.academyId)
            .collection('notifications')
            .doc(notification.id)
            .delete();
        showBjjSnackBar(context, 'Aviso excluído com sucesso!',
            type: 'success');
      } catch (e) {
        showBjjSnackBar(context, 'Erro ao excluir o aviso.', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Meus Avisos Enviados'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('notifications')
                .where('senderRole', isEqualTo: 'admin')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const EmptyStateWidget(
                  icon: Icons.error,
                  title: 'Erro ao carregar avisos',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.send,
                  title: 'Nenhum Aviso Enviado',
                  message: 'Os avisos globais que você enviar aparecerão aqui.',
                );
              }

              final notifications = snapshot.data!.docs
                  .map((doc) => NotificationModel.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Card(
                    child: ListTile(
                      title: Text(notification.title),
                      subtitle: Text(
                        'Enviado em: ${DateFormat.yMd('pt_BR').add_Hm().format(notification.createdAt.toDate())}',
                      ),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: errorColor),
                        tooltip: 'Excluir Aviso',
                        onPressed: () => _confirmDelete(context, notification),
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

class _SendGlobalNotificationDialog extends StatefulWidget {
  const _SendGlobalNotificationDialog();

  @override
  State<_SendGlobalNotificationDialog> createState() =>
      _SendGlobalNotificationDialogState();
}

class _SendGlobalNotificationDialogState
    extends State<_SendGlobalNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sendToAll = true;
  List<DocumentSnapshot> _allAcademies = [];
  Set<String> _selectedAcademyIds = {};
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadAcademies();
  }

  Future<void> _loadAcademies() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('academies').get();
      if (mounted) {
        setState(() {
          _allAcademies = snapshot.docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar academias.', type: 'error');
      }
    }
  }

  Future<void> _sendNotifications() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_sendToAll && _selectedAcademyIds.isEmpty) {
      showBjjSnackBar(context, 'Selecione pelo menos uma academia.',
          type: 'error');
      return;
    }

    setState(() => _isSending = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final academyIdsToSend = _sendToAll
        ? _allAcademies.map((doc) => doc.id).toSet()
        : _selectedAcademyIds;

    for (final academyId in academyIdsToSend) {
      final notificationRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(academyId)
          .collection('notifications')
          .doc();

      batch.set(notificationRef, {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'senderId': currentUser.uid,
        'senderName': 'Admin',
        'senderRole': 'admin',
        'academyId': academyId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [],
      });
    }

    try {
      await batch.commit();
      Navigator.of(context).pop();
      showBjjSnackBar(
          context, 'Aviso enviado para ${academyIdsToSend.length} academia(s)!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao enviar aviso: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar Aviso Global'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration:
                      const InputDecoration(labelText: 'Título do Aviso'),
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Mensagem'),
                  maxLines: 4,
                  validator: (v) =>
                      v!.trim().isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enviar para todas as academias'),
                  value: _sendToAll,
                  onChanged: (value) => setState(() => _sendToAll = value),
                ),
                if (!_sendToAll)
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: borderNormal),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            itemCount: _allAcademies.length,
                            itemBuilder: (context, index) {
                              final academy = _allAcademies[index];
                              final academyName =
                                  (academy.data() as Map)['name'] ?? 'Sem nome';
                              final isSelected =
                                  _selectedAcademyIds.contains(academy.id);
                              return CheckboxListTile(
                                title: Text(academyName),
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedAcademyIds.add(academy.id);
                                    } else {
                                      _selectedAcademyIds.remove(academy.id);
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
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isSending ? null : _sendNotifications,
          child: _isSending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enviar'),
        ),
      ],
    );
  }
}

class _AcademyInfoDialog extends StatelessWidget {
  final DocumentSnapshot academyDoc;
  final UserModel? manager;
  final Future<String> dataUsageFuture;

  const _AcademyInfoDialog(
      {required this.academyDoc, this.manager, required this.dataUsageFuture});

  @override
  Widget build(BuildContext context) {
    final data = academyDoc.data() as Map<String, dynamic>;
    final academyName = data['name'] ?? 'Não informado';
    final contactPhone = data['contactPhoneNumber'] ?? 'Não informado';
    final academyStatus = data['status'] ?? 'active';
    final subscriptionEndDate =
        (data['subscriptionEndDate'] as Timestamp?)?.toDate();

    return AlertDialog(
      title: Text(academyName),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            _buildInfoRow(context, Icons.person_outline, 'Gerente',
                manager?.name ?? 'Não encontrado'),
            _buildInfoRow(context, Icons.email_outlined, 'Email',
                manager?.email ?? 'Não informado'),
            _buildInfoRow(
                context, Icons.phone_outlined, 'Telefone', contactPhone),
            const Divider(height: 24),
            _buildInfoRow(
                context, Icons.toggle_on_outlined, 'Status', academyStatus),
            _buildInfoRow(
                context,
                Icons.event_busy_outlined,
                'Expira em',
                subscriptionEndDate != null
                    ? DateFormat('dd/MM/yyyy').format(subscriptionEndDate)
                    : 'Vitalícia'),
            FutureBuilder<String>(
              future: dataUsageFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildInfoRow(context, Icons.data_usage_outlined,
                      'Consumo de Vídeos', 'Calculando...');
                }
                final usage = snapshot.data ?? "N/D";
                return _buildInfoRow(context, Icons.data_usage_outlined,
                    'Consumo de Vídeos', usage);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
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

class EditAcademySubscriptionDialog extends StatefulWidget {
  final DocumentSnapshot academyDoc;
  const EditAcademySubscriptionDialog({super.key, required this.academyDoc});

  @override
  State<EditAcademySubscriptionDialog> createState() =>
      _EditAcademySubscriptionDialogState();
}

class _EditAcademySubscriptionDialogState
    extends State<EditAcademySubscriptionDialog> {
  late String _currentStatus;
  late DateTime _currentEndDate;
  late bool _hasVideoAccess;
  bool _isLifetime = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.academyDoc.data() as Map<String, dynamic>;
    _currentStatus = data['status'] ?? 'active';
    final endDate = (data['subscriptionEndDate'] as Timestamp?)?.toDate();
    _hasVideoAccess = data['hasVideoLibraryAccess'] ?? false;

    if (endDate == null) {
      _isLifetime = true;
      _currentEndDate = DateTime.now();
    } else {
      _isLifetime = false;
      _currentEndDate = endDate;
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      locale: const Locale('pt', 'BR'),
    );
    if (pickedDate != null) {
      setState(() {
        _currentEndDate = pickedDate;
      });
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> updateData = {
        'status': _currentStatus,
        'subscriptionEndDate':
            _isLifetime ? null : Timestamp.fromDate(_currentEndDate),
        'hasVideoLibraryAccess': _hasVideoAccess,
      };

      await widget.academyDoc.reference.update(updateData);

      if (mounted) {
        Navigator.of(context).pop();
        showBjjSnackBar(context, 'Assinatura atualizada com sucesso!',
            type: 'success');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao salvar: $e', type: 'error');
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
      title: Text(widget.academyDoc['name'] ?? 'Editar Assinatura'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _currentStatus,
              decoration:
                  const InputDecoration(labelText: 'Status da Academia'),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Ativa')),
                DropdownMenuItem(value: 'inactive', child: Text('Inativa')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _currentStatus = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Assinatura Vitalícia'),
              value: _isLifetime,
              onChanged: (value) {
                setState(() {
                  _isLifetime = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Acesso à Videoteca'),
              value: _hasVideoAccess,
              onChanged: (value) {
                setState(() {
                  _hasVideoAccess = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isLifetime)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Expiração da Assinatura',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_currentEndDate),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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

class AcademyPaymentHistoryPage extends StatelessWidget {
  final String academyId;
  final String academyName;

  const AcademyPaymentHistoryPage({
    super.key,
    required this.academyId,
    required this.academyName,
  });

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Pagamentos de $academyName'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(academyId)
                .collection('payment_history')
                .orderBy('paymentDate', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.receipt_long,
                  title: 'Nenhum Pagamento',
                  message:
                      'Nenhum pagamento foi registrado para esta academia ainda.',
                );
              }
              final records = snapshot.data!.docs
                  .map((doc) => PaymentRecord.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.monetization_on,
                          color: successColor),
                      title: Text(priceFormat.format(record.amount)),
                      subtitle: Text(
                          '${record.paymentMethod} em ${DateFormat('dd/MM/yyyy').format(record.paymentDate)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: primaryAccent),
                            tooltip: 'Editar registro',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => EditPaymentRecordDialog(
                                  academyId: academyId,
                                  record: record,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: errorColor),
                            tooltip: 'Excluir registro',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Confirmar Exclusão'),
                                  content: const Text(
                                      'Tem certeza que deseja excluir este registro de pagamento?'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar')),
                                    ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: errorColor),
                                        child: const Text('Excluir')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('academies')
                                    .doc(academyId)
                                    .collection('payment_history')
                                    .doc(record.id)
                                    .delete();
                              }
                            },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AddPaymentRecordDialog(academyId: academyId),
          );
        },
        tooltip: 'Registrar Pagamento',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddPaymentRecordDialog extends StatefulWidget {
  final String academyId;
  const AddPaymentRecordDialog({super.key, required this.academyId});

  @override
  State<AddPaymentRecordDialog> createState() => _AddPaymentRecordDialogState();
}

class _AddPaymentRecordDialogState extends State<AddPaymentRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'Pix';
  DateTime _paymentDate = DateTime.now();
  bool _isLoading = false;

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      locale: const Locale('pt', 'BR'),
    );
    if (pickedDate != null) {
      setState(() {
        _paymentDate = pickedDate;
      });
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null) {
      showBjjSnackBar(context, 'Valor inválido.', type: 'error');
      setState(() => _isLoading = false);
      return;
    }

    final record = PaymentRecord(
      id: '',
      amount: amount,
      paymentDate: _paymentDate,
      paymentMethod: _paymentMethod,
      notes: _notesController.text.trim(),
      recordedByUid: FirebaseAuth.instance.currentUser!.uid,
    );

    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('payment_history')
          .add(record.toMap());

      Navigator.of(context).pop();
      showBjjSnackBar(context, 'Pagamento registrado com sucesso!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao registrar pagamento: $e',
          type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar Novo Pagamento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data do Pagamento',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_paymentDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration:
                    const InputDecoration(labelText: 'Método de Pagamento'),
                items: ['Pix', 'Boleto', 'Cartão de Crédito', 'Dinheiro']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) => setState(() => _paymentMethod = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration:
                    const InputDecoration(labelText: 'Observações (Opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _isLoading ? null : _savePayment,
            child: const Text('Registrar')),
      ],
    );
  }
}

class EditPaymentRecordDialog extends StatefulWidget {
  final String academyId;
  final PaymentRecord record;
  const EditPaymentRecordDialog(
      {super.key, required this.academyId, required this.record});

  @override
  State<EditPaymentRecordDialog> createState() =>
      _EditPaymentRecordDialogState();
}

class _EditPaymentRecordDialogState extends State<EditPaymentRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  late String _paymentMethod;
  late DateTime _paymentDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: widget.record.amount.toStringAsFixed(2));
    _notesController = TextEditingController(text: widget.record.notes ?? '');
    _paymentMethod = widget.record.paymentMethod;
    _paymentDate = widget.record.paymentDate;
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      locale: const Locale('pt', 'BR'),
    );
    if (pickedDate != null) {
      setState(() {
        _paymentDate = pickedDate;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null) {
      showBjjSnackBar(context, 'Valor inválido.', type: 'error');
      setState(() => _isLoading = false);
      return;
    }

    final updatedData = {
      'amount': amount,
      'paymentDate': Timestamp.fromDate(_paymentDate),
      'paymentMethod': _paymentMethod,
      'notes': _notesController.text.trim(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.academyId)
          .collection('payment_history')
          .doc(widget.record.id)
          .update(updatedData);

      Navigator.of(context).pop();
      showBjjSnackBar(context, 'Pagamento atualizado com sucesso!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao atualizar pagamento: $e',
          type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Registro de Pagamento'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data do Pagamento',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_paymentDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration:
                    const InputDecoration(labelText: 'Método de Pagamento'),
                items: ['Pix', 'Boleto', 'Cartão de Crédito', 'Dinheiro']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) => setState(() => _paymentMethod = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration:
                    const InputDecoration(labelText: 'Observações (Opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: const Text('Salvar')),
      ],
    );
  }
}

// --- NOVA TELA DE AUDITORIA DE VÍDEOS ---
class VideoAuditPage extends StatefulWidget {
  const VideoAuditPage({super.key});

  @override
  State<VideoAuditPage> createState() => _VideoAuditPageState();
}

class _VideoAuditPageState extends State<VideoAuditPage> {
  late Future<Map<String, String>> _academyNamesFuture;
  late Future<List<UserModel>> _allUsersFuture;

  @override
  void initState() {
    super.initState();
    _academyNamesFuture = _fetchAcademyNames();
    _allUsersFuture = _fetchAllUsers();
  }

  Future<Map<String, String>> _fetchAcademyNames() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('academies').get();
    return {
      for (var doc in snapshot.docs) doc.id: doc.data()['name'] ?? 'Sem nome'
    };
  }

  Future<List<UserModel>> _fetchAllUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // **NOVA FUNÇÃO PARA ASSISTIR O VÍDEO**
  Future<void> _handleTap(BuildContext context, VideoItem video) async {
    if (video.videoType == VideoType.youtube) {
      final uri = Uri.parse(video.videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        showBjjSnackBar(context, 'Não foi possível abrir o vídeo.',
            type: 'error');
      }
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerPage(video: video),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Future.wait([_academyNamesFuture, _allUsersFuture]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyStateWidget(
                icon: Icons.error, title: 'Erro ao carregar dados');
          }

          final academyNames = snapshot.data![0] as Map<String, String>;
          final allUsers = snapshot.data![1] as List<UserModel>;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('videos')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, videoSnapshot) {
              if (videoSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!videoSnapshot.hasData || videoSnapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.video_library_outlined,
                  title: 'Nenhum vídeo publicado',
                  message: 'Ainda não há vídeos em nenhuma academia.',
                );
              }

              final videosWithContext = videoSnapshot.data!.docs.map((doc) {
                return {
                  'video': VideoItem.fromFirestore(doc),
                  'academyId': doc.reference.parent.parent!.id,
                };
              }).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: videosWithContext.length,
                itemBuilder: (context, index) {
                  final itemData = videosWithContext[index];
                  final video = itemData['video'] as VideoItem;
                  final academyId = itemData['academyId'] as String;
                  final academyName =
                      academyNames[academyId] ?? 'Academia desconhecida';

                  return Card(
                    child: ListTile(
                      title: Text(video.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Academia: $academyName'),
                          Text(
                              'Publicado em: ${DateFormat('dd/MM/yy').format(video.createdAt.toDate())}'),
                        ],
                      ),
                      onTap: () => _handleTap(context, video),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility_outlined,
                            color: textHint),
                        tooltip: 'Ver Visualizações',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => _VideoViewersAuditDialog(
                              watchedByMap: video.watchedBy,
                              allUsers: allUsers,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        });
  }
}

class _VideoViewersAuditDialog extends StatelessWidget {
  final Map<String, dynamic> watchedByMap;
  final List<UserModel> allUsers;

  const _VideoViewersAuditDialog(
      {required this.watchedByMap, required this.allUsers});

  @override
  Widget build(BuildContext context) {
    final allUsersMap = {for (var user in allUsers) user.uid: user};

    final viewers = watchedByMap.entries.map((entry) {
      final user = allUsersMap[entry.key];
      final viewData = entry.value as Map<String, dynamic>;
      final lastWatched = (viewData['lastWatched'] as Timestamp?)?.toDate();
      return {
        'name': user?.name ?? 'Usuário desconhecido',
        'count': viewData['count'] ?? 0,
        'lastWatched': lastWatched,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return AlertDialog(
      title: const Text('Quem Assistiu'),
      content: SizedBox(
        width: double.maxFinite,
        child: viewers.isEmpty
            ? const Center(child: Text('Ninguém visualizou este vídeo ainda.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final viewer = viewers[index];
                  final lastWatchedDate = viewer['lastWatched'] as DateTime?;
                  return ListTile(
                    title: Text(viewer['name'] as String),
                    subtitle: lastWatchedDate != null
                        ? Text(
                            'Última vez: ${DateFormat('dd/MM/yy \'às\' HH:mm').format(lastWatchedDate)}')
                        : null,
                    trailing: Text('${viewer['count']}x',
                        style: const TextStyle(color: textHint)),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
