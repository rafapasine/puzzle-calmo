// =============================================================================
// Puzzle Calmo (Android) - interface Flutter.
//
// Princípios aplicados:
//   * nenhum cronômetro; erro nunca pune; dicas em 3 degraus;
//   * áreas de toque >= 64 dp, bem espaçadas; proteção contra toque duplo;
//   * forma + cor + nome em cada peça; contraste de texto >= 4,5:1;
//   * respeita o tamanho de fonte do sistema e o ajuste "remover animações";
//   * 100% offline, sem anúncios, sem permissão de internet.
// =============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'catalogo.dart';
import 'progresso.dart';

class Cores {
  static const fundo = Color(0xFFF3F0E8); // creme claro, reduz brilho
  static const celula = Color(0xFFFFFFFF);
  static const celulaFixa = Color(0xFFE2DCCE); // casas que já vêm prontas
  static const borda = Color(0xFFB3AB9B);
  static const texto = Color(0xFF2B2F33); // ~12:1 sobre o fundo
  static const textoSuave = Color(0xFF555B61); // ~6:1
  static const primario = Color(0xFF3F6896); // texto branco ~5,9:1
  static const botao = Color(0xFFE0D9CB);
  static const destaque = Color(0xFFC28E25); // âmbar suave (dicas)
  static const conflito = Color(0xFFC9825A); // terracota suave (repetições)
  static const sucesso = Color(0xFF4B7A55);
  static const respiro = Color(0xFFA9BFD6);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await progresso.carregar();
  if (catalogo.isEmpty) throw StateError('Catálogo vazio.'); // gera uma vez (< 1 s)
  runApp(const PuzzleCalmoApp());
}

// =============================================================================
// App e tema
// =============================================================================

class _TransicaoSuave extends PageTransitionsBuilder {
  const _TransicaoSuave();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut), child: child);
  }
}

ThemeData _tema() {
  final esquema = ColorScheme.fromSeed(seedColor: Cores.primario).copyWith(
    primary: Cores.primario,
    onPrimary: Colors.white,
    surface: Cores.fundo,
    onSurface: Cores.texto,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Cores.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      foregroundColor: Cores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Cores.texto),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Cores.texto),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Cores.texto),
      titleMedium: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Cores.texto),
      bodyLarge: TextStyle(fontSize: 18, color: Cores.texto, height: 1.35),
      bodyMedium: TextStyle(fontSize: 17, color: Cores.texto, height: 1.35),
      bodySmall: TextStyle(fontSize: 15, color: Cores.textoSuave, height: 1.3),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _TransicaoSuave(),
      TargetPlatform.iOS: _TransicaoSuave(),
    }),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Cores.textoSuave),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Cores.primario : Cores.botao),
    ),
  );
}

class PuzzleCalmoApp extends StatelessWidget {
  const PuzzleCalmoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: progresso,
      builder: (context, _) => MaterialApp(
        title: 'Puzzle Calmo',
        debugShowCheckedModeBanner: false,
        theme: _tema(),
        // Respeita a fonte do sistema, aplica "Texto grande" do app e limita
        // o exagero para nada sair da tela.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final sistema = mq.textScaler.scale(1.0);
          final fator = progresso.textoGrande ? 1.25 : 1.0;
          final total = (sistema * fator).clamp(1.0, 1.8).toDouble();
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(total)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const TelaMenu(),
      ),
    );
  }
}

// =============================================================================
// Componentes reutilizáveis
// =============================================================================

/// Botão grande (altura mínima 64 dp), plano e com cores suaves.
class BotaoGrande extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;
  final bool primario;
  final IconData? icone;
  const BotaoGrande(this.texto, this.aoTocar, {super.key, this.primario = false, this.icone});

  @override
  Widget build(BuildContext context) {
    final estilo = ElevatedButton.styleFrom(
      backgroundColor: primario ? Cores.primario : Cores.botao,
      foregroundColor: primario ? Colors.white : Cores.texto,
      disabledBackgroundColor: Color.lerp(Cores.botao, Cores.fundo, 0.5),
      disabledForegroundColor: Cores.textoSuave,
      minimumSize: const Size(64, 64),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
    final rotulo = Text(texto, textAlign: TextAlign.center);
    if (icone == null) {
      return ElevatedButton(onPressed: aoTocar, style: estilo, child: rotulo);
    }
    return ElevatedButton.icon(
        onPressed: aoTocar, style: estilo, icon: Icon(icone, size: 24), label: rotulo);
  }
}

