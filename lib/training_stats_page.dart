// lib/training_stats_page.dart
// ignore_for_file: unused_field, unreachable_switch_default, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:collection/collection.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'training_log_module.dart';

// --- (Enums e Modelos de Dados - Inalterados) ---
enum SparringChartType { column, bar, pie }

enum PerformanceChartType { line, spline, column, area }

enum TechniquesChartType { pie, doughnut, bar }

enum TopTechniquesChartType { bar, pie }

enum PartnersChartType { bar, pie }

class _ChartData {
  final String x;
  final num y;
  final num? y2;
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
  // --- INÍCIO DAS ALTERAÇÕES ---

  // Mapa para controlar a visibilidade de cada gráfico
  Map<String, bool> _chartVisibility = {
    'sparring': true,
    'performanceByCondition': true,
    'topSubmissions': true,
    'partners': true,
    'performance': true,
    'techniques': true,
  };

  // Mapa para os nomes dos gráficos no diálogo
  final Map<String, String> _chartNames = {
    'sparring': 'Ações de Sparring',
    'performanceByCondition': 'Performance por Condição',
    'topSubmissions': 'Top 5 Finalizações',
    'partners': 'Principais Parceiros',
    'performance': 'Evolução da Performance',
    'techniques': 'Técnicas Focadas',
  };

  // --- FIM DAS ALTERAÇÕES ---

  SparringChartType _sparringChartType = SparringChartType.column;
  PerformanceChartType _performanceChartType = PerformanceChartType.line;
  TechniquesChartType _techniquesChartType = TechniquesChartType.pie;
  TopTechniquesChartType _topSubmissionsChartType = TopTechniquesChartType.bar;
  PartnersChartType _partnersChartType = PartnersChartType.bar;

  bool _isLoadingPreferences = true;

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
            // Carrega os tipos de gráfico (lógica existente)
            _sparringChartType = SparringChartType.values.firstWhere(
                (e) => e.name == data['sparringChart'],
                orElse: () => SparringChartType.column);
            _performanceChartType = PerformanceChartType.values.firstWhere(
                (e) => e.name == data['performanceChart'],
                orElse: () => PerformanceChartType.line);
            _techniquesChartType = TechniquesChartType.values.firstWhere(
                (e) => e.name == data['techniquesChart'],
                orElse: () => TechniquesChartType.pie);
            _topSubmissionsChartType = TopTechniquesChartType.values.firstWhere(
                (e) => e.name == data['topSubmissionsChart'],
                orElse: () => TopTechniquesChartType.bar);
            _partnersChartType = PartnersChartType.values.firstWhere(
                (e) => e.name == data['partnersChart'],
                orElse: () => PartnersChartType.bar);

            // --- INÍCIO DA ALTERAÇÃO ---
            // Carrega as preferências de visibilidade
            if (data['chartVisibility'] != null) {
              final visibilityData =
                  Map<String, bool>.from(data['chartVisibility']);
              _chartVisibility = {
                ..._chartVisibility,
                ...visibilityData
              }; // Mescla com o padrão
            }
            // --- FIM DA ALTERAÇÃO ---
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

  Future<void> _saveChartPreference(String key, dynamic value) async {
    await _preferencesRef.set({key: value}, SetOptions(merge: true));
  }

