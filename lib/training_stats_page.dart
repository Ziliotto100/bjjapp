// lib/training_stats_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:collection/collection.dart'; // Import necessário

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'training_log_module.dart';

// --- ENUMS PARA OS TIPOS DE GRÁFICO ---
enum SparringChartType { column, bar, pie }

enum PerformanceChartType { line, spline, column, area }

enum TechniquesChartType { pie, doughnut, bar }

// --- NOVOS ENUMS ---
enum TopTechniquesChartType { bar, pie }

enum PartnersChartType { bar, pie }

// --- MODELOS PARA OS DADOS DOS GRÁFICOS ---
class _ChartData {
  final String x;
  final num y;
  final num? y2; // Para séries secundárias (ex: A favor vs Contra)
  _ChartData(this.x, this.y, {this.y2});
}

class _PerformanceData {
  final DateTime x;
  final int y;
  _PerformanceData(this.x, this.y);
}

// --- TELA DE ESTATÍSTICAS (STATEFUL) ---
class TrainingStatsPage extends StatefulWidget {
  final UserModel user;
  const TrainingStatsPage({super.key, required this.user});

  @override
  State<TrainingStatsPage> createState() => _TrainingStatsPageState();
}

class _TrainingStatsPageState extends State<TrainingStatsPage> {
  // Estado para armazenar as preferências do usuário
  SparringChartType _sparringChartType = SparringChartType.column;
  PerformanceChartType _performanceChartType = PerformanceChartType.line;
  TechniquesChartType _techniquesChartType = TechniquesChartType.pie;
  // --- NOVAS PREFERÊNCIAS ---
  TopTechniquesChartType _topSubmissionsChartType = TopTechniquesChartType.bar;
  PartnersChartType _partnersChartType = PartnersChartType.bar;

  bool _isLoadingPreferences = true;

  // Paleta de cores personalizada
  final List<Color> _customPalette = [
    primaryAccent,
    infoColor,
    successColor,
    warningColor,
    errorColor,
    Colors.purple.shade300,
    Colors.orange.shade300,
  ];

  @override
  void initState() {
    super.initState();
    _loadChartPreferences();
  }

  // --- LÓGICA PARA CARREGAR E SALVAR PREFERÊNCIAS ---
  DocumentReference get _preferencesRef => FirebaseFirestore.instance
      .collection('users')
      .doc(widget.user.uid)
      .collection('user_settings')
      .doc('chart_preferences');

