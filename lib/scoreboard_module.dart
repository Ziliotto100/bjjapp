// lib/scoreboard_module.dart
// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'dart:async';
import 'package:flutter/material.dart';

import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart'; // Import necessário para showBjjSnackBar e EmptyStateWidget

class MatchSetupPage extends StatefulWidget {
  final String academyId;
  final List<Aluno> todosAlunosDaAcademia;
  final UserModel user;
  // O plano da academia é recebido para verificar a permissão
  final SubscriptionPlan? currentPlan;

  const MatchSetupPage({
    super.key,
    required this.academyId,
    required this.todosAlunosDaAcademia,
    required this.user,
    this.currentPlan, // Adicionado ao construtor
  });

  @override
  State<MatchSetupPage> createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage> {
  final _formKey = GlobalKey<FormState>();
  Aluno? _athlete1;
  Aluno? _athlete2;
  String _kimonoColor1 = 'Branco';
  String _kimonoColor2 = 'Azul';
  int _matchTimeInMinutes = 5;

  final List<String> _kimonoColors = ['Branco', 'Azul', 'Preto'];
  final List<int> _matchTimes = List.generate(10, (index) => index + 1);

  void _startMatch() {
    if (_athlete1?.id == _athlete2?.id && _athlete1 != null) {
      showBjjSnackBar(context, 'Os atletas não podem ser os mesmos.',
          type: 'error');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final settings = MatchSettings(
      athlete1: _athlete1!,
      athlete2: _athlete2!,
      kimonoColor1: _kimonoColor1,
      kimonoColor2: _kimonoColor2,
      matchDuration: Duration(minutes: _matchTimeInMinutes),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScoreboardPage(settings: settings),
      ),
    );
  }

  Future<void> _selectAthlete(int playerNumber) async {
    final List<Aluno> availableAthletes =
        List.from(widget.todosAlunosDaAcademia);
    if (playerNumber == 1 && _athlete2 != null) {
      availableAthletes.removeWhere((a) => a.id == _athlete2!.id);
    } else if (playerNumber == 2 && _athlete1 != null) {
      availableAthletes.removeWhere((a) => a.id == _athlete1!.id);
    }

    final Aluno? selectedAthlete = await showDialog<Aluno>(
      context: context,
      builder: (context) => _AthleteSelectionDialog(
        athletes: availableAthletes,
        title: "Selecione o Atleta $playerNumber",
      ),
    );

    if (selectedAthlete != null) {
      setState(() {
        if (playerNumber == 1) {
          _athlete1 = selectedAthlete;
        } else {
          _athlete2 = selectedAthlete;
        }
        _formKey.currentState?.validate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- LÓGICA DE PERMISSÃO CENTRALIZADA AQUI ---
    final bool hasAccess =
        widget.currentPlan?.features['scoreboard_module'] ?? false;

    if (!hasAccess) {
      // Se o plano não dá acesso, mostra a tela de "Recurso Premium".
      return const AppBackground(
        child: SafeArea(
          child: EmptyStateWidget(
            icon: Icons.scoreboard_outlined,
            title: 'Recurso Premium',
            message:
                'O Placar é um recurso exclusivo. Peça ao gerente da sua academia para saber mais sobre os planos de assinatura.',
          ),
        ),
      );
    }

    // Se o acesso for permitido, constrói a tela normal.
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Atleta 1",
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            _buildAthleteSelector(
                              context: context,
                              athlete: _athlete1,
                              onTap: () => _selectAthlete(1),
                              validator: (value) {
                                if (_athlete1 == null)
                                  return 'Selecione o atleta 1';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _kimonoColor1,
                              decoration: const InputDecoration(
                                  labelText: 'Cor do Kimono'),
                              items: _kimonoColors
                                  .map((color) => DropdownMenuItem<String>(
                                      value: color, child: Text(color)))
                                  .toList(),
                              onChanged: (color) =>
                                  setState(() => _kimonoColor1 = color!),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Atleta 2",
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            _buildAthleteSelector(
                              context: context,
                              athlete: _athlete2,
                              onTap: () => _selectAthlete(2),
                              validator: (value) {
                                if (_athlete2 == null)
                                  return 'Selecione o atleta 2';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _kimonoColor2,
                              decoration: const InputDecoration(
                                  labelText: 'Cor do Kimono'),
                              items: _kimonoColors
                                  .map((color) => DropdownMenuItem<String>(
                                      value: color, child: Text(color)))
                                  .toList(),
                              onChanged: (color) =>
                                  setState(() => _kimonoColor2 = color!),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: DropdownButtonFormField<int>(
                          value: _matchTimeInMinutes,
                          decoration:
                              const InputDecoration(labelText: 'Tempo de Luta'),
                          items: _matchTimes
                              .map((time) => DropdownMenuItem<int>(
                                  value: time, child: Text('$time minutos')))
                              .toList(),
                          onChanged: (time) =>
                              setState(() => _matchTimeInMinutes = time!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('INICIAR LUTA'),
              onPressed: _startMatch,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildAthleteSelector({
  required BuildContext context,
  required Aluno? athlete,
  required VoidCallback onTap,
  required FormFieldValidator<Aluno?> validator,
}) {
  return FormField<Aluno?>(
    initialValue: athlete,
    validator: validator,
    builder: (field) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: athlete == null
                    ? 'Clique para selecionar'
                    : 'Atleta Selecionado',
                errorText: field.errorText,
              ),
              child: athlete == null
                  ? const SizedBox(height: 16)
                  : Text(
                      athlete.nome,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ),
          ),
        ],
      );
    },
  );
}

class _AthleteSelectionDialog extends StatefulWidget {
  final List<Aluno> athletes;
  final String title;

  const _AthleteSelectionDialog({required this.athletes, required this.title});

  @override
  State<_AthleteSelectionDialog> createState() =>
      __AthleteSelectionDialogState();
}

class __AthleteSelectionDialogState extends State<_AthleteSelectionDialog> {
  final _searchController = TextEditingController();
  List<Aluno> _filteredAthletes = [];

  @override
  void initState() {
    super.initState();
    _filteredAthletes = widget.athletes;
    _searchController.addListener(_filterAthletes);
  }

  void _filterAthletes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAthletes = widget.athletes.where((athlete) {
        return athlete.nome.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Buscar por nome...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredAthletes.isEmpty
                  ? const Center(child: Text("Nenhum atleta encontrado."))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredAthletes.length,
                      itemBuilder: (context, index) {
                        final athlete = _filteredAthletes[index];
                        return ListTile(
                          title: Text(athlete.nome),
                          onTap: () {
                            Navigator.of(context).pop(athlete);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _PlayerScore {
  int totalScore = 0;
  int advantages = 0;
  int penalties = 0;
  int takedowns = 0;
  int passes = 0;
  int mountsOrBack = 0;

  void reset() {
    totalScore = 0;
    advantages = 0;
    penalties = 0;
    takedowns = 0;
    passes = 0;
    mountsOrBack = 0;
  }
}

class ScoreboardPage extends StatefulWidget {
  final MatchSettings settings;

  const ScoreboardPage({
    super.key,
    required this.settings,
  });

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  final _player1Score = _PlayerScore();
  final _player2Score = _PlayerScore();

  Timer? _timer;
  late Duration _timeRemaining;
  bool _isRunning = false;
  bool _isMatchOver = false;

  @override
  void initState() {
    super.initState();
    _timeRemaining = widget.settings.matchDuration;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerString {
    final minutes = _timeRemaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (_timeRemaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _toggleTimer() {
    if (_isMatchOver) return;

    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_timer?.isActive ?? false) return;
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_timeRemaining.inSeconds > 0) {
          _timeRemaining -= const Duration(seconds: 1);
        } else {
          _pauseTimer();
          _handleEndOfMatch(reason: "por tempo");
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _restartMatch() {
    _pauseTimer();
    setState(() {
      _timeRemaining = widget.settings.matchDuration;
      _isMatchOver = false;
      _player1Score.reset();
      _player2Score.reset();
    });
  }

  void _updateScore(
      int playerIndex, int points, Function(int) updateCounter, int increment) {
    if (_isMatchOver) return;

    final score = playerIndex == 1 ? _player1Score : _player2Score;

    if (increment < 0) {
      if ((points == 2 && score.takedowns == 0) ||
          (points == 3 && score.passes == 0) ||
          (points == 4 && score.mountsOrBack == 0)) {
        return;
      }
    }

    setState(() {
      score.totalScore += (points * increment);
      updateCounter(increment);
    });
  }

  void _updateAdvantages(int playerIndex, int increment) {
    if (_isMatchOver) return;

    final score = playerIndex == 1 ? _player1Score : _player2Score;
    if (increment < 0 && score.advantages == 0) return;

    setState(() {
      score.advantages += increment;
    });
  }

  void _handlePenaltyUpdate(int playerIndex, int increment) {
    if (_isMatchOver) return;

    final punishedScore = playerIndex == 1 ? _player1Score : _player2Score;
    final opponentScore = playerIndex == 1 ? _player2Score : _player1Score;

    if (increment < 0 && punishedScore.penalties == 0) return;

    setState(() {
      final oldPenaltyCount = punishedScore.penalties;
      punishedScore.penalties += increment;
      final newPenaltyCount = punishedScore.penalties;

      if (increment > 0) {
        if (newPenaltyCount == 2) opponentScore.advantages += 1;
        if (newPenaltyCount == 3) opponentScore.totalScore += 2;
        if (newPenaltyCount >= 4) {
          final winner = playerIndex == 1
              ? widget.settings.athlete2
              : widget.settings.athlete1;
          _handleEndOfMatch(reason: "por desclassificação", winner: winner);
        }
      } else {
        if (oldPenaltyCount == 2) opponentScore.advantages -= 1;
        if (oldPenaltyCount == 3) opponentScore.totalScore -= 2;
      }
    });
  }

  void _handleEndOfMatch({String reason = "", Aluno? winner}) {
    _pauseTimer();
    setState(() => _isMatchOver = true);

    String resultMessage;
    if (winner != null) {
      resultMessage = "${winner.nome} venceu $reason!";
    } else {
      if (_player1Score.totalScore > _player2Score.totalScore) {
        resultMessage = "${widget.settings.athlete1.nome} venceu por pontos!";
      } else if (_player2Score.totalScore > _player1Score.totalScore) {
        resultMessage = "${widget.settings.athlete2.nome} venceu por pontos!";
      } else {
        if (_player1Score.advantages > _player2Score.advantages) {
          resultMessage =
              "${widget.settings.athlete1.nome} venceu por vantagens!";
        } else if (_player2Score.advantages > _player1Score.advantages) {
          resultMessage =
              "${widget.settings.athlete2.nome} venceu por vantagens!";
        } else {
          if (_player1Score.penalties < _player2Score.penalties) {
            resultMessage =
                "${widget.settings.athlete1.nome} venceu por menos punições!";
          } else if (_player2Score.penalties < _player1Score.penalties) {
            resultMessage =
                "${widget.settings.athlete2.nome} venceu por menos punições!";
          } else {
            resultMessage = "A luta terminou em EMPATE!";
          }
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Fim de Luta!"),
        content: Text(resultMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Placar da Luta"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: darkScaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                _buildPlayerHeader(
                  athlete: widget.settings.athlete1,
                  score: _player1Score,
                  color: widget.settings.colorForAthlete1,
                  isPlayer2: false,
                ),
                _buildPlayerHeader(
                  athlete: widget.settings.athlete2,
                  score: _player2Score,
                  color: widget.settings.colorForAthlete2,
                  isPlayer2: true,
                ),
              ],
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 50,
                    color: errorColor,
                    icon: const Icon(Icons.restart_alt_rounded),
                    onPressed: _restartMatch,
                  ),
                  Text(
                    _timerString,
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: _isMatchOver ? textHint : textPrimary,
                      shadows: const [
                        Shadow(
                          blurRadius: 4.0,
                          color: Colors.black54,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    iconSize: 50,
                    color: _isRunning ? warningColor : successColor,
                    icon: Icon(_isRunning
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded),
                    onPressed: _isMatchOver ? null : _toggleTimer,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(top: 8.0),
                color: darkSurface.withOpacity(0.7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScoreControl(
                      playerIndex: 1,
                      score: _player1Score,
                    ),
                    const VerticalDivider(
                        color: borderNormal, thickness: 1, width: 1),
                    _buildScoreControl(
                      playerIndex: 2,
                      score: _player2Score,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHeader({
    required Aluno athlete,
    required _PlayerScore score,
    required Color color,
    required bool isPlayer2,
  }) {
    bool useGradient = isPlayer2 &&
        widget.settings.kimonoColor1 == widget.settings.kimonoColor2;
    final displayColor = (color == Colors.grey.shade800) ? Colors.white : color;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderNormal, width: 2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: useGradient ? primaryAccent : color, width: 2),
                gradient: useGradient
                    ? LinearGradient(
                        colors: [primaryAccent, Colors.yellow.shade800])
                    : null,
              ),
              child: Text(
                athlete.nome.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: useGradient ? primaryAccentForeground : displayColor,
                  shadows: const [
                    Shadow(
                      blurRadius: 2.0,
                      color: Colors.black87,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${score.totalScore}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: displayColor,
                height: 1,
                shadows: const [
                  Shadow(
                    blurRadius: 4.0,
                    color: Colors.black,
                    offset: Offset(2.0, 2.0),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text("V: ${score.advantages}",
                    style: const TextStyle(
                        fontSize: 18,
                        color: textSecondary,
                        fontWeight: FontWeight.bold)),
                Text("P: ${score.penalties}",
                    style: const TextStyle(
                        fontSize: 18,
                        color: textSecondary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreControl(
      {required int playerIndex, required _PlayerScore score}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildScoreButton(
              label: 'Montada / Costas',
              pointsLabel: '(+4 pontos)',
              count: score.mountsOrBack,
              onAdd: () => _updateScore(
                  playerIndex, 4, (inc) => score.mountsOrBack += inc, 1),
              onRemove: () => _updateScore(
                  playerIndex, 4, (inc) => score.mountsOrBack += inc, -1),
            ),
            _buildScoreButton(
              label: 'Passagem',
              pointsLabel: '(+3 pontos)',
              count: score.passes,
              onAdd: () =>
                  _updateScore(playerIndex, 3, (inc) => score.passes += inc, 1),
              onRemove: () => _updateScore(
                  playerIndex, 3, (inc) => score.passes += inc, -1),
            ),
            _buildScoreButton(
              label: 'Queda / Raspagem',
              pointsLabel: '(+2 pontos)',
              count: score.takedowns,
              onAdd: () => _updateScore(
                  playerIndex, 2, (inc) => score.takedowns += inc, 1),
              onRemove: () => _updateScore(
                  playerIndex, 2, (inc) => score.takedowns += inc, -1),
            ),
            _buildScoreButton(
              label: 'Vantagens',
              pointsLabel: '(+1 Vant.)',
              count: score.advantages,
              onAdd: () => _updateAdvantages(playerIndex, 1),
              onRemove: () => _updateAdvantages(playerIndex, -1),
            ),
            _buildScoreButton(
              label: 'Punições',
              pointsLabel: '(+1 Puni.)',
              count: score.penalties,
              onAdd: () => _handlePenaltyUpdate(playerIndex, 1),
              onRemove: () => _handlePenaltyUpdate(playerIndex, -1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreButton({
    required String label,
    required String pointsLabel,
    required int count,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    return FittedBox(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _isMatchOver ? null : onRemove,
            color: textHint,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(
            width: 160,
            child: Column(
              children: [
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                Text('$count',
                    style: const TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text(pointsLabel,
                    style: const TextStyle(color: textHint, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _isMatchOver ? null : onAdd,
            color: textHint,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