/// Cartão grande e tocável (níveis, ritmos).
class CartaoEscolha extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final bool selecionado;
  final VoidCallback aoTocar;
  const CartaoEscolha(
      {super.key,
      required this.titulo,
      required this.subtitulo,
      required this.selecionado,
      required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Semantics(
      selected: selecionado,
      button: true,
      child: Material(
        color: selecionado ? Color.lerp(Cores.fundo, Cores.primario, 0.12) : Cores.celula,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: selecionado ? Cores.primario : Cores.borda, width: selecionado ? 3 : 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo, style: tema.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitulo, style: tema.bodySmall),
                  ]),
                ),
                if (selecionado) const Icon(Icons.check_circle, color: Cores.primario, size: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desenha uma peça (forma + cor). [t] de 0 a 1 faz a peça surgir suavemente.
class PintorSimbolo extends CustomPainter {
  final Simbolo simbolo;
  final Color fundo;
  final double t;
  PintorSimbolo(this.simbolo, this.fundo, [this.t = 1.0]);

  @override
  void paint(Canvas canvas, Size size) {
    final cor = Color(simbolo.argb);
    final preench = Paint()..color = Color.lerp(fundo, cor, t)!;
    final contorno = Paint()
      ..color = Color.lerp(fundo, Color.lerp(cor, Colors.black, 0.35)!, t)!
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(2.0, size.shortestSide * 0.045);
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.92;
    var caminho = Path();
    switch (simbolo.forma) {
      case Forma.circulo:
        caminho = Path()..addOval(Rect.fromCircle(center: c, radius: r));
      case Forma.quadrado:
        final s = r * 0.86;
        caminho = Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: 2 * s, height: 2 * s), Radius.circular(s * 0.25)));
      case Forma.triangulo:
        caminho = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.98, c.dy + r * 0.78)
          ..lineTo(c.dx - r * 0.98, c.dy + r * 0.78)
          ..close();
      case Forma.losango:
        caminho = Path()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r, c.dy)
          ..close();
    }
    canvas.drawPath(caminho, preench);
    canvas.drawPath(caminho, contorno);
  }

  @override
  bool shouldRepaint(PintorSimbolo antigo) =>
      antigo.simbolo != simbolo || antigo.fundo != fundo || antigo.t != t;
}

void abrirJogo(BuildContext context, Puzzle p, String aviso, {bool substituir = false}) {
  progresso.alterar(() => progresso.nivel = p.nivel);
  final rota = MaterialPageRoute<void>(builder: (_) => TelaJogo(puzzle: p, aviso: aviso));
  if (substituir) {
    Navigator.of(context).pushReplacement(rota);
  } else {
    Navigator.of(context).push(rota);
  }
}

// =============================================================================
// Tela inicial
// =============================================================================

