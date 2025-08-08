// lib/super_admin_module.dart
// ignore_for_file: use_build_context_synchronously, prefer_final_fields

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_dashboard_module.dart';
import 'admin_financial_page.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';
import 'auth_gate.dart';

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
  ];

  final List<String> _pageTitles = [
    'Dashboard',
    'Financeiro',
    'Gerenciar Academias',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_pageTitles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthGate()),
                  (route) => false,
                );
              }
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
        ],
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

// --- NOVA TELA PARA GERENCIAR AVISOS GLOBAIS ENVIADOS ---
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

// --- DIÁLOGO PARA ENVIAR AVISO GLOBAL ---
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

class AcademyDetailPage extends StatefulWidget {
  final DocumentSnapshot academyDoc;
  const AcademyDetailPage({super.key, required this.academyDoc});

  @override
  State<AcademyDetailPage> createState() => _AcademyDetailPageState();
}

class _AcademyDetailPageState extends State<AcademyDetailPage> {
  late Future<List<dynamic>> _usersFuture;
  late Future<UserModel?> _managerFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
    _managerFuture = _fetchManager();
  }

  Future<UserModel?> _fetchManager() async {
    final data = widget.academyDoc.data() as Map<String, dynamic>;
    final ownerId = data['ownerId'];
    if (ownerId == null) return null;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Future<List<dynamic>> _fetchUsers() async {
    final academyId = widget.academyDoc.id;
    final List<dynamic> allUsers = [];

    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('academyId', isEqualTo: academyId)
        .where('role', isEqualTo: 'teacher')
        .get();
    allUsers.addAll(
        teachersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)));

    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('academies')
        .doc(academyId)
        .collection('students')
        .get();
    allUsers.addAll(
        studentsSnapshot.docs.map((doc) => Aluno.fromJson(doc.id, doc.data())));

    return allUsers;
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
      builder: (_) =>
          _AcademyInfoDialog(academyDoc: widget.academyDoc, manager: manager),
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
            icon: const Icon(Icons.receipt_long_rounded, color: successColor),
            tooltip: 'Histórico de Pagamentos',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AcademyPaymentHistoryPage(
                    academyId: academyId, academyName: academyName),
              ));
            },
          ),
          FutureBuilder<UserModel?>(
              future: _managerFuture,
              builder: (context, managerSnapshot) {
                return IconButton(
                  icon: const Icon(Icons.info_outline, color: infoColor),
                  tooltip: 'Ver Informações',
                  onPressed: () =>
                      _showAcademyInfoDialog(context, managerSnapshot.data),
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
          child: FutureBuilder<List<dynamic>>(
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
              final teachers = users.whereType<UserModel>().toList();
              final students = users.whereType<Aluno>().toList();

              return FutureBuilder<UserModel?>(
                  future: _managerFuture,
                  builder: (context, managerSnapshot) {
                    final manager = managerSnapshot.data;
                    return ListView(
                      children: [
                        if (manager != null)
                          _buildUserSection("Gerente", [manager]),
                        if (teachers.isNotEmpty)
                          _buildUserSection("Professores", teachers),
                        if (students.isNotEmpty)
                          _buildUserSection("Alunos", students),
                      ],
                    );
                  });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection(String title, List<dynamic> users) {
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
            final bool isStudent = user is Aluno;
            final String name = isStudent ? user.nome : user.name;
            final String uid = isStudent ? user.userId ?? '' : user.uid;
            final String? image =
                isStudent ? null : (user as UserModel).profileImagePath;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: (image != null && image.isNotEmpty)
                      ? CachedNetworkImageProvider(image)
                      : null,
                  child: (image == null || image.isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(name),
                trailing: (uid.isNotEmpty)
                    ? IconButton(
                        icon: const Icon(Icons.theater_comedy_outlined,
                            color: warningColor),
                        tooltip: 'Entrar como $name',
                        onPressed: () => _startImpersonation(uid),
                      )
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AcademyInfoDialog extends StatelessWidget {
  final DocumentSnapshot academyDoc;
  final UserModel? manager;

  const _AcademyInfoDialog({required this.academyDoc, this.manager});

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
  bool _isLifetime = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.academyDoc.data() as Map<String, dynamic>;
    _currentStatus = data['status'] ?? 'active';
    final endDate = (data['subscriptionEndDate'] as Timestamp?)?.toDate();

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
