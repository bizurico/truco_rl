import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/dealer_service.dart';
import 'mesa_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String salaId;
  final String meuNome;
  final bool souHost;

  const LobbyScreen({
    super.key,
    required this.salaId,
    required this.meuNome,
    required this.souHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _pontosCustomController = TextEditingController();
  int pontosParaEliminar = 10; // Valor padrão

  @override
  Widget build(BuildContext context) {
    DatabaseReference salaRef = FirebaseDatabase.instance.ref(
      "salas/${widget.salaId}",
    );

    return Scaffold(
      backgroundColor: const Color(0xFF061612), // Cor do protótipo
      appBar: AppBar(
        title: Text("SALA: ${widget.salaId}"),
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder(
        stream: salaRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          Map dados = snapshot.data!.snapshot.value as Map;
          if (dados['status'] == 'jogando') {
            // O addPostFrameCallback garante que o Flutter termine de
            // ler o banco antes de forçar a troca de tela (evita tela vermelha)
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              DatabaseReference salaRef = FirebaseDatabase.instance
                  .ref()
                  .child('salas')
                  .child(widget.salaId);

              // 1. Puxa os dados da sala uma vez antes de entrar
              DataSnapshot snapshot = await salaRef.get();

              if (snapshot.exists) {
                Map data = snapshot.value as Map;
                Map? jogadores = data['jogadores'];

                // 2. A PERÍCIA: Se a sala existe mas a lista de jogadores está vazia ou nula
                if (jogadores == null || jogadores.isEmpty) {
                  // Apaga a carcaça da sala antiga para começar do zero
                  await salaRef.remove();

                  // Agora ela está limpa para ser "criada" novamente sem lixo
                }
              }

              Navigator.pushReplacement(
                // ignore: use_build_context_synchronously
                context,
                MaterialPageRoute(
                  builder: (context) => MesaScreen(
                    salaId: widget.salaId,
                    meuNome: widget.meuNome,
                  ),
                ),
              );
            });

            // Enquanto ele troca de tela, mostramos um loading verde
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF9D)),
            );
          }
          // ==========================================

          Map jogadores = dados['jogadores'] ?? {};
          int metaAtual = dados['meta_pontos'] ?? 10;
          int qtdBaralhos = dados['qtd_baralhos'] ?? 1;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: 0.05,
                    ), // Fundo translúcido sutil
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "NOME DA SALA",
                        style: TextStyle(
                          color: Colors.white54,
                          letterSpacing: 2,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.salaId.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Botão de copiar (estilo protótipo)
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              color: Color(0xFF00FF9D),
                            ),
                            onPressed: () {
                              // Aqui você pode adicionar a funcionalidade de copiar depois!
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Código da sala copiado!"),
                                  backgroundColor: Color.fromARGB(
                                    255,
                                    91,
                                    189,
                                    255,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                // Configuração de Pontos (Apenas para o Host)
                if (widget.souHost) ...[
                  const Text(
                    "LIMITE DE PONTOS PARA ELIMINAÇÃO",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("5"),
                        selected: metaAtual == 5,
                        onSelected: (_) => salaRef.update({'meta_pontos': 5}),
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("10"),
                        selected: metaAtual == 10,
                        onSelected: (_) => salaRef.update({'meta_pontos': 10}),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _pontosCustomController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: "Outro"),
                          onSubmitted: (val) =>
                              salaRef.update({'meta_pontos': int.parse(val)}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "QUANTIDADE DE BARALHOS",
                    style: TextStyle(color: Colors.white70),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. Mostra "1 Baralho" SOMENTE se tiver menos de 6 jogadores
                      if (jogadores.length < 6)
                        ChoiceChip(
                          label: const Text("1 Baralho"),
                          selected: qtdBaralhos == 1,
                          onSelected: (_) =>
                              salaRef.update({'qtd_baralhos': 1}),
                        ),

                      // 2. Espaçamento condicional (só aparece se os dois botões estiverem na tela)
                      if (jogadores.length >= 4 && jogadores.length < 6)
                        const SizedBox(width: 10),

                      // 3. Mostra "2 Baralhos" SOMENTE se tiver 4 ou mais jogadores
                      if (jogadores.length >= 4)
                        ChoiceChip(
                          label: const Text("2 Baralhos"),
                          selected: qtdBaralhos == 2,
                          onSelected: (_) =>
                              salaRef.update({'qtd_baralhos': 2}),
                        ),
                    ],
                  ),
                ] else ...[
                  Text(
                    "META DE PONTOS: $metaAtual",
                    style: const TextStyle(color: Colors.amber, fontSize: 18),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "BARALHOS NA MESA: $qtdBaralhos",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
                const Divider(color: Colors.white24, height: 40),
                Text(
                  "JOGADORES (${jogadores.length}/4)",
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),

                // Lista de Jogadores conectada ao Firebase
                Expanded(
                  child: ListView(
                    children: jogadores.keys
                        .map(
                          (nome) => ListTile(
                            leading: const Icon(
                              Icons.person,
                              color: Color(0xFF00FF9D),
                            ),
                            title: Text(
                              nome.toString(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: nome == widget.meuNome
                                ? const Text(
                                    "(Você)",
                                    style: TextStyle(color: Colors.white54),
                                  )
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ),

                // Botão de Iniciar (Só aparece para o Host e quando o status for aguardando)
                if (widget.souHost && dados['status'] == 'aguardando')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF9D),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () async {
                      List<String> nomes = jogadores.keys
                          .cast<String>()
                          .toList();
                      await DealerService.iniciarNovaRodada(
                        widget.salaId,
                        nomes,
                        qtdBaralhos,
                        1, // Começamos na rodada 1, onde se distribui 4 cartas
                      );
                      await salaRef.update({'status': 'jogando'});
                    },
                    child: const Text(
                      "INICIAR PARTIDA",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