class TelaMenu extends StatelessWidget {
  const TelaMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: progresso,
          builder: (context, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Puzzle Calmo', textAlign: TextAlign.center, style: tema.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Um passo de cada vez. Sem pressa, sem relógio.',
                        textAlign: TextAlign.center,
                        style: tema.bodyLarge?.copyWith(color: Cores.textoSuave)),
                    const SizedBox(height: 28),
                    BotaoGrande('Iniciar · Nível ${progresso.nivel}', () {
                      final (p, aviso) = progresso.escolherPuzzle(progresso.nivel);
                      abrirJogo(context, p, aviso);
                    }, primario: true, icone: Icons.play_arrow_rounded),
                    const SizedBox(height: 14),
                    BotaoGrande('Escolher nível e ritmo', () {
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const TelaNiveis()));
                    }, icone: Icons.tune_rounded),
                    const SizedBox(height: 14),
                    BotaoGrande('Como jogar', () {
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const TelaComoJogar()));
                    }, icone: Icons.help_outline_rounded),
                    const SizedBox(height: 14),
                    BotaoGrande('Ajustes', () {
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => const TelaAjustes()));
                    }, icone: Icons.settings_outlined),
                    const SizedBox(height: 28),
                    Text(progresso.textoProgresso(),
                        textAlign: TextAlign.center,
                        style: tema.bodyMedium?.copyWith(color: Cores.textoSuave)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Nível e ritmo
// =============================================================================

class TelaNiveis extends StatelessWidget {
  const TelaNiveis({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Nível e ritmo')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: progresso,
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  Text('Ritmo (nenhum dos dois tem tempo-limite):', style: tema.titleMedium),
                  const SizedBox(height: 10),
                  for (final r in ritmos.values) ...[
                    CartaoEscolha(
                      titulo: r.nome,
                      subtitulo: r.descricao,
                      selecionado: progresso.ritmoChave == r.chave,
                      aoTocar: () => progresso.alterar(() => progresso.ritmoChave = r.chave),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 14),
                  Text('Escolha um nível para começar:', style: tema.titleMedium),
                  const SizedBox(height: 10),
                  for (final nv in niveis) ...[
                    CartaoEscolha(
                      titulo: 'Nível ${nv.numero} · ${nv.titulo}',
                      subtitulo: '${nv.descricao}\n'
                          '${catalogo.where((p) => p.nivel == nv.numero && progresso.concluidos.contains(p.id)).length}'
                          ' de ${nv.qtd} feitos',
                      selecionado: progresso.nivel == nv.numero,
                      aoTocar: () {
                        final (p, aviso) = progresso.escolherPuzzle(nv.numero);
                        abrirJogo(context, p, aviso, substituir: true);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Como jogar
// =============================================================================

class TelaComoJogar extends StatelessWidget {
  const TelaComoJogar({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    Widget secao(String titulo, String corpo) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: tema.titleMedium),
            const SizedBox(height: 6),
            Text(corpo, style: tema.bodyLarge),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Como jogar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              children: [
                secao('Sem pressa',
                    'Não há relógio nem pontos perdidos. Jogue no seu ritmo. Errar faz parte.'),
                secao('Memória (níveis 1, 3 e 5)',
                    '1. Olhe o padrão de peças pelo tempo que quiser.\n'
                        '2. Toque em “Já memorizei”. A grade fica vazia.\n'
                        '3. Escolha a peça embaixo da grade e toque nas casas para colocá-la. '
                        'Tocar de novo na mesma casa retira a peça.\n'
                        '4. Esqueceu? Toque em “Rever padrão”: ele aparece por alguns segundos '
                        'e o que você já fez continua guardado.'),
                secao('Lógica (níveis 2, 4 e 6)',
                    'Complete a grade para que cada linha e cada coluna tenham todos os símbolos, '
                        'sem repetir. As casas mais escuras já vêm prontas.'),
                secao('Dicas gentis',
                    '1º toque: um lembrete da regra ou do padrão.\n'
                        '2º toque: uma casa fica destacada para você olhar.\n'
                        '3º toque em diante: uma peça certa é colocada para você.'),
                secao('Botões de apoio',
                    '“Desfazer” volta a última mudança. “Limpar” esvazia a grade, '
                        'e também pode ser desfeito.'),
                secao('Respire',
                    'Antes de cada puzzle, um círculo cresce e diminui devagar. '
                        'Acompanhe com a respiração ou toque em “Começar agora”. '
                        'Dá para desligar em Ajustes.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Ajustes
// =============================================================================

class TelaAjustes extends StatelessWidget {
  const TelaAjustes({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    Widget chave(String titulo, String ajuda, bool valor, void Function(bool) mudar) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Cores.celula,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Cores.borda, width: 1.5)),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: valor,
              onChanged: mudar,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              title: Text(titulo, style: tema.titleMedium),
              subtitle: Text(ajuda, style: tema.bodySmall),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: progresso,
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  chave('Som suave', 'Um clique baixo só ao concluir. Nunca há som de erro.',
                      progresso.som, (v) {
                    progresso.alterar(() => progresso.som = v);
                    if (v) SystemSound.play(SystemSoundType.click);
                  }),
                  chave('Vibração leve', 'Um toque sutil ao colocar uma peça.', progresso.vibracao,
                      (v) {
                    progresso.alterar(() => progresso.vibracao = v);
                    if (v) HapticFeedback.selectionClick();
                  }),
                  chave('Texto grande', 'Aumenta letras e botões.', progresso.textoGrande,
                      (v) => progresso.alterar(() => progresso.textoGrande = v)),
                  chave('Pausa para respirar', 'Um círculo que cresce e diminui antes de cada puzzle.',
                      progresso.respiracao, (v) => progresso.alterar(() => progresso.respiracao = v)),
                  chave(
                      'Proteção contra toque duplo',
                      'Ignora um segundo toque acidental na mesma casa (útil com tremor).',
                      progresso.protecaoToque,
                      (v) => progresso.alterar(() => progresso.protecaoToque = v)),
                  const SizedBox(height: 14),
                  Text('Ritmo', style: tema.titleMedium),
                  const SizedBox(height: 10),
                  for (final r in ritmos.values) ...[
                    CartaoEscolha(
                      titulo: r.nome,
                      subtitulo: r.descricao,
                      selecionado: progresso.ritmoChave == r.chave,
                      aoTocar: () => progresso.alterar(() => progresso.ritmoChave = r.chave),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 14),
                  BotaoGrande('Apagar meu progresso', () => _confirmarApagar(context),
                      icone: Icons.restart_alt_rounded),
                  const SizedBox(height: 14),
                  Text('Seu progresso fica salvo só neste aparelho. O jogo funciona sem internet.',
                      style: tema.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarApagar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recomeçar do zero?'),
        content: const Text('Os puzzles concluídos serão desmarcados.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size(96, 56)),
              child: const Text('Cancelar', style: TextStyle(fontSize: 18))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(minimumSize: const Size(96, 56)),
              child: const Text('Apagar', style: TextStyle(fontSize: 18))),
        ],
      ),
    );
    if (ok == true) progresso.apagarTudo();
  }
}

// =============================================================================
// Tela de jogo
//   respirar -> (memória) observar -> recriar <-> revendo -> concluido
//   respirar -> (lógica)  resolver -> concluido
// =============================================================================

enum Fase { respirar, observar, recriar, revendo, resolver, concluido }

class TelaJogo extends StatefulWidget {
  final Puzzle puzzle;
  final String aviso;
  const TelaJogo({super.key, required this.puzzle, this.aviso = ''});

  @override
  State<TelaJogo> createState() => _TelaJogoState();
}

class _TelaJogoState extends State<TelaJogo> with TickerProviderStateMixin {
  late List<int> estado;
  late final Set<int> fixas;
  Fase fase = Fase.respirar;
  int nivelDica = 0;
  int? destaque;
  final List<List<int>> pilhaDesfazer = [];
  bool mostrarConflitos = false;
  int pincel = 1; // peça escolhida na paleta (0 = apagar)
  bool vencendo = false;
  bool navegando = false;
  String mensagem = '';
  Color corMensagem = Cores.texto;

  int _token = 0; // invalida timers de fases anteriores
  final List<Timer> _timers = [];
  int? _ultimaCelula;
  DateTime _ultimoToque = DateTime.fromMillisecondsSinceEpoch(0);

  late final AnimationController _respiro;
  late final AnimationController _entrada;

  Puzzle get p => widget.puzzle;
  Ritmo get ritmo => progresso.ritmo;
  bool get editavel => fase == Fase.recriar || fase == Fase.resolver;

  @override
  void initState() {
    super.initState();
    estado = List<int>.of(p.inicial);
    fixas = p.fixas;
    _respiro = AnimationController(vsync: this, duration: Duration(seconds: ritmo.respiroS))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && fase == Fase.respirar) _faseDoPuzzle();
      });
    _entrada =
        AnimationController(vsync: this, duration: Duration(milliseconds: ritmo.animMs), value: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _comecar();
    });
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _respiro.dispose();
    _entrada.dispose();
    super.dispose();
  }

  void _agendar(Duration d, VoidCallback f) {
    final tok = _token;
    _timers.add(Timer(d, () {
      if (mounted && tok == _token) f();
    }));
  }

  // ------------------------------------------------------------------ fases
  void _comecar() => progresso.respiracao ? _mudarFase(Fase.respirar) : _faseDoPuzzle();

  void _faseDoPuzzle() =>
      _mudarFase(p.tipo == TipoPuzzle.memoria ? Fase.observar : Fase.resolver);

  String _textoPadrao(Fase f) => switch (f) {
        Fase.respirar => 'Antes de começar, acompanhe o círculo e respire devagar.',
        Fase.observar =>
          'Observe o padrão com calma. Quando sentir que memorizou, toque em “Já memorizei”. '
              'Não há pressa.',
        Fase.recriar => 'Agora recrie o padrão: escolha a peça embaixo e toque nas casas.',
        Fase.revendo => 'Este é o padrão de referência. O que você já fez continua guardado.',
        Fase.resolver => 'Cada linha e cada coluna devem ter todos os símbolos, sem repetir. '
            'Casas escuras já vêm prontas.',
        Fase.concluido => '',
      };

  void _mudarFase(Fase f) {
    _token++;
    final semAnim = MediaQuery.of(context).disableAnimations;
    setState(() {
      fase = f;
      var texto = _textoPadrao(f);
      if (widget.aviso.isNotEmpty &&
          (f == Fase.respirar || f == Fase.observar || f == Fase.resolver)) {
        texto = '${widget.aviso}\n$texto';
      }
      mensagem = texto;
      corMensagem = Cores.texto;
    });
    if (f == Fase.respirar) {
      if (semAnim) {
        _respiro.value = 0.5; // círculo parado; a pessoa toca em "Começar agora"
      } else {
        _respiro.forward(from: 0);
      }
    } else {
      _respiro.stop();
    }
    if (f == Fase.observar || f == Fase.revendo) {
      if (semAnim) {
        _entrada.value = 1;
      } else {
        _entrada.forward(from: 0);
      }
    }
    if (f == Fase.revendo) {
      _agendar(Duration(seconds: ritmo.reverS), () => _mudarFase(Fase.recriar));
    }
  }

  // ---------------------------------------------------------------- jogadas
  void _msg(String texto, [Color cor = Cores.texto]) => setState(() {
        mensagem = texto;
        corMensagem = cor;
      });

  void _tocarCelula(int i) {
    if (!editavel || vencendo) return;
    if (fixas.contains(i)) {
      _msg('Esta casa já vem pronta e não muda. Escolha uma casa clara.');
      return;
    }
    final agora = DateTime.now();
    if (progresso.protecaoToque &&
        _ultimaCelula == i &&
        agora.difference(_ultimoToque).inMilliseconds < 450) {
      return; // segundo toque acidental (tremor): ignorado
    }
    _ultimaCelula = i;
    _ultimoToque = agora;
    _definir(i, estado[i] == pincel ? 0 : pincel);
  }

  void _definir(int i, int v) {
    if (estado[i] == v) return;
    pilhaDesfazer.add(List<int>.of(estado));
    if (pilhaDesfazer.length > 300) pilhaDesfazer.removeAt(0);
    setState(() {
      estado[i] = v;
      if (destaque == i) destaque = null;
      mensagem = _textoPadrao(fase);
      corMensagem = Cores.texto;
    });
    if (progresso.vibracao) HapticFeedback.selectionClick();
    _checarVitoria();
  }

  void _desfazer() {
    if (!editavel) return;
    if (pilhaDesfazer.isEmpty) {
      _msg('Não há nada para desfazer.');
      return;
    }
    setState(() {
      estado = pilhaDesfazer.removeLast();
      mensagem = _textoPadrao(fase);
      corMensagem = Cores.texto;
    });
  }

  void _limpar() {
    if (!editavel) return;
    final novo = List<int>.of(p.inicial);
    if (!estadosIguais(novo, estado)) pilhaDesfazer.add(List<int>.of(estado));
    setState(() {
      estado = novo;
      destaque = null;
      mensagem = 'Grade limpa. Se mudar de ideia, toque em “Desfazer”.';
      corMensagem = Cores.texto;
    });
  }

  void _dica() {
    if (!editavel) return;
    nivelDica++;
    final d = calcularDica(p, estado, nivelDica);
    setState(() {
      if (d.tipo == TipoDica.destacar) {
        destaque = d.celula;
      } else if (d.tipo == TipoDica.preencher) {
        pilhaDesfazer.add(List<int>.of(estado));
        estado[d.celula!] = d.valor!;
        destaque = d.celula;
      }
      if (p.tipo == TipoPuzzle.logica && nivelDica >= 2) mostrarConflitos = true;
      mensagem = d.mensagem;
      corMensagem = Cores.texto;
    });
    _checarVitoria();
  }

  void _verificar() {
    if (!editavel) return;
    if (estadosIguais(estado, p.alvo)) {
      _vitoria();
      return;
    }
    String texto;
    if (p.tipo == TipoPuzzle.logica) {
      mostrarConflitos = true;
      final vazias = estado.where((v) => v == 0).length;
      if (celulasEmConflito(estado, p.n).isNotEmpty) {
        texto = 'Quase lá. Há símbolos repetidos (borda laranja). Sem pressa: ajuste quando quiser.';
      } else if (vazias > 0) {
        texto = 'Até aqui, sem repetições. Ainda faltam $vazias casa(s) para preencher.';
      } else {
        texto = 'Quase lá. Algo ainda não se encaixa. Se quiser, peça uma dica.';
      }
    } else {
      texto = 'Quase lá. Ainda há alguma diferença. Você pode rever o padrão ou pedir uma dica.';
    }
    _msg(texto);
  }

  void _checarVitoria() {
    if (!vencendo && estadosIguais(estado, p.alvo)) {
      vencendo = true;
      _agendar(Duration(milliseconds: ritmo.vitoriaMs), _vitoria);
    }
  }

  void _vitoria() {
    if (!estadosIguais(estado, p.alvo)) {
      vencendo = false;
      return;
    }
    vencendo = true;
    destaque = null;
    progresso.marcarConcluido(p.id);
    if (progresso.som) SystemSound.play(SystemSoundType.click);
    if (progresso.vibracao) HapticFeedback.lightImpact();
    const frases = [
      'Muito bem! Puzzle concluído.',
      'Pronto! Você chegou lá no seu ritmo.',
      'Belo trabalho de atenção. Concluído!',
    ];
    final extra = ritmo.chave == 'calmo' ? ' Respire. Quando quiser, siga para o próximo.' : '';
    _mudarFase(Fase.concluido);
    _msg(frases[p.id % frases.length] + extra, Cores.sucesso);
  }

  void _proximo() {
    if (navegando) return; // evita pular dois puzzles com toque duplo
    navegando = true;
    final (proximo, aviso) = progresso.escolherPuzzle(p.nivel, apos: p);
    abrirJogo(context, proximo, aviso, substituir: true);
  }

  // ---------------------------------------------------------------- interface
  @override
  Widget build(BuildContext context) {
    final cfg = nivelPorNumero(p.nivel);
    return Scaffold(
      appBar: AppBar(
        title: Text('Nível ${cfg.numero} · puzzle ${p.indiceNoNivel} de ${cfg.qtd}'),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, cons) {
          if (fase == Fase.respirar) return _telaRespiro(cons);
          final paisagem = cons.maxWidth > cons.maxHeight && cons.maxWidth >= 600;
          final escalaTexto = MediaQuery.textScalerOf(context).scale(1.0);
          if (paisagem) {
            final lado = math.max(180.0, math.min(cons.maxHeight - 32, cons.maxWidth * 0.55 - 32));
            return Row(children: [
              Expanded(
                flex: 11,
                child: Center(child: SizedBox(width: lado, height: lado, child: _tabuleiro(lado))),
              ),
              Expanded(
                flex: 9,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 16, 20, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _mensagem(),
                    const SizedBox(height: 16),
                    _paleta(),
                    const SizedBox(height: 16),
                    _botoes(),
                  ]),
                ),
              ),
            ]);
          }
          final reservado = 300.0 + 70.0 * escalaTexto;
          final lado = math
              .min(math.min(cons.maxWidth - 32, cons.maxHeight - reservado), 560.0)
              .clamp(200.0, 560.0)
              .toDouble();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _mensagem(),
                  const SizedBox(height: 12),
                  Center(child: SizedBox(width: lado, height: lado, child: _tabuleiro(lado))),
                  const SizedBox(height: 16),
                  _paleta(),
                  const SizedBox(height: 14),
                  _botoes(),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _mensagem() {
    return Semantics(
      liveRegion: true, // o leitor de tela anuncia mudanças
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : Duration(milliseconds: ritmo.animMs ~/ 2),
          child: Text(
            mensagem,
            key: ValueKey(mensagem),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.35, color: corMensagem),
          ),
        ),
      ),
    );
  }

  Widget _telaRespiro(BoxConstraints cons) {
    final semAnim = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(children: [
        _mensagem(),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final rMax = math.max(60.0, math.min(c.maxWidth, c.maxHeight - 60) * 0.42);
            return AnimatedBuilder(
              animation: _respiro,
              builder: (context, _) {
                final v = _respiro.value;
                final k = semAnim ? 0.6 : 0.5 - 0.5 * math.cos(2 * math.pi * v);
                final r = 36 + (rMax - 36) * k;
                final legenda = semAnim
                    ? 'Respire devagar, três vezes.'
                    : (v < 0.5 ? 'Inspire devagar...' : 'Solte o ar devagar...');
                // FittedBox: em telas baixas (celular deitado) tudo encolhe em vez de cortar.
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: rMax * 2,
                    height: rMax * 2,
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: rMax * 2,
                        height: rMax * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Color.lerp(Cores.fundo, Cores.respiro, 0.6)!, width: 2),
                        ),
                      ),
                      Container(
                        width: r * 2,
                        height: r * 2,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(Cores.fundo, Cores.respiro, 0.75)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  Text(legenda,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  ]),
                );
              },
            );
          }),
        ),
        SizedBox(
          width: double.infinity,
          child: BotaoGrande('Começar agora', _faseDoPuzzle, primario: true),
        ),
      ]),
    );
  }

  Widget _tabuleiro(double lado) {
    final n = p.n;
    final mostrarAlvo = fase == Fase.observar || fase == Fase.revendo;
    final grade = mostrarAlvo ? p.alvo : estado;
    final conflitos =
        (mostrarConflitos && !mostrarAlvo) ? celulasEmConflito(estado, n) : const <int>{};
    final espaco = lado * 0.012 + 2;
    return AnimatedBuilder(
      animation: _entrada,
      builder: (context, _) {
        final t = mostrarAlvo ? Curves.easeInOut.transform(_entrada.value) : 1.0;
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: mostrarAlvo ? Color.lerp(Cores.fundo, Cores.respiro, 0.35) : Cores.fundo,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: fase == Fase.concluido ? Cores.sucesso : Cores.fundo, width: 4),
          ),
          child: Column(children: [
            for (var lin = 0; lin < n; lin++)
              Expanded(
                child: Row(children: [
                  for (var col = 0; col < n; col++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(espaco),
                        child: _celula(lin * n + col, lin, col, grade, conflitos, mostrarAlvo, t),
                      ),
                    ),
                ]),
              ),
          ]),
        );
      },
    );
  }

  Widget _celula(int i, int lin, int col, List<int> grade, Set<int> conflitos, bool mostrarAlvo,
      double t) {
    final v = grade[i];
    final fixa = fixas.contains(i) && !mostrarAlvo;
    final fundo = fixa ? Cores.celulaFixa : Cores.celula;
    final destacada = destaque == i && !mostrarAlvo;
    final conflito = conflitos.contains(i) && !fixas.contains(i);
    final cor = destacada ? Cores.destaque : (conflito ? Cores.conflito : Cores.borda);
    final largura = destacada ? 5.0 : (conflito ? 4.0 : 2.0);
    final descricao = 'Linha ${lin + 1}, coluna ${col + 1}: '
        '${v == 0 ? 'vazia' : simbolos[v]!.rotulo}${fixa ? ', já vem pronta' : ''}'
        '${destacada ? ', destacada pela dica' : ''}';
    return Semantics(
      button: editavel && !fixa,
      label: descricao,
      excludeSemantics: true,
      onTap: editavel && !fixa ? () => _tocarCelula(i) : null, // TalkBack: toque duplo
      child: Material(
        color: fundo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cor, width: largura),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: editavel ? () => _tocarCelula(i) : null,
          splashColor: Color.lerp(fundo, Cores.primario, 0.15),
          highlightColor: Colors.transparent,
          child: v == 0
              ? const SizedBox.expand()
              : Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    heightFactor: 0.62,
                    child: CustomPaint(painter: PintorSimbolo(simbolos[v]!, fundo, t)),
                  ),
                ),
        ),
      ),
    );
  }

  /// Paleta "pincel": escolhe a peça uma vez e toca nas casas. Fora das fases
  /// editáveis ela vira apenas legenda (nome + forma + cor).
  Widget _paleta() {
    final itens = <Widget>[
      for (var v = 1; v <= p.qtdSimbolos; v++)
        _botaoPeca(
          rotulo: simbolos[v]!.rotulo,
          desenho: CustomPaint(painter: PintorSimbolo(simbolos[v]!, Cores.celula)),
          selecionado: editavel && pincel == v,
          aoTocar: editavel ? () => setState(() => pincel = v) : null,
        ),
      if (editavel)
        _botaoPeca(
          rotulo: 'Apagar',
          desenho: const Icon(Icons.backspace_outlined, color: Cores.textoSuave),
          selecionado: pincel == 0,
          aoTocar: () => setState(() => pincel = 0),
        ),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(editavel ? 'Escolha a peça e toque nas casas:' : 'Peças deste puzzle:',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: itens),
    ]);
  }

  Widget _botaoPeca(
      {required String rotulo,
      required Widget desenho,
      required bool selecionado,
      VoidCallback? aoTocar}) {
    return Semantics(
      selected: selecionado,
      button: aoTocar != null,
      label: rotulo,
      excludeSemantics: true,
      onTap: aoTocar,
      child: Material(
        color: selecionado ? Color.lerp(Cores.fundo, Cores.primario, 0.14) : Cores.celula,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selecionado ? Cores.primario : Cores.borda, width: selecionado ? 4 : 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64, minWidth: 120),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 30, height: 30, child: desenho),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(rotulo,
                      style: TextStyle(
                          fontSize: 17,
                          color: Cores.texto,
                          fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _botoes() {
    Widget linha(List<Widget> filhos) => Row(children: [
          for (var k = 0; k < filhos.length; k++) ...[
            if (k > 0) const SizedBox(width: 10),
            Expanded(child: filhos[k]),
          ]
        ]);
    return switch (fase) {
      Fase.respirar => const SizedBox.shrink(),
      Fase.observar => BotaoGrande('Já memorizei', () => _mudarFase(Fase.recriar),
          primario: true, icone: Icons.check_rounded),
      Fase.revendo =>
        BotaoGrande('Voltar ao meu tabuleiro', () => _mudarFase(Fase.recriar), primario: true),
      Fase.recriar || Fase.resolver =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          linha([
            BotaoGrande('Dica gentil', _dica),
            BotaoGrande('Desfazer', _desfazer),
            BotaoGrande('Limpar', _limpar),
          ]),
          const SizedBox(height: 10),
          linha([
            if (p.tipo == TipoPuzzle.memoria)
              BotaoGrande('Rever padrão', () => _mudarFase(Fase.revendo)),
            BotaoGrande('Verificar', _verificar, primario: true),
          ]),
        ]),
      Fase.concluido => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BotaoGrande('Próximo puzzle', _proximo,
              primario: true, icone: Icons.arrow_forward_rounded),
          const SizedBox(height: 10),
          BotaoGrande('Voltar ao menu', () => Navigator.of(context).maybePop()),
        ]),
    };
  }
}
