// lib/curriculum_manager_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

// --- TELA PARA GERENCIAR OS CURRÍCULOS DA ACADEMIA ---
class CurriculumManagerPage extends StatefulWidget {
  final UserModel user;
  const CurriculumManagerPage({super.key, required this.user});

  @override
  State<CurriculumManagerPage> createState() => _CurriculumManagerPageState();
}

class _CurriculumManagerPageState extends State<CurriculumManagerPage> {
  late final CollectionReference _curriculumsCollection;

  @override
  void initState() {
    super.initState();
    _curriculumsCollection = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('curriculums');
  }

  void _showCurriculumDialog({Curriculum? curriculum}) {
    showDialog(
      context: context,
      builder: (_) => _AddEditCurriculumDialog(
        curriculumsCollection: _curriculumsCollection,
        curriculum: curriculum,
      ),
    );
  }

  Future<void> _deleteCurriculum(Curriculum curriculum) async {
    // Adicionar verificação se o currículo está em uso
    final inUseCheck = await FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('schedule')
        .where('curriculumId', isEqualTo: curriculum.id)
        .limit(1)
        .get();

    if (inUseCheck.docs.isNotEmpty) {
      showBjjSnackBar(context,
          'Este currículo está em uso por uma ou mais aulas e não pode ser excluído.',
          type: 'error');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Currículo?'),
        content: Text(
            'Tem certeza que deseja excluir o currículo "${curriculum.name}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _curriculumsCollection.doc(curriculum.id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Gerenciar Currículos'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _curriculumsCollection.orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const EmptyStateWidget(
                    icon: Icons.error, title: 'Erro ao Carregar');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.school_outlined,
                  title: 'Nenhum Currículo Criado',
                  message:
                      'Clique no botão "+" para adicionar o primeiro currículo (ex: Iniciantes, Kids).',
                );
              }

              final curriculums = snapshot.data!.docs
                  .map((doc) => Curriculum.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: curriculums.length,
                itemBuilder: (context, index) {
                  final curriculum = curriculums[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_rounded,
                          color: primaryAccent),
                      title: Text(curriculum.name),
                      subtitle: curriculum.description.isNotEmpty
                          ? Text(curriculum.description)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: textHint),
                            onPressed: () =>
                                _showCurriculumDialog(curriculum: curriculum),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: errorColor),
                            onPressed: () => _deleteCurriculum(curriculum),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCurriculumDialog(),
        tooltip: 'Novo Currículo',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- DIÁLOGO PARA ADICIONAR/EDITAR UM CURRÍCULO ---
class _AddEditCurriculumDialog extends StatefulWidget {
  final CollectionReference curriculumsCollection;
  final Curriculum? curriculum;

  const _AddEditCurriculumDialog(
      {required this.curriculumsCollection, this.curriculum});

  @override
  State<_AddEditCurriculumDialog> createState() =>
      _AddEditCurriculumDialogState();
}

class _AddEditCurriculumDialogState extends State<_AddEditCurriculumDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.curriculum != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.curriculum!.name;
      _descriptionController.text = widget.curriculum!.description;
    }
  }

  Future<void> _saveCurriculum() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      if (_isEditing) {
        await widget.curriculumsCollection
            .doc(widget.curriculum!.id)
            .update(data);
      } else {
        await widget.curriculumsCollection.add(data);
      }
      Navigator.of(context).pop();
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar currículo.', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Currículo' : 'Novo Currículo'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Nome do Currículo'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'O nome é obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Descrição (Opcional)'),
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
          onPressed: _isLoading ? null : _saveCurriculum,
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
