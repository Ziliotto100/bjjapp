// lib/strength_stats_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:collection/collection.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

// Lista de exercícios padrão para referência nos gráficos.
// Garante que exercícios pré-definidos sejam contabilizados mesmo se o usuário não os criou.
final List<Exercise> _predefinedExercisesForStats = [
  Exercise(id: 'predef_1', name: 'Supino Reto (Barra)', muscleGroup: 'Peito'),
  Exercise(
      id: 'predef_2', name: 'Agachamento Livre (Barra)', muscleGroup: 'Pernas'),
  Exercise(id: 'predef_3', name: 'Levantamento Terra', muscleGroup: 'Costas'),
  Exercise(
      id: 'predef_4',
      name: 'Desenvolvimento (Halteres)',
      muscleGroup: 'Ombros'),
  Exercise(
      id: 'predef_5', name: 'Puxada Frontal (Pulley)', muscleGroup: 'Costas'),
  Exercise(id: 'predef_6', name: 'Rosca Direta (Barra)', muscleGroup: 'Bíceps'),
  Exercise(
      id: 'predef_7', name: 'Tríceps Testa (Barra W)', muscleGroup: 'Tríceps'),
  Exercise(id: 'predef_8', name: 'Leg Press 45', muscleGroup: 'Pernas'),
  Exercise(
      id: 'predef_9',
      name: 'Elevação Lateral (Halteres)',
      muscleGroup: 'Ombros'),
  Exercise(
      id: 'predef_10', name: 'Remada Curvada (Barra)', muscleGroup: 'Costas'),
  Exercise(
      id: 'predef_11',
      name: 'Flexão de Braço',
      muscleGroup: 'Peito',
      equipment: 'Peso do Corpo'),
  Exercise(
      id: 'predef_12',
      name: 'Barra Fixa',
      muscleGroup: 'Costas',
      equipment: 'Peso do Corpo'),
];

class StrengthStatisticsPage extends StatefulWidget {
  final UserModel user;
  const StrengthStatisticsPage({super.key, required this.user});

  @override
  State<StrengthStatisticsPage> createState() => _StrengthStatisticsPageState();
}

class _StrengthStatisticsPageState extends State<StrengthStatisticsPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .collection('workout_logs')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.bar_chart_rounded,
            title: 'Sem Dados',
            message: 'Complete alguns treinos para ver suas estatísticas.',
          );
        }

        final logs = snapshot.data!.docs
            .map((doc) => WorkoutLog.fromFirestore(doc))
            .toList();

        return _StatsDashboard(user: widget.user, logs: logs);
      },
    );
  }
}

class _StatsDashboard extends StatefulWidget {
  final UserModel user;
  final List<WorkoutLog> logs;

  const _StatsDashboard({required this.user, required this.logs});

  @override
  State<_StatsDashboard> createState() => _StatsDashboardState();
}

enum ChartType {
  totalVolume,
  routineFrequency,
  muscleGroup,
  exerciseProgress,
  exerciseFrequencyByGroup,
  dispositionFrequency,
}

class _StatsDashboardState extends State<_StatsDashboard> {
  ChartType _selectedChart = ChartType.totalVolume;
  String? _selectedExerciseName;
  String? _selectedMuscleGroup;
  List<Exercise> _allExercises = [];
  List<String> _muscleGroups = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .collection('exercises')
        .get();
    final userExercises =
        snapshot.docs.map((doc) => Exercise.fromFirestore(doc)).toList();

    final allExercises = [...userExercises, ..._predefinedExercisesForStats];

    final Set<String> exerciseNames = {for (var ex in allExercises) ex.name};
    final Set<String> muscleGroups = {
      for (var ex in allExercises) ex.muscleGroup
    };

    final exercisesForDropdown = exerciseNames
        .map((name) => Exercise(id: name, name: name, muscleGroup: ''))
        .toList();
    exercisesForDropdown.sort((a, b) => a.name.compareTo(b.name));

