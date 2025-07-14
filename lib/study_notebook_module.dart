// lib/study_notebook_module.dart

// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';

// --- SERVICE ---
// Colocando o serviço no mesmo arquivo para simplificar.
class StudyNoteService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> _localFile(String userId) async {
    final path = await _localPath;
    return File('$path/studynotes_$userId.json');
  }

  Future<List<StudyNote>> loadNotes(String userId) async {
    try {
      final file = await _localFile(userId);
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => StudyNote.fromJson(json)).toList();
    } catch (e) {
      // Em caso de erro, retorna uma lista vazia
      return [];
    }
  }

  Future<File> saveNotes(String userId, List<StudyNote> notes) async {
    final file = await _localFile(userId);
    final jsonList = notes.map((note) => note.toJson()).toList();
    return file.writeAsString(json.encode(jsonList));
  }

  Future<String?> saveImage(String userId, XFile image) async {
    try {
      final path = await _localPath;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newImagePath = '$path/$fileName';
      final newImageFile = File(newImagePath);
      await newImageFile.writeAsBytes(await image.readAsBytes());
      return newImagePath;
    } catch (e) {
      return null;
    }
  }
}

// --- TELA PRINCIPAL DO CADERNO ---
class StudyNotebookPage extends StatefulWidget {
  final String userId;
  const StudyNotebookPage({super.key, required this.userId});

  @override
  State<StudyNotebookPage> createState() => _StudyNotebookPageState();
}

class _StudyNotebookPageState extends State<StudyNotebookPage> {
  final StudyNoteService _noteService = StudyNoteService();
  List<StudyNote> _notes = [];
  List<StudyNote> _filteredNotes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        _filterNotes();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _noteService.loadNotes(widget.userId);
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      setState(() {
        _notes = notes;
        _filterNotes();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Erro ao carregar anotações.', type: 'error');
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterNotes() {
    if (_searchQuery.isEmpty) {
      _filteredNotes = _notes;
    } else {
      _filteredNotes = _notes.where((note) {
        final query = _searchQuery.toLowerCase();
        return note.title.toLowerCase().contains(query) ||
            note.content.toLowerCase().contains(query) ||
            note.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }
  }

  Future<void> _deleteNote(String id) async {
    final updatedNotes = _notes.where((note) => note.id != id).toList();
    await _noteService.saveNotes(widget.userId, updatedNotes);
    _loadNotes();
    if (mounted) {
      showBjjSnackBar(context, 'Anotação excluída!', type: 'success');
    }
  }

  void _confirmDelete(String id) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Excluir Anotação?'),
              content: const Text(
                  'Esta ação não pode ser desfeita. Deseja continuar?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteNote(id);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: errorColor),
                  child: const Text('Excluir'),
                )
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    // AJUSTE EDGE-TO-EDGE: A página agora não tem Scaffold próprio,
    // pois é exibida dentro do IndexedStack que já tem um SafeArea.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar por título, conteúdo ou tag...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.note_add_rounded,
                      title: 'Nenhuma Anotação',
                      message:
                          'Clique no botão "${_isEditing ? 'Salvar' : 'Nova Anotação'}" para criar sua primeira anotação de estudo.',
                    )
                  : _filteredNotes.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.search_off_rounded,
                          title: 'Nenhum resultado',
                          message:
                              "Sua busca por '$_searchQuery' não retornou resultados.")
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                          itemCount: _filteredNotes.length,
                          itemBuilder: (context, index) {
                            final note = _filteredNotes[index];
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
                                      Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (_) => EditStudyNotePage(
                                                  note: note,
                                                  userId: widget.userId)))
                                          .then((_) => _loadNotes());
                                    } else if (value == 'delete') {
                                      _confirmDelete(note.id);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'edit', child: Text('Editar')),
                                    const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Excluir')),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            NoteDetailPage(note: note))),
                              ),
                            );
                          }),
        )
      ],
    );
  }

  bool get _isEditing => false;
}

// --- TELA DE DETALHES ---
class NoteDetailPage extends StatelessWidget {
  final StudyNote note;

  const NoteDetailPage({super.key, required this.note});

  Future<void> _launchUrl(BuildContext context) async {
    if (note.videoUrl != null && note.videoUrl!.isNotEmpty) {
      final uri = Uri.parse(note.videoUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
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
      appBar: AppBar(
        title: Text(note.title),
      ),
      body: AppBackground(
        // AJUSTE EDGE-TO-EDGE: SafeArea envolvendo o ListView
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                note.title,
                style: Theme.of(context).textTheme.headlineSmall,
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
              if (note.imagePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0),
                    child: Image.file(File(note.imagePath!)),
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
              Text(
                "Anotações",
                style: Theme.of(context).textTheme.titleLarge,
              ),
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

// --- TELA DE EDIÇÃO ---
class EditStudyNotePage extends StatefulWidget {
  final StudyNote? note;
  final String userId;

  const EditStudyNotePage({super.key, this.note, required this.userId});

  @override
  State<EditStudyNotePage> createState() => _EditStudyNotePageState();
}

class _EditStudyNotePageState extends State<EditStudyNotePage> {
  final _formKey = GlobalKey<FormState>();
  final _noteService = StudyNoteService();
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

      final savedPath = await _noteService.saveImage(widget.userId, image);

      if (context.mounted) Navigator.of(context).pop();

      if (savedPath != null) {
        setState(() {
          _imagePath = savedPath;
        });
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

    final allNotes = await _noteService.loadNotes(widget.userId);
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (_isEditing) {
      final index = allNotes.indexWhere((n) => n.id == widget.note!.id);
      if (index != -1) {
        allNotes[index].title = _titleController.text;
        allNotes[index].content = _contentController.text;
        allNotes[index].tags = tags;
        allNotes[index].videoUrl = _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim();
        allNotes[index].imagePath = _imagePath;
        allNotes[index].updatedAt = DateTime.now();
      }
    } else {
      final newNote = StudyNote.create(
        title: _titleController.text,
        content: _contentController.text,
        tags: tags,
        videoUrl: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        imagePath: _imagePath,
      );
      allNotes.add(newNote);
    }

    await _noteService.saveNotes(widget.userId, allNotes);

    if (mounted) {
      showBjjSnackBar(context, "Anotação salva com sucesso!", type: 'success');
      Navigator.of(context).pop();
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
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
        // AJUSTE EDGE-TO-EDGE: SafeArea envolvendo o conteúdo do body
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
                      if (_imagePath != null)
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
                                  child: Image.file(File(_imagePath!)),
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
