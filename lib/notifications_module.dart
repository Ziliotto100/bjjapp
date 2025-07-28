// lib/notifications_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class NotificationsPage extends StatefulWidget {
  final UserModel user;
  const NotificationsPage({super.key, required this.user});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<UserModel> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
  }

  Future<void> _fetchAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('academyId', isEqualTo: widget.user.academyId)
          .get();
      if (mounted) {
        setState(() {
          _allUsers =
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
        });
      }
    } catch (e) {
      // Tratar erro se necessário
    }
  }

  void _showSendNotificationDialog(BuildContext context,
      {NotificationModel? notification}) {
    showDialog(
      context: context,
      builder: (_) => _SendNotificationDialog(
          user: widget.user, notificationToEdit: notification),
    );
  }

  // --- NOVA FUNÇÃO PARA MARCAR COMO LIDO ---
  void _markNotificationsAsRead(List<NotificationModel> notifications) {
    // Adiciona um pequeno atraso para garantir que a UI tenha tempo de construir
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final batch = FirebaseFirestore.instance.batch();
      int updates = 0;

      for (final notification in notifications) {
        if (!notification.readBy.contains(widget.user.uid)) {
          final docRef = FirebaseFirestore.instance
              .collection('academies')
              .doc(widget.user.academyId)
              .collection('notifications')
              .doc(notification.id);
          batch.update(docRef, {
            'readBy': FieldValue.arrayUnion([widget.user.uid])
          });
          updates++;
        }
      }

      if (updates > 0) {
        try {
          await batch.commit();
        } catch (e) {
          // Erro silencioso para não incomodar o usuário
          debugPrint("Erro ao marcar avisos como lidos: $e");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canSend = widget.user.role == UserRole.manager ||
        widget.user.role == UserRole.teacher;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('academies')
            .doc(widget.user.academyId)
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyStateWidget(
              icon: Icons.error_outline,
              title: 'Erro ao Carregar',
              message: 'Não foi possível buscar os avisos.',
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.notifications_off_outlined,
              title: 'Nenhum Aviso',
              message: 'Ainda não há avisos para a sua academia.',
            );
          }

          final notifications = snapshot.data!.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();

          // Chama a função para marcar como lido
          _markNotificationsAsRead(notifications);

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                user: widget.user,
                allUsers: _allUsers, // Passa a lista de usuários
              );
            },
          );
        },
      ),
      floatingActionButton: canSend
          ? FloatingActionButton(
              onPressed: () => _showSendNotificationDialog(context),
              tooltip: 'Enviar Novo Aviso',
              child: const Icon(Icons.add_alert_rounded),
            )
          : null,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final UserModel user;
  final List<UserModel> allUsers; // <-- Recebe a lista de todos os usuários

  const _NotificationCard(
      {required this.notification, required this.user, required this.allUsers});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
            'Tem certeza que deseja excluir este aviso permanentemente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
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
                showBjjSnackBar(context, 'Erro ao excluir o aviso.',
                    type: 'error');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _SendNotificationDialog(
        user: user,
        notificationToEdit: notification,
      ),
    );
  }

  // --- NOVA FUNÇÃO PARA MOSTRAR QUEM VISUALIZOU ---
  void _showViewersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ViewersDialog(
          readByUserIds: notification.readBy, allUsers: allUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canModify =
        user.role == UserRole.manager || user.role == UserRole.teacher;
    final bool isUnread = !notification.readBy.contains(user.uid);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: infoColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          notification.title,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canModify)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditDialog(context);
                      } else if (value == 'delete') {
                        _confirmDelete(context);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Editar Aviso'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Excluir Aviso'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.message,
              style:
                  Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Por: ${notification.senderName}',
                  style: const TextStyle(color: textHint, fontSize: 12),
                ),
                Text(
                  DateFormat.yMd('pt_BR')
                      .add_Hm()
                      .format(notification.createdAt.toDate()),
                  style: const TextStyle(color: textHint, fontSize: 12),
                ),
              ],
            ),
            // --- NOVO BOTÃO DE VISUALIZAÇÕES ---
            if (canModify)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: TextButton.icon(
                  onPressed: () => _showViewersDialog(context),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label:
                      Text('Visto por ${notification.readBy.length} pessoas'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- NOVO WIDGET PARA MOSTRAR QUEM VISUALIZOU ---
class _ViewersDialog extends StatelessWidget {
  final List<String> readByUserIds;
  final List<UserModel> allUsers;

  const _ViewersDialog({required this.readByUserIds, required this.allUsers});

  @override
  Widget build(BuildContext context) {
    final viewers = allUsers
        .where((user) => readByUserIds.contains(user.uid))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return AlertDialog(
      title: const Text('Visualizações'),
      content: SizedBox(
        width: double.maxFinite,
        child: viewers.isEmpty
            ? const Center(child: Text('Ninguém visualizou este aviso ainda.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final user = viewers[index];
                  return ListTile(
                    title: Text(user.name),
                    leading: const Icon(Icons.person_outline),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        )
      ],
    );
  }
}

class _SendNotificationDialog extends StatefulWidget {
  final UserModel user;
  final NotificationModel? notificationToEdit;

  const _SendNotificationDialog({required this.user, this.notificationToEdit});

  @override
  State<_SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  bool get _isEditing => widget.notificationToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.notificationToEdit!.title;
      _messageController.text = widget.notificationToEdit!.message;
    }
  }

  Future<void> _saveNotification() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSending = true);

    final collectionRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('notifications');

    try {
      if (_isEditing) {
        await collectionRef.doc(widget.notificationToEdit!.id).update({
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
        });
      } else {
        await collectionRef.add({
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
          'senderId': widget.user.uid,
          'senderName': widget.user.name,
          'senderRole': widget.user.role.toString().split('.').last,
          'academyId': widget.user.academyId,
          'createdAt': FieldValue.serverTimestamp(),
          'readBy': [], // <-- Inicializa a lista de lidos
        });
      }

      Navigator.of(context).pop();
      showBjjSnackBar(
          context, _isEditing ? 'Aviso atualizado!' : 'Aviso enviado!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar aviso: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Aviso' : 'Enviar Novo Aviso'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'O título é obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Mensagem',
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'A mensagem é obrigatória'
                    : null,
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
          onPressed: _isSending ? null : _saveNotification,
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Salvar' : 'Enviar'),
        ),
      ],
    );
  }
}
