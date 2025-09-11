// lib/manager_units_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'user_card_widget.dart';

class ManageUnitsPage extends StatelessWidget {
  final String academyId;
  final UserModel manager;
  const ManageUnitsPage(
      {super.key, required this.academyId, required this.manager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // REMOVIDO: AppBar foi removido daqui para evitar duplicidade de título.
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('academies')
                .doc(academyId)
                .collection('units')
                .orderBy('name')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const EmptyStateWidget(
                    icon: Icons.error, title: 'Erro ao carregar');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Nenhuma Unidade Cadastrada',
                  message:
                      'Clique no botão "+" para adicionar sua primeira unidade (ex: Matriz).',
                );
              }

              final units = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                itemCount: units.length,
                itemBuilder: (context, index) {
                  final unit = units[index];
                  final unitName = unit['name'] ?? 'Sem nome';

                  return Card(
                    child: ListTile(
                      title: Text(unitName),
                      trailing:
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => UnitDetailPage(
                            academyId: academyId,
                            unitDoc: unit,
                            manager: manager,
                          ),
                        ));
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => _AddEditUnitDialog(academyId: academyId),
          );
        },
        tooltip: 'Adicionar Unidade',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class UnitDetailPage extends StatefulWidget {
  final String academyId;
  final DocumentSnapshot unitDoc;
  final UserModel manager;

  const UnitDetailPage(
      {super.key,
      required this.academyId,
      required this.unitDoc,
      required this.manager});

  @override
  State<UnitDetailPage> createState() => _UnitDetailPageState();
}

class _UnitDetailPageState extends State<UnitDetailPage> {
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchUnitDetails();
  }

  Future<Map<String, dynamic>> _fetchUnitDetails() async {
    final unitId = widget.unitDoc.id;
    final firestore = FirebaseFirestore.instance;

    final studentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.academyId)
        .collection('students')
        .where('unitId', isEqualTo: unitId)
        .get();
    final students = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();

    final teachersSnapshot = await firestore
        .collection('users')
        .where('academyId', isEqualTo: widget.academyId)
        .where('role', isEqualTo: 'teacher')
        .where('unitId', isEqualTo: unitId)
        .get();
    final teachers = teachersSnapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();

    int paidCount = 0;
    int pendingCount = 0;
    int overdueCount = 0;
    final now = DateTime.now();
    final studentIdsInUnit = students.map((s) => s.id).toList();

    if (studentIdsInUnit.isNotEmpty) {
      final paymentsSnapshot = await firestore
          .collection('academies')
          .doc(widget.academyId)
          .collection('payment_history')
          .where('paymentDate',
              isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1))
          .get();

      final paidStudentNames = <String>{};
      for (var doc in paymentsSnapshot.docs) {
        final note = doc.data()['notes'] as String?;
        if (note != null) {
          paidStudentNames.add(note.replaceAll('Mensalidade de ', ''));
        }
      }

      for (final student in students) {
        if (paidStudentNames.contains(student.nome)) {
          paidCount++;
        } else {
          if (now.day > 10) {
            overdueCount++;
          } else {
            pendingCount++;
          }
        }
      }
    }

    return {
      'students': students,
      'teachers': teachers,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
      'overdueCount': overdueCount,
    };
  }

  void _showUnitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddEditUnitDialog(
          academyId: widget.academyId, unitDoc: widget.unitDoc),
    ).then((_) {
      if (mounted) {
        setState(() {
          _detailsFuture = _fetchUnitDetails();
        });
      }
    });
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja excluir a unidade "${widget.unitDoc['name']}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await widget.unitDoc.reference.delete();
                if (context.mounted) {
                  Navigator.of(context).pop();
                  showBjjSnackBar(context, 'Unidade excluída!',
                      type: 'success');
                }
              } catch (e) {
                if (context.mounted) {
                  showBjjSnackBar(context,
                      'Erro ao excluir unidade. Verifique se ela não está em uso.',
                      type: 'error');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: textHint)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitName =
        (widget.unitDoc.data() as Map<String, dynamic>?)?['name'] ??
            'Detalhes da Unidade';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(unitName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Renomear',
            onPressed: () => _showUnitDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: errorColor),
            tooltip: 'Excluir',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _detailsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyStateWidget(
                    icon: Icons.error,
                    title: 'Erro',
                    message: snapshot.error.toString());
              }
              if (!snapshot.hasData) {
                return const EmptyStateWidget(
                    icon: Icons.search_off, title: 'Sem Dados');
              }

              final data = snapshot.data!;
              final students = data['students'] as List<Aluno>;
              final teachers = data['teachers'] as List<UserModel>;

              return ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  Row(
                    children: [
                      _buildMetricCard("Alunos", students.length.toString(),
                          Icons.people_alt_rounded, primaryAccent),
                      const SizedBox(width: 12),
                      _buildMetricCard(
                          "Professores",
                          teachers.length.toString(),
                          Icons.school_rounded,
                          infoColor),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Financeiro (Mês Atual)",
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _FinancialStatusChip(
                                  label: 'Pagas',
                                  count: data['paidCount'],
                                  color: successColor),
                              _FinancialStatusChip(
                                  label: 'Pendentes',
                                  count: data['pendingCount'],
                                  color: warningColor),
                              _FinancialStatusChip(
                                  label: 'Atrasadas',
                                  count: data['overdueCount'],
                                  color: errorColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (teachers.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 24.0, left: 4, bottom: 8),
                      child: Text("Professores da Unidade",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...teachers.map((teacher) => UserCard(
                        user: teacher,
                        academyId: widget.academyId,
                        currentUser: widget.manager))
                  ],
                  if (students.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 24.0, left: 4, bottom: 8),
                      child: Text("Alunos da Unidade",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ...students.map((student) => UserCard(
                        user: student,
                        academyId: widget.academyId,
                        currentUser: widget.manager))
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FinancialStatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _FinancialStatusChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(count.toString(),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _AddEditUnitDialog extends StatefulWidget {
  final String academyId;
  final DocumentSnapshot? unitDoc;

  const _AddEditUnitDialog({required this.academyId, this.unitDoc});

  @override
  State<_AddEditUnitDialog> createState() => _AddEditUnitDialogState();
}

class _AddEditUnitDialogState extends State<_AddEditUnitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.unitDoc != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.unitDoc!['name'];
    }
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final collectionRef = FirebaseFirestore.instance
        .collection('academies')
        .doc(widget.academyId)
        .collection('units');

    final unitName = _nameController.text.trim().capitalizeWords();

    try {
      if (_isEditing) {
        await collectionRef.doc(widget.unitDoc!.id).update({'name': unitName});
      } else {
        await collectionRef.add({'name': unitName});
      }
      Navigator.of(context).pop();
      showBjjSnackBar(context, 'Unidade salva com sucesso!', type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar unidade.', type: 'error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Renomear Unidade' : 'Adicionar Unidade'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da Unidade'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'O nome é obrigatório'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUnit,
          child: _isLoading
              ? const SizedBox(
                  height: 20, width: 20, child: CircularProgressIndicator())
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
