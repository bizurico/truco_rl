import 'dart:math';
import 'package:flutter/material.dart';

/// Baralho animado com dois estados:
/// - Idle: flutuação suave contínua.
/// - Embaralhando: cartas voam para fora e voltam.
class DeckWidget extends StatefulWidget {
  final bool embaralhando;
  final VoidCallback? onEmbaralhadoConcluido;

  const DeckWidget({
    super.key,
    this.embaralhando = false,
    this.onEmbaralhadoConcluido,
  });

  @override
  State<DeckWidget> createState() => _DeckWidgetState();
}

class _DeckWidgetState extends State<DeckWidget> with TickerProviderStateMixin {
  late AnimationController _embaralharCtrl;
  late AnimationController _flutuarCtrl;
  late Animation<double> _flutuacao;

  final List<_CartaVoando> _cartasVoando = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _flutuarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _flutuacao = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _flutuarCtrl, curve: Curves.easeInOut),
    );

    _embaralharCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _embaralharCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _cartasVoando.clear());
        widget.onEmbaralhadoConcluido?.call();
      }
    });

    if (widget.embaralhando) _iniciarEmbaralhar();
  }

  @override
  void didUpdateWidget(DeckWidget old) {
    super.didUpdateWidget(old);
    if (widget.embaralhando && !old.embaralhando) _iniciarEmbaralhar();
  }

  void _iniciarEmbaralhar() {
    if (!mounted) return;
    setState(() {
      _cartasVoando.clear();
      for (int i = 0; i < 8; i++) {
        _cartasVoando.add(_CartaVoando(
          dx: (_rng.nextDouble() - 0.5) * 90,
          dy: (_rng.nextDouble() - 0.5) * 70,
          rotacao: (_rng.nextDouble() - 0.5) * pi * 0.5,
          delay: i * 0.07,
        ));
      }
    });
    _embaralharCtrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _embaralharCtrl.dispose();
    _flutuarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_embaralharCtrl, _flutuarCtrl]),
      builder: (context, _) {
        return SizedBox(
          width: 110,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Cartas voando durante o embaralhar
              ..._cartasVoando.map((c) {
                final progress =
                    (_embaralharCtrl.value - c.delay).clamp(0.0, 1.0);
                final t = progress < 0.5
                    ? Curves.easeOut.transform(progress * 2)
                    : Curves.easeIn
                        .transform(1 - (progress - 0.5) * 2);

                return Opacity(
                  opacity: progress > 0 ? 0.85 : 0,
                  child: Transform.translate(
                    offset: Offset(c.dx * t, c.dy * t),
                    child: Transform.rotate(
                      angle: c.rotacao * t,
                      child: _buildVerso(w: 52, h: 76),
                    ),
                  ),
                );
              }),

              // Baralho principal com flutuação
              Transform.translate(
                offset: Offset(0, _flutuacao.value),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sombra dinâmica (maior quando o baralho está em baixo)
                    Positioned(
                      bottom: -10,
                      child: Container(
                        width: 48,
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(
                            alpha: 0.25 +
                                ((_flutuacao.value + 5) / 10) * 0.15,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Camadas de profundidade
                    for (int i = 5; i >= 0; i--)
                      Transform.translate(
                        offset: Offset(i * 0.4, -i * 0.7),
                        child: _buildVerso(
                          w: 60,
                          h: 90,
                          opacidade: 0.55 + i * 0.09,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVerso(
      {required double w, required double h, double opacidade = 1.0}) {
    return Opacity(
      opacity: opacidade,
      child: Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: w * 0.62,
            height: h * 0.70,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text('🃏', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaVoando {
  final double dx, dy, rotacao, delay;
  _CartaVoando(
      {required this.dx,
      required this.dy,
      required this.rotacao,
      required this.delay});
}