// lib/financial_student_list_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'manager_module.dart' show AddPaymentDialog;
// --- INÍCIO DA CORREÇÃO ---
// Corrigido o caminho do import para o pacote url_launcher
import 'package:url_launcher/url_launcher.dart';
// --- FIM DA CORREÇÃO ---

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
    _studentsList = List.from(widget.students);
  }

  Future<void> _registerPayment(Aluno student) async {
    final bool? success = await showDialog<bool>(
      context: context,
      builder: (_) => AddPaymentDialog(
        academyId: widget.academyId,
        student: student,
      ),
    );

    if (success == true) {
      showBjjSnackBar(context, "Pagamento registrado com sucesso!",
          type: 'success');
      setState(() {
        _studentsList.removeWhere((s) => s.id == student.id);
      });
    }
  }

  Future<void> _sendWhatsAppReminder(Aluno student) async {
    final phoneNumber = student.phoneNumber;
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      showBjjSnackBar(context, 'Este aluno não possui telefone cadastrado.',
          type: 'error');
      return;
    }

    String formattedPhoneNumber =
        phoneNumber.trim().replaceAll(RegExp(r'\D'), '');
    if (!formattedPhoneNumber.startsWith('55')) {
      formattedPhoneNumber = '55$formattedPhoneNumber';
    }

    final message = Uri.encodeComponent(
        'Olá, ${student.nome}! Tudo bem? Passando para lembrar sobre a mensalidade deste mês. Se já efetuou o pagamento, por favor, desconsidere esta mensagem. Oss!');
    final whatsappUrl =
        Uri.parse("https://wa.me/$formattedPhoneNumber?text=$message");

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        showBjjSnackBar(context, 'Não foi possível abrir o WhatsApp.',
            type: 'error');
      }
    } catch (e) {
      showBjjSnackBar(context, 'Ocorreu um erro ao tentar abrir o WhatsApp.',
          type: 'error');
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
              ? const EmptyStateWidget(
                  // Conteúdo inalterado
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum Aluno',
                  message: 'Não há mais alunos nesta categoria.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: _studentsList.length,
                  itemBuilder: (context, index) {
                    final student = _studentsList[index];
                    final bool hasPhone = student.phoneNumber != null &&
                        student.phoneNumber!.trim().isNotEmpty;

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              // Conteúdo inalterado
                              children: [
                                Expanded(
                                  child: Text(student.nome,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ),
                                if (!hasPhone)
                                  const Tooltip(
                                    // Conteúdo inalterado
                                    message: 'Telefone não cadastrado',
                                    child: Icon(Icons.warning_amber_rounded,
                                        color: warningColor, size: 20),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4), // Conteúdo inalterado
                            Text(student.faixa, // Conteúdo inalterado
                                style: const TextStyle(color: textHint)),
                            const Divider(height: 16),
                            // --- INÍCIO DA CORREÇÃO ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Botão Lembrar dentro de Expanded
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.message_outlined,
                                        size: 18),
                                    label: const Text('Lembrar'),
                                    onPressed: hasPhone
                                        ? () => _sendWhatsAppReminder(student)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: textHint,
                                      side:
                                          const BorderSide(color: borderNormal),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8), // Espaço entre botões
                                // Botão Registrar dentro de Expanded
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.payment_rounded,
                                        size: 18),
                                    label: const Text('Registrar'),
                                    onPressed: () => _registerPayment(student),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: successColor,
                                      // Garante que o texto não quebre linha facilmente
                                      textStyle: const TextStyle(
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ),
                                ),
                              ],
                            )
                            // --- FIM DA CORREÇÃO ---
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
