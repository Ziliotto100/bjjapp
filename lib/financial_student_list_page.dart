// lib/financial_student_list_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
// INÍCIO DA ALTERAÇÃO: Importa o diálogo de pagamento do módulo do gerente
import 'manager_module.dart' show AddPaymentDialog;
// FIM DA ALTERAÇÃO

// --- INÍCIO DA ALTERAÇÃO: A classe agora é um StatefulWidget ---
class FinancialStudentListPage extends StatefulWidget {
  final String title;
  final List<Aluno> students;
  final UserModel currentUser;
  final String academyId;

  const FinancialStudentListPage({
    super.key,
    required this.title,
    required this.students,
    required this.currentUser,
    required this.academyId,
  });

  @override
  State<FinancialStudentListPage> createState() =>
      _FinancialStudentListPageState();
}

class _FinancialStudentListPageState extends State<FinancialStudentListPage> {
  late List<Aluno> _studentsList;

  @override
  void initState() {
    super.initState();
    // Cria uma cópia mutável da lista de alunos
    _studentsList = List.from(widget.students);
  }

  // Nova função para exibir o diálogo e registrar o pagamento
  Future<void> _registerPayment(Aluno student) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (_) => AddPaymentDialog(
        academyId: widget.academyId,
        student: student,
      ),
    );

    // Se o pagamento foi registrado com sucesso, remove o aluno da lista
    if (success == true) {
      showBjjSnackBar(context, "Pagamento registrado com sucesso!",
          type: 'success');
      setState(() {
        _studentsList.removeWhere((s) => s.id == student.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: AppBackground(
        child: SafeArea(
          child: _studentsList.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum Aluno',
                  message: 'Não há mais alunos nesta categoria.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: _studentsList.length,
                  itemBuilder: (context, index) {
                    final student = _studentsList[index];
                    // Card customizado com o novo botão
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.nome,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(student.faixa,
                                style: const TextStyle(color: textHint)),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.payment_rounded,
                                      size: 18),
                                  label: const Text('Registrar Pagamento'),
                                  onPressed: () => _registerPayment(student),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: successColor,
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
