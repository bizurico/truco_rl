import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;
import '../models/carta_model.dart';
import '../services/dealer_service.dart';
import '../services/game_logic.dart';

class MesaScreen extends StatefulWidget {
  final String salaId;
  final String meuNome;

  const MesaScreen({super.key, required this.salaId, required this.meuNome});

  @override
  State<MesaScreen> createState() => _MesaScreenState();
}

class _MesaScreenState extends State<MesaScreen> {
  late DatabaseReference salaRef;

  @override
  void initState() {
    super.initState();
    salaRef = FirebaseDatabase.instance.ref("salas/${widget.salaId}");
    salaRef
        .child('jogadores/${widget.meuNome}')
        .onDisconnect()
        .remove(); // Limpa o jogador do banco se ele desconectar abruptamente
  }

  // Função para sair e limpar o Firebase
  Future<void> _sairDaSala() async {
    // 1. Remove o seu jogador da lista
    await salaRef.child('jogadores/${widget.meuNome}').remove();

    // 2. Verifica se ainda sobrou alguém na sala
    DataSnapshot snap = await salaRef.child('jogadores').get();

    if (!snap.exists || snap.value == null) {
      // 3. Você era o ÚLTIMO! Então apaga a sala inteira do banco de dados.
      await salaRef.remove();
    }

    // 4. Volta para a tela anterior (Lobby)
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // Lógica inteligente que entende a passagem de turno e de fases
  void _confirmarPalpite(int palpite, List<String> ordem, int rodada) async {
    int meuIndex = ordem.indexOf(widget.meuNome);
    int proximoIndex = (meuIndex + 1) % ordem.length;
    String proximoJogador = ordem[proximoIndex];

    // Descobre quem foi o primeiro a dar palpite nesta rodada específica
    int indexQuemComecou = (rodada - 1) % ordem.length;

    Map<String, dynamic> updates = {};
    updates['jogadores/${widget.meuNome}/palpite'] = palpite;

    // A fase de palpites SÓ ACABA quando o próximo seria quem começou a rodada
    if (proximoIndex == indexQuemComecou) {
      updates['fase'] = 'cartas';
      updates['turno_atual'] =
          ordem[indexQuemComecou]; // O primeiro a palpitar abre a mesa
    } else {
      updates['turno_atual'] = proximoJogador;
    }

    await salaRef.update(updates);
  }

  // Lógica de jogar a carta adaptada para a nova ordem
  void _jogarCarta(
    Carta carta,
    int indexNaMao,
    List<dynamic> maoAtualRaw,
    List<String> ordem,
  ) async {
    List<dynamic> maoAtual = List.from(maoAtualRaw);
    maoAtual.removeAt(indexNaMao);

    DataSnapshot mesaSnap = await salaRef.child('mesa').get();
    Map mesaAtual = mesaSnap.value != null
        ? Map.from(mesaSnap.value as Map)
        : {};

    mesaAtual[widget.meuNome] = carta.toMap();

    Map<String, dynamic> updates = {};
    updates["jogadores/${widget.meuNome}/cartas"] = maoAtual;
    updates["mesa/${widget.meuNome}"] = carta.toMap();

    // === O TRIBUNAL (Verifica se a vaza acabou) ===
    if (mesaAtual.length == ordem.length) {
      updates["turno_atual"] = "JUIZ";
      await salaRef.update(updates);

      await Future.delayed(const Duration(seconds: 2));

      // 3. Puxa todos os dados atualizados para julgar o empate
      DataSnapshot salaSnap = await salaRef.get();
      Map salaData = salaSnap.value as Map;
      Map jogadoresData = salaData['jogadores'] ?? {};

      Carta viraObj = Carta.fromMap(salaData['vira']);
      int vazasAcumuladas = salaData['vazas_acumuladas'] ?? 1;
      String ultimoVencedorVaza = salaData['ultimo_vencedor_vaza'] ?? "";

      // Descobre se é rodada cega para avisar o Juiz
      int totalVazasMesa = 0;
      jogadoresData.forEach((k, v) {
        totalVazasMesa += (v['vazas_feitas'] ?? 0) as int;
      });
      bool isRodadaCega = (maoAtual.length + 1 + totalVazasMesa) == 1;

      // 4. O Juiz apita!
      String vencedor = GameLogic.determinarVencedorVaza(
        mesaAtual,
        viraObj.valor,
        isRodadaCega,
      );

      Map<String, dynamic> fechamentoUpdates = {};

      // 5. TRATAMENTO DO EMPATE (Canga)
      if (vencedor == "EMPATE") {
        if (ultimoVencedorVaza == "") {
          // Empatou na PRIMEIRA leva! Acumula o ponto e quem jogou a última carta sai jogando.
          fechamentoUpdates["vazas_acumuladas"] = vazasAcumuladas + 1;
          fechamentoUpdates["mesa"] = null;
          fechamentoUpdates["turno_atual"] = widget.meuNome;
        } else {
          // Empatou em levas seguintes! O vencedor da leva anterior ganha automaticamente.
          vencedor = ultimoVencedorVaza;
        }
      }

      // 6. ENTREGA DOS PONTOS (Se alguém venceu a leva ou levou por desempate anterior)
      if (vencedor != "EMPATE") {
        int vazasAtuais = (jogadoresData[vencedor]['vazas_feitas'] ?? 0) as int;

        fechamentoUpdates["jogadores/$vencedor/vazas_feitas"] =
            vazasAtuais + vazasAcumuladas;
        fechamentoUpdates["mesa"] = null;
        fechamentoUpdates["turno_atual"] = vencedor;
        fechamentoUpdates["ultimo_vencedor_vaza"] =
            vencedor; // Salva quem ganhou essa leva
        fechamentoUpdates["vazas_acumuladas"] = 1; // Reseta as vazas acumuladas
      }

      await salaRef.update(fechamentoUpdates);
      // ==========================================================
      // === NOVO: VERIFICADOR DE FIM DE RODADA (A MÃO ACABOU?) ===
      // ==========================================================
      if (maoAtual.isEmpty) {
        // Suspense extra de 2 segundos para a galera ver quem levou a última vaza
        await Future.delayed(const Duration(seconds: 2));

        // O Juiz puxa todos os dados atualizados da sala para o "Acerto de Contas"
        DataSnapshot salaSnap = await salaRef.get();
        Map salaData = salaSnap.value as Map;
        Map jogadoresData = salaData['jogadores'] ?? {};

        Map<String, dynamic> balancoUpdates = {};
        List<String> sobreviventes =
            []; // Lista para guardar quem continua vivo

        // 1. O Acerto de Contas (Perdendo Vidas e checando sobreviventes)
        jogadoresData.forEach((nome, dadosJogador) {
          int palpite = dadosJogador['palpite'] ?? 0;
          int feitas = dadosJogador['vazas_feitas'] ?? 0;
          int vidasAtuais = dadosJogador['vidas'] ?? 10;

          int diferenca = (palpite - feitas).abs();
          int vidasRestantes = vidasAtuais - diferenca;

          balancoUpdates["jogadores/$nome/vidas"] = vidasRestantes;
          balancoUpdates["jogadores/$nome/palpite"] = -1;
          balancoUpdates["jogadores/$nome/vazas_feitas"] = 0;

          // Se o jogador não morreu, adiciona ele na lista de sobreviventes
          if (vidasRestantes > 0) {
            sobreviventes.add(nome.toString());
          }
        });

        int rodadaAtual = salaData['rodada_atual'] ?? 1;
        int qtdBaralhos = salaData['qtd_baralhos'] ?? 1;

        // ...
        balancoUpdates["rodada_atual"] = rodadaAtual + 1;

        // Limpa a memória de empates para a próxima rodada
        balancoUpdates["ultimo_vencedor_vaza"] = "";
        balancoUpdates["vazas_acumuladas"] = 1;

        // === VERIFICAÇÃO DE FIM DE JOGO ===
        if (sobreviventes.length <= 1) {
          // O JOGO ACABOU!
          balancoUpdates["fase"] = 'game_over';

          // Se sobrou 1, ele é o vencedor. Se sobrou 0 (raro, mas possível num empate fatal), o jogo declara empate.
          balancoUpdates["vencedor"] = sobreviventes.isNotEmpty
              ? sobreviventes.first
              : "Empate";

          await salaRef.update(balancoUpdates); // Salva o fim do jogo
        } else {
          // O JOGO CONTINUA! (Prepara a próxima rodada só com os sobreviventes)
          balancoUpdates["rodada_atual"] = rodadaAtual + 1;
          await salaRef.update(balancoUpdates);

          await DealerService.iniciarNovaRodada(
            widget.salaId,
            sobreviventes, // Atenção: Passa só os vivos para o Dealer!
            qtdBaralhos,
            rodadaAtual + 1,
          );
        }
      }
    } else {
      // Jogo segue normal (só passa a vez)
      int meuIndex = ordem.indexOf(widget.meuNome);
      int proximoIndex = (meuIndex + 1) % ordem.length;
      updates["turno_atual"] = ordem[proximoIndex];
      await salaRef.update(updates);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061612),
      appBar: AppBar(
        title: Text("SALA: ${widget.salaId}"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: salaRef.onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          Map<dynamic, dynamic> dados = snapshot.data!.snapshot.value as Map;
          Map<dynamic, dynamic> jogadores = dados['jogadores'] ?? {};
          Map<dynamic, dynamic> cartasNaMesa = dados['mesa'] ?? {};

          // DADOS DA MÁQUINA DE ESTADOS DO JOGO
          String fase = dados['fase'] ?? 'palpites';
          if (fase == 'game_over') {
            String vencedor = dados['vencedor'] ?? 'Desconhecido';
            bool euVenci = vencedor == widget.meuNome;

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
                  Text(
                    "Grande Campeão:",
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
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
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                    onPressed: () =>
                        _sairDaSala(), // Chama a função de sair da sala e limpar o banco{
                    child: const Text(
                      "VOLTAR AO LOBBY",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Puxa a ordem salva no Firebase para não desincronizar os celulares
          List<dynamic> ordemRaw =
              dados['ordem_jogadores'] ?? jogadores.keys.toList();
          List<String> ordemJogadores = ordemRaw.cast<String>();

          String turnoAtual = dados['turno_atual'] ?? '';
          bool ehMinhaVez = turnoAtual == widget.meuNome;

          var eu = jogadores[widget.meuNome];
          List<dynamic> minhaMaoRaw = eu['cartas'] ?? [];
          int meuPalpite = eu['palpite'] ?? -1;

          int totalVazasMesa = 0;
          jogadores.forEach((k, v) {
            totalVazasMesa += (v['vazas_feitas'] ?? 0) as int;
          });

          bool jaJogueiMinhaCarta = cartasNaMesa.containsKey(widget.meuNome);

          // A soma da sua mão atual + a carta que você já jogou na mesa + as vazas passadas
          // revela o tamanho exato da rodada atual!
          int qtdCartasNestaRodada =
              minhaMaoRaw.length +
              (jaJogueiMinhaCarta ? 1 : 0) +
              totalVazasMesa;

          // Se a rodada é de 1 carta, o modo cego é ATIVADO!
          bool ehRodadaCega = qtdCartasNestaRodada == 1;

          int rodadaAtual = dados['rodada_atual'] ?? 1;

          // === 2. A MÁGICA DA "FODINHA" (Palpite Proibido) ===
          int palpiteProibido = -1;

          if (ordemJogadores.isNotEmpty) {
            // Descobre quem é o Primeiro e quem é o Último desta rodada
            int indexQuemComecou = (rodadaAtual - 1) % ordemJogadores.length;

            // O último é o anterior ao primeiro. O "+ length" serve para o Dart não bugar com números negativos!
            int indexUltimo =
                (indexQuemComecou - 1 + ordemJogadores.length) %
                ordemJogadores.length;
            String ultimoJogador = ordemJogadores[indexUltimo];

            // A regra SÓ se aplica se o seu nome for o do último jogador!
            if (widget.meuNome == ultimoJogador) {
              int somaPalpites = 0;

              jogadores.forEach((key, value) {
                // Soma os palpites de todo mundo da mesa, MENOS o seu
                if (key != widget.meuNome) {
                  int p = value['palpite'] ?? -1;
                  if (p != -1) somaPalpites += p;
                }
              });

              // Calcula o número amaldiçoado
              palpiteProibido = minhaMaoRaw.length - somaPalpites;
            }
          }

          // 1. Reordenar a lista para VOCÊ ser sempre o primeiro (ficar na base da tela)
          int meuIndex = ordemJogadores.indexOf(widget.meuNome);
          List<String> ordemVisual = [];
          if (meuIndex != -1) {
            ordemVisual = [
              ...ordemJogadores.sublist(meuIndex),
              ...ordemJogadores.sublist(0, meuIndex),
            ];
          } else {
            ordemVisual = ordemJogadores;
          }

          return Column(
            children: [
              // === ÁREAS 1 e 2 UNIFICADAS: A MESA E OS JOGADORES AO REDOR ===
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // --- O FUNDO DA MESA VERDE ---
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 20.0,
                          ),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [Color(0xFF1B5E20), Color(0xFF0A290A)],
                                radius: 0.8,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // --- POSICIONANDO OS ADVERSÁRIOS EM CÍRCULO ---
                        ...ordemVisual.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String nome = entry.value;
                          var jog = jogadores[nome] ?? {};

                          // O índice 0 é você (já tem a sua área grande lá embaixo, então não desenha aqui)
                          if (idx == 0) return const SizedBox.shrink();

                          return _posicionarJogador(
                            idx,
                            ordemVisual.length,
                            constraints.maxWidth,
                            constraints.maxHeight,
                            _buildAvatarAdversario(
                              nome,
                              jog,
                              turnoAtual == nome,
                            ),
                          );
                        }),

                        // --- AS CARTAS NO CENTRO DA MESA E A VIRA ---
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // A Vira
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
                                _buildCartaFisica(Carta.fromMap(dados['vira'])),
                                const SizedBox(height: 30),
                              ],

                              // Cartas Jogadas pela galera
                              if (cartasNaMesa.isNotEmpty)
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  alignment: WrapAlignment.center,
                                  children: cartasNaMesa.entries.map((e) {
                                    Carta c = Carta.fromMap(e.value);
                                    return _buildCartaFisica(
                                      c,
                                      rotulada: e.key,
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

              // === 3. SUA ÁREA (Controle de Turno, Palpites e Mão) ===
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color:
                      Colors.black45, // Fundo destacado para a área de controle
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // INDICADOR DE VEZ (Verde se for você, Amarelo se for outro)
                    Text(
                      ehMinhaVez ? "Sua vez!" : "Aguarde a vez de: $turnoAtual",
                      style: TextStyle(
                        color: ehMinhaVez
                            ? const Color(0xFF00FF9D)
                            : Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // ---- CONTEÚDO DINÂMICO (Botões de Palpite OU Palpite Escolhido) ----
                    if (fase == 'palpites' && meuPalpite == -1) ...[
                      // Fase de palpites e você AINDA NÃO escolheu
                      const Text(
                        "QUANTAS VAZAS VOCÊ VAI FAZER?",
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: List.generate(minhaMaoRaw.length + 1, (
                          index,
                        ) {
                          bool isProibido = index == palpiteProibido;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isProibido
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : Colors.white12,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(15),
                            ),
                            // Chama a função atômica e não buga o banco
                            onPressed: (ehMinhaVez && !isProibido)
                                ? () => _confirmarPalpite(
                                    index,
                                    ordemJogadores,
                                    rodadaAtual,
                                  )
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
                        }),
                      ),
                    ] else if (fase == 'palpites' && meuPalpite != -1) ...[
                      // Fase de palpites, mas VOCÊ JÁ ESCOLHEU
                      Text(
                        "SEU PALPITE: $meuPalpite",
                        style: const TextStyle(
                          color: Colors.white54,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        "Aguardando os outros jogadores...",
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ] else ...[
                      // O jogo virou para a FASE DE CARTAS!
                      Text(
                        "SEU PALPITE: $meuPalpite",
                        style: const TextStyle(
                          color: Colors.white54,
                          letterSpacing: 2,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ---- AS SUAS CARTAS (AGORA SEMPRE VISÍVEIS!) ----
                    const Text(
                      "SUA MÃO",
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: minhaMaoRaw.asMap().entries.map((entry) {
                        Carta c = Carta.fromMap(entry.value);

                        // REGRA MÁGICA: Só pode jogar a carta se a fase for 'cartas' E for sua vez.
                        bool jaJoguei = cartasNaMesa.containsKey(
                          widget.meuNome,
                        );
                        bool podeJogarCarta =
                            (fase == 'cartas' && ehMinhaVez && !jaJoguei);

                        return GestureDetector(
                          onTap: podeJogarCarta
                              ? () => _jogarCarta(
                                  c,
                                  entry.key,
                                  minhaMaoRaw,
                                  ordemJogadores,
                                )
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Opacity(
                              // A carta fica acesa se você estiver apenas olhando (fase de palpites)
                              // ou se for a sua vez de jogar (fase de cartas).
                              opacity: (fase == 'palpites' || podeJogarCarta)
                                  ? 1.0
                                  : 0.4,
                              child: ehRodadaCega
                                  ? Container(
                                      width: 60,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Colors.blueGrey,
                                            Colors.black87,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white54,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "❓",
                                          style: TextStyle(fontSize: 30),
                                        ),
                                      ),
                                    )
                                  : _buildCartaFisica(c),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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

// Widget para desenhar a carta seguindo o estilo do Truco RL
Widget _buildCartaFisica(Carta carta, {String? rotulada}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (rotulada != null)
        Text(
          rotulada,
          style: const TextStyle(color: Colors.amber, fontSize: 10),
        ),
      Container(
        width: 60,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            "${carta.texto}\n${carta.iconeNaipe}",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ),
    ],
  );
}

// Função para calcular a posição (X, Y) de cada jogador na mesa
Widget _posicionarJogador(
  int index,
  int total,
  double largura,
  double altura,
  Widget filho,
) {
  // O jogador "0" (você) sempre fica embaixo (90 graus)
  // Distribuímos os outros uniformemente
  double anguloInicial = 90 * (3.141592 / 180); // 90 graus em radianos
  double variacaoAngulo = (2 * 3.141592) / total;

  // O ângulo atual do jogador (sentido horário)
  double angulo = anguloInicial + (index * variacaoAngulo);

  // Raio da elipse (ajustado para não bater nas bordas)
  double raioX = largura * 0.35;
  double raioY = altura * 0.35;

  // Coordenadas centrais
  double centroX = largura / 2;
  double centroY = altura / 2;

  // Posição final
  double x = centroX + raioX * math.cos(angulo);
  double y = centroY + raioY * math.sin(angulo);

  return Positioned(
    left: x - 60, // Metade da largura estimada do widget do jogador
    top: y - 50, // Metade da altura estimada
    child: filho,
  );
}

Widget _buildAvatarAdversario(String nome, Map jog, bool ehTurno) {
  int cartasNaMao = (jog['cartas'] as List? ?? []).length;
  int vidas = jog['vidas'] ?? 10;
  int palpite = jog['palpite'] ?? -1;
  int feitas = jog['vazas_feitas'] ?? 0;

  return Column(
    mainAxisSize:
        MainAxisSize.min, // Garante que a coluna não ocupe espaço desnecessário
    children: [
      // === AGORA O CARD DE STATUS FICA EM CIMA ===
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ehTurno ? Colors.amber.withValues(alpha: 0.9) : Colors.black87,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ehTurno ? Colors.white : Colors.amber.withValues(alpha: 0.3),
            width: ehTurno ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
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
            // Exibe Vidas ❤️ e Vazas Feitas/Pedidas 🏆
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

      // Um pequeno espaço entre o card e as cartas
      const SizedBox(height: 8),

      // === E O LEQUE DE CARTAS FICA EMBAIXO ===
      SizedBox(
        height: 50,
        width: 80,
        child: Stack(
          alignment: Alignment.topCenter, // Alinha o leque pelo topo agora
          children: List.generate(cartasNaMao, (i) {
            // Lógica de rotação e translação para criar o efeito de leque (invisível/costas da carta)
            return Transform.translate(
              offset: Offset((i - (cartasNaMao - 1) / 2) * 15, 0),
              child: Transform.rotate(
                angle: (i - (cartasNaMao - 1) / 2) * 0.2,
                child: Container(
                  width: 30,
                  height: 45,
                  decoration: BoxDecoration(
                    // Cor escura para simular o verso da carta (pode usar imagem depois)
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 2,
                        color: Colors.black45,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "🃏", // Um emoji temporário para representar o baralho
                      style: TextStyle(fontSize: 12),
                    ),
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
