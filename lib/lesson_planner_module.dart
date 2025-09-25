// lib/lesson_planner_module.dart
// ignore_for_file: use_build_context_synchronously, unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'video_picker_dialog.dart';

class EditLessonPlanPage extends StatefulWidget {
  final UserModel currentUser;
  final TrainingClass trainingClass;
  final DateTime classDate;
  final LessonPlan? existingPlan;

  const EditLessonPlanPage({
    super.key,
    required this.currentUser,
    required this.trainingClass,
    required this.classDate,
    this.existingPlan,
  });

  @override
  State<EditLessonPlanPage> createState() => _EditLessonPlanPageState();
}

class _EditLessonPlanPageState extends State<EditLessonPlanPage> {
  final _formKey = GlobalKey<FormState>();
  final _warmupController = TextEditingController();
  final _observationsController = TextEditingController();

  List<TaughtTechnique> _techniques = [];
  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _descriptionControllers = [];

  bool _isLoading = false;
  bool _hasVideoAccess = false;

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    _checkVideoAccess();
    if (_isEditing) {
      final plan = widget.existingPlan!;
      _warmupController.text = plan.warmup;
      _observationsController.text = plan.observations;
      _techniques = List<TaughtTechnique>.from(
          plan.techniques.map((t) => TaughtTechnique.fromMap(t.toMap())));

      for (var tech in _techniques) {
        _nameControllers.add(TextEditingController(text: tech.name));
        _descriptionControllers
            .add(TextEditingController(text: tech.description));
      }
    } else {
      _warmupController.text = 'Padrão';
    }
  }

  @override
  void dispose() {
    _warmupController.dispose();
    _observationsController.dispose();
    for (var controller in _nameControllers) {
      controller.dispose();
    }
    for (var controller in _descriptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkVideoAccess() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.currentUser.academyId)
          .get();
      if (doc.exists && doc.data() != null) {
        if (mounted) {
          setState(() {
            _hasVideoAccess = doc.data()!['hasVideoLibraryAccess'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao verificar acesso à videoteca: $e");
    }
  }

  void _addTechnique() {
    setState(() {
      _techniques.add(TaughtTechnique(name: '', description: ''));
      _nameControllers.add(TextEditingController());
      _descriptionControllers.add(TextEditingController());
    });
  }

  void _removeTechnique(int index) {
    setState(() {
      _nameControllers[index].dispose();
      _descriptionControllers[index].dispose();
      _nameControllers.removeAt(index);
      _descriptionControllers.removeAt(index);
      _techniques.removeAt(index);
    });
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    for (int i = 0; i < _techniques.length; i++) {
      _techniques[i].name = _nameControllers[i].text.trim();
      _techniques[i].description = _descriptionControllers[i].text.trim();
    }

    final now = Timestamp.now();

    // --- INÍCIO DA CORREÇÃO ---
    // Garante que o curriculumId seja salvo, usando o campo 'audience' como fallback
    // para aulas antigas que talvez não tenham o campo 'curriculumId'.
    final planData = {
      'academyId': widget.currentUser.academyId,
      'classId': widget.trainingClass.id,
      'classDate': Timestamp.fromDate(widget.classDate),
      'curriculumId': widget.trainingClass.curriculumId ??
          widget.trainingClass.audience, // <-- CORREÇÃO APLICADA AQUI
      'warmup': _warmupController.text.trim(),
      'observations': _observationsController.text.trim(),
      'techniques': _techniques.map((t) => t.toMap()).toList(),
      'lastUpdatedByUid': widget.currentUser.uid,
      'lastUpdatedByName': widget.currentUser.name,
      'lastUpdatedAt': now,
    };
    // --- FIM DA CORREÇÃO ---

    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.currentUser.academyId)
          .collection('lesson_plans');

      if (_isEditing) {
        await collectionRef.doc(widget.existingPlan!.id).update(planData);
      } else {
        await collectionRef.add({
          ...planData,
          'createdByUid': widget.currentUser.uid,
          'createdByName': widget.currentUser.name,
          'createdAt': now,
        });
      }

      Navigator.of(context).pop();
      showBjjSnackBar(context, 'Plano de aula salvo com sucesso!',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar o plano: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title:
            Text(_isEditing ? 'Editar Diário de Aula' : 'Novo Diário de Aula'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isLoading ? null : _savePlan,
            tooltip: 'Salvar',
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Aquecimento Específico',
                        child: TextFormField(
                          controller: _warmupController,
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            hintText: 'Descreva o aquecimento realizado...',
                          ),
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTechniquesSection(context),
                      const SizedBox(height: 16),
                      _buildSectionCard(
                        title: 'Observações do Professor',
                        child: TextFormField(
                          controller: _observationsController,
                          decoration: const InputDecoration(
                            alignLabelWithHint: true,
                            hintText:
                                'Anotações sobre a turma, dificuldades, etc.',
                          ),
                          keyboardType: TextInputType.multiline,
                          minLines: 1,
                          maxLines: null,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      Text(
                        widget.trainingClass.level,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: primaryAccent),
                      ),
                      Text(
                        '(${widget.trainingClass.startTime} - ${widget.trainingClass.endTime})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Professor: ${widget.trainingClass.teacherName}',
                    style: const TextStyle(color: textHint, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(widget.classDate),
              style: const TextStyle(
                color: textHint,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechniquesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text('Técnicas da Aula',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              icon:
                  const Icon(Icons.add_circle, color: primaryAccent, size: 30),
              onPressed: _addTechnique,
              tooltip: 'Adicionar Técnica',
            )
          ],
        ),
        const SizedBox(height: 8),
        if (_techniques.isEmpty)
          const EmptyStateWidget(
            icon: Icons.list_alt_rounded,
            title: 'Nenhuma Técnica',
            message: 'Adicione as técnicas ensinadas na aula.',
          )
        else
          ..._techniques.asMap().entries.map((entry) {
            int index = entry.key;
            TaughtTechnique technique = entry.value;
            return _TechniqueEditCard(
                key: ObjectKey(technique),
                technique: technique,
                nameController: _nameControllers[index],
                descriptionController: _descriptionControllers[index],
                onRemove: () => _removeTechnique(index),
                hasVideoAccess: _hasVideoAccess,
                academyId: widget.currentUser.academyId,
                onVideoChanged: (video) {
                  setState(() {
                    _techniques[index].videoId = video.id;
                    _techniques[index].videoTitle = video.title;
                    _techniques[index].videoThumbnailUrl = video.thumbnailUrl;
                  });
                },
                onVideoRemoved: () {
                  setState(() {
                    _techniques[index].videoId = null;
                    _techniques[index].videoTitle = null;
                    _techniques[index].videoThumbnailUrl = null;
                  });
                });
          }),
      ],
    );
  }
}

class _TechniqueEditCard extends StatelessWidget {
  final TaughtTechnique technique;
  final VoidCallback onRemove;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool hasVideoAccess;
  final String academyId;
  final ValueSetter<VideoItem> onVideoChanged;
  final VoidCallback onVideoRemoved;

  const _TechniqueEditCard({
    super.key,
    required this.technique,
    required this.onRemove,
    required this.nameController,
    required this.descriptionController,
    required this.hasVideoAccess,
    required this.academyId,
    required this.onVideoChanged,
    required this.onVideoRemoved,
  });

  Future<void> _selectVideo(BuildContext context) async {
    final VideoItem? selectedVideo = await showDialog<VideoItem>(
      context: context,
      builder: (_) => VideoPickerDialog(academyId: academyId),
    );

    if (selectedVideo != null) {
      onVideoChanged(selectedVideo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Técnica', style: Theme.of(context).textTheme.titleSmall),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: errorColor),
                  onPressed: onRemove,
                )
              ],
            ),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome da Técnica'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'O nome é obrigatório'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descriptionController,
              decoration:
                  const InputDecoration(labelText: 'Descrição (opcional)'),
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: null,
            ),
            if (hasVideoAccess) ...[
              const SizedBox(height: 12),
              if (technique.videoId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Image.network(technique.videoThumbnailUrl!,
                      width: 56, fit: BoxFit.cover),
                  title: const Text("Vídeo Anexado"),
                  subtitle: Text(technique.videoTitle ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: errorColor),
                    onPressed: onVideoRemoved,
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _selectVideo(context),
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('Anexar Vídeo'),
                ),
            ]
          ],
        ),
      ),
    );
  }
}
