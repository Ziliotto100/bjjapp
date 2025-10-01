// lib/study_notebook_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use, prefer_final_fields, unused_field

import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:video_compress/video_compress.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';
import 'user_card_widget.dart';
import 'video_library_module.dart';

// --- SERVICE (Inalterado) ---
class StudyNoteService {
  final String userId;

  StudyNoteService({required this.userId});

  CollectionReference get _subjectsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('study_subjects');
  CollectionReference get _volumesCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('study_volumes');
  CollectionReference get _notesCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('study_notes');
  CollectionReference get _tagsCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('study_tags');

  // --- MÉTODOS DE TAGS ---
  Stream<List<String>> getTagsStream() {
    return _tagsCollection.orderBy('name').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc['name'] as String).toList());
  }

  Future<void> addTag(String tagName) async {
    final query = await _tagsCollection
        .where('name', isEqualTo: tagName.trim())
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      await _tagsCollection.add({'name': tagName.trim()});
    }
  }

  Future<void> deleteTag(String tagName) async {
    final query =
        await _tagsCollection.where('name', isEqualTo: tagName).limit(1).get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
    }
  }

  // --- MÉTODOS DE ASSUNTOS ---
  Stream<QuerySnapshot> getSubjectsStream() {
    return _subjectsCollection.orderBy('orderIndex').snapshots();
  }

  Stream<QuerySnapshot> getQuickNotesStream() {
    return _notesCollection.where('subjectId', isNull: true).snapshots();
  }

  Future<void> saveSubject(StudySubject subject) async {
    final data = subject.toJson();
    if (subject.id.isEmpty) {
      final querySnapshot = await _subjectsCollection
          .orderBy('orderIndex', descending: true)
          .limit(1)
          .get();
      final maxIndex = querySnapshot.docs.isNotEmpty
          ? (querySnapshot.docs.first.data()
                  as Map<String, dynamic>)['orderIndex'] ??
              0
          : 0;
      data['orderIndex'] = maxIndex + 1;
      await _subjectsCollection.add(data);
    } else {
      await _subjectsCollection.doc(subject.id).update(data);
    }
  }

  Future<void> reorderSubjects(List<StudySubject> reorderedSubjects) {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reorderedSubjects.length; i++) {
      final docRef = _subjectsCollection.doc(reorderedSubjects[i].id);
      batch.update(docRef, {'orderIndex': i});
    }
    return batch.commit();
  }

  Future<void> deleteSubject(String subjectId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_subjectsCollection.doc(subjectId));
    final volumesSnapshot =
        await _volumesCollection.where('subjectId', isEqualTo: subjectId).get();
    for (var volDoc in volumesSnapshot.docs) {
      batch.delete(volDoc.reference);
    }
    final notesSnapshot =
        await _notesCollection.where('subjectId', isEqualTo: subjectId).get();
    for (var noteDoc in notesSnapshot.docs) {
      batch.delete(noteDoc.reference);
    }
    return batch.commit();
  }

  // --- MÉTODOS DE VOLUMES ---
  Stream<QuerySnapshot> getVolumesStream(String subjectId) {
    return _volumesCollection
        .where('subjectId', isEqualTo: subjectId)
        .orderBy('orderIndex')
        .snapshots();
  }

  Future<void> saveVolume(StudyVolume volume) async {
    final data = volume.toJson();
    if (volume.id.isEmpty) {
      final querySnapshot = await _volumesCollection
          .where('subjectId', isEqualTo: volume.subjectId)
          .orderBy('orderIndex', descending: true)
          .limit(1)
          .get();
      final maxIndex = querySnapshot.docs.isNotEmpty
          ? (querySnapshot.docs.first.data()
                  as Map<String, dynamic>)['orderIndex'] ??
              0
          : 0;
      data['orderIndex'] = maxIndex + 1;
      await _volumesCollection.add(data);
    } else {
      await _volumesCollection.doc(volume.id).update(data);
    }
  }

  Future<void> reorderVolumes(List<StudyVolume> reorderedVolumes) {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reorderedVolumes.length; i++) {
      final docRef = _volumesCollection.doc(reorderedVolumes[i].id);
      batch.update(docRef, {'orderIndex': i});
    }
    return batch.commit();
  }

  Future<void> deleteVolume(String volumeId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_volumesCollection.doc(volumeId));
    final notesSnapshot =
        await _notesCollection.where('volumeId', isEqualTo: volumeId).get();
    for (var doc in notesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    return batch.commit();
  }

  // --- MÉTODOS DE ANOTAÇÕES ---
  Stream<QuerySnapshot> getNotesStream(String volumeId) {
    return _notesCollection
        .where('volumeId', isEqualTo: volumeId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getRootNotesStream(String subjectId) {
    return _notesCollection
        .where('subjectId', isEqualTo: subjectId)
        .where('volumeId', isNull: true)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Stream<int> getNotesCountStream(String volumeId) {
    return _notesCollection
        .where('volumeId', isEqualTo: volumeId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> saveNote(StudyNote note) {
    final data = note.toJson();
    if (note.id.isEmpty) {
      return _notesCollection.add(data).then((_) {});
    } else {
      return _notesCollection.doc(note.id).update(data);
    }
  }

  Future<void> deleteNote(String noteId) async {
    final docRef = _notesCollection.doc(noteId);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) return;

    final note = StudyNote.fromFirestore(docSnapshot);

    if (note.imagePath != null && note.imagePath!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(note.imagePath!).delete();
      } catch (e) {
        debugPrint("Erro ao deletar imagem do Storage: $e");
      }
    }
    if (note.videoUrl != null && note.videoUrl!.isNotEmpty) {
      try {
        final isExternalUrl = note.videoUrl!.contains('youtube.com') ||
            note.videoUrl!.contains('youtu.be') ||
            note.videoUrl!.contains('instagram.com');
        if (!isExternalUrl) {
          await FirebaseStorage.instance.refFromURL(note.videoUrl!).delete();
        }
      } catch (e) {
        debugPrint("Erro ao deletar vídeo do Storage: $e");
      }
    }

    await docRef.delete();
  }

  Future<String?> saveImage(XFile image) async {
    try {
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('study_notes_images')
          .child(userId)
          .child(fileName);
      await ref.putData(await image.readAsBytes());
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Erro ao salvar imagem no Storage: $e");
      return null;
    }
  }

  UploadTask saveVideo(dynamic videoFile, String fileName) {
    final ref = FirebaseStorage.instance
        .ref()
        .child('study_notes_videos')
        .child(userId)
        .child(fileName);

    if (kIsWeb) {
      return ref.putData(
          videoFile as Uint8List, SettableMetadata(contentType: 'video/mp4'));
    } else {
      return ref.putFile(videoFile as File);
    }
  }
}

// --- TELA PRINCIPAL (ASSUNTOS) ---
class StudyNotebookPage extends StatefulWidget {
  final String userId;
  // O plano da academia é recebido para verificar a permissão
  final SubscriptionPlan? currentPlan;

  const StudyNotebookPage({
    super.key,
    required this.userId,
    this.currentPlan, // Adicionado ao construtor
  });

  @override
  State<StudyNotebookPage> createState() => _StudyNotebookPageState();
}

class _StudyNotebookPageState extends State<StudyNotebookPage> {
  late final StudyNoteService _noteService;
  List<StudySubject> _subjects = [];

  @override
  void initState() {
    super.initState();
    _noteService = StudyNoteService(userId: widget.userId);
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.note_add_outlined, color: primaryAccent),
                title: const Text('Anotação Rápida'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditStudyNotePage(
                        userId: widget.userId,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined,
                    color: primaryAccent),
                title: const Text('Novo Volume'),
                onTap: () {
                  Navigator.pop(context);
                  _showSubjectDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubjectDialog({StudySubject? subject}) {
    final controller = TextEditingController(text: subject?.title ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(subject == null ? 'Novo Volume' : 'Editar Volume'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome do Volume'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final newSubject = StudySubject(
                    id: subject?.id ?? '',
                    title: controller.text.trim(),
                    createdAt: subject?.createdAt ?? DateTime.now(),
                    orderIndex: subject?.orderIndex ?? 0,
                  );
                  _noteService.saveSubject(newSubject);
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSubject(StudySubject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Volume?'),
        content: Text(
            'Isso excluirá "${subject.title}" e todos os seus subvolumes e anotações permanentemente. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              _noteService.deleteSubject(subject.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir Tudo'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteQuickNote(String noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Anotação?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              _noteService.deleteNote(noteId);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE PERMISSÃO CENTRALIZADA AQUI ---
    final bool hasAccess =
        widget.currentPlan?.features['study_notebook'] ?? false;

    if (!hasAccess) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const AppBackground(
          child: SafeArea(
            child: EmptyStateWidget(
              icon: Icons.book_outlined,
              title: 'Recurso Premium',
              message:
                  'O Caderno de Estudos é um recurso exclusivo. Peça ao gerente da sua academia para saber mais sobre os planos de assinatura.',
            ),
          ),
        ),
      );
    }

    // Se o acesso for permitido, constrói a tela normal.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: _noteService.getQuickNotesStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final quickNotes = snapshot.data!.docs
                    .map((doc) => StudyNote.fromFirestore(doc))
                    .toList()
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Anotações Rápidas',
                          style: TextStyle(color: textHint, fontSize: 16)),
                    ),
                    AnimationLimiter(
                      child: MasonryGridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        itemCount: quickNotes.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        itemBuilder: (context, index) {
                          final note = quickNotes[index];
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            columnCount: 2,
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: _QuickNoteCard(
                                  note: note,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            NoteDetailPage(note: note)),
                                  ),
                                  onEdit: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditStudyNotePage(
                                          userId: widget.userId, note: note),
                                    ),
                                  ),
                                  onDelete: () =>
                                      _confirmDeleteQuickNote(note.id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
                stream: _noteService.getSubjectsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text('Meus Volumes',
                        style: TextStyle(color: textHint, fontSize: 16)),
                  );
                }),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: _noteService.getSubjectsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverFillRemaining(
                  child: EmptyStateWidget(
                    icon: Icons.folder_copy_outlined,
                    title: 'Nenhum Volume',
                    message:
                        'Crie sua primeira anotação rápida ou volume no botão "+".',
                  ),
                );
              }
              _subjects = snapshot.data!.docs
                  .map((doc) => StudySubject.fromFirestore(doc))
                  .toList();
              return SliverReorderableList(
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  return Padding(
                    key: ValueKey(subject.id),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_outlined,
                            color: primaryAccent),
                        title: Text(subject.title),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudyVolumesPage(
                                userId: widget.userId,
                                subject: subject,
                              ),
                            ),
                          );
                        },
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Renomear')),
                            const PopupMenuItem(
                                value: 'delete', child: Text('Excluir')),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showSubjectDialog(subject: subject);
                            } else if (value == 'delete') {
                              _confirmDeleteSubject(subject);
                            }
                          },
                        ),
                      ),
                    ),
                  );
                },
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final StudySubject item = _subjects.removeAt(oldIndex);
                    _subjects.insert(newIndex, item);
                    _noteService.reorderSubjects(_subjects);
                  });
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'study_subject_fab',
        onPressed: _showAddMenu,
        tooltip: 'Adicionar',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _QuickNoteCard extends StatelessWidget {
  final StudyNote note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuickNoteCard({
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E2830),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 40, 12),
              child: Text(
                note.content,
                style: const TextStyle(
                    color: textSecondary, fontSize: 14, height: 1.4),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: textHint, size: 20),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudyVolumesPage extends StatefulWidget {
  final String userId;
  final StudySubject subject;

  const StudyVolumesPage(
      {super.key, required this.userId, required this.subject});

  @override
  State<StudyVolumesPage> createState() => _StudyVolumesPageState();
}

class _StudyVolumesPageState extends State<StudyVolumesPage> {
  late final StudyNoteService _noteService;
  // REMOVIDA a variável de estado `_volumes` para evitar o loop de rebuild

  @override
  void initState() {
    super.initState();
    _noteService = StudyNoteService(userId: widget.userId);
  }

  void _showVolumeDialog({StudyVolume? volume}) {
    final controller = TextEditingController(text: volume?.title ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(volume == null ? 'Novo Subvolume' : 'Editar Subvolume'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome do Subvolume'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final newVolume = StudyVolume(
                    id: volume?.id ?? '',
                    title: controller.text.trim(),
                    subjectId: widget.subject.id,
                    createdAt: volume?.createdAt ?? DateTime.now(),
                    orderIndex: volume?.orderIndex ?? 0,
                  );
                  _noteService.saveVolume(newVolume);
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteVolume(StudyVolume volume) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Subvolume?'),
        content: Text(
            'Isso excluirá "${volume.title}" e todas as suas anotações permanentemente. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              _noteService.deleteVolume(volume.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir Tudo'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNote(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Anotação?'),
        content:
            const Text('Esta ação não pode ser desfeita. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _noteService.deleteNote(id);
              if (mounted) {
                showBjjSnackBar(context, 'Anotação excluída!', type: 'success');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          )
        ],
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.note_add_outlined, color: primaryAccent),
                title: const Text('Nova Anotação'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditStudyNotePage(
                        userId: widget.userId,
                        subjectId: widget.subject.id,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined,
                    color: primaryAccent),
                title: const Text('Novo Subvolume'),
                onTap: () {
                  Navigator.pop(context);
                  _showVolumeDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // >>>>> MÉTODO BUILD TOTALMENTE CORRIGIDO <<<<<
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.subject.title),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _noteService.getVolumesStream(widget.subject.id),
            builder: (context, volumesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _noteService.getRootNotesStream(widget.subject.id),
                builder: (context, notesSnapshot) {
                  if (!volumesSnapshot.hasData || !notesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final volumes = volumesSnapshot.data!.docs
                      .map((doc) => StudyVolume.fromFirestore(doc))
                      .toList();
                  final notes = notesSnapshot.data!.docs
                      .map((doc) => StudyNote.fromFirestore(doc))
                      .toList();

                  if (volumes.isEmpty && notes.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.create_new_folder_outlined,
                      title: 'Nenhum Conteúdo',
                      message: 'Crie subvolumes ou anotações no botão "+".',
                    );
                  }

                  return CustomScrollView(
                    slivers: [
                      if (volumes.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text('Subvolumes',
                                style: TextStyle(color: textHint)),
                          ),
                        ),
                        SliverReorderableList(
                          itemCount: volumes.length,
                          itemBuilder: (context, index) {
                            final volume = volumes[index];
                            return _VolumeListItem(
                              key: ValueKey(volume.id),
                              volume: volume,
                              noteService: _noteService,
                              userId: widget.userId,
                              subject: widget.subject,
                              onEdit: () => _showVolumeDialog(volume: volume),
                              onDelete: () => _confirmDeleteVolume(volume),
                            );
                          },
                          onReorder: (int oldIndex, int newIndex) {
                            final List<StudyVolume> reorderedVolumes =
                                List.from(volumes);
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final StudyVolume item =
                                reorderedVolumes.removeAt(oldIndex);
                            reorderedVolumes.insert(newIndex, item);

                            // Apenas envia a nova ordem para o Firestore.
                            // O próprio StreamBuilder se encarregará de atualizar a UI
                            // quando receber os dados atualizados.
                            _noteService.reorderVolumes(reorderedVolumes);
                          },
                        ),
                        if (notes.isNotEmpty)
                          const SliverToBoxAdapter(child: Divider(height: 32)),
                      ],
                      if (notes.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text('Anotações Gerais',
                                style: TextStyle(color: textHint)),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final note = notes[index];
                              return _NoteListItem(
                                note: note,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => NoteDetailPage(note: note),
                                  ),
                                ),
                                onEdit: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditStudyNotePage(
                                      note: note,
                                      userId: widget.userId,
                                      subjectId: widget.subject.id,
                                    ),
                                  ),
                                ),
                                onDelete: () => _confirmDeleteNote(note.id),
                              );
                            },
                            childCount: notes.length,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        tooltip: 'Adicionar',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _VolumeListItem extends StatelessWidget {
  final StudyVolume volume;
  final StudyNoteService noteService;
  final String userId;
  final StudySubject subject;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VolumeListItem({
    super.key,
    required this.volume,
    required this.noteService,
    required this.userId,
    required this.subject,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.folder_open_outlined, color: primaryAccent),
        title: Text(volume.title),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NoteListPage(
                userId: userId,
                subject: subject,
                volume: volume,
              ),
            ),
          );
        },
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Renomear')),
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            }
          },
        ),
      ),
    );
  }
}

