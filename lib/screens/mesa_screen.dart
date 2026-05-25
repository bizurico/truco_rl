import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
import '../models/carta_model.dart';
import '../services/dealer_service.dart';
import '../services/game_logic.dart';
import '../widgets/vira_animada_widget.dart';
import '../widgets/carta_widget.dart';
import '../widgets/deck_widget.dart';

class MesaScreen extends StatefulWidget {
  final String salaId;
  final String meuNome;

  const MesaScreen({super.key, required this.salaId, required this.meuNome});

  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen> {
  late DatabaseReference salaRef;

  /// Controla se a animação de embaralhar está ativa.
  bool _embaralhando = false;

  /// Guarda a última vira vista para detectar mudança de rodada.
  String? _ultimaViraKey;

  @override
  void initState() {
    super.initState();
    salaRef = FirebaseDatabase.instance.ref("salas/${widget.salaId}");
    salaRef
        .child('jogadores/${widget.meuNome}')
        .onDisconnect()
        .remove();
  }

  // ─── Saída da sala ─────────────────────────────────────────────────────────

  Future<void> _sairDaSala() async {
    await salaRef.child('jogadores/${widget.meuNome}').remove();
    final snap = await salaRef.child('jogadores').get();
    if (!snap.exists || snap.value == null) {
      await salaRef.remove();
    }
    if (mounted) Navigator.of(context).pop();
  }

  // ─── Lógica de palpite ──────────────────────────────────────────────────────

  void _confirmarPalpite(int palpite, List<String> ordem, int rodada) async {
    int meuIndex = ordem.indexOf(widget.meuNome);
    int proximoIndex = (meuIndex + 1) % ordem.length;
    String proximoJogador = ordem[proximoIndex];
    int indexQuemComecou = (rodada - 1) % ordem.length;

    Map<String, dynamic> updates = {};
    updates['jogadores/${widget.meuNome}/palpite'] = palpite;

    if (proximoIndex == indexQuemComecou) {
      updates['fase'] = 'cartas';
      updates['turno_atual'] = ordem[indexQuemComecou];
    } else {
      updates['turno_atual'] = proximoJogador;
    }

    await salaRef.update(updates);
  }

  // ─── Lógica de jogar carta ──────────────────────────────────────────────────

  void _jogarCarta(
    Carta carta,
    int indexNaMao,
    List<dynamic> maoAtualRaw,
    List<String> ordem,
  ) async {
    List<dynamic> maoAtual = List.from(maoAtualRaw);
    maoAtual.removeAt(indexNaMao);

    final mesaSnap = await salaRef.child('mesa').get();
    Map mesaAtual =
        mesaSnap.value != null ? Map.from(mesaSnap.value as Map) : {};
    mesaAtual[widget.meuNome] = carta.toMap();

    Map<String, dynamic> updates = {};
    updates["jogadores/${widget.meuNome}/cartas"] = maoAtual;
    updates["mesa/${widget.meuNome}"] = carta.toMap();

    if (mesaAtual.length == ordem.length) {
      updates["turno_atual"] = "JUIZ";
      await salaRef.update(updates);

      await Future.delayed(const Duration(seconds: 2));

      final salaSnap = await salaRef.get();
      Map salaData = salaSnap.value as Map;
      Map jogadoresData = salaData['jogadores'] ?? {};

      final Carta viraObj = Carta.fromMap(salaData['vira']);
      int vazasAcumuladas = salaData['vazas_acumuladas'] ?? 1;
      String ultimoVencedorVaza = salaData['ultimo_vencedor_vaza'] ?? "";

      int totalVazasMesa = 0;
      jogadoresData.forEach((k, v) {
        totalVazasMesa += (v['vazas_feitas'] ?? 0) as int;
      });
      bool isRodadaCega = (maoAtual.length + 1 + totalVazasMesa) == 1;

      String vencedor = GameLogic.determinarVencedorVaza(
        mesaAtual,
        viraObj.valor,
        isRodadaCega,
      );

      Map<String, dynamic> fechamentoUpdates = {};

      if (vencedor == "EMPATE") {
        if (ultimoVencedorVaza == "") {
          fechamentoUpdates["vazas_acumuladas"] = vazasAcumuladas + 1;
          fechamentoUpdates["mesa"] = null;
          fechamentoUpdates["turno_atual"] = widget.meuNome;
        } else {
          vencedor = ultimoVencedorVaza;
        }
      }

      if (vencedor != "EMPATE") {
        int vazasAtuais =
            (jogadoresData[vencedor]['vazas_feitas'] ?? 0) as int;
        fechamentoUpdates["jogadores/$vencedor/vazas_feitas"] =
            vazasAtuais + vazasAcumuladas;
        fechamentoUpdates["mesa"] = null;
        fechamentoUpdates["turno_atual"] = vencedor;
        fechamentoUpdates["ultimo_vencedor_vaza"] = vencedor;
        fechamentoUpdates["vazas_acumuladas"] = 1;
      }

      await salaRef.update(fechamentoUpdates);

      if (maoAtual.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));

        final salaSnap2 = await salaRef.get();
        Map salaData2 = salaSnap2.value as Map;
        Map jogadoresData2 = salaData2['jogadores'] ?? {};

        Map<String, dynamic> balancoUpdates = {};
        List<String> sobreviventes = [];

        jogadoresData2.forEach((nome, dadosJogador) {
          int palpite = dadosJogador['palpite'] ?? 0;
          int feitas = dadosJogador['vazas_feitas'] ?? 0;
          int vidasAtuais = dadosJogador['vidas'] ?? 10;
          int diferenca = (palpite - feitas).abs();
          int vidasRestantes = vidasAtuais - diferenca;

          balancoUpdates["jogadores/$nome/vidas"] = vidasRestantes;
          balancoUpdates["jogadores/$nome/palpite"] = -1;
          balancoUpdates["jogadores/$nome/vazas_feitas"] = 0;

          if (vidasRestantes > 0) sobreviventes.add(nome.toString());
        });

        int rodadaAtual = salaData2['rodada_atual'] ?? 1;
        int qtdBaralhos = salaData2['qtd_baralhos'] ?? 1;

        balancoUpdates["rodada_atual"] = rodadaAtual + 1;
        balancoUpdates["ultimo_vencedor_vaza"] = "";
        balancoUpdates["vazas_acumuladas"] = 1;

        if (sobreviventes.length <= 1) {
          balancoUpdates["fase"] = 'game_over';
          balancoUpdates["vencedor"] =
              sobreviventes.isNotEmpty ? sobreviventes.first : "Empate";
          await salaRef.update(balancoUpdates);
        } else {
          balancoUpdates["rodada_atual"] = rodadaAtual + 1;
          await salaRef.update(balancoUpdates);

          // Aciona a animação de embaralhar antes de distribuir
          if (mounted) setState(() => _embaralhando = true);

          await Future.delayed(const Duration(milliseconds: 1600));

          await DealerService.iniciarNovaRodada(
            widget.salaId,
            sobreviventes,
            qtdBaralhos,
            rodadaAtual + 1,
          );
        }
      }
    } else {
      int meuIndex = ordem.indexOf(widget.meuNome);
      int proximoIndex = (meuIndex + 1) % ordem.length;
      updates["turno_atual"] = ordem[proximoIndex];
      await salaRef.update(updates);
    }
  }

  // ─── Build principal ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061612),
      appBar: AppBar(
        title: Text("SALA: ${widget.salaId}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: _sairDaSala,
            tooltip: 'Sair da sala',
          ),
        ],
      ),
      body: StreamBuilder(
        stream: salaRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData ||
              snapshot.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<dynamic, dynamic> dados =
              snapshot.data!.snapshot.value as Map;
          final Map<dynamic, dynamic> jogadores =
              dados['jogadores'] ?? {};
          final Map<dynamic, dynamic> cartasNaMesa =
              dados['mesa'] ?? {};

          // ── Game Over ───────────────────────────────────────────────────────
          final String fase = dados['fase'] ?? 'palpites';
          if (fase == 'game_over') {
            final String vencedor = dados['vencedor'] ?? 'Desconhecido';
            final bool euVenci = vencedor == widget.meuNome;

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    euVenci ? "🎉 VOCÊ VENCEU! 🎉" : "FIM DE JOGO",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: euVenci ? Colors.amber : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Grande Campeão:",
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  Text(
                    vencedor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                    ),
                    onPressed: _sairDaSala,
                    child: const Text(
                      "VOLTAR AO LOBBY",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Dados do jogo ───────────────────────────────────────────────────
          final List<dynamic> ordemRaw =
              dados['ordem_jogadores'] ?? jogadores.keys.toList();
          final List<String> ordemJogadores = ordemRaw.cast<String>();

          final String turnoAtual = dados['turno_atual'] ?? '';
          final bool ehMinhaVez = turnoAtual == widget.meuNome;

          final eu = jogadores[widget.meuNome];
          final List<dynamic> minhaMaoRaw = eu['cartas'] ?? [];
          final int meuPalpite = eu['palpite'] ?? -1;
          final int rodadaAtual = dados['rodada_atual'] ?? 1;

          int totalVazasMesa = 0;
          jogadores.forEach((k, v) {
            totalVazasMesa += (v['vazas_feitas'] ?? 0) as int;
          });

          final bool jaJogueiMinhaCarta =
              cartasNaMesa.containsKey(widget.meuNome);
          final int qtdCartasNestaRodada = minhaMaoRaw.length +
              (jaJogueiMinhaCarta ? 1 : 0) +
              totalVazasMesa;
          final bool ehRodadaCega = qtdCartasNestaRodada == 1;

          // Palpite proibido (fodinha)
          int palpiteProibido = -1;
          if (ordemJogadores.isNotEmpty) {
            final int indexQuemComecou =
                (rodadaAtual - 1) % ordemJogadores.length;
            final int indexUltimo =
                (indexQuemComecou - 1 + ordemJogadores.length) %
                    ordemJogadores.length;
            if (widget.meuNome == ordemJogadores[indexUltimo]) {
              int somaPalpites = 0;
              jogadores.forEach((key, value) {
                if (key != widget.meuNome) {
                  int p = value['palpite'] ?? -1;
                  if (p != -1) somaPalpites += p;
                }
              });
              palpiteProibido = minhaMaoRaw.length - somaPalpites;
            }
          }

          // Ordem visual (você sempre primeiro)
          int meuIndex = ordemJogadores.indexOf(widget.meuNome);
          List<String> ordemVisual = meuIndex != -1
              ? [
                  ...ordemJogadores.sublist(meuIndex),
                  ...ordemJogadores.sublist(0, meuIndex),
                ]
              : ordemJogadores;

          // Detecta nova rodada pela mudança da vira → aciona embaralhar
          final String? viraKey = dados['vira']?.toString();
          if (viraKey != null &&
              _ultimaViraKey != null &&
              viraKey != _ultimaViraKey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _embaralhando = true);
            });
          }
          _ultimaViraKey = viraKey;

          // ── Layout ──────────────────────────────────────────────────────────
          return Column(
            children: [
              // Área da mesa
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Mesa verde
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 20),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xFF1B5E20),
                                  Color(0xFF0A290A)
                                ],
                                radius: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Adversários em círculo
                        ...ordemVisual.asMap().entries.map((entry) {
                          if (entry.key == 0) return const SizedBox.shrink();
                          final jog = jogadores[entry.value] ?? {};
                          return _posicionarJogador(
                            entry.key,
                            ordemVisual.length,
                            constraints.maxWidth,
                            constraints.maxHeight,
                            _buildAvatarAdversario(
                                entry.value, jog, turnoAtual == entry.value),
                          );
                        }),

                        // Centro da mesa: baralho + vira + cartas jogadas
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Baralho com animação de embaralhar
                              DeckWidget(
                                embaralhando: _embaralhando,
                                onEmbaralhadoConcluido: () {
                                  if (mounted) {
                                    setState(() => _embaralhando = false);
                                  }
                                },
                              ),

                              const SizedBox(height: 8),

                              // Vira com flip 3D
                              if (dados['vira'] != null) ...[
                                const Text(
                                  "VIRA",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                // Key baseada na vira para forçar recriação
                                // do widget (e reexecutar a animação) a cada rodada
                                ViraAnimadaWidget(
                                  key: ValueKey(dados['vira'].toString()),
                                  carta: Carta.fromMap(dados['vira']),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Cartas na mesa com animação de entrada
                              if (cartasNaMesa.isNotEmpty)
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: cartasNaMesa.entries.map((e) {
                                    final Carta c =
                                        Carta.fromMap(e.value);
                                    return CartaMesaWidget(
                                      key: ValueKey(
                                          '${e.key}_${c.valor}_${c.naipe.index}'),
                                      carta: c,
                                      rotulo: e.key.toString(),
                                    );
                                  }).toList(),
                                )
                              else if (fase == 'cartas')
                                const Text(
                                  "Aguardando jogadas...",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Área do jogador
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicador de vez
                    Text(
                      ehMinhaVez
                          ? "Sua vez!"
                          : "Aguarde a vez de: $turnoAtual",
                      style: TextStyle(
                        color: ehMinhaVez
                            ? const Color(0xFF00FF9D)
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Palpites / status
                    if (fase == 'palpites' && meuPalpite == -1) ...[
                      const Text(
                        "QUANTAS VAZAS VOCÊ VAI FAZER?",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: List.generate(
                          minhaMaoRaw.length + 1,
                          (index) {
                            final bool isProibido =
                                index == palpiteProibido;
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isProibido
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : Colors.white12,
                                shape: const CircleBorder(),
                                padding: const EdgeInsets.all(15),
                              ),
                              onPressed: (ehMinhaVez && !isProibido)
                                  ? () => _confirmarPalpite(
                                      index, ordemJogadores, rodadaAtual)
                                  : null,
                              child: Text(
                                "$index",
                                style: TextStyle(
                                  color: isProibido
                                      ? Colors.redAccent
                                      : Colors.white,
                                  fontSize: 18,
                                  decoration: isProibido
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else if (fase == 'palpites' && meuPalpite != -1) ...[
                      Text(
                        "SEU PALPITE: $meuPalpite",
                        style: const TextStyle(
                            color: Colors.white54, letterSpacing: 2),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Aguardando os outros jogadores...",
                        style:
                            TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ] else ...[
                      Text(
                        "SEU PALPITE: $meuPalpite",
                        style: const TextStyle(
                            color: Colors.white54, letterSpacing: 2),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Sua mão de cartas
                    const Text(
                      "SUA MÃO",
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: minhaMaoRaw.asMap().entries.map((entry) {
                        final Carta c = Carta.fromMap(entry.value);
                        final bool jaJoguei =
                            cartasNaMesa.containsKey(widget.meuNome);
                        final bool podeJogar = fase == 'cartas' &&
                            ehMinhaVez &&
                            !jaJoguei;

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: ehRodadaCega
                              // Carta cega (❓)
                              ? GestureDetector(
                                  onTap: podeJogar
                                      ? () => _jogarCarta(c, entry.key,
                                          minhaMaoRaw, ordemJogadores)
                                      : null,
                                  child: Opacity(
                                    opacity: podeJogar ? 1.0 : 0.4,
                                    child: Container(
                                      width: 60,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.blueGrey,
                                            Colors.black87
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.white54,
                                            width: 2),
                                      ),
                                      child: const Center(
                                        child: Text("❓",
                                            style:
                                                TextStyle(fontSize: 30)),
                                      ),
                                    ),
                                  ),
                                )
                              // Carta normal com animação
                              : CartaWidget(
                                  key: ValueKey(
                                      '${entry.key}_${c.valor}_${c.naipe.index}'),
                                  carta: c,
                                  podeSelecionada: podeJogar,
                                  onJogar: () => _jogarCarta(
                                      c,
                                      entry.key,
                                      minhaMaoRaw,
                                      ordemJogadores),
                                ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Helpers (funções de layout e avatar) ──────────────────────────────────────

Widget _posicionarJogador(
  int index,
  int total,
  double largura,
  double altura,
  Widget filho,
) {
  final double anguloInicial = 90 * (math.pi / 180);
  final double variacaoAngulo = (2 * math.pi) / total;
  final double angulo = anguloInicial + (index * variacaoAngulo);

  final double raioX = largura * 0.35;
  final double raioY = altura * 0.35;
  final double centroX = largura / 2;
  final double centroY = altura / 2;

  final double x = centroX + raioX * math.cos(angulo);
  final double y = centroY + raioY * math.sin(angulo);

  return Positioned(
    left: x - 60,
    top: y - 50,
    child: filho,
  );
}

Widget _buildAvatarAdversario(String nome, Map jog, bool ehTurno) {
  final int cartasNaMao = (jog['cartas'] as List? ?? []).length;
  final int vidas = jog['vidas'] ?? 10;
  final int palpite = jog['palpite'] ?? -1;
  final int feitas = jog['vazas_feitas'] ?? 0;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Card de status
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ehTurno
              ? Colors.amber.withValues(alpha: 0.9)
              : Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ehTurno
                ? Colors.white
                : Colors.amber.withValues(alpha: 0.3),
            width: ehTurno ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(
              nome,
              style: TextStyle(
                color: ehTurno ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              "❤️ $vidas | 🏆 $feitas/${palpite == -1 ? '?' : palpite}",
              style: TextStyle(
                color: ehTurno ? Colors.black87 : Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 8),

      // Leque de cartas do adversário
      SizedBox(
        height: 50,
        width: 80,
        child: Stack(
          alignment: Alignment.topCenter,
          children: List.generate(cartasNaMao, (i) {
            return Transform.translate(
              offset: Offset((i - (cartasNaMao - 1) / 2) * 15, 0),
              child: Transform.rotate(
                angle: (i - (cartasNaMao - 1) / 2) * 0.2,
                child: Container(
                  width: 30,
                  height: 45,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF283593)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.white24, width: 1),
                    boxShadow: const [
                      BoxShadow(
                          blurRadius: 2,
                          color: Colors.black45,
                          offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Center(
                    child: Text("🃏", style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ],
  );
}