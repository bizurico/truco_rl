import 'package:flutter/material.dart';

class LogoUnificado extends StatelessWidget {
  final double cardSize;
  final double textSize;

  const LogoUnificado({
    super.key,
    required this.cardSize,
    required this.textSize,
  });

  @override
  Widget build(BuildContext context) {
    // Proporção de uma carta real (largura é ~65% da altura)
    final double cardWidth = cardSize * 0.65;
    final double cardHeight = cardSize;

    // Função interna para desenhar uma carta individual limpa e bonita
    Widget buildCard(double angle, Color bgColor, {String? naipe}) {
      return Transform.rotate(
        angle: angle,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(
              cardSize * 0.1,
            ), // Cantos arredondados da carta
            border: Border.all(
              color: const Color(0xFF061612),
              width: cardSize * 0.04,
            ), // Borda escura
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(2, 4), // Sombra para dar profundidade
              ),
            ],
          ),
          child: naipe != null
              ? Center(
                  child: Text(
                    naipe,
                    style: TextStyle(
                      color: const Color(
                        0xFF061612,
                      ), // Cor do naipe (mesma do fundo)
                      fontSize: cardSize * 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Caixa delimitadora para a animação do Hero ficar suave e não cortar as cartas
        SizedBox(
          width: cardSize * 1.8,
          height: cardSize * 1.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Carta da Esquerda (Inclinada para a esquerda e um pouco mais escura)
              Positioned(
                left: 0,
                bottom: 0,
                child: buildCard(-0.4, Colors.amber.shade600),
              ),
              // Carta da Direita (Inclinada para a direita e um pouco mais escura)
              Positioned(
                right: 0,
                bottom: 0,
                child: buildCard(0.4, Colors.amber.shade600),
              ),
              // Carta do Centro (Reta, cor principal e com o detalhe do naipe)
              Positioned(
                bottom: cardSize * 0.1,
                child: buildCard(0.0, Colors.amber, naipe: '♠'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Texto TRUCO RL
        Text(
          "TRUCO RL",
          style: TextStyle(
            color: Colors.amber,
            fontSize: textSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
