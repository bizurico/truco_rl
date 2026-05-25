import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'instrucoes.dart';
import 'lobby_screen.dart';

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  bool isCriando = true;
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _salaController = TextEditingController();

  void _entrarNaMesa() async {
    String nome = _nomeController.text.trim();
    String sala = _salaController.text.trim();

    if (nome.isEmpty || sala.isEmpty) return;

    DatabaseReference salaRef = FirebaseDatabase.instance.ref("salas/$sala");

    if (isCriando) {
      // Cria a sala e define o status inicial
      await salaRef.set({
        'status': 'aguardando',
        'jogadores': {
          nome: {'pontos': 0, 'palpite': -1},
        },
      });
    } else {
      // Apenas adiciona o jogador na sala existente
      await salaRef.child("jogadores/$nome").set({'pontos': 0, 'palpite': -1});
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(
          salaId: sala,
          meuNome: nome,
          souHost: isCriando, // Se está criando, é o host!
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber, // Fundo amarelo
        shape: const CircleBorder(), // Garante que seja perfeitamente redondo
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InstrucoesScreen()),
          );
        },
        child: const Icon(
          Icons.question_mark,
          color: Color(
            0xFF1B5E20,
          ), // Interrogação no tom de verde escuro do jogo
          size: 32,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.style, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "TRUCO RL",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Alternador Criar/Entrar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Criar"),
                  selected: isCriando,
                  onSelected: (val) => setState(() => isCriando = true),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("Entrar"),
                  selected: !isCriando,
                  onSelected: (val) => setState(() => isCriando = false),
                ),
              ],
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: "Seu Nome"),
            ),
            TextField(
              controller: _salaController,
              decoration: const InputDecoration(labelText: "Nome da Sala"),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: _entrarNaMesa,
                child: Text(
                  isCriando ? "CRIAR MESA" : "ENTRAR NA MESA",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
