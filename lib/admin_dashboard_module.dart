// lib/admin_dashboard_module.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

// --- WIDGET HELPER MOVido PARA FORA DA CLASSE ---
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

// Modelo para armazenar as métricas do dashboard
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

// Tela do Dashboard do Administrador
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

    // 1. Busca Academias
    final academySnapshot = await firestore.collection('academies').get();
    final totalAcademies = academySnapshot.docs.length;
    final activeAcademies = academySnapshot.docs
        .where((doc) => (doc.data()['status'] ?? 'active') == 'active')
        .length;
    final inactiveAcademies = totalAcademies - activeAcademies;

    // 2. Busca Assinaturas a Vencer
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    final expiringSubscriptions = academySnapshot.docs.where((doc) {
      final data = doc.data();
      final endDate = (data['subscriptionEndDate'] as Timestamp?)?.toDate();
      return endDate != null &&
          endDate.isAfter(now) &&
          endDate.isBefore(thirtyDaysFromNow);
    }).toList();

    // 3. Busca Usuários
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

// --- TELA FINANCEIRA ---
class AdminFinancialPage extends StatefulWidget {
  const AdminFinancialPage({super.key});

  @override
  State<AdminFinancialPage> createState() => _AdminFinancialPageState();
}

class _AdminFinancialPageState extends State<AdminFinancialPage> {
  late Future<Map<String, String>> _academyNamesFuture;

  @override
  void initState() {
    super.initState();
    _academyNamesFuture = _fetchAcademyNames();
  }

  // --- FUNÇÃO CORRIGIDA PARA BUSCAR NOMES DAS ACADEMIAS ---
  Future<Map<String, String>> _fetchAcademyNames() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('academies').get();
    return {
      for (var doc in snapshot.docs)
        doc.id: doc.data()['name'] ?? 'Nome não encontrado'
    };
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return Column(
      children: [
        // Card de Faturamento do Mês
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collectionGroup('payment_history')
                .where('paymentDate',
                    isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                .where('paymentDate',
                    isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator())));
              }
              double totalRevenue = 0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  totalRevenue +=
                      ((doc.data() as Map<String, dynamic>)['amount'] as num)
                          .toDouble();
                }
              }
              return _buildMetricCard(
                  context,
                  'Faturamento do Mês',
                  priceFormat.format(totalRevenue),
                  Icons.attach_money_rounded,
                  successColor);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Todos os Pagamentos Recebidos',
              style: TextStyle(color: textHint)),
        ),
        // Lista de Todos os Pagamentos
        Expanded(
          child: FutureBuilder<Map<String, String>>(
            future: _academyNamesFuture,
            builder: (context, academyNamesSnapshot) {
              if (academyNamesSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final academyNames = academyNamesSnapshot.data ?? {};

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collectionGroup('payment_history')
                    .orderBy('paymentDate', descending: true)
                    .snapshots(),
                builder: (context, paymentSnapshot) {
                  if (paymentSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!paymentSnapshot.hasData ||
                      paymentSnapshot.data!.docs.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.receipt_long,
                      title: 'Nenhum Pagamento Registrado',
                    );
                  }
                  final records = paymentSnapshot.data!.docs.map((doc) {
                    final academyId = doc.reference.parent.parent!.id;
                    final payment = PaymentRecord.fromFirestore(doc);
                    return MapEntry(academyId, payment);
                  }).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final recordEntry = records[index];
                      final academyId = recordEntry.key;
                      final record = recordEntry.value;
                      final academyName =
                          academyNames[academyId] ?? 'Academia não encontrada';

                      return Card(
                        child: ListTile(
                          title: Text(priceFormat.format(record.amount)),
                          subtitle: Text(
                              '$academyName em ${DateFormat('dd/MM/yyyy').format(record.paymentDate)}'),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
