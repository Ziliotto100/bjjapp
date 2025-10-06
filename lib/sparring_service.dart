// lib/sparring_service.dart
import 'models.dart';

/// Serviço para encapsular a lógica de geração de rodadas de sparring.
class SparringService {
  final List<Aluno> participantes;
  final String tipoGeracao; // 'Aleatório', 'Por Faixa', 'Por Peso'

  SparringService({required this.participantes, required this.tipoGeracao});

  /// Ponto de entrada principal para gerar as rodadas com base no tipo selecionado.
  List<List<Map<String, String>>> gerarRodadas() {
    if (participantes.length < 2) {
      return [];
    }

    if (tipoGeracao == 'Aleatório') {
      return _gerarRodadasAleatorias();
    } else {
      return _gerarRodadasHierarquicasCorrigido();
    }
  }

  /// Gera rodadas usando o algoritmo de pareamento aleatório (Round Robin).
  List<List<Map<String, String>>> _gerarRodadasAleatorias() {
    List<Aluno> tempAlunos = List.from(participantes);
    tempAlunos.shuffle();

    // Adiciona um participante "fantasma" se o número for ímpar
    if (tempAlunos.length % 2 != 0) {
      tempAlunos.add(Aluno.novo(
          nome: "DESCANSA", faixa: "Branca", peso: 0, id: 'descansa-id'));
    }
    int numRodadas = tempAlunos.length - 1;
    // Para o caso de apenas 2 participantes, precisamos de 1 rodada.
    if (numRodadas <= 0) numRodadas = 1;

    List<List<Map<String, String>>> rodadas = [];
    for (int i = 0; i < numRodadas; i++) {
      List<Map<String, String>> rodadaAtual = [];
      for (int j = 0; j < tempAlunos.length / 2; j++) {
        final aluno1 = tempAlunos[j];
        final aluno2 = tempAlunos[tempAlunos.length - 1 - j];
        rodadaAtual.add({'p1': aluno1.id, 'p2': aluno2.id});
      }
      rodadas.add(rodadaAtual);
      // Gira os participantes para a próxima rodada
      tempAlunos.insert(1, tempAlunos.removeLast());
    }
    return rodadas;
  }

  /// Lógica corrigida que garante "todos contra todos" e depois ordena as rodadas.
  List<List<Map<String, String>>> _gerarRodadasHierarquicasCorrigido() {
    List<Aluno> tempAlunos = List.from(participantes);

    // Adiciona um participante "fantasma" se o número for ímpar
    if (tempAlunos.length % 2 != 0) {
      tempAlunos.add(Aluno.novo(
          nome: "DESCANSA", faixa: "Branca", peso: 0, id: 'descansa-id'));
    }

    int numRodadas = tempAlunos.length - 1;
    if (numRodadas <= 0) numRodadas = 1;

    List<List<Luta>> rodadasDeLutas = [];

    // 1. Gera o cronograma completo usando Round Robin para garantir "todos contra todos"
    for (int i = 0; i < numRodadas; i++) {
      List<Luta> rodadaAtual = [];
      for (int j = 0; j < tempAlunos.length / 2; j++) {
        final aluno1 = tempAlunos[j];
        final aluno2 = tempAlunos[tempAlunos.length - 1 - j];
        rodadaAtual.add(Luta(aluno1, aluno2, _calcularCusto(aluno1, aluno2)));
      }
      rodadasDeLutas.add(rodadaAtual);
      // Gira os participantes para a próxima rodada
      tempAlunos.insert(1, tempAlunos.removeLast());
    }

    // 2. Ordena as rodadas com base no custo médio das lutas reais
    rodadasDeLutas.sort((a, b) {
      final lutasReaisA = a.where((l) => l.custo != double.infinity);
      final lutasReaisB = b.where((l) => l.custo != double.infinity);

      if (lutasReaisA.isEmpty) {
        return 1; // Coloca rodadas sem lutas reais no final
      }
      if (lutasReaisB.isEmpty) return -1;

      final custoMedioA =
          lutasReaisA.map((l) => l.custo).reduce((v, e) => v + e) /
              lutasReaisA.length;
      final custoMedioB =
          lutasReaisB.map((l) => l.custo).reduce((v, e) => v + e) /
              lutasReaisB.length;

      return custoMedioA.compareTo(custoMedioB);
    });

    // 3. Converte as rodadas ordenadas para o formato de mapa de IDs
    return rodadasDeLutas.map((rodada) {
      return rodada.map((luta) {
        return {'p1': luta.aluno1.id, 'p2': luta.aluno2.id};
      }).toList();
    }).toList();
  }

  /// Calcula o "custo" de uma luta para fins de ordenação.
  double _calcularCusto(Aluno a1, Aluno a2) {
    // Se um dos alunos é o "DESCANSA", o custo é infinito para não influenciar no cálculo médio da rodada.
    if (a1.id == 'descansa-id' || a2.id == 'descansa-id') {
      return double.infinity;
    }

    if (tipoGeracao == 'Por Peso') {
      return (a1.peso - a2.peso).abs();
    } else {
      // 'Por Faixa'
      int indexFaixa1 = _getBeltIndex(a1.faixa);
      int indexFaixa2 = _getBeltIndex(a2.faixa);
      double diffPeso = (a1.peso - a2.peso).abs();
      // O custo principal é a diferença de faixa (com peso maior), com um pequeno ajuste pelo peso.
      return ((indexFaixa1 - indexFaixa2).abs() * 1000) + diffPeso;
    }
  }

  /// Retorna um índice numérico para a faixa, para fins de ordenação.
  int _getBeltIndex(String faixa) {
    const List<String> ordemFaixas = [
      'Branca',
      'Cinza/Branca',
      'Cinza',
      'Cinza/Preta',
      'Amarela/Branca',
      'Amarela',
      'Amarela/Preta',
      'Laranja/Branca',
      'Laranja',
      'Laranja/Preta',
      'Verde/Branca',
      'Verde',
      'Verde/Preta',
      'Azul',
      'Roxa',
      'Marrom',
      'Preta'
    ];
    final index =
        ordemFaixas.indexWhere((f) => f.toLowerCase() == faixa.toLowerCase());
    return index == -1 ? 99 : index; // Retorna um número alto se não encontrar
  }
}
