// lib/student_ranking_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

class StudentRankingPage extends StatefulWidget {
  final UserModel user;
  final List<Aluno> students;
  final List<UserModel> teachers;

  const StudentRankingPage({
    super.key,
    required this.user,
    required this.students,
    required this.teachers,
  });

  @override
  State<StudentRankingPage> createState() => _StudentRankingPageState();
}

class _StudentRankingPageState extends State<StudentRankingPage> {
  bool _isLoading = true;
  String _filter = 'mes_atual';
  DateTime _mesSelecionado = DateTime.now();
  bool _showMonthPicker = false;
  List<DateTime> _mesesDisponiveis = [];

  // Top 3 com contagem
  List<_RankEntry> _top3 = [];
  // Posição do aluno logado
  int _myPosition = 0;
  int _myCount = 0;
  // Foto dos top3
  Map<String, String> _profileImages = {};

  // systemStartDate
  DateTime? _systemStartDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final academyId = widget.user.academyId;

      // systemStartDate
      final academyDoc =
          await firestore.collection('academies').doc(academyId).get();
      final aData = academyDoc.data();
      if (aData != null && aData['systemStartDate'] != null) {
        final ts = aData['systemStartDate'] as Timestamp;
        final d = ts.toDate();
        _systemStartDate = DateTime(d.year, d.month, d.day);
      }

      // Todos os participantes
      final allParticipants = [
        ...widget.students,
        ...widget.teachers.map((u) => Aluno.fromUserModel(u)).toList(),
      ];

      // Checkins aprovados
      final checkinsSnap = await firestore
          .collection('academies')
          .doc(academyId)
          .collection('checkins')
          .where('status',
              isEqualTo: checkinStatusToString(CheckinStatus.approved))
          .get();

      final rawCheckins = checkinsSnap.docs
          .map((d) => CheckinEntry.fromJson(d.id, d.data()))
          .toList();

      final allCheckins = _systemStartDate == null
          ? rawCheckins
          : rawCheckins
              .where((c) => !c.date.isBefore(_systemStartDate!))
              .toList();

      // Meses disponíveis
      final mesesSet = <String>{};
      for (var c in allCheckins) {
        mesesSet
            .add('${c.date.year}-${c.date.month.toString().padLeft(2, '0')}');
      }
      _mesesDisponiveis = mesesSet.map((s) {
        final p = s.split('-');
        return DateTime(int.parse(p[0]), int.parse(p[1]));
      }).toList()
        ..sort((a, b) => b.compareTo(a));

      // Contar por participante
      final now = DateTime.now();
      final Map<String, int> counts = {
        for (var p in allParticipants) p.id: 0,
      };

      for (var c in allCheckins) {
        bool count = false;
        switch (_filter) {
          case 'mes_atual':
            count = c.date.month == now.month && c.date.year == now.year;
            break;
          case 'ano':
            count = c.date.year == now.year;
            break;
          case 'total':
            count = true;
            break;
          default:
            count = c.date.month == _mesSelecionado.month &&
                c.date.year == _mesSelecionado.year;
        }
        if (count) {
          counts.update(c.studentId, (v) => v + 1, ifAbsent: () => 1);
        }
      }

      // Ordenar
      final ranked = allParticipants.toList()
        ..sort((a, b) {
          final ca = counts[a.id] ?? 0;
          final cb = counts[b.id] ?? 0;
          return cb != ca ? cb.compareTo(ca) : a.nome.compareTo(b.nome);
        });

      // Identificar o userId do aluno logado
      // O aluno pode estar como studentRecordId ou como uid
      final myStudentRecordId = widget.user.studentRecordId;
      final myUid = widget.user.uid;

      int myPos = 0;
      int myCount = 0;
      for (var i = 0; i < ranked.length; i++) {
        final p = ranked[i];
        if (p.id == myStudentRecordId || p.id == myUid || p.userId == myUid) {
          myPos = i + 1;
          myCount = counts[p.id] ?? 0;
          break;
        }
      }

