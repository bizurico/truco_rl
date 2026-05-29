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

  @override
  void dispose() {
    _pontosCustomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DatabaseReference salaRef = FirebaseDatabase.instance.ref(
      "salas/${widget.salaId}",
    );

    return Scaffold(
      backgroundColor: const Color(0xFF061612),
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
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              DatabaseReference salaRef = FirebaseDatabase.instance
                  .ref()
                  .child('salas')
                  .child(widget.salaId);

              DataSnapshot snapshot = await salaRef.get();

              if (snapshot.exists) {
                Map data = snapshot.value as Map;
                Map? jogadores = data['jogadores'];
                if (jogadores == null || jogadores.isEmpty) {
                  await salaRef.remove();
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

            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FF9D)),
            );
          }

          Map jogadores = dados['jogadores'] ?? {};
          if (jogadores.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              salaRef.remove();
            });
            return const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            );
          }
          int metaAtual = dados['meta_pontos'] ?? 10;
          int qtdBaralhos = dados['qtd_baralhos'] ?? 1;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Card do nome da sala
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
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
                          IconButton(
                            icon: const Icon(
                              Icons.copy,
                              color: Color(0xFF00FF9D),
                            ),
                            onPressed: () {
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

                // Configurações (apenas host)
                if (widget.souHost) ...[
                  const Text(
                    "LIMITE DE PONTOS PARA ELIMINAÇÃO",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text("5"),
                        selected:
                            metaAtual == 5 &&
                            _pontosCustomController.text.isEmpty,
                        onSelected: (_) {
                          _pontosCustomController.clear();
                          setState(() {});
                          salaRef.update({'meta_pontos': 5});
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        label: const Text("10"),
                        selected:
                            metaAtual == 10 &&
                            _pontosCustomController.text.isEmpty,
                        onSelected: (_) {
                          _pontosCustomController.clear();
                          setState(() {});
                          salaRef.update({'meta_pontos': 10});
                        },
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _pontosCustomController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: "Outro",
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _pontosCustomController.text.isNotEmpty
                                    ? Colors.amber
                                    : Colors.white24,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.amber),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              salaRef.update({'meta_pontos': parsed});
                            }
                            setState(() {});
                          },
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
                      if (jogadores.length < 6)
                        ChoiceChip(
                          label: const Text("1 Baralho"),
                          selected: qtdBaralhos == 1,
                          onSelected: (_) =>
                              salaRef.update({'qtd_baralhos': 1}),
                        ),
                      if (jogadores.length >= 4 && jogadores.length < 6)
                        const SizedBox(width: 10),
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

                // Botão iniciar (só host)
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

                      // Aplica a meta_pontos como vidas iniciais de todos
                      Map<String, dynamic> vidasUpdate = {};
                      for (String nome in nomes) {
                        vidasUpdate['jogadores/$nome/vidas'] = metaAtual;
                      }
                      await salaRef.update(vidasUpdate);

                      await DealerService.iniciarNovaRodada(
                        widget.salaId,
                        nomes,
                        qtdBaralhos,
                        1,
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