class NoteListPage extends StatefulWidget {
  final String userId;
  final StudySubject subject;
  final StudyVolume? volume;

  const NoteListPage(
      {super.key, required this.userId, required this.subject, this.volume});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  late final StudyNoteService _noteService;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _noteService = StudyNoteService(userId: widget.userId);
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Anotação?'),
        content:
            const Text('Esta ação não pode ser desfeita. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _noteService.deleteNote(id);
              if (mounted) {
                showBjjSnackBar(context, 'Anotação excluída!', type: 'success');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.volume?.title ?? widget.subject.title)),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por título, conteúdo ou tag...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: widget.volume != null
                      ? _noteService.getNotesStream(widget.volume!.id)
                      : _noteService.getRootNotesStream(widget.subject.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const EmptyStateWidget(
                          icon: Icons.error_outline,
                          title: 'Erro ao carregar',
                          message: 'Não foi possível buscar suas anotações.');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.note_add_rounded,
                        title: 'Nenhuma Anotação',
                        message:
                            'Clique no botão "+" para criar sua primeira anotação.',
                      );
                    }

                    final allNotes = snapshot.data!.docs
                        .map((doc) => StudyNote.fromFirestore(doc))
                        .toList();

                    final searchQuery = _searchController.text.toLowerCase();
                    final filteredNotes = searchQuery.isEmpty
                        ? allNotes
                        : allNotes.where((note) {
                            final titleMatches = note.title
                                    ?.toLowerCase()
                                    .contains(searchQuery) ??
                                false;
                            final contentMatches = note.content
                                .toLowerCase()
                                .contains(searchQuery);
                            final tagMatches = note.tags.any((tag) =>
                                tag.toLowerCase().contains(searchQuery));
                            return titleMatches || contentMatches || tagMatches;
                          }).toList();

                    if (filteredNotes.isEmpty) {
                      return EmptyStateWidget(
                          icon: Icons.search_off_rounded,
                          title: 'Nenhum resultado',
                          message:
                              "Sua busca por '${_searchController.text}' não retornou resultados.");
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        return _NoteListItem(
                          note: note,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoteDetailPage(note: note),
                            ),
                          ),
                          onEdit: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditStudyNotePage(
                                note: note,
                                userId: widget.userId,
                                subjectId: widget.subject.id,
                                volumeId: widget.volume?.id,
                              ),
                            ),
                          ),
                          onDelete: () => _confirmDelete(note.id),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EditStudyNotePage(
                      userId: widget.userId,
                      subjectId: widget.subject.id,
                      volumeId: widget.volume?.id,
                    ))),
        tooltip: 'Nova Anotação',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  final StudyNote note;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteListItem({
    required this.note,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = note.imagePath != null && note.imagePath!.isNotEmpty;
    final heroTag = 'note_image_${note.id}';

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: hasImage
                          ? () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PhotoViewPage(
                                  imageUrl: note.imagePath!,
                                  heroTag: heroTag,
                                ),
                              ));
                            }
                          : null,
                      child: Hero(
                        tag: heroTag,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: darkSurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: hasImage
                                ? CachedNetworkImage(
                                    imageUrl: note.imagePath!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        Container(color: darkSurface),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.broken_image,
                                            color: textHint),
                                  )
                                : const Icon(Icons.notes_rounded,
                                    color: textHint, size: 32),
                          ),
                        ),
                      ),
                    ),
                    if (note.videoUrl != null && note.videoUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Icon(Icons.video_library_outlined,
                            size: 20, color: textHint),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.title != null && note.title!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          note.title!,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    if (note.tags.isNotEmpty)
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children: note.tags
                            .take(3)
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  labelStyle: const TextStyle(fontSize: 10),
                                  padding: const EdgeInsets.all(4),
                                  backgroundColor:
                                      primaryAccent.withOpacity(0.1),
                                  side: BorderSide.none,
                                ))
                            .toList(),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoteDetailPage extends StatelessWidget {
  final StudyNote note;
  const NoteDetailPage({super.key, required this.note});

  Future<void> _launchUrl(BuildContext context) async {
    if (note.videoUrl != null && note.videoUrl!.isNotEmpty) {
      final isKnownUrl = note.videoUrl!.contains('youtube.com') ||
          note.videoUrl!.contains('youtu.be') ||
          note.videoUrl!.contains('instagram.com');

      if (!isKnownUrl) {
        final videoItem = VideoItem(
          id: note.id,
          title: note.title ?? 'Vídeo de Estudo',
          description: note.content,
          videoUrl: note.videoUrl!,
          videoType: VideoType.uploaded,
          thumbnailUrl: note.imagePath ?? '',
          uploadedByUid: '',
          uploadedByName: '',
          createdAt: Timestamp.fromDate(note.createdAt),
          tags: note.tags,
        );
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VideoPlayerPage(video: videoItem),
        ));
      } else {
        final uri = Uri.parse(note.videoUrl!);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            showBjjSnackBar(
                context, 'Não foi possível abrir o link: ${note.videoUrl}',
                type: 'error');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isQuickNote = note.subjectId == null;
    final bool hasTitle = note.title != null && note.title!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          title: Text(isQuickNote
              ? 'Anotação Rápida'
              : (hasTitle ? note.title! : "Anotação"))),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (hasTitle && !isQuickNote)
                Text(note.title!,
                    style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Atualizado em: ${DateFormat.yMd('pt_BR').add_Hm().format(note.updatedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textHint),
              ),
              if (note.tags.isNotEmpty && !isQuickNote) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children:
                      note.tags.map((tag) => Chip(label: Text(tag))).toList(),
                ),
              ],
              const SizedBox(height: 16),
              if (note.imagePath != null && note.imagePath!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.network(
                      note.imagePath!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image,
                            size: 50, color: textHint);
                      },
                    ),
                  ),
                ),
              if (note.videoUrl != null && note.videoUrl!.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.video_library_rounded,
                        color: primaryAccent),
                    title: const Text("Assistir Vídeo de Referência"),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () => _launchUrl(context),
                  ),
                ),
              const SizedBox(height: 16),
              if (hasTitle && !isQuickNote) ...[
                Text("Anotações",
                    style: Theme.of(context).textTheme.titleLarge),
                const Divider(height: 20),
              ],
              SelectableText(
                note.content,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditStudyNotePage extends StatefulWidget {
  final StudyNote? note;
  final String userId;
  final String? subjectId;
  final String? volumeId;

  const EditStudyNotePage(
      {super.key,
      this.note,
      required this.userId,
      this.subjectId,
      this.volumeId});

  @override
  State<EditStudyNotePage> createState() => _EditStudyNotePageState();
}

class _EditStudyNotePageState extends State<EditStudyNotePage> {
  final _formKey = GlobalKey<FormState>();
  late final StudyNoteService _noteService;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _urlController = TextEditingController();

  List<String> _selectedTags = [];

  String? _imagePath;
  String? _videoPath;
  bool _isSaving = false;
  Future<UserModel?>? _userFuture;
  double _uploadProgress = 0.0;

  dynamic _videoToUpload; // Can be File (mobile) or XFile (web)
  XFile? _pickedThumbnail;

  bool get _isEditing => widget.note != null;
  bool get _isQuickNote =>
      _isEditing ? widget.note!.subjectId == null : widget.subjectId == null;

  @override
  void initState() {
    super.initState();
    _noteService = StudyNoteService(userId: widget.userId);
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get()
        .then(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
        );
    if (_isEditing) {
      _titleController.text = widget.note!.title ?? '';
      _contentController.text = widget.note!.content;
      _selectedTags = List<String>.from(widget.note!.tags);
      _urlController.text = widget.note!.videoUrl ?? '';
      _imagePath = widget.note!.imagePath;
      _videoPath = widget.note!.videoUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final ImagePicker picker = ImagePicker();
    if (isVideo) {
      final XFile? video = await picker.pickVideo(source: source);
      if (video == null) return;

      if (!kIsWeb) {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
                  content: Row(children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text("Comprimindo vídeo...")
                  ]),
                ));
        final compressedInfo = await VideoCompress.compressVideo(
          video.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );
        Navigator.of(context).pop();

        if (compressedInfo?.file != null) {
          final originalSize =
              (await video.length() / (1024 * 1024)).toStringAsFixed(2);
          final compressedSize =
              (await compressedInfo!.file!.length() / (1024 * 1024))
                  .toStringAsFixed(2);
          final reduction = 100 -
              ((double.parse(compressedSize) / double.parse(originalSize)) *
                  100);
          debugPrint('--- COMPRESSÃO DE VÍDEO ---');
          debugPrint('Tamanho Original: $originalSize MB');
          debugPrint('Tamanho Comprimido: $compressedSize MB');
          debugPrint('Redução de: ${reduction.toStringAsFixed(1)}%');

          setState(() {
            _videoToUpload = compressedInfo.file;
          });
        } else {
          showBjjSnackBar(context, 'Falha ao comprimir o vídeo.',
              type: 'error');
        }
      } else {
        // Na Web, não comprime, usa o arquivo original
        setState(() {
          _videoToUpload = video;
        });
      }
    } else {
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 80);
      if (image != null) {
        setState(() {
          _pickedThumbnail = image;
        });
      }
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_videoToUpload != null) {
        dynamic fileData;
        final fileName =
            '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

        if (kIsWeb) {
          fileData = await (_videoToUpload as XFile).readAsBytes();
        } else {
          fileData = _videoToUpload as File;
        }

        final uploadTask = _noteService.saveVideo(fileData, fileName);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: StreamBuilder<TaskSnapshot>(
                stream: uploadTask.snapshotEvents,
                builder: (context, snapshot) {
                  var progress = 0.0;
                  if (snapshot.hasData) {
                    final data = snapshot.data!;
                    progress = data.bytesTransferred / data.totalBytes;
                  }
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(value: progress),
                    const SizedBox(width: 20),
                    Text(
                        "Enviando vídeo... ${(progress * 100).toStringAsFixed(0)}%"),
                  ]);
                },
              ),
            ),
          ),
        );

        final snapshot = await uploadTask.whenComplete(() {});
        _videoPath = await snapshot.ref.getDownloadURL();
        if (mounted) Navigator.of(context).pop();
      }

      final tags = _isQuickNote ? <String>[] : _selectedTags;
      final noteToSave = StudyNote(
        id: _isEditing ? widget.note!.id : '',
        title: _isQuickNote ? null : _titleController.text.trim(),
        content: _contentController.text.trim(),
        tags: tags,
        videoUrl: _videoPath ??
            (_urlController.text.trim().isEmpty
                ? null
                : _urlController.text.trim()),
        imagePath: _imagePath,
        updatedAt: DateTime.now(),
        createdAt: _isEditing ? widget.note!.createdAt : DateTime.now(),
        subjectId: widget.subjectId,
        volumeId: widget.volumeId,
      );

      await _noteService.saveNote(noteToSave);

      if (mounted) {
        showBjjSnackBar(context, "Anotação salva com sucesso!",
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao salvar anotação: $e", type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _removeMedia({bool isVideo = false}) {
    setState(() {
      if (isVideo) {
        _videoPath = null;
        _videoToUpload = null;
      } else {
        _imagePath = null;
        _pickedThumbnail = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // AQUI ESTÁ A CORREÇÃO
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(_isQuickNote
              ? 'Anotação Rápida'
              : (_isEditing ? 'Editar Anotação' : 'Nova Anotação')),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveNote,
              tooltip: 'Salvar Anotação',
            )
          ],
        ),
        body: SafeArea(
          child: _isSaving
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 80,
                          width: 80,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: _uploadProgress > 0
                                    ? _uploadProgress
                                    : null,
                                strokeWidth: 6,
                                backgroundColor: darkSurface,
                              ),
                              Center(
                                child: Text(
                                  "${(_uploadProgress * 100).toStringAsFixed(0)}%",
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text("Enviando vídeo, por favor aguarde..."),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      if (!_isQuickNote) ...[
                        TextFormField(
                          controller: _titleController,
                          decoration:
                              const InputDecoration(labelText: 'Título'),
                          validator: (v) {
                            if (v != null && v.trim().isEmpty) {
                              return 'O título é obrigatório.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _contentController,
                        decoration: InputDecoration(
                          labelText:
                              _isQuickNote ? 'Sua anotação...' : 'Anotações',
                          alignLabelWithHint: true,
                        ),
                        maxLines: _isQuickNote ? 15 : 10,
                        autofocus: _isQuickNote,
                        validator: (v) => v!.trim().isEmpty
                            ? 'O conteúdo é obrigatório.'
                            : null,
                      ),
                      if (!_isQuickNote) ...[
                        const SizedBox(height: 16),
                        _TagsInputField(
                          noteService: _noteService,
                          initialTags: _selectedTags,
                          onChanged: (newTags) {
                            setState(() {
                              _selectedTags = newTags;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        decoration: InputDecoration(
                            labelText: 'Link do Vídeo (Opcional)',
                            enabled: _videoPath == null),
                      ),
                      const SizedBox(height: 24),
                      if (_imagePath != null && _imagePath!.isNotEmpty)
                        _buildMediaPreview(
                            isImage: true,
                            path: _imagePath!,
                            onRemove: () => _removeMedia(isVideo: false)),
                      if (_videoToUpload != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              'Vídeo selecionado: ${kIsWeb ? (_videoToUpload as XFile).name : (_videoToUpload as File).path.split('/').last}',
                              style: const TextStyle(color: textHint)),
                        ),
                      FutureBuilder<UserModel?>(
                        future: _userFuture,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final user = snapshot.data!;
                          return Column(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.attach_file),
                                label: Text(_imagePath == null
                                    ? 'Anexar Imagem'
                                    : 'Trocar Imagem'),
                                onPressed: () =>
                                    _pickMedia(ImageSource.gallery),
                              ),
                              if (user.canUploadStudyVideos)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.video_call_outlined),
                                    label: Text(_videoToUpload == null
                                        ? 'Anexar Vídeo'
                                        : 'Trocar Vídeo'),
                                    onPressed: () => _pickMedia(
                                        ImageSource.gallery,
                                        isVideo: true),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview(
      {required bool isImage,
      required String path,
      required VoidCallback onRemove}) {
    return Column(
      children: [
        Text(isImage ? "Imagem Anexada:" : "Vídeo Anexado:",
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: darkSurface, borderRadius: BorderRadius.circular(12)),
              child: isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        path,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.error, color: textHint),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.videocam, size: 50, color: textHint)),
            ),
            IconButton(
              icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, color: Colors.white)),
              onPressed: onRemove,
            )
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TagsInputField extends StatefulWidget {
  final StudyNoteService noteService;
  final List<String> initialTags;
  final ValueChanged<List<String>> onChanged;

  const _TagsInputField({
    required this.noteService,
    required this.initialTags,
    required this.onChanged,
  });

  @override
  State<_TagsInputField> createState() => _TagsInputFieldState();
}

class _TagsInputFieldState extends State<_TagsInputField> {
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _selectedTags = List<String>.from(widget.initialTags);
  }

  void _showManageTagsDialog() {
    showDialog(
      context: context,
      builder: (context) => _ManageTagsDialog(noteService: widget.noteService),
    );
  }

  void _showAddTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Guarda Aranha'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final newTag = controller.text.trim();
                widget.noteService.addTag(newTag);
                if (!_selectedTags.contains(newTag)) {
                  setState(() {
                    _selectedTags.add(newTag);
                  });
                  widget.onChanged(_selectedTags);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Tags'),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _selectedTags.map((tag) {
              return Chip(
                label: Text(tag),
                onDeleted: () {
                  setState(() {
                    _selectedTags.remove(tag);
                  });
                  widget.onChanged(_selectedTags);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<String>>(
          stream: widget.noteService.getTagsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final availableTags = snapshot.data!
                .where((tag) => !_selectedTags.contains(tag))
                .toList();

            return Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                ...availableTags.map((tag) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedTags.add(tag);
                      });
                      widget.onChanged(_selectedTags);
                    },
                    child: Chip(
                      label: Text(tag),
                      backgroundColor: darkSurface,
                    ),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Nova'),
                  onPressed: _showAddTagDialog,
                ),
                ActionChip(
                  avatar: const Icon(Icons.settings, size: 16),
                  label: const Text('Gerenciar'),
                  onPressed: _showManageTagsDialog,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ManageTagsDialog extends StatelessWidget {
  final StudyNoteService noteService;
  const _ManageTagsDialog({required this.noteService});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gerenciar Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<List<String>>(
          stream: noteService.getTagsStream(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('Nenhuma tag criada.'));
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final tag = snapshot.data![index];
                return ListTile(
                  title: Text(tag),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: errorColor),
                    onPressed: () => noteService.deleteTag(tag),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar')),
      ],
    );
  }
}
