import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'study_note_service.dart';
import 'main.dart'; // Para acessar widgets como EmptyStateWidget, showBjjSnackBar, e as páginas de edição/detalhe

class StudyNotebookPage extends StatefulWidget {
  final String userId; // Adicionado para identificar o usuário

  const StudyNotebookPage({Key? key, required this.userId}) : super(key: key);

  @override
  _StudyNotebookPageState createState() => _StudyNotebookPageState();
}

class _StudyNotebookPageState extends State<StudyNotebookPage> {
  final _noteService = StudyNoteService();
  late Future<List<StudyNote>> _notesFuture;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadNotes() {
    setState(() {
      // Agora passamos o ID do usuário para o serviço
      _notesFuture = _noteService.loadNotes(widget.userId);
    });
  }

  Future<void> _deleteNote(StudyNote note) async {
    final allNotes = await _noteService.loadNotes(widget.userId);
    allNotes.removeWhere((n) => n.id == note.id);
    await _noteService.saveNotes(widget.userId, allNotes);
    if (note.imagePath != null) {
      await _noteService.deleteImage(note.imagePath);
    }
    if (mounted) {
      showBjjSnackBar(context, "Anotação '${note.title}' excluída.",
          type: 'success');
    }
    _loadNotes();
  }

  void _confirmDelete(StudyNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirmar Exclusão"),
        content: Text(
            "Tem certeza que deseja excluir permanentemente a anotação '${note.title}'?"),
        actions: [
          TextButton(
            child: Text("Cancelar"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: BjjApp.errorColor,
                foregroundColor: Colors.white),
            child: Text("Excluir"),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteNote(note);
            },
          ),
        ],
      ),
    );
  }

  void _shareNote(StudyNote note) {
    final shareText = """
*${note.title}*

*Tags:* ${note.tags.join(', ')}

${note.content}

_Anotação do Match BJJ App_
""";
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar por título ou tag...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<StudyNote>>(
                future: _notesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return EmptyStateWidget(
                      icon: Icons.error_outline,
                      title: 'Erro ao carregar anotações',
                      message: snapshot.error.toString(),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.note_add_outlined,
                      title: 'Nenhuma anotação encontrada',
                      message:
                          'Clique no botão "+" para criar sua primeira anotação de estudo.',
                    );
                  }

                  final allNotes = snapshot.data!;
                  final filteredNotes = allNotes.where((note) {
                    final titleMatch =
                        note.title.toLowerCase().contains(_searchQuery);
                    final tagMatch = note.tags
                        .any((tag) => tag.toLowerCase().contains(_searchQuery));
                    return titleMatch || tagMatch;
                  }).toList();

                  if (filteredNotes.isEmpty && _searchQuery.isNotEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.search_off_rounded,
                      title: 'Nenhum resultado',
                      message:
                          'Não foram encontradas anotações para a busca "$_searchQuery".',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
                    itemCount: filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = filteredNotes[index];
                      return Card(
                        child: ListTile(
                          leading: note.imagePath != null
                              ? CircleAvatar(
                                  backgroundImage:
                                      FileImage(File(note.imagePath!)),
                                )
                              : CircleAvatar(
                                  child: Icon(Icons.notes_rounded),
                                ),
                          title: Text(note.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text(
                            'Atualizado em: ${DateFormat.yMd('pt_BR').add_Hm().format(note.updatedAt)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: BjjApp.textHint),
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => NoteDetailPage(note: note)),
                            );
                            _loadNotes();
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => EditStudyNotePage(
                                            note: note, userId: widget.userId)))
                                    .then((_) => _loadNotes());
                              } else if (value == 'delete') {
                                _confirmDelete(note);
                              } else if (value == 'share') {
                                _shareNote(note);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: 'edit',
                                child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar')),
                              ),
                              const PopupMenuItem<String>(
                                value: 'share',
                                child: ListTile(
                                    leading: Icon(Icons.share_outlined),
                                    title: Text('Compartilhar')),
                              ),
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: ListTile(
                                    leading: Icon(Icons.delete_outline,
                                        color: BjjApp.errorColor),
                                    title: Text('Excluir')),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        tooltip: 'Nova Anotação',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => EditStudyNotePage(userId: widget.userId)),
          );
          _loadNotes();
        },
      ),
    );
  }
}