      // Top 3
      final top3 = ranked
          .take(3)
          .map((a) => _RankEntry(
                aluno: a,
                count: counts[a.id] ?? 0,
              ))
          .toList();

      // Fotos do top 3
      final Map<String, String> photos = {};
      final top3Ids = top3
          .where((e) => e.aluno.userId != null && e.aluno.userId!.isNotEmpty)
          .map((e) => e.aluno.userId!)
          .toList();
      // Professores: id == uid
      final top3ProfIds = top3
          .where((e) => e.aluno.userId == null || e.aluno.userId!.isEmpty)
          .map((e) => e.aluno.id)
          .toList();
      final allIds = [...top3Ids, ...top3ProfIds];

      if (allIds.isNotEmpty) {
        final usersSnap = await firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: allIds.take(10).toList())
            .get();
        for (final doc in usersSnap.docs) {
          final data = doc.data();
          final path = (data['profileImagePath'] as String?)?.isNotEmpty == true
              ? data['profileImagePath'] as String
              : null;
          if (path != null) photos[doc.id] = path;
        }
        // Remapear aluno.id → foto
        for (final e in top3) {
          if (e.aluno.userId != null && photos.containsKey(e.aluno.userId)) {
            photos[e.aluno.id] = photos[e.aluno.userId]!;
          } else if (photos.containsKey(e.aluno.id)) {
            // professor: id == uid
          }
        }
      }

      if (mounted) {
        setState(() {
          _top3 = top3;
          _myPosition = myPos;
          _myCount = myCount;
          _profileImages = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showBjjSnackBar(context, 'Erro ao carregar ranking.', type: 'error');
      }
    }
  }

  String get _filterLabel {
    final now = DateTime.now();
    switch (_filter) {
      case 'mes_atual':
        return DateFormat('MMMM yyyy', 'pt_BR').format(now);
      case 'ano':
        return 'Ano ${now.year}';
      case 'total':
        return 'Histórico total';
      default:
        return DateFormat('MMMM yyyy', 'pt_BR').format(_mesSelecionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capitalizedFilter =
        _filterLabel[0].toUpperCase() + _filterLabel.substring(1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Ranking de Presença')),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Filtros ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mes_atual', label: Text('Mês')),
                    ButtonSegment(value: 'ano', label: Text('Ano')),
                    ButtonSegment(value: 'total', label: Text('Total')),
                  ],
                  selected: {
                    ['mes_atual', 'ano', 'total'].contains(_filter)
                        ? _filter
                        : 'mes_atual'
                  },
                  onSelectionChanged: (s) {
                    setState(() {
                      _filter = s.first;
                      _showMonthPicker = false;
                    });
                    _loadData();
                  },
                ),
              ),

              // ── Mês específico ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _showMonthPicker = !_showMonthPicker),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (!['mes_atual', 'ano', 'total'].contains(_filter))
                          ? primaryAccent.withOpacity(0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color:
                            (!['mes_atual', 'ano', 'total'].contains(_filter))
                                ? primaryAccent
                                : textHint.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 16, color: primaryAccent),
                        const SizedBox(width: 6),
                        Text(
                          (!['mes_atual', 'ano', 'total'].contains(_filter))
                              ? capitalizedFilter
                              : 'Mês específico',
                          style: TextStyle(
                            color: (!['mes_atual', 'ano', 'total']
                                    .contains(_filter))
                                ? primaryAccent
                                : textHint,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showMonthPicker
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: primaryAccent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_showMonthPicker && _mesesDisponiveis.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: darkSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: primaryAccent.withOpacity(0.3), width: 1),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _mesesDisponiveis.length,
                    itemBuilder: (ctx, i) {
                      final mes = _mesesDisponiveis[i];
                      final key =
                          'mes_${mes.year}-${mes.month.toString().padLeft(2, '0')}';
                      final isSelected = _filter == key;
                      final label =
                          DateFormat('MMMM yyyy', 'pt_BR').format(mes);
                      final cap = label[0].toUpperCase() + label.substring(1);
                      return ListTile(
                        dense: true,
                        title: Text(cap,
                            style: TextStyle(
                              color: isSelected ? primaryAccent : textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            )),
                        trailing: isSelected
                            ? const Icon(Icons.check,
                                color: primaryAccent, size: 16)
                            : null,
                        onTap: () {
                          setState(() {
                            _mesSelecionado = mes;
                            _filter = key;
                            _showMonthPicker = false;
                          });
                          _loadData();
                        },
                      );
                    },
                  ),
                ),

              // ── Conteúdo ───────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          // Período
                          Center(
                            child: Text(
                              capitalizedFilter,
                              style: const TextStyle(
                                  color: textHint, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Pódio ──────────────────────────
                          if (_top3.isNotEmpty) _buildPodium(),

                          const SizedBox(height: 16),

                          // ── Minha posição ──────────────────
                          _buildMyPosition(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium() {
    const podiumOrder = [1, 0, 2]; // visual: 2º, 1º, 3º
    const colors = [primaryAccent, Color(0xFFC0C0C0), Color(0xFFCD7F32)];
    const heights = [90.0, 65.0, 50.0];
    const emojis = ['🥇', '🥈', '🥉'];
    const sizes = [52.0, 44.0, 40.0];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        child: Column(
          children: [
            const Text('Pódio',
                style: TextStyle(
                    color: primaryAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: podiumOrder.map((i) {
                if (i >= _top3.length) return const Expanded(child: SizedBox());
                final entry = _top3[i];
                final color = colors[i];
                final avatarSize = sizes[i];
                final photoUrl = _profileImages[entry.aluno.id] ??
                    _profileImages[entry.aluno.userId ?? ''];
                final firstName = entry.aluno.nome.split(' ').first;

                return Expanded(
                  child: Column(
                    children: [
                      Text(emojis[i], style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: avatarSize / 2,
                        backgroundColor: color.withOpacity(0.2),
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                                entry.aluno.nome.isNotEmpty
                                    ? entry.aluno.nome[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: avatarSize * 0.4),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        firstName,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: i == 0 ? 14 : 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.count} ${entry.count == 1 ? 'treino' : 'treinos'}',
                        style: const TextStyle(color: textHint, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: heights[i],
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          border: Border(
                            top: BorderSide(color: color, width: 2),
                            left: BorderSide(
                                color: color.withOpacity(0.3), width: 1),
                            right: BorderSide(
                                color: color.withOpacity(0.3), width: 1),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}°',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: i == 0 ? 22 : 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyPosition() {
    if (_myPosition == 0) return const SizedBox.shrink();

    final isInTop3 = _myPosition <= 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SUA POSIÇÃO',
                style: TextStyle(
                    color: primaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
            const Divider(height: 14, thickness: 0.5),
            Row(
              children: [
                // Medalha ou número
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isInTop3
                        ? primaryAccent.withOpacity(0.15)
                        : darkSurface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          isInTop3 ? primaryAccent : textHint.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isInTop3
                          ? ['🥇', '🥈', '🥉'][_myPosition - 1]
                          : '$_myPosition°',
                      style: TextStyle(
                        fontSize: isInTop3 ? 22 : 16,
                        fontWeight: FontWeight.bold,
                        color: isInTop3 ? primaryAccent : textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.name,
                        style: const TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$_myCount ${_myCount == 1 ? 'treino' : 'treinos'} no período',
                        style: const TextStyle(color: textHint, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Indicador se está no top 3
                if (isInTop3)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: successColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: successColor.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Top 3!',
                      style: TextStyle(
                          color: successColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            if (!isInTop3) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _top3.isNotEmpty && _top3.first.count > 0
                    ? (_myCount / _top3.first.count).clamp(0.0, 1.0)
                    : 0,
                backgroundColor: textHint.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(primaryAccent),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 4),
              Text(
                _top3.isNotEmpty && _top3.first.count > 0
                    ? 'Faltam ${_top3.first.count - _myCount} treino(s) para chegar ao 1° lugar'
                    : '',
                style: const TextStyle(color: textHint, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RankEntry {
  final Aluno aluno;
  final int count;
  const _RankEntry({required this.aluno, required this.count});
}
