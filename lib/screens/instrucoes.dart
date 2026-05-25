import 'package:flutter/material.dart';

class InstrucoesScreen extends StatelessWidget {
  const InstrucoesScreen({super.key});

  // Widget auxiliar para os Títulos das seções
  Widget _buildTitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.amber,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // Widget auxiliar para os textos base
  Widget _buildTexto(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          height: 1.5, // Dá um bom espaçamento entre as linhas (entrelinha)
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061612), // Fundo verde escuro do jogo
      appBar: AppBar(
        title: const Text(
          "COMO JOGAR",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      // O Floating Action Button (FAB) amarelo no canto inferior direito
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        onPressed: () {
          // Fecha a tela de regras e volta para onde estava (ex: Lobby)
          Navigator.of(context).pop();
        },
        tooltip: 'Voltar',
        child: const Icon(Icons.check, color: Colors.black, size: 30),
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 100.0,
          ), // Padding inferior extra por causa do botão
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitulo("VISÃO GERAL"),
              _buildTexto(
                "Truco RL é um jogo individual onde você adivinha quantas levas você ganha a cada rodada e, com a diferença entre o seu palpite e a quantidade de levas que você ganhou, você ganha 1 ponto.",
              ),
              _buildTexto(
                "O objetivo é não levar pontos, ganha o último jogador da mesa.\nSe estamos na rodada de 4 cartas, então, teremos 4 levas, uma leva é composta por uma carta jogada de cada jogador.",
              ),

              _buildTitulo("SISTEMA DE PONTOS"),
              _buildTexto("O sistema de pontos funciona da seguinte forma:"),
              _buildTexto(
                "• Se o palpite for 2 jogos e você ganhar 2 jogos, parabéns! Você não levou pontos.\n• Se o palpite for 2 jogos e você ganhar 1 jogo, você levou 1 ponto.\n• Se o palpite for 2 jogos e você ganhar 3 jogos, você leva 1 ponto.",
              ),
              _buildTexto(
                "Ou seja, para não levar pontos, o seu palpite deve ser exato.",
              ),

              _buildTitulo("FORÇA DAS CARTAS"),
              _buildTexto(
                "Antes de tudo, é necessário ter a ordem de força decorada. Como o nome do jogo sugere, é um jogo que tem suas semelhanças com o truco, dentre elas, a ordem de força das cartas, que é: 4, 5, 6, 7, Q, J, K, A, 2, 3 e a manilha. (Mais a frente será explicado sobre a manilha).",
              ),
              _buildTexto(
                "A carta mais forte vence e de modo geral o naipe não influencia na força das cartas.",
              ),

              _buildTitulo("MANILHA"),
              _buildTexto(
                "Após as cartas serem distribuídas para todos os jogadores, uma carta é virada na mesa e a carta posterior a ela é chamada de manilha. A manilha sempre será a carta mais forte.",
              ),
              _buildTexto(
                "Por exemplo: após as cartas serem distribuídas, a carta virada foi um 7, logo, a manilha é o Q. Então a sequência exclusiva dessa leva é: 4, 5, 6, 7, J, K, A, 2, 3, Q.",
              ),

              _buildTitulo("EMPATES E DESEMPATES"),
              _buildTexto(
                "Caso 2 ou mais jogadores joguem cartas de mesmo valor (2 de ouros e 2 de paus, por exemplo), desde que não sejam manilhas, as cartas se anulam e a carta com mais força após essas ganha. Por exemplo: a mesa é 2, 2, J, 6. Os dois \"2\" se anulam e o J ganha a leva.",
              ),
              _buildTexto(
                "Caso as cartas iguais sejam manilhas, então o naipe será utilizado para desempatar as manilhas seguindo a ordem de força: Ouros (♦), Espadas (♠), Copas (♥), Paus (♣). Logo, se a manilha for o Q, o Q de copas vence do Q de espadas e etc.",
              ),
              _buildTexto(
                "E se todas as cartas empatarem?\nSe for na primeira leva, então a leva fica empatada, o jogador que jogou a última carta inicia a 2ª leva e o jogador que vencer a 2ª leva, vence as duas.",
              ),
              _buildTexto(
                "Se forem nas levas seguintes, então o jogador que venceu a leva anterior ganha. Exemplo: se eu ganhei a 1ª e a 2ª empatou, então eu levo a 2ª.\nNas rodadas de uma carta, caso todas empatem, então o naipe da mais forte será o critério de desempate.",
              ),

              _buildTitulo("PREPARAÇÃO"),
              _buildTexto(
                "A quantidade de cartas de cada rodada varia conforme as rodadas avançam. Sempre começam com 4 cartas, depois 3, 2, 1, 2, 3, 4, 3, 2, 1 e assim sucessivamente.",
              ),
              _buildTexto(
                "Primeiramente, deve-se remover as cartas 8, 9 e 10 do baralho, embaralhar e distribuir 4 cartas para todos jogadores. Em sentido horário, o jogador à esquerda de quem distribuiu as cartas deve falar seu palpite, iniciando assim a fase dos palpites.",
              ),

              _buildTitulo("FASE DOS PALPITES"),
              _buildTexto(
                "Todos os jogadores, em sentido horário, devem dar seus palpites de quantos jogos ganham. Porém há uma regra especial que garante que alguém sempre vai levar um ponto. Essa regra é que a soma dos palpites não pode ser igual à soma de cartas.",
              ),
              _buildTexto(
                "Ou seja, vamos supor que há 3 jogadores e estamos na rodada de 3 cartas, se o primeiro e o segundo jogador falarem 1 carta cada, logo, o último jogador não poderá falar 0. Pois 1 palpite do 1º jogador + 1 palpite do 2º jogador = 2 palpites, se o 3º jogador falasse 1 também, seriam 3 palpites para 3 cartas.",
              ),

              _buildTitulo("FASE DAS CARTAS"),
              _buildTexto(
                "Após todos os jogadores darem seus palpites, o primeiro jogador que deu o palpite deve ser o primeiro a jogar uma carta, continuando assim em sentido horário. Quando o último jogador jogar uma carta, então faz a comparação de quem ganhou essa leva, levando em conta manilhas, empates e tudo mais. Então o jogador que venceu essa leva deve ser o primeiro a jogar a carta.",
              ),
              _buildTexto(
                "Agora, é só seguir até acabarem as cartas da mão e iniciar a próxima rodada. A cada leva alguém sempre vai tomar pontos.",
              ),

              _buildTitulo("IMPORTANTE:"),
              _buildTexto(
                "Nas rodadas de uma única carta, o jogador não pode ver a própria carta, ele verá apenas as cartas dos seus adversários e baseado nelas deve dar seu palpite. Mantendo as regras de manilha, empates e quantidade de palpites diferente da leva.",
              ),

              _buildTitulo("REGRAS ESPECIAIS"),
              _buildTexto(
                "Caso estejam com 2 baralhos, as manilhas de naipes iguais vão se anular.\n\nObrigado por jogar!",
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
