// lib/study_notebook_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';

// --- SERVICE (Refatorado para suportar a nova estrutura) ---
class StudyNoteService {
  final String userId;

  StudyNoteService({required this.userId});

  // Caminhos das coleções
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

  // --- MÉTODOS PARA ASSUNTOS (SUBJECTS) ---
  Stream<QuerySnapshot> getSubjectsStream() {
    return _subjectsCollection
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> saveSubject(StudySubject subject) {
    final data = subject.toJson();
    if (subject.id.isEmpty) {
      return _subjectsCollection.add(data);
    } else {
      return _subjectsCollection.doc(subject.id).update(data);
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    final batch = FirebaseFirestore.instance.batch();
    // Deleta o assunto
    batch.delete(_subjectsCollection.doc(subjectId));
    // Deleta volumes e anotações associados (requer múltiplas leituras)
    final volumesSnapshot =
        await _volumesCollection.where('subjectId', isEqualTo: subjectId).get();
    for (var volDoc in volumesSnapshot.docs) {
      batch.delete(volDoc.reference);
      final notesSnapshot =
          await _notesCollection.where('volumeId', isEqualTo: volDoc.id).get();
      for (var noteDoc in notesSnapshot.docs) {
        batch.delete(noteDoc.reference);
      }
    }
    return batch.commit();
  }

  // --- MÉTODOS PARA VOLUMES ---
  Stream<QuerySnapshot> getVolumesStream(String subjectId) {
    // CORREÇÃO: Removida a ordenação do Firestore para evitar problemas de índice.
    // A ordenação será feita no lado do cliente (no widget).
    return _volumesCollection
        .where('subjectId', isEqualTo: subjectId)
        .snapshots();
  }

  Future<void> saveVolume(StudyVolume volume) {
    final data = volume.toJson();
    if (volume.id.isEmpty) {
      return _volumesCollection.add(data);
    } else {
      return _volumesCollection.doc(volume.id).update(data);
    }
  }

  Future<void> deleteVolume(String volumeId) async {
    final batch = FirebaseFirestore.instance.batch();
    // Deleta o volume
    batch.delete(_volumesCollection.doc(volumeId));
    // Deleta anotações associadas
    final notesSnapshot =
        await _notesCollection.where('volumeId', isEqualTo: volumeId).get();
    for (var doc in notesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    return batch.commit();
  }

  // --- MÉTODOS PARA ANOTAÇÕES (NOTES) ---
  Stream<QuerySnapshot> getNotesStream(String volumeId) {
    return _notesCollection
        .where('volumeId', isEqualTo: volumeId)
        .orderBy('updatedAt', descending: true)
        .snapshots();
  }

  Future<void> saveNote(StudyNote note) {
    final data = note.toJson();
    if (note.id.isEmpty) {
      return _notesCollection.add(data);
    } else {
      return _notesCollection.doc(note.id).update(data);
    }
  }

  Future<void> deleteNote(String noteId) {
    return _notesCollection.doc(noteId).delete();
  }

  // --- UPLOAD DE IMAGEM (Inalterado) ---
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
}

// --- TELA PRINCIPAL (AGORA LISTA ASSUNTOS) ---
class StudyNotebookPage extends StatefulWidget {
  final String userId;
  const StudyNotebookPage({super.key, required this.userId});

  @override
  State<StudyNotebookPage> createState() => _StudyNotebookPageState();
}

class _StudyNotebookPageState extends State<StudyNotebookPage> {
  late final StudyNoteService _noteService;

  @override
  void initState() {
    super.initState();
    _noteService = StudyNoteService(userId: widget.userId);
  }

  void _showSubjectDialog({StudySubject? subject}) {
    final controller = TextEditingController(text: subject?.title ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(subject == null ? 'Novo Assunto' : 'Editar Assunto'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(labelText: 'Nome do Assunto/Curso'),
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
        title: const Text('Excluir Assunto?'),
        content: Text(
            'Isso excluirá "${subject.title}" e todos os seus volumes e anotações permanentemente. Deseja continuar?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: _noteService.getSubjectsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.folder_copy_outlined,
              title: 'Nenhum Assunto',
              message: 'Crie seu primeiro assunto de estudo no botão "+".',
            );
          }
          final subjects = snapshot.data!.docs
              .map((doc) => StudySubject.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.folder_outlined, color: primaryAccent),
                  title: Text(subject.title),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => StudyVolumesPage(
                                userId: widget.userId, subject: subject)));
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
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubjectDialog(),
        tooltip: 'Novo Assunto',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- NOVA TELA PARA LISTAR VOLUMES ---
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
          title: Text(volume == null ? 'Novo Volume' : 'Editar Volume'),
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
                  final newVolume = StudyVolume(
                    id: volume?.id ?? '',
                    title: controller.text.trim(),
                    subjectId: widget.subject.id,
                    createdAt: volume?.createdAt ?? DateTime.now(),
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
        title: const Text('Excluir Volume?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.subject.title)),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _noteService.getVolumesStream(widget.subject.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.create_new_folder_outlined,
                  title: 'Nenhum Volume',
                  message:
                      'Crie o primeiro volume para este assunto no botão "+".',
                );
              }
              // CORREÇÃO: Mapeia e ordena a lista de volumes aqui no widget.
              final volumes = snapshot.data!.docs
                  .map((doc) => StudyVolume.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: volumes.length,
                itemBuilder: (context, index) {
                  final volume = volumes[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.folder_open_outlined,
                          color: primaryAccent),
                      title: Text(volume.title),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => NoteListPage(
                                    userId: widget.userId, volume: volume)));
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
                            _showVolumeDialog(volume: volume);
                          } else if (value == 'delete') {
                            _confirmDeleteVolume(volume);
                          }
                        },
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
        onPressed: () => _showVolumeDialog(),
        tooltip: 'Novo Volume',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- TELA DE LISTA DE ANOTAÇÕES (ANTIGA StudyNotebookPage) ---
class NoteListPage extends StatefulWidget {
  final String userId;
  final StudyVolume volume;

  const NoteListPage({super.key, required this.userId, required this.volume});

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
      appBar: AppBar(title: Text(widget.volume.title)),
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
                  stream: _noteService.getNotesStream(widget.volume.id),
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
                            return note.title
                                    .toLowerCase()
                                    .contains(searchQuery) ||
                                note.content
                                    .toLowerCase()
                                    .contains(searchQuery) ||
                                note.tags.any((tag) =>
                                    tag.toLowerCase().contains(searchQuery));
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
                        return Card(
                          child: ListTile(
                            title: Text(note.title),
                            subtitle: Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => EditStudyNotePage(
                                              note: note,
                                              userId: widget.userId,
                                              volumeId: widget.volume.id)));
                                } else if (value == 'delete') {
                                  _confirmDelete(note.id);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Editar')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Excluir')),
                              ],
                            ),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        NoteDetailPage(note: note))),
                          ),
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
                    userId: widget.userId, volumeId: widget.volume.id))),
        tooltip: 'Nova Anotação',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- TELA DE DETALHES (Inalterada) ---
