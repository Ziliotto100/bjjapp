// lib/financial_student_list_page.dart
// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'user_card_widget.dart';

class FinancialStudentListPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
      ),
      body: AppBackground(
        child: SafeArea(
          child: students.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.check_circle_outline,
                  title: 'Nenhum Aluno',
                  message: 'Não há alunos nesta categoria no momento.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    // Reutilizamos o UserCard para manter a consistência visual
                    return UserCard(
                      user: student,
                      academyId: academyId,
                      currentUser: currentUser,
                      // A imagem de perfil não é necessária aqui, mas o card a aceita.
                      // Você pode adaptar para buscar a imagem se desejar.
                      profileImageUrl: null,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
