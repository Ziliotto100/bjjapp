// lib/rules_module.dart
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'models.dart';

// --- Estrutura de Dados para as Tabelas de Peso ---
class WeightCategory {
  final String name;
  final String maxWeight;
  WeightCategory({required this.name, required this.maxWeight});
}

class AgeDivision {
  final String title;
  final List<WeightCategory> categories;
  AgeDivision({required this.title, required this.categories});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgeDivision &&
          runtimeType == other.runtimeType &&
          title == other.title;

  @override
  int get hashCode => title.hashCode;
}

// --- Estrutura de Dados para os Golpes Proibidos ---
class IllegalMove {
  final int number;
  final String name;
  final String imagePath;

  IllegalMove({
    required this.number,
    required this.name,
    required this.imagePath,
  });
}

class IllegalMoveCategory {
  final String title;
  final String ageGroup;
  final List<IllegalMove> moves;

  IllegalMoveCategory({
    required this.title,
    required this.ageGroup,
    required this.moves,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IllegalMoveCategory &&
          runtimeType == other.runtimeType &&
          title == other.title;

  @override
  int get hashCode => title.hashCode;
}

// --- Estrutura de Dados para Pontuação ---
class ScoreItem {
  final String points;
  final String description;
  final IconData icon;
  ScoreItem(
      {required this.points, required this.description, required this.icon});
}

// --- Estrutura de Dados para Tempo de Luta (MODIFICADA) ---
class MatchTime {
  final String category;
  final String? age; // NOVO CAMPO OPCIONAL
  final String belt;
  final String duration;
  MatchTime(
      {required this.category,
      this.age,
      required this.belt,
      required this.duration});
}

// --- Tela Principal do Módulo ---
class RulesPage extends StatefulWidget {
  final UserModel user;
  const RulesPage({super.key, required this.user});

  @override
  State<RulesPage> createState() => _RulesPageState();
}

class _RulesPageState extends State<RulesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: darkSurface,
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            tabs: const [
              Tab(icon: Icon(Icons.scale_rounded), text: 'Peso'),
              Tab(icon: Icon(Icons.scoreboard_rounded), text: 'Pontuação'),
              Tab(icon: Icon(Icons.timer_outlined), text: 'Tempo'),
              Tab(icon: Icon(Icons.block_flipped), text: 'Proibidos'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              WeightCategoriesTab(),
              ScoringTab(),
              MatchTimeTab(),
              IllegalMovesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// --- WIDGET DA ABA DE CATEGORIAS DE PESO ---
class WeightCategoriesTab extends StatefulWidget {
  const WeightCategoriesTab({super.key});

  @override
  State<WeightCategoriesTab> createState() => _WeightCategoriesTabState();
}

class _WeightCategoriesTabState extends State<WeightCategoriesTab> {
  AgeDivision? _selectedDivision;

  static final List<AgeDivision> weightDivisions = [
    AgeDivision(title: "Adulto e Masters - Masculino", categories: [
      WeightCategory(name: 'Galo', maxWeight: '57,50 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '64,00 kg'),
      WeightCategory(name: 'Pena', maxWeight: '70,00 kg'),
      WeightCategory(name: 'Leve', maxWeight: '76,00 kg'),
      WeightCategory(name: 'Médio', maxWeight: '82,30 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '88,30 kg'),
      WeightCategory(name: 'Pesado', maxWeight: '94,30 kg'),
      WeightCategory(name: 'Super-Pesado', maxWeight: '100,50 kg'),
      WeightCategory(name: 'Pesadíssimo', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Adulto e Masters - Feminino", categories: [
      WeightCategory(name: 'Galo', maxWeight: '48,50 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '53,50 kg'),
      WeightCategory(name: 'Pena', maxWeight: '58,50 kg'),
      WeightCategory(name: 'Leve', maxWeight: '64,00 kg'),
      WeightCategory(name: 'Médio', maxWeight: '69,00 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '74,00 kg'),
      WeightCategory(name: 'Pesado', maxWeight: '79,30 kg'),
      WeightCategory(name: 'Super-Pesado', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Juvenil (16 e 17 anos) - Masculino", categories: [
      WeightCategory(name: 'Galo', maxWeight: '53,50 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '58,50 kg'),
      WeightCategory(name: 'Pena', maxWeight: '64,00 kg'),
      WeightCategory(name: 'Leve', maxWeight: '69,00 kg'),
      WeightCategory(name: 'Médio', maxWeight: '74,00 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '79,30 kg'),
      WeightCategory(name: 'Pesado', maxWeight: '84,30 kg'),
      WeightCategory(name: 'Super-Pesado', maxWeight: '89,30 kg'),
      WeightCategory(name: 'Pesadíssimo', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Juvenil (16 e 17 anos) - Feminino", categories: [
      WeightCategory(name: 'Galo', maxWeight: '44,30 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '48,30 kg'),
      WeightCategory(name: 'Pena', maxWeight: '52,50 kg'),
      WeightCategory(name: 'Leve', maxWeight: '56,50 kg'),
      WeightCategory(name: 'Médio', maxWeight: '60,50 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '65,00 kg'),
      WeightCategory(name: 'Pesado', maxWeight: '69,00 kg'),
      WeightCategory(name: 'Super-Pesado', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Infanto-Juvenil (12 a 15 anos)", categories: [
      WeightCategory(name: 'Galo', maxWeight: '42,5 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '46,5 kg'),
      WeightCategory(name: 'Pena', maxWeight: '50,5 kg'),
      WeightCategory(name: 'Leve', maxWeight: '54,5 kg'),
      WeightCategory(name: 'Médio', maxWeight: '58,5 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '63,0 kg'),
      WeightCategory(name: 'Pesado', maxWeight: '67,0 kg'),
      WeightCategory(name: 'Super-Pesado', maxWeight: '71,0 kg'),
      WeightCategory(name: 'Pesadíssimo', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Infantil B (10 e 11 anos)", categories: [
      WeightCategory(name: 'Galo', maxWeight: '34,5 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '37,5 kg'),
      WeightCategory(name: 'Pena', maxWeight: '40,5 kg'),
      WeightCategory(name: 'Leve', maxWeight: '43,5 kg'),
      WeightCategory(name: 'Médio', maxWeight: '46,5 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '49,5 kg'),
      WeightCategory(name: 'Pesado', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Infantil A (8 e 9 anos)", categories: [
      WeightCategory(name: 'Galo', maxWeight: '28,5 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '31,5 kg'),
      WeightCategory(name: 'Pena', maxWeight: '34,5 kg'),
      WeightCategory(name: 'Leve', maxWeight: '37,5 kg'),
      WeightCategory(name: 'Médio', maxWeight: '40,5 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '43,5 kg'),
      WeightCategory(name: 'Pesado', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Mirim (6 e 7 anos)", categories: [
      WeightCategory(name: 'Galo', maxWeight: '22,5 kg'),
      WeightCategory(name: 'Pluma', maxWeight: '25,5 kg'),
      WeightCategory(name: 'Pena', maxWeight: '28,5 kg'),
      WeightCategory(name: 'Leve', maxWeight: '31,5 kg'),
      WeightCategory(name: 'Médio', maxWeight: '34,5 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '37,5 kg'),
      WeightCategory(name: 'Pesado', maxWeight: 'Sem limite'),
    ]),
    AgeDivision(title: "Pré-Mirim (4 e 5 anos)", categories: [
      WeightCategory(name: 'Pluma', maxWeight: '18,0 kg'),
      WeightCategory(name: 'Pena', maxWeight: '21,0 kg'),
      WeightCategory(name: 'Leve', maxWeight: '24,0 kg'),
      WeightCategory(name: 'Médio', maxWeight: '27,0 kg'),
      WeightCategory(name: 'Meio-Pesado', maxWeight: '30,0 kg'),
      WeightCategory(name: 'Pesado', maxWeight: 'Sem limite'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final divisionsToShow =
        _selectedDivision == null ? weightDivisions : [_selectedDivision!];

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        DropdownButtonFormField<AgeDivision>(
          value: _selectedDivision,
          hint: const Text('Filtrar por divisão de idade/gênero...'),
          isExpanded: true,
          items: weightDivisions.map((division) {
            return DropdownMenuItem(
              value: division,
              child: Text(division.title, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedDivision = newValue;
            });
          },
        ),
        if (_selectedDivision != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _selectedDivision = null),
              child: const Text('Mostrar Todas'),
            ),
          ),
        const SizedBox(height: 8),
        ...divisionsToShow
            .map((division) => _buildWeightTable(context, division)),
      ],
    );
  }

  Widget _buildWeightTable(BuildContext context, AgeDivision division) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(division.title, style: Theme.of(context).textTheme.titleLarge),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Atenção: A pesagem é realizada com o kimono vestido.',
                style: TextStyle(color: textHint, fontSize: 12),
              ),
            ),
            const Divider(height: 10),
            ...division.categories.map((cat) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(cat.name,
                          style: Theme.of(context).textTheme.bodyLarge),
                      Text(cat.maxWeight,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// --- ABA DE PONTUAÇÃO E PUNIÇÕES ---
class ScoringTab extends StatelessWidget {
  const ScoringTab({super.key});

  static final List<ScoreItem> scores = [
    ScoreItem(
        points: '4',
        description: 'Montada ou Pegada pelas Costas',
        icon: Icons.person_pin_circle_rounded),
    ScoreItem(
        points: '3',
        description: 'Passagem de Guarda',
        icon: Icons.double_arrow_rounded),
    ScoreItem(
        points: '2',
        description: 'Queda ou Raspagem',
        icon: Icons.swap_vert_circle_rounded),
    ScoreItem(
        points: '2',
        description: 'Joelho na Barriga',
        icon: Icons.airline_seat_legroom_reduced_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildScoringCard(context),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Vantagens',
          icon: Icons.star_half_rounded,
          color: infoColor,
          content:
              'Concedida em uma "quase pontuação" ou tentativa de finalização defendida. É o primeiro critério de desempate.',
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Punições',
          icon: Icons.gavel_rounded,
          color: warningColor,
          content:
              'Aplicadas por falta de combatividade ou faltas. Após a 3ª punição, o atleta é desclassificado. Punições também servem como critério de desempate.',
        ),
      ],
    );
  }

  Widget _buildScoringCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pontuação Oficial',
                style: Theme.of(context).textTheme.titleLarge),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'A posição deve ser mantida por 3 segundos para validar os pontos.',
                style: TextStyle(color: textHint, fontSize: 12),
              ),
            ),
            const Divider(height: 10),
            ...scores.map((item) => ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: primaryAccent,
                    child: Text(
                      item.points,
                      style: const TextStyle(
                        color: primaryAccentForeground,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  title: Text(item.description),
                )),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET REUTILIZÁVEL PARA CARDS DE INFORMAÇÃO ---
class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String content;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 20),
            Text(
              content,
              style: const TextStyle(height: 1.5, color: textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ABA DE TEMPO DE LUTA (COM MELHORIAS VISUAIS) ---
class MatchTimeTab extends StatelessWidget {
  const MatchTimeTab({super.key});

  // ALTERAÇÃO: Dados atualizados com as idades
  static final List<MatchTime> matchTimes = [
    MatchTime(category: 'Adulto', belt: 'Branca', duration: '5 min'),
    MatchTime(category: 'Adulto', belt: 'Azul', duration: '6 min'),
    MatchTime(category: 'Adulto', belt: 'Roxa', duration: '7 min'),
    MatchTime(category: 'Adulto', belt: 'Marrom', duration: '8 min'),
    MatchTime(category: 'Adulto', belt: 'Preta', duration: '10 min'),
    MatchTime(
        category: 'Juvenil',
        age: '16 e 17 anos',
        belt: 'Todas',
        duration: '5 min'),
    MatchTime(
        category: 'Infanto-Juvenil',
        age: '13 a 15 anos',
        belt: 'Todas',
        duration: '4 min'),
    MatchTime(
        category: 'Infantil',
        age: '10 a 12 anos',
        belt: 'Todas',
        duration: '4 min'),
    MatchTime(
        category: 'Mirim', age: '7 a 9 anos', belt: 'Todas', duration: '3 min'),
    MatchTime(
        category: 'Pré-Mirim',
        age: '4 a 6 anos',
        belt: 'Todas',
        duration: '2 min'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tempo de Luta Oficial',
                    style: Theme.of(context).textTheme.titleLarge),
                const Divider(height: 16),
                Center(
                  child: DataTable(
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Categoria')),
                      DataColumn(label: Text('Faixa')),
                      DataColumn(label: Text('Duração')),
                    ],
                    rows: matchTimes
                        .map((mt) => DataRow(cells: [
                              DataCell(
                                // ALTERAÇÃO: Categoria e idade em uma coluna
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(mt.category),
                                    if (mt.age != null)
                                      Text(
                                        mt.age!,
                                        style: const TextStyle(
                                            fontSize: 12, color: textHint),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(Text(mt.belt)),
                              DataCell(Text(mt.duration,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                            ]))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- ABA DE GOLPES PROIBIDOS ---
class IllegalMovesTab extends StatefulWidget {
  const IllegalMovesTab({super.key});

  @override
  State<IllegalMovesTab> createState() => _IllegalMovesTabState();
}

class _IllegalMovesTabState extends State<IllegalMovesTab> {
  IllegalMoveCategory? _selectedCategory;

  static final List<IllegalMove> allIllegalMoves = [
    IllegalMove(
        number: 1,
        name: 'Posição de finalização forçando a abertura da virilha',
        imagePath: 'assets/images/golpes_proibidos/golpe1.png'),
    IllegalMove(
        number: 2,
        name: 'Estrangulamento que force a cervical',
        imagePath: 'assets/images/golpes_proibidos/golpe2.png'),
    IllegalMove(
        number: 3,
        name: 'Chave de pé reta',
        imagePath: 'assets/images/golpes_proibidos/golpe3.png'),
    IllegalMove(
        number: 4,
        name: 'Estrangulamento utilizando a manga do kimono (Ezequiel)',
        imagePath: 'assets/images/golpes_proibidos/golpe4.png'),
    IllegalMove(
        number: 5,
        name: 'Gravata técnica de frente',
        imagePath: 'assets/images/golpes_proibidos/golpe5.png'),
    IllegalMove(
        number: 6,
        name: 'Omoplata',
        imagePath: 'assets/images/golpes_proibidos/golpe6.png'),
    IllegalMove(
        number: 7,
        name: 'Triângulo (puxando a cabeça)',
        imagePath: 'assets/images/golpes_proibidos/golpe7.png'),
    IllegalMove(
        number: 8,
        name: 'Triângulo de mão',
        imagePath: 'assets/images/golpes_proibidos/golpe8.png'),
    IllegalMove(
        number: 9,
        name:
            'Chave que pressione as costelas ou os rins dentro da guarda fechada',
        imagePath: 'assets/images/golpes_proibidos/golpe9.png'),
    IllegalMove(
        number: 10,
        name: 'Mão de Vaca',
        imagePath: 'assets/images/golpes_proibidos/golpe10.png'),
    IllegalMove(
        number: 11,
        name: 'Single leg com a cabeça para fora (**)',
        imagePath: 'assets/images/golpes_proibidos/golpe11.png'),
    IllegalMove(
        number: 12,
        name: 'Chave de bíceps',
        imagePath: 'assets/images/golpes_proibidos/golpe12.png'),
    IllegalMove(
        number: 13,
        name: 'Chave de panturrilha',
        imagePath: 'assets/images/golpes_proibidos/golpe13.png'),
    IllegalMove(
        number: 14,
        name: 'Leg lock (chave de joelho reta)',
        imagePath: 'assets/images/golpes_proibidos/golpe14.png'),
    IllegalMove(
        number: 15,
        name: 'Mata-leão no pé',
        imagePath: 'assets/images/golpes_proibidos/golpe15.png'),
    IllegalMove(
        number: 16,
        name:
            'Na chave de pé reta, girar na direção do pé que não está sendo atacado',
        imagePath: 'assets/images/golpes_proibidos/golpe16.png'),
    IllegalMove(
        number: 17,
        name: 'Chave de calcanhar',
        imagePath: 'assets/images/golpes_proibidos/golpe17.png'),
    IllegalMove(
        number: 18,
        name: 'Chave que torça o joelho',
        imagePath: 'assets/images/golpes_proibidos/golpe18.png'),
    IllegalMove(
        number: 19,
        name: 'Cruzada de perna (ver detalhes ao lado)',
        imagePath: 'assets/images/golpes_proibidos/golpe19.png'),
    IllegalMove(
        number: 20,
        name: 'No mata-leão no pé, aplicar a pressão para o lado externo do pé',
        imagePath: 'assets/images/golpes_proibidos/golpe20.png'),
    IllegalMove(
        number: 21,
        name: 'Bate estaca',
        imagePath: 'assets/images/golpes_proibidos/golpe21.png'),
    IllegalMove(
        number: 22,
        name: 'Chave de cervical',
        imagePath: 'assets/images/golpes_proibidos/golpe22.png'),
    IllegalMove(
        number: 23,
        name: 'Queda-tesoura',
        imagePath: 'assets/images/golpes_proibidos/golpe23.png'),
    IllegalMove(
        number: 24,
        name: 'Torcer os dedos para trás',
        imagePath: 'assets/images/golpes_proibidos/golpe24.png'),
    IllegalMove(
        number: 25,
        name:
            'Segurar na faixa do adversário e projetá-lo de cabeça ao solo enquanto se defende de um Single Leg com a cabeça para fora',
        imagePath: 'assets/images/golpes_proibidos/golpe25.png'),
    IllegalMove(
        number: 26,
        name: 'Suplex derrubando o adversário de cabeça ou pescoço ao solo',
        imagePath: 'assets/images/golpes_proibidos/golpe26.png'),
  ];

  static final List<IllegalMoveCategory> illegalMovesData = [
    IllegalMoveCategory(
      title: '4 a 12 anos',
      ageGroup: '',
      moves: allIllegalMoves
          .where((m) => [
                1,
                2,
                3,
                4,
                5,
                6,
                7,
                8,
                9,
                10,
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
                19,
                20,
                21,
                22,
                23,
                24,
                25,
                26
              ].contains(m.number))
          .toList(),
    ),
    IllegalMoveCategory(
      title: '13 a 15 anos',
      ageGroup: '',
      moves: allIllegalMoves
          .where((m) => [
                2,
                3,
                4,
                5,
                6,
                7,
                8,
                9,
                10,
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
                19,
                20,
                21,
                22,
                23,
                24,
                25,
                26
              ].contains(m.number))
          .toList(),
    ),
    IllegalMoveCategory(
      title: '16 e 17 (Todas as faixas) e Faixa Branca (Adulto a Master)',
      ageGroup: '',
      moves: allIllegalMoves
          .where((m) => [
                10,
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
                19,
                20,
                21,
                22,
                23,
                24,
                25,
                26
              ].contains(m.number))
          .toList(),
    ),
    IllegalMoveCategory(
      title: 'Adulto a Master (Azul e Roxa)',
      ageGroup: '',
      moves: allIllegalMoves
          .where((m) => [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25]
              .contains(m.number))
          .toList(),
    ),
    IllegalMoveCategory(
      title: 'Adulto a Master (Marrom e Preta) - Com Kimono',
      ageGroup: '',
      moves: allIllegalMoves
          .where((m) => [17, 18, 19, 21, 22, 23, 24, 25, 26].contains(m.number))
          .toList(),
    ),
    IllegalMoveCategory(
      title: 'Adultos (Marrom e Preta) - Sem Kimono',
      ageGroup: '',
      moves: allIllegalMoves
          .where((m) => [21, 22, 23, 26].contains(m.number))
          .toList(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        DropdownButtonFormField<IllegalMoveCategory>(
          value: _selectedCategory,
          hint: const Text('Filtrar por idade/faixa...'),
          isExpanded: true,
          items: illegalMovesData.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category.title, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedCategory = newValue;
            });
          },
        ),
        if (_selectedCategory != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _selectedCategory = null),
              child: const Text('Limpar Filtro / Ver Todos'),
            ),
          ),
        const SizedBox(height: 8),
        if (_selectedCategory != null)
          _buildIllegalMoveCard(context, _selectedCategory!),
        if (_selectedCategory == null)
          _buildIllegalMoveCard(
              context,
              IllegalMoveCategory(
                  title: "Todos os Golpes Proibidos",
                  ageGroup: "Lista de referência completa",
                  moves: allIllegalMoves)),
      ],
    );
  }

  Widget _buildIllegalMoveCard(
      BuildContext context, IllegalMoveCategory category) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.title, style: Theme.of(context).textTheme.titleLarge),
            if (category.ageGroup.isNotEmpty)
              Text(category.ageGroup, style: const TextStyle(color: textHint)),
            const Divider(height: 20),
            ...category.moves.asMap().entries.map((entry) {
              final index = _selectedCategory == null
                  ? entry.value.number
                  : entry.key + 1;
              final move = entry.value;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: SizedBox(
                  width: 40,
                  child: Text(
                    '$index.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: errorColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(move.name),
                trailing:
                    const Icon(Icons.photo_library_outlined, color: textHint),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => IllegalMoveDetailPage(move: move),
                  ));
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// --- TELA DE DETALHES DA IMAGEM DO GOLPE ---
class IllegalMoveDetailPage extends StatelessWidget {
  final IllegalMove move;
  const IllegalMoveDetailPage({super.key, required this.move});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('${move.number}. ${move.name}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.asset(
            move.imagePath,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 80, color: textHint),
                    SizedBox(height: 16),
                    Text('Imagem não encontrada',
                        style: TextStyle(color: textHint)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
