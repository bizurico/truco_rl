import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
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

    DatabaseReference salaRef =
        FirebaseDatabase.instance.ref("salas/$sala");

    if (isCriando) {
      await salaRef.set({
        'status': 'aguardando',
        'meta_pontos': 10, // padrão, alterável no lobby
        'jogadores': {
          nome: {'pontos': 0, 'palpite': -1, 'vidas': 10},
        },
      });
    } else {
      // Ao entrar, lê a meta_pontos da sala para inicializar as vidas corretamente
      final snap = await salaRef.child('meta_pontos').get();
      final int meta = (snap.value as int?) ?? 10;
      await salaRef
          .child("jogadores/$nome")
          .set({'pontos': 0, 'palpite': -1, 'vidas': meta});
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
  }

  void _abrirComoJogar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ComoJogarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.style, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              "TRUCO RL",
              style:
                  TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            // Alternador Criar/Entrar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Criar"),
                  selected: isCriando,
                  onSelected: (val) =>
                      setState(() => isCriando = true),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("Entrar"),
                  selected: !isCriando,
                  onSelected: (val) =>
                      setState(() => isCriando = false),
                ),
              ],
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _nomeController,
              decoration:
                  const InputDecoration(labelText: "Seu Nome"),
            ),
            TextField(
              controller: _salaController,
              decoration:
                  const InputDecoration(labelText: "Nome da Sala"),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber),
                onPressed: _entrarNaMesa,
                child: Text(
                  isCriando ? "CRIAR MESA" : "ENTRAR NA MESA",
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Botão Como Jogar
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.amber),
                  foregroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _abrirComoJogar,
                icon: const Icon(Icons.help_outline),
                label: const Text("COMO JOGAR"),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Tela Como Jogar ──────────────────────────────────────────────────────────

class ComoJogarScreen extends StatelessWidget {
  const ComoJogarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061612),
      appBar: AppBar(
        title: const Text("COMO JOGAR"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.amber,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          _Secao(
            titulo: "VISÃO GERAL",
            icone: Icons.info_outline,
            conteudo:
                "Truco RL é um jogo individual onde você adivinha quantas levas você ganha a cada rodada e, com a diferença entre o seu palpite e a quantidade de levas que você ganhou, você ganha pontos. O objetivo é não levar pontos — ganha o último jogador da mesa.\n\nSe estamos na rodada de 4 cartas, então teremos 4 levas. Uma leva é composta por uma carta jogada de cada jogador.",
          ),
          _Secao(
            titulo: "SISTEMA DE PONTOS",
            icone: Icons.score,
            conteudo:
                "• Palpite 2, ganhou 2 → não levou pontos ✅\n• Palpite 2, ganhou 1 → levou 1 ponto ❌\n• Palpite 2, ganhou 3 → levou 1 ponto ❌\n\nPara não levar pontos, o seu palpite deve ser exato.",
          ),
          _Secao(
            titulo: "FORÇA DAS CARTAS",
            icone: Icons.bar_chart,
            conteudo:
                "A ordem de força das cartas é: 4, 5, 6, 7, Q, J, K, A, 2, 3 e a manilha.\n\nA carta mais forte vence. De modo geral, o naipe não influencia na força das cartas.",
          ),
          _Secao(
            titulo: "MANILHA",
            icone: Icons.auto_awesome,
            conteudo:
                "Após as cartas serem distribuídas, uma carta é virada na mesa e a carta posterior a ela é chamada de manilha. A manilha sempre será a carta mais forte.\n\nExemplo: a carta virada foi um 7, logo a manilha é o Q. A sequência exclusiva dessa leva fica: 4, 5, 6, 7, J, K, A, 2, 3, Q.",
          ),
          _Secao(
            titulo: "EMPATES E DESEMPATES",
            icone: Icons.balance,
            conteudo:
                "Caso 2 ou mais jogadores joguem cartas de mesmo valor (que não sejam manilhas), as cartas se anulam e a carta mais forte após essas ganha.\n\nExemplo: mesa é 2, 2, J, 6 → os dois '2' se anulam e o J ganha.\n\nSe as cartas iguais forem manilhas, o naipe desempata:\n♦ Ouros < ♠ Espadas < ♥ Copas < ♣ Paus\n\nSe todas as cartas empatarem:\n• Na 1ª leva: leva fica empatada, quem jogou a última carta inicia a 2ª leva, e o vencedor da 2ª leva leva as duas.\n• Nas levas seguintes: o vencedor da leva anterior ganha.\n\nNas rodadas de uma carta, se todas empatarem, o naipe da mais forte é o critério de desempate.",
          ),
          _Secao(
            titulo: "PREPARAÇÃO",
            icone: Icons.shuffle,
            conteudo:
                "A quantidade de cartas por rodada varia: começa com 4, depois 3, 2, 1, 2, 3, 4, 3, 2, 1 e assim sucessivamente.\n\nRemova as cartas 8, 9 e 10 do baralho, embaralhe e distribua. Em sentido horário, o jogador à esquerda de quem distribuiu inicia a fase dos palpites.",
          ),
          _Secao(
            titulo: "FASE DOS PALPITES",
            icone: Icons.record_voice_over,
            conteudo:
                "Todos os jogadores, em sentido horário, devem dar seus palpites de quantas levas ganham.\n\nRegra especial: a soma dos palpites não pode ser igual à quantidade de cartas da rodada. Isso garante que alguém sempre vai levar pontos.",
          ),
          _Secao(
            titulo: "FASE DAS CARTAS",
            icone: Icons.style,
            conteudo:
                "Após os palpites, o primeiro jogador que palpitou inicia jogando uma carta, seguindo em sentido horário. Ao final de cada leva, o vencedor joga primeiro na próxima.\n\nSiga até acabarem as cartas da mão e inicie a próxima rodada.",
          ),
          _Secao(
            titulo: "RODADA DE UMA CARTA",
            icone: Icons.visibility_off,
            conteudo:
                "Nas rodadas de uma única carta, o jogador não pode ver a própria carta — apenas as dos adversários. Com base nelas deve dar seu palpite. As regras de manilha, empates e palpites continuam valendo.",
          ),
          _Secao(
            titulo: "REGRAS ESPECIAIS",
            icone: Icons.library_books,
            conteudo:
                "Com 2 baralhos, manilhas de naipes iguais se anulam.",
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              "Obrigado por jogar! 🃏",
              style: TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final String conteudo;
  final IconData icone;

  const _Secao({
    required this.titulo,
    required this.conteudo,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            conteudo,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}