    if (mounted) {
      setState(() {
        _allExercises = exercisesForDropdown;
        _muscleGroups = muscleGroups.where((g) => g.isNotEmpty).toList()
          ..sort();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cálculos das Métricas
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthLogs =
        widget.logs.where((log) => log.date.isAfter(firstDayOfMonth)).toList();
    int totalMinutesThisMonth = 0;
    for (var log in thisMonthLogs) {
      totalMinutesThisMonth += log.durationInMinutes ?? 0;
    }
    final hours = totalMinutesThisMonth ~/ 60;
    final minutes = totalMinutesThisMonth % 60;
    final timeThisMonth =
        hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';
    final workoutsThisMonth = thisMonthLogs.length;
    final totalWorkouts = widget.logs.length;
    Map<String, int> exerciseFrequency = {};
    for (var log in widget.logs) {
      for (var exercise in log.exercises) {
        exerciseFrequency.update(
          exercise.exerciseName,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final mostFrequentExercise = exerciseFrequency.entries
        .toList()
        .sorted((a, b) => b.value.compareTo(a.value))
        .firstOrNull;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Column(
                children: [
                  _buildMetricTile('Tempo no Mês', timeThisMonth, Icons.timer,
                      primaryAccent),
                  const Divider(height: 1),
                  _buildMetricTile(
                      'Treinos no Mês',
                      workoutsThisMonth.toString(),
                      Icons.calendar_month,
                      infoColor),
                  const Divider(height: 1),
                  _buildMetricTile('Total de Treinos', totalWorkouts.toString(),
                      Icons.history, successColor),
                  if (mostFrequentExercise != null) ...[
                    const Divider(height: 1),
                    _buildMetricTile('Exercício Frequente',
                        mostFrequentExercise.key, Icons.star, warningColor),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Análise Gráfica',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildChartSelector(),
            const SizedBox(height: 16),
            SizedBox(
              height: 350,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildChart(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      String title, String value, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChartSelector() {
    return Column(
      children: [
        DropdownButtonFormField<ChartType>(
          value: _selectedChart,
          decoration: const InputDecoration(labelText: 'Tipo de Gráfico'),
          items: const [
            DropdownMenuItem(
                value: ChartType.totalVolume,
                child: Text('Volume Total por Treino')),
            DropdownMenuItem(
                value: ChartType.routineFrequency,
                child: Text('Fichas Mais Treinadas no Mês')),
            DropdownMenuItem(
                value: ChartType.dispositionFrequency,
                child: Text('Frequência de Disposição')),
            DropdownMenuItem(
                value: ChartType.muscleGroup,
                child: Text('Volume por Grupo Muscular')),
            DropdownMenuItem(
                value: ChartType.exerciseProgress,
                child: Text('Progressão de Exercício')),
            DropdownMenuItem(
                value: ChartType.exerciseFrequencyByGroup,
                child: Text('Exercícios Mais Feitos por Grupo')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedChart = value!;
              _selectedExerciseName = null;
              _selectedMuscleGroup = null;
            });
          },
        ),
        if (_selectedChart == ChartType.exerciseProgress)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedExerciseName,
              decoration:
                  const InputDecoration(labelText: 'Selecione um Exercício'),
              items: _allExercises
                  .map((ex) =>
                      DropdownMenuItem(value: ex.name, child: Text(ex.name)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedExerciseName = value),
            ),
          ),
        if (_selectedChart == ChartType.exerciseFrequencyByGroup)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedMuscleGroup,
              decoration: const InputDecoration(
                  labelText: 'Selecione um Grupo Muscular'),
              items: _muscleGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedMuscleGroup = value),
            ),
          ),
      ],
    );
  }

  Widget _buildChart() {
    switch (_selectedChart) {
      case ChartType.totalVolume:
        return _TotalVolumeChart(logs: widget.logs);
      case ChartType.routineFrequency:
        return _RoutineFrequencyChart(logs: widget.logs);
      case ChartType.dispositionFrequency:
        return _DispositionFrequencyChart(logs: widget.logs);
      case ChartType.muscleGroup:
        return _MuscleGroupPieChart(logs: widget.logs, user: widget.user);
      case ChartType.exerciseProgress:
        if (_selectedExerciseName == null) {
          return const Center(child: Text('Selecione um exercício acima.'));
        }
        return _ExerciseProgressChart(
            logs: widget.logs, exerciseName: _selectedExerciseName!);
      case ChartType.exerciseFrequencyByGroup:
        if (_selectedMuscleGroup == null) {
          return const Center(
              child: Text('Selecione um grupo muscular acima.'));
        }
        return _ExerciseFrequencyChart(
            user: widget.user,
            logs: widget.logs,
            selectedGroup: _selectedMuscleGroup!);
    }
  }
}
// ... (O restante das classes de dados como _ChartData, _PieData, _BarData permanecem iguais) ...

class _ChartTitleWithInfo extends StatelessWidget {
  final String title;
  final String infoText;

  const _ChartTitleWithInfo({required this.title, required this.infoText});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: textHint, size: 20),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(title),
                content: Text(infoText),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
          tooltip: 'O que isso significa?',
        ),
      ],
    );
  }
}

class _ChartData {
  _ChartData(this.x, this.y);
  final DateTime x;
  final double y;
}

class _PieData {
  _PieData(this.x, this.y, this.color);
  final String x;
  final double y;
  final Color color;
}

class _BarData {
  _BarData(this.x, this.y);
  final String x;
  final int y;
}

class _TotalVolumeChart extends StatelessWidget {
  final List<WorkoutLog> logs;
  const _TotalVolumeChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final List<_ChartData> chartData = [];
    final reversedLogs = logs.reversed.toList();
    for (var log in reversedLogs) {
      double volume = 0;
      for (var exercise in log.exercises) {
        for (var set in exercise.sets) {
          volume += set.weight * set.repetitions;
        }
      }
      chartData.add(_ChartData(log.date, volume));
    }
    return Column(
      children: [
        const _ChartTitleWithInfo(
          title: 'Volume Total por Treino',
          infoText:
              'Este gráfico mostra a soma de (Carga x Repetições) de todos os exercícios em cada sessão de treino. É um indicador chave da sua progressão de trabalho total ao longo do tempo.',
        ),
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: DateTimeAxis(
              dateFormat: DateFormat('dd/MM/yy'),
              intervalType: DateTimeIntervalType.auto,
            ),
            primaryYAxis: NumericAxis(
              numberFormat: NumberFormat.compact(),
              title: AxisTitle(text: 'Volume (kg)'),
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<_ChartData, DateTime>>[
              LineSeries<_ChartData, DateTime>(
                dataSource: chartData,
                xValueMapper: (_ChartData data, _) => data.x,
                yValueMapper: (_ChartData data, _) => data.y,
                name: 'Volume',
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _RoutineFrequencyChart extends StatelessWidget {
  final List<WorkoutLog> logs;
  const _RoutineFrequencyChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final thisMonthLogs =
        logs.where((log) => log.date.isAfter(firstDayOfMonth)).toList();
    if (thisMonthLogs.isEmpty) {
      return const Center(child: Text('Nenhum treino registrado neste mês.'));
    }
    final frequencyMap = <String, int>{};
    for (var log in thisMonthLogs) {
      frequencyMap.update(log.routineName, (value) => value + 1,
          ifAbsent: () => 1);
    }
    final List<_PieData> pieData = frequencyMap.entries
        .map((entry) =>
            _PieData(entry.key, entry.value.toDouble(), Colors.transparent))
        .toList();
    return Column(
      children: [
        const _ChartTitleWithInfo(
          title: 'Fichas Treinadas Este Mês',
          infoText:
              'Este gráfico mostra a distribuição das fichas de treino que você utilizou no mês corrente, ajudando a visualizar a frequência de cada uma.',
        ),
        Expanded(
          child: SfCircularChart(
            legend: const Legend(
                isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries<_PieData, String>>[
              PieSeries<_PieData, String>(
                dataSource: pieData,
                xValueMapper: (_PieData data, _) => data.x,
                yValueMapper: (_PieData data, _) => data.y,
                dataLabelMapper: (_PieData data, _) => '${data.y.toInt()}',
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _DispositionFrequencyChart extends StatelessWidget {
  final List<WorkoutLog> logs;
  const _DispositionFrequencyChart({required this.logs});

  String _getDispositionText(PhysicalCondition condition) {
    switch (condition) {
      case PhysicalCondition.disposto:
        return 'Disposto 😃';
      case PhysicalCondition.normal:
        return 'Normal 😐';
      case PhysicalCondition.cansado:
        return 'Cansado 😴';
    }
  }

  Color _getDispositionColor(PhysicalCondition condition) {
    switch (condition) {
      case PhysicalCondition.disposto:
        return successColor;
      case PhysicalCondition.normal:
        return infoColor;
      case PhysicalCondition.cansado:
        return warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final frequencyMap = <PhysicalCondition, int>{};
    for (var log in logs) {
      if (log.physicalCondition != null) {
        frequencyMap.update(log.physicalCondition!, (value) => value + 1,
            ifAbsent: () => 1);
      }
    }

    if (frequencyMap.isEmpty) {
      return const Center(
          child: Text('Nenhum registro de disposição encontrado.'));
    }

    final List<_PieData> pieData = frequencyMap.entries
        .map((entry) => _PieData(_getDispositionText(entry.key),
            entry.value.toDouble(), _getDispositionColor(entry.key)))
        .toList();

    return Column(
      children: [
        const _ChartTitleWithInfo(
          title: 'Frequência de Disposição (Geral)',
          infoText:
              'Este gráfico mostra a proporção de vezes que você iniciou seus treinos sentindo-se disposto, normal ou cansado, com base em todos os seus registros.',
        ),
        Expanded(
          child: SfCircularChart(
            legend: const Legend(
                isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
            series: <CircularSeries<_PieData, String>>[
              PieSeries<_PieData, String>(
                dataSource: pieData,
                xValueMapper: (_PieData data, _) => data.x,
                yValueMapper: (_PieData data, _) => data.y,
                pointColorMapper: (_PieData data, _) => data.color,
                dataLabelMapper: (_PieData data, _) => '${data.y.toInt()}',
                dataLabelSettings: const DataLabelSettings(isVisible: true),
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _MuscleGroupPieChart extends StatelessWidget {
  final List<WorkoutLog> logs;
  final UserModel user;
  const _MuscleGroupPieChart({required this.logs, required this.user});
  Future<Map<String, double>> _calculateVolumeByGroup() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('exercises')
        .get();
    final userExercises =
        snapshot.docs.map((doc) => Exercise.fromFirestore(doc)).toList();

    final allExercises = [...userExercises, ..._predefinedExercisesForStats];

    final Map<String, String> exerciseToGroupMap = {
      for (var ex in allExercises) ex.name: ex.muscleGroup
    };
    final Map<String, double> volumeByGroup = {};
    for (var log in logs) {
      for (var loggedEx in log.exercises) {
        final group = exerciseToGroupMap[loggedEx.exerciseName] ?? 'Outro';
        double volume = 0;
        for (var set in loggedEx.sets) {
          volume += set.weight * set.repetitions;
        }
        volumeByGroup.update(group, (value) => value + volume,
            ifAbsent: () => volume);
      }
    }
    return volumeByGroup;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _ChartTitleWithInfo(
          title: 'Volume por Grupo Muscular',
          infoText:
              'Este gráfico de pizza mostra a distribuição do seu volume total de treino (Carga x Repetições) entre os diferentes grupos musculares, com base nos exercícios cadastrados na sua biblioteca.',
        ),
        Expanded(
          child: FutureBuilder<Map<String, double>>(
            future: _calculateVolumeByGroup(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text(
                        'Não há dados suficientes ou seus exercícios não têm grupos musculares definidos.'));
              }
              final volumeByGroup = snapshot.data!;
              final List<_PieData> pieData = volumeByGroup.entries
                  .map((entry) =>
                      _PieData(entry.key, entry.value, Colors.transparent))
                  .toList();
              return SfCircularChart(
                legend: const Legend(
                    isVisible: true, overflowMode: LegendItemOverflowMode.wrap),
                series: <CircularSeries<_PieData, String>>[
                  PieSeries<_PieData, String>(
                    dataSource: pieData,
                    xValueMapper: (_PieData data, _) => data.x,
                    yValueMapper: (_PieData data, _) => data.y,
                    dataLabelMapper: (_PieData data, _) => data.x,
                    dataLabelSettings: const DataLabelSettings(isVisible: true),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExerciseProgressChart extends StatelessWidget {
  final List<WorkoutLog> logs;
  final String exerciseName;
  const _ExerciseProgressChart(
      {required this.logs, required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final List<_ChartData> chartData = [];
    final relevantLogs = logs
        .where(
            (log) => log.exercises.any((ex) => ex.exerciseName == exerciseName))
        .toList()
        .reversed
        .toList();
    if (relevantLogs.isEmpty) {
      return const Center(child: Text('Nenhum registro para este exercício.'));
    }
    for (var log in relevantLogs) {
      final exerciseLog =
          log.exercises.firstWhere((ex) => ex.exerciseName == exerciseName);
      double volume = 0;
      for (var set in exerciseLog.sets) {
        volume += set.weight * set.repetitions;
      }
      chartData.add(_ChartData(log.date, volume));
    }
    return Column(
      children: [
        _ChartTitleWithInfo(
          title: 'Progressão: $exerciseName',
          infoText:
              'Este gráfico mostra a evolução do seu volume total (Carga x Repetições) para o exercício selecionado ao longo do tempo.',
        ),
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: DateTimeAxis(
              dateFormat: DateFormat('dd/MM/yy'),
              intervalType: DateTimeIntervalType.auto,
            ),
            primaryYAxis: NumericAxis(
              numberFormat: NumberFormat.compact(),
              title: AxisTitle(text: 'Volume (kg)'),
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: <CartesianSeries<_ChartData, DateTime>>[
              LineSeries<_ChartData, DateTime>(
                dataSource: chartData,
                xValueMapper: (_ChartData data, _) => data.x,
                yValueMapper: (_ChartData data, _) => data.y,
                name: 'Volume',
                color: successColor,
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseFrequencyChart extends StatelessWidget {
  final UserModel user;
  final List<WorkoutLog> logs;
  final String selectedGroup;

  const _ExerciseFrequencyChart(
      {required this.user, required this.logs, required this.selectedGroup});

  Future<Map<String, int>> _calculateFrequency() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('exercises')
        .get();
    final userExercises =
        snapshot.docs.map((doc) => Exercise.fromFirestore(doc)).toList();

    final allExercises = [...userExercises, ..._predefinedExercisesForStats];

    final Map<String, String> exerciseToGroupMap = {
      for (var ex in allExercises) ex.name: ex.muscleGroup
    };

    Map<String, int> frequencyMap = {};
    for (var log in logs) {
      for (var loggedEx in log.exercises) {
        if (exerciseToGroupMap[loggedEx.exerciseName] == selectedGroup) {
          frequencyMap.update(loggedEx.exerciseName, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }
    }
    return frequencyMap;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChartTitleWithInfo(
          title: 'Frequência de Exercícios: $selectedGroup',
          infoText:
              'Este gráfico de barras mostra quantas vezes cada exercício do grupo muscular selecionado foi realizado, com base em todo o seu histórico de treinos.',
        ),
        Expanded(
          child: FutureBuilder<Map<String, int>>(
            future: _calculateFrequency(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('Nenhum treino encontrado para este grupo.'));
              }

              final frequencyMap = snapshot.data!;
              final List<_BarData> chartData = frequencyMap.entries
                  .map((e) => _BarData(e.key, e.value))
                  .toList()
                ..sort((a, b) => b.y.compareTo(a.y));

              return SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                primaryYAxis: NumericAxis(
                    minimum: 0, title: AxisTitle(text: 'Nº de Vezes Feito')),
                series: <CartesianSeries<_BarData, String>>[
                  BarSeries<_BarData, String>(
                    dataSource: chartData,
                    xValueMapper: (_BarData data, _) => data.x,
                    yValueMapper: (_BarData data, _) => data.y,
                    name: 'Frequência',
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
