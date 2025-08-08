// lib/admin_financial_page.dart
// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, unnecessary_to_list_in_spreads

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

// Modelo para os dados agregados
class FinancialSummary {
  final double grandTotal;
  final Map<int, Map<int, double>> yearlyData;

  FinancialSummary({required this.grandTotal, required this.yearlyData});
}

class AdminFinancialPage extends StatefulWidget {
  const AdminFinancialPage({super.key});

  @override
  State<AdminFinancialPage> createState() => _AdminFinancialPageState();
}

class _AdminFinancialPageState extends State<AdminFinancialPage> {
  late Future<FinancialSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _fetchFinancialSummary();
  }

  Future<FinancialSummary> _fetchFinancialSummary() async {
    final Map<int, Map<int, double>> yearlyData = {};
    double grandTotal = 0.0;

    final academiesSnapshot =
        await FirebaseFirestore.instance.collection('academies').get();

    for (final academyDoc in academiesSnapshot.docs) {
      final paymentsSnapshot =
          await academyDoc.reference.collection('payment_history').get();

      for (final paymentDoc in paymentsSnapshot.docs) {
        try {
          final record = PaymentRecord.fromFirestore(paymentDoc);
          final year = record.paymentDate.year;
          final month = record.paymentDate.month;
          final amount = record.amount;

          grandTotal += amount;

          yearlyData.putIfAbsent(year, () => {});
          yearlyData[year]!
              .update(month, (value) => value + amount, ifAbsent: () => amount);
        } catch (e) {
          debugPrint(
              'Could not parse payment record ${paymentDoc.id} from academy ${academyDoc.id}: $e');
        }
      }
    }
    return FinancialSummary(grandTotal: grandTotal, yearlyData: yearlyData);
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return FutureBuilder<FinancialSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyStateWidget(
            icon: Icons.error,
            title: 'Erro ao carregar dados',
            message: snapshot.error.toString(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.grandTotal == 0) {
          return const EmptyStateWidget(
            icon: Icons.receipt_long,
            title: 'Nenhum Pagamento',
            message: 'Ainda não foram registrados pagamentos nas academias.',
          );
        }

        final summary = snapshot.data!;
        final yearlyData = summary.yearlyData;
        final years = yearlyData.keys.toList()..sort((a, b) => b.compareTo(a));

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _summaryFuture = _fetchFinancialSummary();
            });
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildMetricCard(
                context,
                'Receita Total (Geral)',
                priceFormat.format(summary.grandTotal),
                Icons.show_chart_rounded,
                successColor,
              ),
              const SizedBox(height: 16),
              ...years.map((year) {
                final monthlyData = yearlyData[year]!;
                final yearTotal = monthlyData.values.reduce((a, b) => a + b);
                final months = monthlyData.keys.toList()
                  ..sort((a, b) => a.compareTo(b));

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ExpansionTile(
                    initiallyExpanded: year == DateTime.now().year,
                    title: Text(year.toString(),
                        style: Theme.of(context).textTheme.titleLarge),
                    subtitle:
                        Text('Total Anual: ${priceFormat.format(yearTotal)}'),
                    children: months.map((month) {
                      final monthTotal = monthlyData[month]!;
                      final monthName = DateFormat.MMMM('pt_BR')
                          .format(DateTime(year, month));
                      return ListTile(
                        title: Text(monthName.capitalize()),
                        trailing: Text(priceFormat.format(monthTotal)),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

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
}
