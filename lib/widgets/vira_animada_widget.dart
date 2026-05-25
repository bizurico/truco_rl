import 'dart:math';
import 'package:flutter/material.dart';
import '../models/carta_model.dart';

/// Carta da vira com flip 3D: começa virada para baixo e revela a frente.
class ViraAnimadaWidget extends StatefulWidget {
  final Carta carta;

  const ViraAnimadaWidget({super.key, required this.carta});

  @override
  State<ViraAnimadaWidget> createState() => _ViraAnimadaWidgetState();
}

class _ViraAnimadaWidgetState extends State<ViraAnimadaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotacao;
  late Animation<double> _escala;
  late Animation<double> _brilho;
  bool _mostrandoFrente = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotacao = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _escala = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(_controller);

    _brilho = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(_controller);

    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_mostrandoFrente) {
        setState(() => _mostrandoFrente = true);
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _controller.forward();
    });
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
        final double anguloAjustado =
            _mostrandoFrente ? _rotacao.value - pi : _rotacao.value;

        return Transform.scale(
          scale: _escala.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Brilho dourado no flip
              if (_brilho.value > 0)
                Container(
                  width: 70,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber
                            .withValues(alpha: _brilho.value * 0.8),
                        blurRadius: 20 * _brilho.value,
                        spreadRadius: 5 * _brilho.value,
                      ),
                    ],
                  ),
                ),

              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(anguloAjustado),
                child:
                    _mostrandoFrente ? _buildFrente() : _buildVerso(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFrente() {
    return Container(
      width: 65,
      height: 95,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
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
          Text(widget.carta.iconeNaipe,
              style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildVerso() {
    return Container(
      width: 65,
      height: 95,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Center(
        child: Text('🃏', style: TextStyle(fontSize: 28)),
      ),
    );
  }
}