import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:truco_rl/screens/splash_screen.dart';
import 'firebase_options.dart'; // O arquivo que o CLI acabou de criar

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização profissional e multiplataforma
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const TrucoRL());
}

class TrucoRL extends StatelessWidget {
  const TrucoRL({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Truco RL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF061612), // Fundo das imagens
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00FF9D), // O verde neon dos botões
          primary: const Color(0xFF00FF9D),
        ),
      ),
      // Por enquanto, vamos apontar para um Placeholder até criarmos a tela
      home: const SplashScreen(),
    );
  }
}
