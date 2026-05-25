import 'package:flutter/material.dart';
import '../models/carta_model.dart';

/// Carta na mão do jogador.
/// Primeiro toque: levanta a carta (selecionada).
/// Segundo toque: confirma e joga.
class CartaWidget extends StatefulWidget {
  final Carta carta;
  final bool podeSelecionada;
  final VoidCallback? onJogar;

  const CartaWidget({
    super.key,
    required this.carta,
    required this.podeSelecionada,
    this.onJogar,
  });

  @override
  State<CartaWidget> createState() => _CartaWidgetState();
}

class _CartaWidgetState extends State<CartaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _elevacao;
  late Animation<double> _escala;
  bool _selecionada = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _elevacao = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _escala = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(CartaWidget old) {
    super.didUpdateWidget(old);
    // Se o widget foi reconstruído e não pode mais ser selecionado, reseta
    if (!widget.podeSelecionada && _selecionada) {
      _selecionada = false;
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!widget.podeSelecionada) return;

    if (!_selecionada) {
      setState(() => _selecionada = true);
      _controller.forward();
    } else {
      // Segundo toque: joga a carta
      widget.onJogar?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _elevacao.value),
          child: Transform.scale(
            scale: _escala.value,
            child: GestureDetector(
              onTap: _onTap,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Brilho quando selecionada
                  if (_selecionada)
                    Container(
                      width: 68,
                      height: 98,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.7),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),

                  // Corpo da carta
                  Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      color: widget.podeSelecionada
                          ? Colors.white
                          : Colors.grey[350],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selecionada
                            ? Colors.amber
                            : Colors.grey.withValues(alpha: 0.3),
                        width: _selecionada ? 2.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.carta.texto,
                          style: TextStyle(
                            color: widget.podeSelecionada
                                ? Colors.black
                                : Colors.black38,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          widget.carta.iconeNaipe,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),

                  // Badge "JOGAR" quando selecionada
                  if (_selecionada)
                    Positioned(
                      bottom: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'JOGAR',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Carta jogada na mesa — entra com animação de deslize de baixo para cima.
class CartaMesaWidget extends StatefulWidget {
  final Carta carta;
  final String? rotulo;

  const CartaMesaWidget({super.key, required this.carta, this.rotulo});

  @override
  State<CartaMesaWidget> createState() => _CartaMesaWidgetState();
}

class _CartaMesaWidgetState extends State<CartaMesaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _posicao;
  late Animation<double> _opacidade;
  late Animation<double> _rotacao;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _posicao = Tween<Offset>(
      begin: const Offset(0, 1.8),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacidade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Leve rotação aleatória para parecer mais natural
    final seed = widget.carta.valor + widget.carta.naipe.index;
    final angulo = ((seed % 7) - 3) * 0.025;
    _rotacao = Tween<double>(begin: 0, end: angulo).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: _opacidade,
          child: SlideTransition(
            position: _posicao,
            child: Transform.rotate(
              angle: _rotacao.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.rotulo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        widget.rotulo!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.carta.texto,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          widget.carta.iconeNaipe,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}