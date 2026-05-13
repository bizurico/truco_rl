enum Naipe { ouros, espadas, copas, paus }

class Carta {
  final int valor; // 1 (A), 2, 3, 4, 5, 6, 7, 10 (J), 11 (Q), 12 (K)
  final Naipe naipe;

  Carta({required this.valor, required this.naipe});

  // Getters para facilitar a UI
  String get texto => _mapearValor(valor);
  String get iconeNaipe => _mapearNaipe(naipe);

  // Serialização para o Firebase Realtime Database
  Map<String, dynamic> toMap() => {'v': valor, 'n': naipe.index};

  factory Carta.fromMap(Map<dynamic, dynamic> map) {
    return Carta(valor: map['v'] as int, naipe: Naipe.values[map['n'] as int]);
  }

  static String _mapearValor(int v) {
    if (v == 1) return 'A';
    if (v == 10) return 'Q';
    if (v == 11) return 'J';
    if (v == 12) return 'K';
    return v.toString();
  }

  static String _mapearNaipe(Naipe n) {
    switch (n) {
      case Naipe.ouros:
        return '♦️';
      case Naipe.espadas:
        return '♠️';
      case Naipe.copas:
        return '♥️';
      case Naipe.paus:
        return '♣️';
    }
  }
}
