import 'package:flutter/material.dart';
import 'tela_inicial.dart'; // Importe sua Home/Tela Inicial
import 'logo_unificado.dart'; // Importe o componente novo

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(seconds: 1), // Tempo da "viagem"
            pageBuilder: (_, __, ___) => const TelaInicial(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061612),
      body: Center(
        child: Hero(
          tag: 'logo_completo_hero', // Tag única para o bloco todo
          child: const LogoUnificado(
            cardSize: 150, // Tamanho grande na Splash
            textSize: 40,
          ),
        ),
      ),
    );
  }
}