class NoteDetailPage extends StatelessWidget {
  final StudyNote note;
  const NoteDetailPage({super.key, required this.note});

  Future<void> _launchUrl(BuildContext context) async {
    if (note.videoUrl != null && note.videoUrl!.isNotEmpty) {
      final uri = Uri.parse(note.videoUrl!);
      if (!await launchUrl(uri)) {
        if (context.mounted) {
          showBjjSnackBar(
              context, 'Não foi possível abrir o link: ${note.videoUrl}',
              type: 'error');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(note.title)),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(note.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Atualizado em: ${DateFormat.yMd('pt_BR').add_Hm().format(note.updatedAt)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: textHint),
              ),
              const SizedBox(height: 16),
              if (note.tags.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children:
                      note.tags.map((tag) => Chip(label: Text(tag))).toList(),
                ),
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
              Text("Anotações", style: Theme.of(context).textTheme.titleLarge),
              const Divider(height: 20),
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

// --- TELA DE EDIÇÃO (MODIFICADA) ---
class EditStudyNotePage extends StatefulWidget {
  final StudyNote? note;
  final String userId;
  final String volumeId;

  const EditStudyNotePage(
      {super.key, this.note, required this.userId, required this.volumeId});

  @override
  State<EditStudyNotePage> createState() => _EditStudyNotePageState();
}

class _EditStudyNotePageState extends State<EditStudyNotePage> {
  final _formKey = GlobalKey<FormState>();
  late final StudyNoteService _noteService;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  final _urlController = TextEditingController();

  String? _imagePath;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _noteService = StudyNoteService(userId: widget.userId);
    if (_isEditing) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _tagsController.text = widget.note!.tags.join(', ');
      _urlController.text = widget.note!.videoUrl ?? '';
      _imagePath = widget.note!.imagePath;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (image != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Salvando imagem..."),
              ]),
            ),
          );
        },
      );

      final savedPath = await _noteService.saveImage(image);

      if (context.mounted) Navigator.of(context).pop();

      if (savedPath != null) {
        setState(() => _imagePath = savedPath);
      } else {
        if (context.mounted) {
          showBjjSnackBar(context, "Não foi possível salvar a imagem.",
              type: 'error');
        }
      }
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final noteToSave = StudyNote(
      id: _isEditing ? widget.note!.id : '',
      title: _titleController.text,
      content: _contentController.text,
      tags: tags,
      videoUrl: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      imagePath: _imagePath,
      updatedAt: DateTime.now(),
      createdAt: _isEditing ? widget.note!.createdAt : DateTime.now(),
      volumeId: widget.volumeId, // Associa a nota ao volume atual
    );

    try {
      await _noteService.saveNote(noteToSave);
      if (mounted) {
        showBjjSnackBar(context, "Anotação salva com sucesso!",
            type: 'success');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, "Erro ao salvar anotação.", type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Anotação' : 'Nova Anotação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveNote,
            tooltip: 'Salvar Anotação',
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isSaving
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Título'),
                        validator: (v) => v!.trim().isEmpty
                            ? 'O título é obrigatório.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Anotações',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 10,
                        validator: (v) => v!.trim().isEmpty
                            ? 'O conteúdo é obrigatório.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                            labelText: 'Tags (separadas por vírgula)'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                            labelText: 'Link do Vídeo (Opcional)'),
                      ),
                      const SizedBox(height: 24),
                      if (_imagePath != null && _imagePath!.isNotEmpty)
                        Column(
                          children: [
                            Text("Imagem Anexada:",
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _imagePath!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child,
                                            progress) =>
                                        progress == null
                                            ? child
                                            : const Center(
                                                child:
                                                    CircularProgressIndicator()),
                                    errorBuilder: (context, error, stack) =>
                                        const Icon(Icons.error,
                                            color: textHint),
                                  ),
                                ),
                                IconButton(
                                  icon: const CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: Icon(Icons.close,
                                          color: Colors.white)),
                                  onPressed: _removeImage,
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.attach_file),
                        label: Text(_imagePath == null
                            ? 'Anexar Imagem'
                            : 'Trocar Imagem'),
                        onPressed: _pickImage,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
