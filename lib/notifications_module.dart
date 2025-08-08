// lib/notifications_module.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
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
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _notificationSubscription;

  // --- NOVA VARIÁVEL DE ESTADO PARA O FILTRO ---
  String _filterMode = 'all'; // 'all' ou 'sent'

  @override
  void initState() {
    super.initState();
    _fetchAllUsers();
    _listenForNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // --- FUNÇÃO DE LÓGICA PRINCIPAL MODIFICADA ---
  void _listenForNotifications() {
    // Cancela a inscrição anterior se houver uma
    _notificationSubscription?.cancel();

    // Cria a query base
    Query query = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('notifications')
        .orderBy('createdAt', descending: true);

    // Adiciona o filtro se necessário
    if (_filterMode == 'sent') {
      query = query.where('senderId', isEqualTo: widget.user.uid);
    }

    // Escuta o stream da query construída
    _notificationSubscription = query.snapshots().listen((snapshot) {
      if (mounted) {
        final notifications = snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc))
            .toList();

        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });

        // Marca como lido apenas se estiver na visualização de "todos"
        if (_filterMode == 'all') {
          _markNotificationsAsRead(notifications);
        }
      }
    });
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
    ).then((value) {
      // Se um novo aviso foi enviado, volta para a aba "Meus Avisos"
      if (value == true && _filterMode != 'sent') {
        setState(() {
          _filterMode = 'sent';
          _isLoading = true;
        });
        _listenForNotifications();
      }
    });
  }

  void _markNotificationsAsRead(List<NotificationModel> notifications) async {
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
        debugPrint("Erro ao marcar avisos como lidos: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSend = widget.user.role == UserRole.manager ||
        widget.user.role == UserRole.teacher;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // --- WIDGET DE FILTRO ADICIONADO ---
          if (canSend)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(
                      value: 'all',
                      label: Text('Todos os Avisos'),
                      icon: Icon(Icons.notifications_rounded)),
                  ButtonSegment<String>(
                      value: 'sent',
                      label: Text('Meus Avisos'),
                      icon: Icon(Icons.send_rounded)),
                ],
                selected: {_filterMode},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _filterMode = newSelection.first;
                    _isLoading = true;
                    _listenForNotifications();
                  });
                },
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.notifications_off_outlined,
                        title: _filterMode == 'sent'
                            ? 'Nenhum Aviso Enviado'
                            : 'Nenhum Aviso',
                        message: _filterMode == 'sent'
                            ? 'Os avisos que você enviar aparecerão aqui.'
                            : 'Ainda não há avisos para a sua academia.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _NotificationCard(
                            notification: notification,
                            user: widget.user,
                            allUsers: _allUsers,
                          );
                        },
                      ),
          ),
        ],
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
  final List<UserModel> allUsers;

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

  void _showViewersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ViewersDialog(
          readByUserIds: notification.readBy, allUsers: allUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE PERMISSÃO MODIFICADA ---
    final bool canManageThisNotification = notification.senderId == user.uid;
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
                // --- BOTÃO DE MENU AGORA DEPENDE SE O USUÁRIO É O AUTOR ---
                if (canManageThisNotification)
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
            if (canManageThisNotification)
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
          'readBy': [],
        });
      }

      // --- RETORNA 'true' PARA INDICAR SUCESSO ---
      Navigator.of(context).pop(true);
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
