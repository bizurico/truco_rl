import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// Vamos criar este em seguida
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

    if (nome.isEmpty || sala.isEmpty) {
      print('ERRO: nome ou sala vazios');
      return;
    }

    print('Tentando conectar ao Firebase...');
    
    try {
      DatabaseReference salaRef = FirebaseDatabase.instance.ref("salas/$sala");
      print('Referência criada: salas/$sala');

      if (isCriando) {
        print('Criando sala...');
        await salaRef.set({
          'status': 'aguardando',
          'jogadores': {
            nome: {'pontos': 0, 'palpite': -1, 'vidas': 10},
          },
        });
        print('Sala criada com sucesso!');
      } else {
        print('Entrando na sala...');
        await salaRef.child("jogadores/$nome").set({'pontos': 0, 'palpite': -1, 'vidas': 10});
        print('Entrou na sala com sucesso!');
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LobbyScreen(
            salaId: sala,
            meuNome: nome,
            souHost: isCriando,
          ),
        ),
      );
    } catch (e) {
      print('ERRO Firebase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
