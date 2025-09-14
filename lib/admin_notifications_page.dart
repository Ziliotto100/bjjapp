// lib/admin_notifications_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({super.key});

  @override
  State<AdminNotificationsPage> createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  void _showSendNotificationDialog({
    List<DocumentSnapshot>? allAcademies,
    DocumentSnapshot? notificationToEdit,
  }) {
    // Se estiver a editar, não precisa carregar todas as academias novamente.
    if (notificationToEdit == null && allAcademies != null) {
      showDialog(
        context: context,
        builder: (_) => _SendNotificationDialog(allAcademies: allAcademies),
      );
    } else if (notificationToEdit != null) {
      showDialog(
        context: context,
        builder: (_) => _SendNotificationDialog(
          notificationToEdit: notificationToEdit,
          allAcademies: const [], // Não é necessário ao editar
        ),
      );
    }
  }

  Future<void> _deleteNotification(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
            'Tem certeza que deseja excluir este registo de notificação? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
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
            .collection('notification_requests')
            .doc(docId)
            .delete();
        showBjjSnackBar(context, 'Registo excluído com sucesso!',
            type: 'success');
      } catch (e) {
        showBjjSnackBar(context, 'Erro ao excluir: $e', type: 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notification_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyStateWidget(
                icon: Icons.error, title: 'Erro ao carregar histórico');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
                icon: Icons.notifications_off_outlined,
                title: 'Nenhuma Notificação',
                message: 'Clique em "Nova Mensagem" para enviar a primeira.');
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Sem título';
              final timestamp = data['createdAt'] as Timestamp?;
              final status = data['status'] ?? 'pending';

              IconData statusIcon;
              Color statusColor;
              switch (status) {
                case 'complete':
                  statusIcon = Icons.check_circle_outline;
                  statusColor = successColor;
                  break;
                case 'failed':
                  statusIcon = Icons.error_outline;
                  statusColor = errorColor;
                  break;
                default:
                  statusIcon = Icons.hourglass_top_rounded;
                  statusColor = warningColor;
              }

              return Card(
                child: ListTile(
                  leading: Icon(statusIcon, color: statusColor),
                  title: Text(title),
                  subtitle: Text(
                    timestamp != null
                        ? DateFormat('dd/MM/yy \'às\' HH:mm')
                            .format(timestamp.toDate())
                        : 'Enviando...',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showSendNotificationDialog(
                            notificationToEdit: notification);
                      } else if (value == 'delete') {
                        _deleteNotification(notification.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final academiesSnapshot = await FirebaseFirestore.instance
              .collection('academies')
              .orderBy('name')
              .get();
          _showSendNotificationDialog(allAcademies: academiesSnapshot.docs);
        },
        label: const Text('Nova Mensagem'),
        icon: const Icon(Icons.send_rounded),
      ),
    );
  }
}

class _SendNotificationDialog extends StatefulWidget {
  final List<DocumentSnapshot> allAcademies;
  final DocumentSnapshot? notificationToEdit;
  const _SendNotificationDialog(
      {required this.allAcademies, this.notificationToEdit});

  @override
  State<_SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sendToAll = true;
  List<String> _selectedAcademyIds = [];
  bool _isLoading = false;
  final _searchController = TextEditingController();
  List<DocumentSnapshot> _filteredAcademies = [];

  bool get _isEditing => widget.notificationToEdit != null;

  @override
  void initState() {
    super.initState();
    _filteredAcademies = widget.allAcademies;
    _searchController.addListener(_filterList);

    if (_isEditing) {
      final data = widget.notificationToEdit!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _bodyController.text = data['body'] ?? '';
      _sendToAll = data['sendToAll'] ?? true;
      _selectedAcademyIds = List<String>.from(data['academyIds'] ?? []);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAcademies = widget.allAcademies.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _sendNotificationRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_sendToAll && _selectedAcademyIds.isEmpty && !_isEditing) {
      showBjjSnackBar(context, 'Selecione pelo menos uma academia.',
          type: 'error');
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      'sendToAll': _sendToAll,
      'academyIds': _sendToAll ? [] : _selectedAcademyIds,
      'createdAt': _isEditing
          ? widget.notificationToEdit!['createdAt']
          : FieldValue.serverTimestamp(),
      'status': 'pending',
    };

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance
            .collection('notification_requests')
            .doc(widget.notificationToEdit!.id)
            .update(data);
      } else {
        await FirebaseFirestore.instance
            .collection('notification_requests')
            .add(data);
      }
      Navigator.of(context).pop();
      showBjjSnackBar(
          context,
          _isEditing
              ? 'Notificação atualizada!'
              : 'Solicitação de notificação enviada!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Notificação' : 'Enviar Notificação'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Campo obrigatório'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                      labelText: 'Mensagem', alignLabelWithHint: true),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Campo obrigatório'
                      : null,
                ),
                const SizedBox(height: 16),
                if (!_isEditing)
                  SwitchListTile(
                    title: const Text('Enviar para todas as academias'),
                    value: _sendToAll,
                    onChanged: (value) => setState(() => _sendToAll = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                if (!_sendToAll && !_isEditing) ...[
                  const SizedBox(height: 8),
                  Text('Selecione as Academias',
                      style: Theme.of(context).textTheme.titleSmall),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                        labelText: 'Buscar academia...',
                        prefixIcon: Icon(Icons.search)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                        border: Border.all(color: borderNormal),
                        borderRadius: BorderRadius.circular(8.0)),
                    child: _filteredAcademies.isEmpty
                        ? const Center(
                            child: Text("Nenhuma academia encontrada."))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _filteredAcademies.length,
                            itemBuilder: (context, index) {
                              final doc = _filteredAcademies[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final isSelected =
                                  _selectedAcademyIds.contains(doc.id);
                              return CheckboxListTile(
                                title: Text(data['name'] ?? 'Sem nome'),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedAcademyIds.add(doc.id);
                                    } else {
                                      _selectedAcademyIds.remove(doc.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        "${_selectedAcademyIds.length} academia(s) selecionada(s)"),
                  )
                ]
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
          onPressed: _isLoading ? null : _sendNotificationRequest,
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator())
              : Text(_isEditing ? 'Salvar' : 'Enviar'),
        ),
      ],
    );
  }
}
