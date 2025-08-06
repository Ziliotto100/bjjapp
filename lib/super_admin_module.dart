// lib/super_admin_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';
import 'auth_gate.dart';

// --- TELA PRINCIPAL DO ADMIN (LISTA DE ACADEMIAS) ---
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Painel de Controle Master'),
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
          child: StreamBuilder<QuerySnapshot>(
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
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: academies.length,
                itemBuilder: (context, index) {
                  final academyDoc = academies[index];
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
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// --- TELA DE DETALHES DA ACADEMIA E LISTA DE USUÁRIOS ---
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

    // Busca professores
    final teachersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('academyId', isEqualTo: academyId)
        .where('role', isEqualTo: 'teacher')
        .get();
    allUsers.addAll(
        teachersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)));

    // Busca alunos
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(academyName),
        // --- BOTÕES DE GERENCIAMENTO ADICIONADOS AQUI ---
        actions: [
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
