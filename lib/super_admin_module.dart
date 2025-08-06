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

// Tela principal do Super Admin
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  late Future<Map<String, UserModel>> _managersFuture;

  @override
  void initState() {
    super.initState();
    _managersFuture = _fetchManagers();
  }

  Future<Map<String, UserModel>> _fetchManagers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'manager')
        .get();

    return {
      for (var doc in snapshot.docs) doc.id: UserModel.fromFirestore(doc)
    };
  }

  void _showAcademyInfoDialog(
      BuildContext context, DocumentSnapshot academyDoc, UserModel? manager) {
    showDialog(
      context: context,
      builder: (_) =>
          _AcademyInfoDialog(academyDoc: academyDoc, manager: manager),
    );
  }

  Future<void> _startImpersonation(String targetManagerId) async {
    final superAdminUid = FirebaseAuth.instance.currentUser?.uid;
    if (superAdminUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('impersonation_sessions')
          .doc(superAdminUid)
          .set({'targetUid': targetManagerId});

      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao iniciar a personificação: $e',
            type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Painel de Controle Master'),
        // --- BOTÃO DE LOGOUT ADICIONADO AQUI ---
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, UserModel>>(
            future: _managersFuture,
            builder: (context, managersSnapshot) {
              if (managersSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (managersSnapshot.hasError || !managersSnapshot.hasData) {
                return const EmptyStateWidget(
                    icon: Icons.error, title: 'Erro ao carregar gerentes');
              }
              final managersMap = managersSnapshot.data!;

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('academies')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, academySnapshot) {
                  if (academySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!academySnapshot.hasData ||
                      academySnapshot.data!.docs.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.business_center,
                      title: 'Nenhuma Academia Cadastrada',
                    );
                  }

                  final academies = academySnapshot.data!.docs;

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _managersFuture = _fetchManagers();
                      });
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: academies.length,
                      itemBuilder: (context, index) {
                        final academyDoc = academies[index];
                        final data = academyDoc.data() as Map<String, dynamic>;

                        final academyName =
                            data['name'] ?? 'Nome não encontrado';
                        final ownerId = data['ownerId'];
                        final manager = managersMap[ownerId];
                        final managerImage = manager?.profileImagePath;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: darkSurface,
                              backgroundImage: (managerImage != null &&
                                      managerImage.isNotEmpty)
                                  ? CachedNetworkImageProvider(managerImage)
                                  : null,
                              child: (managerImage == null ||
                                      managerImage.isEmpty)
                                  ? const Icon(Icons.business, color: textHint)
                                  : null,
                            ),
                            title: Text(
                              academyName,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            subtitle: Text(
                              manager?.name ?? "Gerente não encontrado",
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (manager != null)
                                  IconButton(
                                    icon: const Icon(
                                        Icons.theater_comedy_outlined,
                                        color: warningColor),
                                    tooltip: 'Entrar como ${manager.name}',
                                    onPressed: () =>
                                        _startImpersonation(manager.uid),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.info_outline,
                                      color: infoColor),
                                  tooltip: 'Ver Informações',
                                  onPressed: () => _showAcademyInfoDialog(
                                      context, academyDoc, manager),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_note,
                                      color: primaryAccent),
                                  tooltip: 'Editar Assinatura',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) =>
                                          EditAcademySubscriptionDialog(
                                              academyDoc: academyDoc),
                                    );
                                  },
                                ),
                              ],
                            ),
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
