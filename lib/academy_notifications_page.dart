// lib/academy_notifications_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

class AcademyNotificationsPage extends StatefulWidget {
  final UserModel user;
  const AcademyNotificationsPage({super.key, required this.user});

  @override
  State<AcademyNotificationsPage> createState() =>
      _AcademyNotificationsPageState();
}

class _AcademyNotificationsPageState extends State<AcademyNotificationsPage> {
  void _showSendNotificationDialog({DocumentSnapshot? notificationToEdit}) {
    showDialog(
      context: context,
      builder: (_) => _SendNotificationDialog(
        user: widget.user,
        notificationToEdit: notificationToEdit,
      ),
    );
  }

  Future<void> _deleteNotification(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Tem certeza que deseja excluir este comunicado?'),
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
            .collection('academies')
            .doc(widget.user.academyId)
            .collection('notification_requests')
            .doc(docId)
            .delete();
        showBjjSnackBar(context, 'Comunicado excluído com sucesso!',
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
            .collection('academies')
            .doc(widget.user.academyId)
            .collection('notification_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyStateWidget(
                icon: Icons.error, title: 'Erro ao carregar comunicados');
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
                icon: Icons.notifications_off_outlined,
                title: 'Nenhum Comunicado',
                message: 'Clique em "Novo Comunicado" para enviar o primeiro.');
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Sem título';
              final author = data['authorName'] ?? 'Desconhecido';
              final timestamp = data['createdAt'] as Timestamp?;

              return Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.campaign_outlined, color: primaryAccent),
                  title: Text(title),
                  subtitle: Text(
                    'Por: $author em ${timestamp != null ? DateFormat('dd/MM/yy \'às\' HH:mm').format(timestamp.toDate()) : ''}',
                  ),
                  trailing: (data['authorUid'] == widget.user.uid ||
                          widget.user.role == UserRole.manager)
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showSendNotificationDialog(
                                  notificationToEdit: notification);
                            } else if (value == 'delete') {
                              _deleteNotification(notification.id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Editar')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Excluir')),
                          ],
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSendNotificationDialog(),
        label: const Text('Novo Comunicado'),
        icon: const Icon(Icons.send_rounded),
      ),
    );
  }
}

class _SendNotificationDialog extends StatefulWidget {
  final UserModel user;
  final DocumentSnapshot? notificationToEdit;
  const _SendNotificationDialog({required this.user, this.notificationToEdit});

  @override
  State<_SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.notificationToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final data = widget.notificationToEdit!.data() as Map<String, dynamic>;
      _titleController.text = data['title'] ?? '';
      _bodyController.text = data['body'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendNotificationRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      'authorUid': widget.user.uid,
      'authorName': widget.user.name,
      'academyId': widget.user.academyId,
      'createdAt': _isEditing
          ? widget.notificationToEdit!['createdAt']
          : FieldValue.serverTimestamp(),
      'status': 'pending',
    };

    final collectionRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('notification_requests');

    try {
      if (_isEditing) {
        await collectionRef.doc(widget.notificationToEdit!.id).update(data);
      } else {
        await collectionRef.add(data);
      }
      Navigator.of(context).pop();
      showBjjSnackBar(
          context,
          _isEditing
              ? 'Comunicado atualizado!'
              : 'Comunicado enviado para a fila!',
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
      title: Text(_isEditing ? 'Editar Comunicado' : 'Novo Comunicado'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obrigatório'
                    : null,
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
