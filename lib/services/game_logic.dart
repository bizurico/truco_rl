import '../models/carta_model.dart';

class GameLogic {
  // Define a força base das cartas (sem considerar a manilha)
  static final Map<int, int> pesosBase = {
    4: 1,
    5: 2,
    6: 3,
    7: 4,
    10: 5,
    11: 6,
    12: 7,
    1: 8,
    2: 9,
    3: 10,
  };

  // Define a força dos naipes apenas para desempate de manilhas
  static final Map<Naipe, int> pesosNaipes = {
    Naipe.ouros: 1,
    Naipe.espadas: 2,
    Naipe.copas: 3,
    Naipe.paus: 4,
  };

  // Função central: Identifica a Manilha baseada na Vira
  static int calcularManilha(int valorVira) {
    if (valorVira == 7) return 10; // Pula 8 e 9
    if (valorVira == 12) return 1; // K vira A[cite: 1]

    List<int> sequencia = [4, 5, 6, 7, 10, 11, 12, 1, 2, 3];
    int index = sequencia.indexOf(valorVira);
    return sequencia[(index + 1) % sequencia.length];
  }

  // Compara duas cartas e retorna a vencedora[cite: 1]
  static String determinarVencedorVaza(
    Map<dynamic, dynamic> cartasNaMesa,
    int valorVira,
    bool isRodadaCega, // Recebe se é a rodada de 1 carta
  ) {
    int valorManilha = calcularManilha(valorVira);

    List<MapEntry<dynamic, Carta>> manilhas = [];
    List<MapEntry<dynamic, Carta>> normais = [];

    // Separa as cartas jogadas
    cartasNaMesa.forEach((jogadorId, cartaMap) {
      Carta c = Carta.fromMap(cartaMap);
      if (c.valor == valorManilha) {
        manilhas.add(MapEntry(jogadorId, c));
      } else {
        normais.add(MapEntry(jogadorId, c));
      }
    });

    // REGRA 1: Manilhas NUNCA se anulam. O naipe sempre desempata entre manilhas.
    if (manilhas.isNotEmpty) {
      manilhas.sort(
        (a, b) =>
            pesosNaipes[b.value.naipe]!.compareTo(pesosNaipes[a.value.naipe]!),
      );
      return manilhas.first.key.toString();
    }

    // REGRA 2: Rodada Cega (1 carta). NADA se anula. Maior peso ganha, naipe desempata tudo.
    if (isRodadaCega) {
      normais.sort((a, b) {
        int pesoA = pesosBase[a.value.valor]!;
        int pesoB = pesosBase[b.value.valor]!;
        if (pesoA != pesoB) return pesoB.compareTo(pesoA);
        return pesosNaipes[b.value.naipe]!.compareTo(
          pesosNaipes[a.value.naipe]!,
        );
      });
      return normais.first.key.toString();
    }

    // REGRA 3: Rodadas Normais (Anulação de Cartas!)
    Map<int, List<MapEntry<dynamic, Carta>>> agrupadas = {};
    for (var entry in normais) {
      int peso = pesosBase[entry.value.valor]!;
      agrupadas.putIfAbsent(peso, () => []).add(entry);
    }

    // Ordena do peso mais forte para o mais fraco
    List<int> pesosDecrescentes = agrupadas.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    for (int peso in pesosDecrescentes) {
      if (agrupadas[peso]!.length == 1) {
        // SOBREVIVEU! É a carta mais alta que não bateu de frente com outra igual.
        return agrupadas[peso]!.first.key.toString();
      }
      // Se a length for > 1, as cartas se ANULARAM. O loop ignora elas e busca a próxima mais forte.
    }

    // Se chegou até aqui, TODAS as cartas da mesa se anularam (Cangou!)
    return "EMPATE";
  }
}
