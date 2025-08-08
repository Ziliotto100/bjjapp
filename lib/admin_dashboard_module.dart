// lib/admin_dashboard_module.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

// --- WIDGET HELPER (Inalterado) ---
Widget _buildMetricCard(BuildContext context, String title, String value,
    IconData icon, Color color) {
  return Card(
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
  );
}

// Modelo para armazenar as métricas do dashboard (Inalterado)
class DashboardMetrics {
  final int totalAcademies;
  final int activeAcademies;
  final int inactiveAcademies;
  final int totalUsers;
  final int totalManagers;
  final int totalTeachers;
  final int totalStudents;
  final List<DocumentSnapshot> expiringSubscriptions;

  DashboardMetrics({
    required this.totalAcademies,
    required this.activeAcademies,
    required this.inactiveAcademies,
    required this.totalUsers,
    required this.totalManagers,
    required this.totalTeachers,
    required this.totalStudents,
    required this.expiringSubscriptions,
  });
}

// Tela do Dashboard do Administrador (Inalterada)
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late Future<DashboardMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _fetchDashboardMetrics();
  }

  Future<DashboardMetrics> _fetchDashboardMetrics() async {
    final firestore = FirebaseFirestore.instance;

    final academySnapshot = await firestore.collection('academies').get();
    final totalAcademies = academySnapshot.docs.length;
    final activeAcademies = academySnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'active') == 'active')
        .length;
    final inactiveAcademies = totalAcademies - activeAcademies;

    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    final expiringSubscriptions = academySnapshot.docs.where((doc) {
      final data = doc.data();
      final endDate = (data['subscriptionEndDate'] as Timestamp?)?.toDate();
      return endDate != null &&
          endDate.isAfter(now) &&
          endDate.isBefore(thirtyDaysFromNow);
    }).toList();

    final usersSnapshot = await firestore.collection('users').get();
    final totalUsers = usersSnapshot.docs.length;
    int managers = 0;
    int teachers = 0;
    int students = 0;
    for (var doc in usersSnapshot.docs) {
      final role = doc.data()['role'];
      if (role == 'manager')
        managers++;
      else if (role == 'teacher')
        teachers++;
      else if (role == 'student') students++;
    }

    return DashboardMetrics(
      totalAcademies: totalAcademies,
      activeAcademies: activeAcademies,
      inactiveAcademies: inactiveAcademies,
      totalUsers: totalUsers,
      totalManagers: managers,
      totalTeachers: teachers,
      totalStudents: students,
      expiringSubscriptions: expiringSubscriptions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateWidget(
            icon: Icons.error,
            title: 'Erro ao carregar métricas',
            message: snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData) {
          return const EmptyStateWidget(
              icon: Icons.bar_chart, title: 'Sem dados para exibir');
        }

        final metrics = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _metricsFuture = _fetchDashboardMetrics();
            });
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMetricCard(
                  context,
                  'Total de Academias',
                  metrics.totalAcademies.toString(),
                  Icons.business_rounded,
                  primaryAccent),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildMetricCard(
                          context,
                          'Ativas',
                          metrics.activeAcademies.toString(),
                          Icons.check_circle_outline,
                          successColor)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildMetricCard(
                          context,
                          'Inativas',
                          metrics.inactiveAcademies.toString(),
                          Icons.cancel_outlined,
                          errorColor)),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetricCard(
                  context,
                  'Total de Usuários',
                  metrics.totalUsers.toString(),
                  Icons.people_alt_rounded,
                  infoColor),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Gerentes: ${metrics.totalManagers}'),
                    Text('Professores: ${metrics.totalTeachers}'),
                    Text('Alunos: ${metrics.totalStudents}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (metrics.expiringSubscriptions.isNotEmpty)
                _buildExpiringSubscriptionsCard(
                    context, metrics.expiringSubscriptions),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpiringSubscriptionsCard(
      BuildContext context, List<DocumentSnapshot> expiring) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assinaturas Vencendo (Próximos 30 dias)',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...expiring.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final endDate =
                  (data['subscriptionEndDate'] as Timestamp).toDate();
              final daysRemaining = endDate.difference(DateTime.now()).inDays;
              return ListTile(
                title: Text(data['name']),
                trailing: Text('$daysRemaining dias',
                    style: const TextStyle(
                        color: warningColor, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    'Vence em: ${DateFormat('dd/MM/yyyy').format(endDate)}'),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