  Future<void> _loadChartPreferences() async {
    try {
      final doc = await _preferencesRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _sparringChartType = SparringChartType.values.firstWhere(
                (e) => e.name == data['sparringChart'],
                orElse: () => SparringChartType.column);
            _performanceChartType = PerformanceChartType.values.firstWhere(
                (e) => e.name == data['performanceChart'],
                orElse: () => PerformanceChartType.line);
            _techniquesChartType = TechniquesChartType.values.firstWhere(
                (e) => e.name == data['techniquesChart'],
                orElse: () => TechniquesChartType.pie);
            // --- CARREGANDO NOVAS PREFERÊNCIAS ---
            _topSubmissionsChartType = TopTechniquesChartType.values.firstWhere(
                (e) => e.name == data['topSubmissionsChart'],
                orElse: () => TopTechniquesChartType.bar);
            _partnersChartType = PartnersChartType.values.firstWhere(
                (e) => e.name == data['partnersChart'],
                orElse: () => PartnersChartType.bar);
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao carregar preferências de gráficos: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPreferences = false;
        });
      }
    }
  }

  Future<void> _saveChartPreference(String key, String value) async {
    await _preferencesRef.set({key: value}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPreferences) {
      return const Center(child: CircularProgressIndicator());
    }

    final logService = TrainingLogService(userId: widget.user.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: logService.getLogsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyStateWidget(
              icon: Icons.error, title: 'Erro ao carregar estatísticas');
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.query_stats_rounded,
            title: 'Estatísticas Indisponíveis',
            message:
                'Registre alguns treinos no seu diário para começar a ver seus gráficos de evolução.',
          );
        }

        final logs = snapshot.data!.docs
            .map((doc) => TrainingLog.fromFirestore(doc))
            .toList();

        return _buildStatsView(context, logs);
      },
    );
  }

  Widget _buildStatsView(BuildContext context, List<TrainingLog> logs) {
    // Processamento de dados
    final totalTrainings = logs.length;

    // --- PROCESSAMENTO DE DADOS APRIMORADO ---
    final Map<SparringEventType, Map<String, int>> eventCounts = {};
    final Map<String, int> topSubmissions = {};
    final Map<String, int> partnerCounts = {};

    for (var log in logs) {
      for (var round in log.sparringRounds) {
        // Contagem de parceiros
        if (round.partnerName.isNotEmpty) {
          partnerCounts.update(round.partnerName, (value) => value + 1,
              ifAbsent: () => 1);
        }

        for (var event in round.events) {
          // Contagem geral de eventos (a favor vs contra)
          eventCounts.putIfAbsent(event.type, () => {'favor': 0, 'contra': 0});
          if (event.wasSuccessful) {
            eventCounts[event.type]!['favor'] =
                (eventCounts[event.type]!['favor'] ?? 0) + 1;
          } else {
            eventCounts[event.type]!['contra'] =
                (eventCounts[event.type]!['contra'] ?? 0) + 1;
          }

          // Contagem das finalizações mais aplicadas
          if (event.type == SparringEventType.finalizacao &&
              event.wasSuccessful) {
            topSubmissions.update(event.technique, (value) => value + 1,
                ifAbsent: () => 1);
          }
        }
      }
    }

    final List<_ChartData> sparringData = eventCounts.entries.map((e) {
      return _ChartData(getSparringEventTypeName(e.key), e.value['favor'] ?? 0,
          y2: e.value['contra'] ?? 0);
    }).toList();

    final List<_ChartData> topSubmissionsData = topSubmissions.entries
        .map((e) => _ChartData(e.key, e.value))
        .sorted((a, b) => b.y.compareTo(a.y))
        .take(5)
        .toList();

    final List<_ChartData> partnerData = partnerCounts.entries
        .map((e) => _ChartData(e.key, e.value))
        .sorted((a, b) => b.y.compareTo(a.y))
        .take(5)
        .toList();

    final List<_PerformanceData> performanceData = logs
        .map((log) => _PerformanceData(log.date, log.performanceRating))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    final Map<String, int> techniqueCounts = {};
    for (var log in logs) {
      for (var tech in log.techniques) {
        techniqueCounts.update(tech.capitalizeWords(), (value) => value + 1,
            ifAbsent: () => 1);
      }
    }
    final List<_ChartData> techniquesData = techniqueCounts.entries
        .map((e) => _ChartData(e.key, e.value))
        .toList()
      ..sort((a, b) => b.y.compareTo(a.y));

    // UI principal com os cards de gráficos
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _buildTotalTrainingsCard(context, totalTrainings),
        const SizedBox(height: 16),
        _buildSparringChart(context, sparringData),
        const SizedBox(height: 16),
        if (topSubmissionsData.isNotEmpty) ...[
          _buildTopSubmissionsChart(context, topSubmissionsData),
          const SizedBox(height: 16),
        ],
        if (partnerData.isNotEmpty) ...[
          _buildPartnersChart(context, partnerData),
          const SizedBox(height: 16),
        ],
        if (performanceData.length > 1) ...[
          _buildPerformanceChart(context, performanceData),
          const SizedBox(height: 16),
        ],
        if (techniquesData.isNotEmpty)
          _buildTechniquesChart(context, techniquesData),
      ],
    );
  }

  // --- WIDGETS DE GRÁFICO ---
  Widget _buildSparringChart(
      BuildContext context, List<_ChartData> sparringData) {
    return _ChartCard(
      title: 'Ações de Sparring',
      infoMessage:
          'Este gráfico compara o total de ações que você aplicou (A Favor) versus as que sofreu (Contra) em seus treinos.',
      chart: SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        legend: const Legend(isVisible: true, position: LegendPosition.bottom),
        series: <CartesianSeries>[
          ColumnSeries<_ChartData, String>(
            name: 'A Favor',
            dataSource: sparringData,
            xValueMapper: (_ChartData data, _) => data.x,
            yValueMapper: (_ChartData data, _) => data.y,
            color: successColor,
          ),
          ColumnSeries<_ChartData, String>(
            name: 'Contra',
            dataSource: sparringData,
            xValueMapper: (_ChartData data, _) => data.x,
            yValueMapper: (_ChartData data, _) => data.y2,
            color: errorColor,
          )
        ],
      ),
      // Opções de tipo de gráfico podem ser adicionadas aqui se desejado
    );
  }

  Widget _buildTopSubmissionsChart(
      BuildContext context, List<_ChartData> data) {
    final Map<TopTechniquesChartType, String> options = {
      TopTechniquesChartType.bar: 'Barras',
      TopTechniquesChartType.pie: 'Pizza',
    };

    Widget chart;
    switch (_topSubmissionsChartType) {
      case TopTechniquesChartType.pie:
        chart = SfCircularChart(
          palette: _customPalette,
          legend: const Legend(
              isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
          series: <CircularSeries>[
            PieSeries<_ChartData, String>(
              dataSource: data,
              xValueMapper: (d, _) => d.x,
              yValueMapper: (d, _) => d.y,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            )
          ],
        );
        break;
      case TopTechniquesChartType.bar:
      default:
        chart = SfCartesianChart(
          primaryXAxis: const CategoryAxis(),
          series: <CartesianSeries>[
            BarSeries<_ChartData, String>(
              dataSource: data,
              xValueMapper: (d, _) => d.x,
              yValueMapper: (d, _) => d.y,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
              color: primaryAccent,
            )
          ],
        );
        break;
    }

    return _ChartCard(
      title: 'Top 5 Finalizações (A Favor)',
      infoMessage: 'Suas finalizações mais aplicadas com sucesso.',
      chart: chart,
      options: options,
      currentValue: _topSubmissionsChartType,
      onChanged: (newValue) {
        if (newValue == null) return;
        setState(() => _topSubmissionsChartType = newValue);
        _saveChartPreference('topSubmissionsChart', newValue.name);
      },
    );
  }

  Widget _buildPartnersChart(BuildContext context, List<_ChartData> data) {
    return _ChartCard(
      title: 'Principais Parceiros de Treino',
      infoMessage: 'As pessoas com quem você mais treinou.',
      chart: SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        series: <CartesianSeries>[
          BarSeries<_ChartData, String>(
            dataSource: data,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            color: infoColor,
          )
        ],
      ),
    );
  }

  Widget _buildPerformanceChart(
      BuildContext context, List<_PerformanceData> performanceData) {
    final Map<PerformanceChartType, String> options = {
      PerformanceChartType.line: 'Linha',
      PerformanceChartType.spline: 'Curva',
      PerformanceChartType.area: 'Área',
      PerformanceChartType.column: 'Colunas',
    };

    CartesianSeries series;
    switch (_performanceChartType) {
      case PerformanceChartType.spline:
        series = SplineSeries<_PerformanceData, DateTime>(
            dataSource: performanceData,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            markerSettings: const MarkerSettings(isVisible: true),
            color: successColor);
        break;
      case PerformanceChartType.area:
        series = AreaSeries<_PerformanceData, DateTime>(
            dataSource: performanceData,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            markerSettings: const MarkerSettings(isVisible: true),
            color: successColor.withOpacity(0.5));
        break;
      case PerformanceChartType.column:
        series = ColumnSeries<_PerformanceData, DateTime>(
            dataSource: performanceData,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            color: successColor);
        break;
      case PerformanceChartType.line:
      default:
        series = LineSeries<_PerformanceData, DateTime>(
            dataSource: performanceData,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            markerSettings: const MarkerSettings(isVisible: true),
            color: successColor);
    }

    return _ChartCard(
      title: 'Evolução da Performance',
      infoMessage:
          'Este gráfico mostra a sua autoavaliação de performance (de 1 a 5 estrelas) ao longo do tempo.\n\nParâmetros:\n• Nota de performance\n• Data de cada treino registrado',
      chart: SfCartesianChart(
        primaryXAxis: DateTimeAxis(
            dateFormat: DateFormat.MMMd('pt_BR'),
            intervalType: DateTimeIntervalType.auto),
        primaryYAxis: const NumericAxis(minimum: 1, maximum: 5, interval: 1),
        series: <CartesianSeries>[series],
      ),
      options: options,
      currentValue: _performanceChartType,
      onChanged: (newValue) {
        if (newValue == null) return;
        setState(() => _performanceChartType = newValue);
        _saveChartPreference('performanceChart', newValue.name);
      },
    );
  }

  Widget _buildTechniquesChart(
      BuildContext context, List<_ChartData> techniquesData) {
    final Map<TechniquesChartType, String> options = {
      TechniquesChartType.pie: 'Pizza',
      TechniquesChartType.doughnut: 'Rosca',
      TechniquesChartType.bar: 'Barras',
    };

    final topTechniques = techniquesData.take(5).toList();
    Widget chart;

    switch (_techniquesChartType) {
      case TechniquesChartType.doughnut:
        chart = SfCircularChart(
          palette: _customPalette,
          legend: const Legend(
              isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
          series: <CircularSeries>[
            DoughnutSeries<_ChartData, String>(
              dataSource: topTechniques,
              xValueMapper: (d, _) => d.x,
              yValueMapper: (d, _) => d.y,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            )
          ],
        );
        break;
      case TechniquesChartType.bar:
        chart = SfCartesianChart(
          primaryXAxis: const CategoryAxis(isVisible: false),
          primaryYAxis: const CategoryAxis(),
          series: <CartesianSeries>[
            BarSeries<_ChartData, String>(
              dataSource: topTechniques,
              xValueMapper: (d, _) => d.x,
              yValueMapper: (d, _) => d.y,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
              pointColorMapper: (_ChartData data, int index) =>
                  _customPalette[index % _customPalette.length],
            )
          ],
        );
        break;
      case TechniquesChartType.pie:
      default:
        chart = SfCircularChart(
          palette: _customPalette,
          legend: const Legend(
              isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
          series: <CircularSeries>[
            PieSeries<_ChartData, String>(
              dataSource: topTechniques,
              xValueMapper: (d, _) => d.x,
              yValueMapper: (d, _) => d.y,
              dataLabelSettings: const DataLabelSettings(
                  isVisible: true,
                  labelPosition: ChartDataLabelPosition.outside),
            )
          ],
        );
    }
    return _ChartCard(
      title: 'Técnicas Focadas no Treino',
      infoMessage:
          'Este gráfico exibe as 5 técnicas que você mais definiu como objetivo em seus treinos.',
      chart: chart,
      options: options,
      currentValue: _techniquesChartType,
      onChanged: (newValue) {
        if (newValue == null) return;
        setState(() => _techniquesChartType = newValue);
        _saveChartPreference('techniquesChart', newValue.name);
      },
    );
  }

  // --- WIDGETS DE UI ---
  // +++ INÍCIO DA MODIFICAÇÃO +++
  Widget _buildTotalTrainingsCard(BuildContext context, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center_rounded,
                size: 32, color: primaryAccent),
            const SizedBox(width: 12),
            Text(
              total.toString(),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(width: 8),
            const Text('Treinos Registrados',
                style: TextStyle(color: textHint, fontSize: 14)),
          ],
        ),
      ),
    );
  }
  // +++ FIM DA MODIFICAÇÃO +++
}

// --- WIDGET REUTILIZÁVEL PARA O CARD COM SELETOR ---
class _ChartCard<T> extends StatelessWidget {
  final String title;
  final String infoMessage;
  final Widget chart;
  final Map<T, String>? options;
  final T? currentValue;
  final ValueChanged<T?>? onChanged;

  const _ChartCard({
    required this.title,
    required this.infoMessage,
    required this.chart,
    this.options,
    this.currentValue,
    this.onChanged,
  });

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(infoMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: textHint),
                  onPressed: () => _showInfoDialog(context),
                  tooltip: 'Sobre este gráfico',
                ),
                if (options != null && onChanged != null)
                  PopupMenuButton<T>(
                    icon: const Icon(Icons.more_vert, color: textHint),
                    onSelected: onChanged,
                    itemBuilder: (BuildContext context) {
                      return options!.entries.map((entry) {
                        return PopupMenuItem<T>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList();
                    },
                  ),
              ],
            ),
            SizedBox(
              height: 250,
              child: chart,
            ),
          ],
        ),
      ),
    );
  }
}
