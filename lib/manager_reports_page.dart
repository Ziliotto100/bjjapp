// lib/manager_reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // <-- CORREÇÃO AQUI
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'financial_student_list_page.dart';

// Modelo para agregar as métricas (com as listas de alunos)
class ManagerDashboardMetrics {
  final double monthlyRevenue;
  final int activeStudentsCount;
  final int newStudentsThisMonth;
  final int inactiveStudentsLast30Days;

  // Listas para a nova funcionalidade de clique
  final List<Aluno> pendingStudents;
  final List<Aluno> overdueStudents;

  ManagerDashboardMetrics({
    required this.monthlyRevenue,
    required this.activeStudentsCount,
    required this.newStudentsThisMonth,
    required this.inactiveStudentsLast30Days,
    required this.pendingStudents,
    required this.overdueStudents,
  });
}

class ManagerReportsPage extends StatefulWidget {
  final UserModel user;
  const ManagerReportsPage({super.key, required this.user});

  @override
  State<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage> {
  late Future<ManagerDashboardMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _fetchMetrics();
  }

  Future<ManagerDashboardMetrics> _fetchMetrics() async {
    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Buscar data de início do sistema para filtrar checkins
    DateTime? systemStartDate;
    try {
      final academyDoc = await firestore
          .collection('academies')
          .doc(widget.user.academyId)
          .get();
      final data = academyDoc.data();
      if (data != null && data['systemStartDate'] != null) {
        final ts = data['systemStartDate'] as Timestamp;
        final d = ts.toDate();
        systemStartDate = DateTime(d.year, d.month, d.day);
      }
    } catch (_) {}

    // Data base para alunos inativos: 30 dias atrás ou systemStartDate, o que for mais recente
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final inactiveCutoff =
        systemStartDate != null && systemStartDate.isAfter(thirtyDaysAgo)
            ? systemStartDate
            : thirtyDaysAgo;

    // 1. Buscar todos os alunos ativos
    final studentsSnapshot = await firestore
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('students')
        .where('isActive', isEqualTo: true)
        .get();
    final allActiveStudents = studentsSnapshot.docs
        .map((doc) => Aluno.fromJson(doc.id, doc.data()))
        .toList();

    // 2. Contar novos alunos
    final newStudentsThisMonth = allActiveStudents.where((student) {
      final createdAt = student.createdAt?.toDate();
      return createdAt != null && createdAt.isAfter(startOfMonth);
    }).length;

    // 3. Lógica Financeira CORRIGIDA
    final feesSnapshot = await firestore
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('monthly_fees')
        .where('paymentYear', isEqualTo: now.year)
        .where('paymentMonth', isEqualTo: now.month)
        .get();

    final feesMap = {
      for (var doc in feesSnapshot.docs)
        doc['studentId']: MonthlyFee.fromFirestore(doc)
    };
    double monthlyRevenue = 0;
    List<Aluno> pendingStudents = [];
    List<Aluno> overdueStudents = [];

    // Compara TODOS os alunos ativos com as mensalidades geradas
    for (final student in allActiveStudents) {
      final fee = feesMap[student.id];
      if (fee != null) {
        if (fee.status == PaymentStatus.pago) {
          monthlyRevenue += fee.amount;
        } else if (now.day > 10) {
          // Vencimento no dia 10
          overdueStudents.add(student);
        } else {
          pendingStudents.add(student);
        }
      } else {
        // Se não existe mensalidade gerada, também está pendente/atrasado
        if (now.day > 10) {
          overdueStudents.add(student);
        } else {
          pendingStudents.add(student);
        }
      }
    }

    // 4. Lógica de Alunos Ausentes
    final checkinsSnapshot = await firestore
        .collection('academies')
        .doc(widget.user.academyId)
        .collection('checkins')
        .where('date', isGreaterThanOrEqualTo: inactiveCutoff)
        .get();

    Set<String> studentsWithRecentCheckin = {
      for (var doc in checkinsSnapshot.docs) doc['studentId']
    };
    final inactiveStudentsLast30Days = allActiveStudents
        .where((s) => !studentsWithRecentCheckin.contains(s.id))
        .length;

    return ManagerDashboardMetrics(
      monthlyRevenue: monthlyRevenue,
      pendingStudents: pendingStudents,
      overdueStudents: overdueStudents,
      activeStudentsCount: allActiveStudents.length,
      newStudentsThisMonth: newStudentsThisMonth,
      inactiveStudentsLast30Days: inactiveStudentsLast30Days,
    );
  }

  // --- Nova Função para Navegação ---
  void _navigateToStudentList(String title, List<Aluno> students) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FinancialStudentListPage(
        title: title,
        students: students,
        currentUser: widget.user,
        academyId: widget.user.academyId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return FutureBuilder<ManagerDashboardMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return EmptyStateWidget(
              icon: Icons.error,
              title: 'Erro ao carregar dados',
              message: snapshot.error.toString());
        }

        final metrics = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _metricsFuture = _fetchMetrics();
            });
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text("Financeiro (Mês Atual)",
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _buildMetricCard(
                  context,
                  'Receita do Mês',
                  priceFormat.format(metrics.monthlyRevenue),
                  Icons.show_chart_rounded,
                  successColor),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildClickableMetricCard(
                        context,
                        'Pendentes',
                        metrics.pendingStudents.length.toString(),
                        Icons.hourglass_empty_rounded,
                        warningColor,
                        onTap: () => _navigateToStudentList(
                            'Alunos Pendentes', metrics.pendingStudents))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildClickableMetricCard(
                        context,
                        'Atrasados',
                        metrics.overdueStudents.length.toString(),
                        Icons.error_outline_rounded,
                        errorColor,
                        onTap: () => _navigateToStudentList(
                            'Alunos Atrasados', metrics.overdueStudents))),
              ]),
              const Divider(height: 32),
              Text("Alunos", style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _buildMetricCard(
                  context,
                  'Alunos Ativos',
                  metrics.activeStudentsCount.toString(),
                  Icons.people_alt_rounded,
                  primaryAccent),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _buildMetricCard(
                        context,
                        'Novos Alunos',
                        metrics.newStudentsThisMonth.toString(),
                        Icons.person_add_alt_1_rounded,
                        infoColor,
                        subtitle: '(mês)')),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildMetricCard(
                        context,
                        'Ausentes',
                        metrics.inactiveStudentsLast30Days.toString(),
                        Icons.person_off_rounded,
                        textHint,
                        subtitle: '(30 dias)')),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value,
      IconData icon, Color color,
      {String? subtitle}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(subtitle,
                            style:
                                const TextStyle(color: textHint, fontSize: 12)),
                      ),
                  ],
                ),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- NOVO WIDGET CLICÃVEL ---
  Widget _buildClickableMetricCard(BuildContext context, String title,
      String value, IconData icon, Color color,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Icon(icon, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
