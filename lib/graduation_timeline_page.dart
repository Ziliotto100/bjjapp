// lib/graduation_timeline_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class GraduationTimelinePage extends StatelessWidget {
  final String academyId;
  final dynamic user; // Pode ser Aluno ou UserModel

  const GraduationTimelinePage({
    super.key,
    required this.academyId,
    required this.user,
  });

  Stream<QuerySnapshot> _getHistoryStream() {
    // --- LÓGICA CORRIGIDA AQUI ---
    if (user is Aluno) {
      // Caso de um gerente/professor vendo o perfil de um aluno
      return FirebaseFirestore.instance
          .collection('academies')
          .doc(academyId)
          .collection('students')
          .doc(user.id)
          .collection('graduation_history')
          .orderBy('date', descending: true)
          .snapshots();
    } else {
      // Caso do próprio usuário logado (UserModel)
      final userModel = user as UserModel;
      if (userModel.role == UserRole.student) {
        // Se o usuário logado for um aluno, buscamos pelo seu registro de aluno
        if (userModel.studentRecordId == null) {
          return const Stream
              .empty(); // Retorna um stream vazio se não houver ID
        }
        return FirebaseFirestore.instance
            .collection('academies')
            .doc(academyId)
            .collection('students')
            .doc(userModel.studentRecordId)
            .collection('graduation_history')
            .orderBy('date', descending: true)
            .snapshots();
      } else {
        // Caso de um professor ou gerente vendo o próprio histórico
        return FirebaseFirestore.instance
            .collection('users')
            .doc(userModel.uid)
            .collection('graduation_history')
            .orderBy('date', descending: true)
            .snapshots();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = (user is Aluno) ? user.nome : user.name;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Linha do Tempo de $name'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getHistoryStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Erro ao Carregar',
                  message: 'Não foi possível buscar o histórico.',
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Nenhum Registro',
                  message: 'Ainda não há graduações registradas.',
                );
              }

              final history = snapshot.data!.docs
                  .map((doc) => GraduationHistory.fromFirestore(doc))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return TimelineTile(
                    alignment: TimelineAlign.manual,
                    lineXY: 0.15,
                    isFirst: index == 0,
                    isLast: index == history.length - 1,
                    indicatorStyle: IndicatorStyle(
                      width: 40,
                      height: 50,
                      indicator: Image.asset(getBeltImagePath(item.belt)),
                    ),
                    beforeLineStyle: const LineStyle(
                      color: borderNormal,
                      thickness: 2,
                    ),
                    endChild: Card(
                      margin:
                          const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.belt}${item.degree != null && item.degree! > 0 ? " - ${item.degree}º Grau" : ""}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Graduado em: ${DateFormat.yMd('pt_BR').format(item.date)}',
                              style: const TextStyle(color: textHint),
                            ),
                            if (item.promotedByName != null)
                              Text(
                                'Por: ${item.promotedByName}',
                                style: const TextStyle(color: textHint),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