  // --- INÍCIO DA ALTERAÇÃO ---
  // Nova função para exibir o diálogo de filtro de visibilidade
  void _showVisibilityFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Usa StatefulBuilder para que o diálogo tenha seu próprio estado
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Exibir Gráficos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _chartVisibility.keys.map((key) {
                    return SwitchListTile(
                      title: Text(_chartNames[key] ?? key),
                      value: _chartVisibility[key]!,
                      onChanged: (bool value) {
                        setDialogState(() {
                          // Atualiza o estado local do diálogo
                          _chartVisibility[key] = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Salva as novas preferências e atualiza a tela principal
                    _saveChartPreference('chartVisibility', _chartVisibility);
                    setState(
                        () {}); // Força a reconstrução da tela de estatísticas
                    Navigator.of(context).pop();
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- FIM DA ALTERAÇÃO ---

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
    // ... (toda a lógica de processamento de dados permanece a mesma)
    final totalTrainings = logs.length;

    final Map<SparringEventType, Map<String, int>> eventCounts = {};
    final Map<String, int> topSubmissions = {};
    final Map<String, int> partnerCounts = {};
    final Map<PhysicalCondition, List<int>> performanceByCondition = {};

    for (var log in logs) {
      for (var round in log.sparringRounds) {
        if (round.partnerName.isNotEmpty) {
          partnerCounts.update(round.partnerName, (value) => value + 1,
              ifAbsent: () => 1);
        }
        if (round.physicalCondition != null) {
          performanceByCondition
              .putIfAbsent(round.physicalCondition!, () => [])
              .add(round.rating);
        }
        for (var event in round.events) {
          eventCounts.putIfAbsent(event.type, () => {'favor': 0, 'contra': 0});
          if (event.wasSuccessful) {
            eventCounts[event.type]!['favor'] =
                (eventCounts[event.type]!['favor'] ?? 0) + 1;
          } else {
            eventCounts[event.type]!['contra'] =
                (eventCounts[event.type]!['contra'] ?? 0) + 1;
          }
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

    final List<_ChartData> performanceByConditionData =
        performanceByCondition.entries.map((entry) {
      final ratings = entry.value;
      final average = ratings.isNotEmpty
          ? ratings.reduce((a, b) => a + b) / ratings.length
          : 0;
      return _ChartData(_getPhysicalConditionName(entry.key), average);
    }).toList();

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
    // --- Fim da lógica de processamento de dados ---

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // --- INÍCIO DA ALTERAÇÃO ---
        _buildTotalTrainingsCard(
            context, totalTrainings, _showVisibilityFilterDialog),
        // --- FIM DA ALTERAÇÃO ---
        const SizedBox(height: 16),

        // --- INÍCIO DA ALTERAÇÃO (Renderização Condicional) ---
        if (_chartVisibility['sparring'] ?? true) ...[
          _buildSparringChart(context, sparringData),
          const SizedBox(height: 16),
        ],
        if ((_chartVisibility['performanceByCondition'] ?? true) &&
            performanceByConditionData.isNotEmpty) ...[
          _buildPerformanceByConditionChart(
              context, performanceByConditionData),
          const SizedBox(height: 16),
        ],
        if ((_chartVisibility['topSubmissions'] ?? true) &&
            topSubmissionsData.isNotEmpty) ...[
          _buildTopSubmissionsChart(context, topSubmissionsData),
          const SizedBox(height: 16),
        ],
        if ((_chartVisibility['partners'] ?? true) &&
            partnerData.isNotEmpty) ...[
          _buildPartnersChart(context, partnerData, logs),
          const SizedBox(height: 16),
        ],
        if ((_chartVisibility['performance'] ?? true) &&
            performanceData.length > 1) ...[
          _buildPerformanceChart(context, performanceData),
          const SizedBox(height: 16),
        ],
        if ((_chartVisibility['techniques'] ?? true) &&
            techniquesData.isNotEmpty) ...[
          _buildTechniquesChart(context, techniquesData),
        ],
        // --- FIM DA ALTERAÇÃO ---
      ],
    );
  }

  // --- (Funções de build dos gráficos - sem alteração na assinatura, exceto _buildPartnersChart) ---

  String _getPhysicalConditionName(PhysicalCondition condition) {
    switch (condition) {
      case PhysicalCondition.disposto:
        return 'Disposto';
      case PhysicalCondition.normal:
        return 'Normal';
      case PhysicalCondition.cansado:
        return 'Cansado';
    }
  }

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
    );
  }

  Widget _buildPerformanceByConditionChart(
      BuildContext context, List<_ChartData> data) {
    return _ChartCard(
      title: 'Performance Média por Condição',
      infoMessage:
          'Sua avaliação média de performance (1 a 5) em rounds quando se sentia disposto, normal ou cansado.',
      chart: SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: const NumericAxis(minimum: 1, maximum: 5, interval: 1),
        series: <CartesianSeries>[
          ColumnSeries<_ChartData, String>(
              dataSource: data,
              xValueMapper: (d, _) => d.x,
              yValueMapper: (d, _) => d.y,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
              pointColorMapper: (_ChartData data, _) {
                switch (data.x) {
                  case 'Disposto':
                    return successColor;
                  case 'Normal':
                    return infoColor;
                  case 'Cansado':
                    return warningColor;
                  default:
                    return Colors.grey;
                }
              })
        ],
      ),
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

  Widget _buildPartnersChart(
      BuildContext context, List<_ChartData> data, List<TrainingLog> allLogs) {
    return _ChartCard(
      title: 'Principais Parceiros de Treino',
      infoMessage:
          'As pessoas com quem você mais treinou. Toque em uma barra para ver o histórico detalhado.',
      chart: SfCartesianChart(
        primaryXAxis: const CategoryAxis(),
        series: <CartesianSeries>[
          BarSeries<_ChartData, String>(
            dataSource: data,
            xValueMapper: (d, _) => d.x,
            yValueMapper: (d, _) => d.y,
            dataLabelSettings: const DataLabelSettings(isVisible: true),
            color: infoColor,
            onPointTap: (ChartPointDetails details) {
              final int pointIndex = details.pointIndex!;
              final String partnerName = data[pointIndex].x;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PartnerStatsDetailPage(
                  partnerName: partnerName,
                  allLogs: allLogs,
                ),
              ));
            },
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

  // --- INÍCIO DA ALTERAÇÃO ---
  // Widget de UI do Card de Treinos Totais modificado para aceitar o callback
  Widget _buildTotalTrainingsCard(
      BuildContext context, int total, VoidCallback onFilterTap) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
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
            const Expanded(
              child: Text('Treinos Registrados',
                  style: TextStyle(color: textHint, fontSize: 14)),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list, color: textHint),
              onPressed: onFilterTap,
              tooltip: 'Filtrar Gráficos',
            ),
          ],
        ),
      ),
    );
  }
}
// --- FIM DA ALTERAÇÃO ---

// --- (Widget _ChartCard e Página PartnerStatsDetailPage - Inalterados) ---

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

class PartnerStatsDetailPage extends StatelessWidget {
  final String partnerName;
  final List<TrainingLog> allLogs;

  const PartnerStatsDetailPage({
    super.key,
    required this.partnerName,
    required this.allLogs,
  });

  @override
  Widget build(BuildContext context) {
    // Filtra os rounds apenas com o parceiro selecionado
    final partnerRounds = allLogs
        .expand((log) => log.sparringRounds)
        .where((round) => round.partnerName == partnerName)
        .toList();

    // Processa os dados para os gráficos
    final Map<SparringEventType, Map<String, int>> eventCounts = {};
    for (var round in partnerRounds) {
      for (var event in round.events) {
        eventCounts.putIfAbsent(event.type, () => {'favor': 0, 'contra': 0});
        if (event.wasSuccessful) {
          eventCounts[event.type]!['favor'] =
              (eventCounts[event.type]!['favor'] ?? 0) + 1;
        } else {
          eventCounts[event.type]!['contra'] =
              (eventCounts[event.type]!['contra'] ?? 0) + 1;
        }
      }
    }
    final List<_ChartData> sparringData = eventCounts.entries.map((e) {
      return _ChartData(getSparringEventTypeName(e.key), e.value['favor'] ?? 0,
          y2: e.value['contra'] ?? 0);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Análise com $partnerName'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _ChartCard(
                title: 'Head-to-Head',
                infoMessage:
                    'Comparativo de ações de sparring apenas com este parceiro.',
                chart: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(),
                  legend: const Legend(
                      isVisible: true, position: LegendPosition.bottom),
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
              ),
              // Adicionar mais cards e análises específicas aqui no futuro
            ],
          ),
        ),
      ),
    );
  }
}
