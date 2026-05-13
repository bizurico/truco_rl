import 'dart:math';
import '../models/carta_model.dart';
import 'package:firebase_database/firebase_database.dart';

class DealerService {
  static int calcularQtdCartas(int rodadaAtual) {
    // A sequência base que se repete: 4, 3, 2, 1, 2, 3
    List<int> sequencia = [4, 3, 2, 1, 2, 3];

    // Como a rodada 1 é o índice 0 do array, subtraímos 1.
    // O operador % (módulo) faz o array "dar a volta" e repetir infinitamente.
    int index = (rodadaAtual - 1) % sequencia.length;
    return sequencia[index];
  }

  static List<Carta> gerarNovoBaralho() {
    List<Carta> baralho = [];
    // Valores do Truco/Fodinha: 1 a 7 e as figuras (10, 11, 12)
    List<int> valores = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];

    for (var naipe in Naipe.values) {
      for (var valor in valores) {
        baralho.add(Carta(valor: valor, naipe: naipe));
      }
    }

    baralho.shuffle(Random()); // Embaralhamento aleatório
    return baralho;
  }

  static Future<void> iniciarNovaRodada(
    String salaId,
    List<String> nomesJogadores,
    int qtdBaralhos,
    int rodadaAtual,
  ) async {
    List<Carta> superBaralho = [];

    for (int i = 0; i < qtdBaralhos; i++) {
      superBaralho.addAll(gerarNovoBaralho());
    }

    superBaralho.shuffle(Random());
    final vira = superBaralho.removeLast();

    // Usa a nossa nova função matemática!
    int qtdCartasParaDar = calcularQtdCartas(rodadaAtual);

    Map<String, dynamic> updates = {};
    updates['vira'] = vira.toMap();
    // === ADICIONE ESTAS 3 LINHAS ===
    updates['ordem_jogadores'] = nomesJogadores;
    updates['fase'] = 'palpites';

    // === O RODÍZIO DA MESA ===
    // A cada rodada, o turno inicial passa para o próximo jogador da roda
    int indexQuemComeca = (rodadaAtual - 1) % nomesJogadores.length;
    updates['turno_atual'] = nomesJogadores[indexQuemComeca];
    // =========================

    for (var nome in nomesJogadores) {
      List<Carta> mao = [];
      // Distribui a quantidade exata de cartas da rodada
      for (int c = 0; c < qtdCartasParaDar; c++) {
        mao.add(superBaralho.removeLast());
      }
      updates['jogadores/$nome/cartas'] = mao.map((c) => c.toMap()).toList();
      updates['jogadores/$nome/palpite'] =
          -1; // Prepara para a fase de palpites
    }

    await FirebaseDatabase.instance.ref("salas/$salaId").update(updates);
  }
}
