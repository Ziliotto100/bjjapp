// lib/lesson_planner_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
// --- INÍCIO DA ALTERAÇÃO ---
import 'video_picker_dialog.dart';
// --- FIM DA ALTERAÇÃO ---

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
  bool _isLoading = false;
  // --- INÍCIO DA ALTERAÇÃO ---
  bool _hasVideoAccess = false;
  // --- FIM DA ALTERAÇÃO ---

  bool get _isEditing => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    // --- INÍCIO DA ALTERAÇÃO ---
    _checkVideoAccess();
    // --- FIM DA ALTERAÇÃO ---
    if (_isEditing) {
      final plan = widget.existingPlan!;
      _warmupController.text = plan.warmup;
      _observationsController.text = plan.observations;
      _techniques =
          List<TaughtTechnique>.from(plan.techniques.map((t) => TaughtTechnique(
                name: t.name,
                description: t.description,
                videoId: t.videoId,
                videoTitle: t.videoTitle,
                videoThumbnailUrl: t.videoThumbnailUrl,
              )));
    } else {
      _warmupController.text = 'Padrão';
    }
  }

  // --- INÍCIO DA ALTERAÇÃO ---
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
  // --- FIM DA ALTERAÇÃO ---

  void _addTechnique() {
    setState(() {
      _techniques.add(TaughtTechnique(name: '', description: ''));
    });
  }

  void _removeTechnique(int index) {
    setState(() {
      _techniques.removeAt(index);
    });
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    final now = Timestamp.now();
    final planData = {
      'academyId': widget.currentUser.academyId,
      'classId': widget.trainingClass.id,
      'classDate': Timestamp.fromDate(widget.classDate),
      'warmup': _warmupController.text.trim(),
      'observations': _observationsController.text.trim(),
      'techniques': _techniques.map((t) => t.toMap()).toList(),
      'lastUpdatedByUid': widget.currentUser.uid,
      'lastUpdatedByName': widget.currentUser.name,
      'lastUpdatedAt': now,
    };

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
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _warmupController,
                        decoration: const InputDecoration(
                          labelText: 'Aquecimento Específico',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      _buildTechniquesSection(context),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _observationsController,
                        decoration: const InputDecoration(
                          labelText: 'Observações do Professor',
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMEEEEd('pt_BR').format(widget.classDate),
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: primaryAccent),
            ),
            const Divider(height: 16),
            Text(
              '${widget.trainingClass.level} (${widget.trainingClass.startTime} - ${widget.trainingClass.endTime})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Professor: ${widget.trainingClass.teacherName}',
              style: const TextStyle(color: textHint),
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
            Text('Técnicas da Aula',
                style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: primaryAccent),
              onPressed: _addTechnique,
              tooltip: 'Adicionar Técnica',
            )
          ],
        ),
        const Divider(height: 8),
        if (_techniques.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text('Nenhuma técnica adicionada.',
                  style: TextStyle(color: textHint)),
            ),
          ),
        ..._techniques.asMap().entries.map((entry) {
          int index = entry.key;
          TaughtTechnique technique = entry.value;
          return _TechniqueEditCard(
              key: ValueKey('${technique.name}-${index}'),
              technique: technique,
              onRemove: () => _removeTechnique(index),
              onSaved: (updatedTechnique) {
                _techniques[index] = updatedTechnique;
              },
              // --- INÍCIO DA ALTERAÇÃO ---
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
              }
              // --- FIM DA ALTERAÇÃO ---
              );
        }),
      ],
    );
  }
}

class _TechniqueEditCard extends StatelessWidget {
  final TaughtTechnique technique;
  final VoidCallback onRemove;
  final ValueSetter<TaughtTechnique> onSaved;
  // --- INÍCIO DA ALTERAÇÃO ---
  final bool hasVideoAccess;
  final String academyId;
  final ValueSetter<VideoItem> onVideoChanged;
  final VoidCallback onVideoRemoved;
  // --- FIM DA ALTERAÇÃO ---

  const _TechniqueEditCard({
    super.key,
    required this.technique,
    required this.onRemove,
    required this.onSaved,
    required this.hasVideoAccess,
    required this.academyId,
    required this.onVideoChanged,
    required this.onVideoRemoved,
  });

  // --- INÍCIO DA ALTERAÇÃO ---
  Future<void> _selectVideo(BuildContext context) async {
    final VideoItem? selectedVideo = await showDialog<VideoItem>(
      context: context,
      builder: (_) => VideoPickerDialog(academyId: academyId),
    );

    if (selectedVideo != null) {
      onVideoChanged(selectedVideo);
    }
  }
  // --- FIM DA ALTERAÇÃO ---

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
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
              initialValue: technique.name,
              decoration: const InputDecoration(labelText: 'Nome da Técnica'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'O nome é obrigatório'
                  : null,
              onSaved: (value) => technique.name = value ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: technique.description,
              decoration:
                  const InputDecoration(labelText: 'Descrição (opcional)'),
              maxLines: 2,
              onSaved: (value) => technique.description = value ?? '',
            ),
            // --- INÍCIO DA ALTERAÇÃO ---
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
            // --- FIM DA ALTERAÇÃO ---
          ],
        ),
      ),
    );
  }
}
