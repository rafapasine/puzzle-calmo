// =============================================================================
// Puzzle Calmo (Android) - lógica pura: catálogo, resolvedor e dicas.
//
// Este arquivo NÃO depende de Flutter: pode ser testado com `flutter test`.
//
// Garantia de no máximo 200 combinações:
//   * cada nível tem quantidade fixa (6 x 30 = 180 puzzles);
//   * a soma é conferida contra [maxPuzzles] (200) antes de gerar;
//   * o gerador de números é próprio (xorshift32) e usa SEMENTE FIXA, então
//     o catálogo é idêntico em qualquer aparelho e em qualquer versão do Dart;
//   * duplicatas são descartadas;
//   * o jogo só lê puzzles deste catálogo: nada é sorteado durante a partida.
// =============================================================================

const int maxPuzzles = 200;
const int sementeCatalogo = 20261122;

/// Impressão digital esperada do catálogo (FNV-1a 32 bits).
/// É a mesma calculada por `ferramentas/conferir_catalogo.py`.
const String impressaoEsperada = 'f74b8149';

enum TipoPuzzle { memoria, logica }

enum Forma { circulo, quadrado, triangulo, losango }

class Simbolo {
  final String nome;
  final String cor;
  final int argb;
  final Forma forma;
  const Simbolo(this.nome, this.cor, this.argb, this.forma);

  String get rotulo => '$nome $cor';
  String get rotuloMinusculo => '${nome.toLowerCase()} $cor';
}

/// Forma + cor juntas: nunca depende só da cor (acessível a daltonismo).
const Map<int, Simbolo> simbolos = {
  1: Simbolo('Círculo', 'azul', 0xFF4F7CAC, Forma.circulo),
  2: Simbolo('Quadrado', 'verde', 0xFF5E8C61, Forma.quadrado),
  3: Simbolo('Triângulo', 'laranja', 0xFFC07A45, Forma.triangulo),
  4: Simbolo('Losango', 'lilás', 0xFF7E6BA8, Forma.losango),
};

class ConfigNivel {
  final int numero;
  final String titulo;
  final TipoPuzzle tipo;
  final int tam;
  final int qtdSimbolos;
  final int faixaMin; // peças (memória) ou pistas (lógica)
  final int faixaMax;
  final int qtd;
  final String descricao;
  const ConfigNivel(this.numero, this.titulo, this.tipo, this.tam, this.qtdSimbolos,
      this.faixaMin, this.faixaMax, this.qtd, this.descricao);
}

/// Seis níveis alternando memória e lógica, com carga crescente.
const List<ConfigNivel> niveis = [
  ConfigNivel(1, 'Lembrar', TipoPuzzle.memoria, 3, 1, 2, 3, 30,
      'Memória · grade 3×3 · 2 a 3 círculos'),
  ConfigNivel(2, 'Completar', TipoPuzzle.logica, 3, 3, 5, 6, 30,
      'Lógica · grade 3×3 · 3 símbolos, muitas pistas'),
  ConfigNivel(3, 'Lembrar mais', TipoPuzzle.memoria, 3, 2, 3, 4, 30,
      'Memória · grade 3×3 · 3 a 4 peças de 2 tipos'),
  ConfigNivel(4, 'Completar mais', TipoPuzzle.logica, 4, 4, 9, 10, 30,
      'Lógica · grade 4×4 · 4 símbolos, muitas pistas'),
  ConfigNivel(5, 'Lembrar com atenção', TipoPuzzle.memoria, 4, 3, 4, 5, 30,
      'Memória · grade 4×4 · 4 a 5 peças de 3 tipos'),
  ConfigNivel(6, 'Deduzir', TipoPuzzle.logica, 4, 4, 6, 7, 30,
      'Lógica · grade 4×4 · poucas pistas'),
];

ConfigNivel nivelPorNumero(int n) => niveis.firstWhere((c) => c.numero == n);

// -----------------------------------------------------------------------------
// Gerador determinístico (xorshift32). Só usa deslocamentos, XOR e máscara de
// 32 bits: resultado idêntico em qualquer plataforma.
// -----------------------------------------------------------------------------
class GeradorDeterministico {
  static const int _mascara = 0xFFFFFFFF;
  int _s;

  GeradorDeterministico(int semente)
      : _s = (semente & _mascara) == 0 ? 0x9E3779B9 : (semente & _mascara);

  int proximo() {
    var x = _s;
    x ^= (x << 13) & _mascara;
    x ^= x >> 17;
    x ^= (x << 5) & _mascara;
    _s = x & _mascara;
    return _s;
  }

  int inteiro(int n) => proximo() % n;

  int entre(int a, int b) => a + inteiro(b - a + 1);

  List<int> amostra(int m, int k) {
    final l = List<int>.generate(m, (i) => i);
    for (var i = 0; i < k; i++) {
      final j = i + inteiro(m - i);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
    return l.sublist(0, k);
  }

  void embaralhar(List<int> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = inteiro(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }

  T escolher<T>(List<T> l) => l[inteiro(l.length)];
}

// -----------------------------------------------------------------------------
// Regras da grade (quadrado latino) e resolvedor
// -----------------------------------------------------------------------------

/// Símbolos que cabem na casa [i] sem repetir na linha nem na coluna (em ordem).
List<int> candidatos(List<int> g, int n, int i) {
  final r = i ~/ n, c = i % n;
  final usados = <int>{};
  for (var k = 0; k < n; k++) {
    usados.add(g[r * n + k]);
    usados.add(g[k * n + c]);
  }
  return [for (var v = 1; v <= n; v++) if (!usados.contains(v)) v];
}

bool conflita(List<int> g, int n, int i, int v) {
  final r = i ~/ n, c = i % n;
  for (var k = 0; k < n; k++) {
    var j = r * n + k;
    if (j != i && g[j] == v) return true;
    j = k * n + c;
    if (j != i && g[j] == v) return true;
  }
  return false;
}

Set<int> celulasEmConflito(List<int> g, int n) => {
      for (var i = 0; i < g.length; i++)
        if (g[i] != 0 && conflita(g, n, i, g[i])) i
    };

bool ehQuadradoLatino(List<int> g, int n) {
  final alvo = {for (var v = 1; v <= n; v++) v};
  for (var k = 0; k < n; k++) {
    final linha = {for (var c = 0; c < n; c++) g[k * n + c]};
    final coluna = {for (var r = 0; r < n; r++) g[r * n + k]};
    if (linha.length != n || !linha.containsAll(alvo)) return false;
    if (coluna.length != n || !coluna.containsAll(alvo)) return false;
  }
  return true;
}

/// Todos os quadrados latinos de ordem n (3 -> 12, 4 -> 576), em ordem fixa.
List<List<int>> quadradosLatinos(int n) {
  final res = <List<int>>[];
  final g = List<int>.filled(n * n, 0);
  void bt(int i) {
    if (i == n * n) {
      res.add(List<int>.of(g));
      return;
    }
    final r = i ~/ n, c = i % n;
    for (var v = 1; v <= n; v++) {
      var ok = true;
      for (var k = 0; k < c && ok; k++) {
        if (g[r * n + k] == v) ok = false;
      }
      for (var k = 0; k < r && ok; k++) {
        if (g[k * n + c] == v) ok = false;
      }
      if (ok) {
        g[i] = v;
        bt(i + 1);
        g[i] = 0;
      }
    }
  }

  bt(0);
  return res;
}

/// Conta soluções até [limite] (backtracking com a casa mais restrita primeiro).
int contarSolucoes(List<int> grade, int n, [int limite = 2]) {
  final g = List<int>.of(grade);
  for (var i = 0; i < g.length; i++) {
    if (g[i] != 0 && conflita(g, n, i, g[i])) return 0;
  }
  var total = 0;
  void bt() {
    var melhor = -1;
    List<int> cands = const [];
    for (var i = 0; i < n * n; i++) {
      if (g[i] == 0) {
        final cs = candidatos(g, n, i);
        if (cs.isEmpty) return;
        if (melhor < 0 || cs.length < cands.length) {
          melhor = i;
          cands = cs;
        }
      }
    }
    if (melhor < 0) {
      total++;
      return;
    }
    for (final v in cands) {
      g[melhor] = v;
      bt();
      g[melhor] = 0;
      if (total >= limite) return;
    }
  }

  bt();
  return total;
}

// -----------------------------------------------------------------------------
// Puzzle e catálogo
// -----------------------------------------------------------------------------
class Puzzle {
  final int id;
  final int nivel;
  final int indiceNoNivel; // 1..30
  final TipoPuzzle tipo;
  final int n;
  final int qtdSimbolos;
  final List<int> inicial; // 0 = vazio
  final List<int> alvo; // solução / padrão a recriar

  Puzzle(this.id, this.nivel, this.indiceNoNivel, this.tipo, this.n, this.qtdSimbolos,
      List<int> inicial, List<int> alvo)
      : inicial = List.unmodifiable(inicial),
        alvo = List.unmodifiable(alvo);

  Set<int> get fixas => {
        for (var i = 0; i < inicial.length; i++)
          if (inicial[i] != 0) i
      };

  String get chave => '${tipo.name}|$n|${inicial.join(',')}|${alvo.join(',')}';
}

int _contaNaoZero(List<int> l) => l.where((v) => v != 0).length;

List<Puzzle> construirCatalogo() {
  final soma = niveis.fold<int>(0, (a, c) => a + c.qtd);
  if (soma > maxPuzzles) {
    throw StateError('Configuração de níveis excede o teto de $maxPuzzles puzzles.');
  }
  final rng = GeradorDeterministico(sementeCatalogo);
  final latinos = {3: quadradosLatinos(3), 4: quadradosLatinos(4)};
  final vistos = <String>{};
  final catalogo = <Puzzle>[];

  for (final cfg in niveis) {
    final nn = cfg.tam * cfg.tam;
    final lote = <List<List<int>>>[]; // [inicial, alvo]
    var tentativas = 0;
    while (lote.length < cfg.qtd) {
      tentativas++;
      if (tentativas > 50000) {
        throw StateError('Não foi possível gerar o nível ${cfg.numero}.');
      }
      List<int> ini;
      List<int> alvo;
      if (cfg.tipo == TipoPuzzle.memoria) {
        final k = rng.entre(cfg.faixaMin, cfg.faixaMax);
        final casas = rng.amostra(nn, k);
        alvo = List<int>.filled(nn, 0);
        for (final c in casas) {
          alvo[c] = rng.entre(1, cfg.qtdSimbolos);
        }
        final tipos = {for (final c in casas) alvo[c]};
        final esperado = cfg.qtdSimbolos < k ? cfg.qtdSimbolos : k;
        if (tipos.length != esperado) continue; // usa todos os tipos de peça
        ini = List<int>.filled(nn, 0);
      } else {
        final solucao = rng.escolher(latinos[cfg.tam]!);
        final meta = rng.entre(cfg.faixaMin, cfg.faixaMax);
        final g = List<int>.of(solucao);
        final ordem = List<int>.generate(nn, (i) => i);
        rng.embaralhar(ordem);
        for (final i in ordem) {
          if (_contaNaoZero(g) <= meta) break;
          final guardado = g[i];
          g[i] = 0;
          if (contarSolucoes(g, cfg.tam, 2) != 1) g[i] = guardado; // manteria ambiguidade
        }
        if (_contaNaoZero(g) != meta) continue;
        ini = g;
        alvo = List<int>.of(solucao);
      }
      final chave = '${cfg.tipo.name}|${cfg.tam}|${ini.join(',')}|${alvo.join(',')}';
      if (!vistos.add(chave)) continue;
      lote.add([ini, alvo]);
    }

    // Progressão gentil dentro do nível. Ordenação ESTÁVEL (desempate pelo
    // índice original), porque List.sort do Dart não garante estabilidade.
    final indices = List<int>.generate(lote.length, (i) => i);
    int comparar(int a, int b) {
      final ea = lote[a], eb = lote[b];
      int r;
      if (cfg.tipo == TipoPuzzle.memoria) {
        r = _contaNaoZero(ea[1]).compareTo(_contaNaoZero(eb[1]));
        if (r == 0) {
          r = ea[1].where((v) => v != 0).toSet().length
              .compareTo(eb[1].where((v) => v != 0).toSet().length);
        }
      } else {
        r = _contaNaoZero(eb[0]).compareTo(_contaNaoZero(ea[0])); // mais pistas primeiro
      }
      return r != 0 ? r : a.compareTo(b);
    }

    indices.sort(comparar);
    var k = 1;
    for (final idx in indices) {
      catalogo.add(Puzzle(catalogo.length + 1, cfg.numero, k++, cfg.tipo, cfg.tam,
          cfg.qtdSimbolos, lote[idx][0], lote[idx][1]));
    }
  }
  if (catalogo.length > maxPuzzles) {
    throw StateError('Catálogo excede o teto de $maxPuzzles puzzles.');
  }
  return List.unmodifiable(catalogo);
}

List<Puzzle>? _cache;

/// Catálogo único do app (gerado uma vez, em memória, em menos de 1 s).
List<Puzzle> get catalogo => _cache ??= construirCatalogo();

/// FNV-1a 32 bits sobre a descrição de todos os puzzles.
String impressaoDigital(List<Puzzle> cat) {
  var h = 0x811C9DC5;
  final texto = StringBuffer();
  for (final p in cat) {
    texto.write('${p.id}|${p.nivel}|${p.chave};');
  }
  for (final b in texto.toString().codeUnits) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

// -----------------------------------------------------------------------------
// Dicas graduais
//   nível 1  -> lembrete em palavras (regra ou contagem de peças)
//   nível 2  -> destaca UMA casa para observar
//   nível 3+ -> coloca UMA peça correta (uma por pedido)
// -----------------------------------------------------------------------------
enum TipoDica { texto, destacar, preencher }

class Dica {
  final TipoDica tipo;
  final int? celula;
  final int? valor;
  final String mensagem;
  const Dica(this.tipo, this.mensagem, {this.celula, this.valor});
}

Dica calcularDica(Puzzle p, List<int> estado, int nivel) {
  final nn = p.n * p.n;
  if (p.tipo == TipoPuzzle.memoria) {
    if (nivel <= 1) {
      final cont = <int, int>{};
      for (final v in p.alvo) {
        if (v != 0) cont[v] = (cont[v] ?? 0) + 1;
      }
      final chaves = cont.keys.toList()..sort();
      final partes = [for (final v in chaves) '${cont[v]} ${simbolos[v]!.rotuloMinusculo}'];
      final total = cont.values.fold<int>(0, (a, b) => a + b);
      return Dica(TipoDica.texto,
          'Dica: o padrão tem $total peças (${partes.join(', ')}). Se quiser, toque em “Rever padrão”.');
    }
    int? errada;
    for (var i = 0; i < nn; i++) {
      if (estado[i] != p.alvo[i]) {
        errada = i;
        break;
      }
    }
    if (errada == null) {
      return const Dica(TipoDica.texto, 'Seu tabuleiro já está igual ao padrão.');
    }
    if (nivel == 2) {
      return Dica(TipoDica.destacar,
          'Observe com calma a casa destacada: ela está diferente do padrão.',
          celula: errada);
    }
    final v = p.alvo[errada];
    final msg = v == 0
        ? 'Esta casa deveria ficar vazia. Retirei a peça para você.'
        : 'Coloquei um ${simbolos[v]!.rotuloMinusculo} na casa destacada. Continue no seu ritmo.';
    return Dica(TipoDica.preencher, msg, celula: errada, valor: v);
  }

  // ---- lógica ----
  if (nivel <= 1) {
    return const Dica(
        TipoDica.texto,
        'Regra: em cada linha (deitada) e em cada coluna (em pé), cada símbolo '
        'aparece uma única vez. Comece pela linha ou coluna mais cheia.');
  }
  final conflitos = celulasEmConflito(estado, p.n);
  final erradas = [
    for (var i = 0; i < nn; i++)
      if (estado[i] != 0 && estado[i] != p.alvo[i]) i
  ];
  final vazias = [
    for (var i = 0; i < nn; i++)
      if (estado[i] == 0) i
  ];
  int cel;
  String motivo;
  if (erradas.isNotEmpty) {
    final pref = erradas.where(conflitos.contains).toList();
    cel = (pref.isNotEmpty ? pref : erradas).first;
    motivo = 'errada';
  } else if (vazias.isNotEmpty) {
    final unicas = vazias.where((i) => candidatos(estado, p.n, i).length == 1).toList();
    if (unicas.isNotEmpty) {
      cel = unicas.first;
      motivo = 'unica';
    } else {
      cel = vazias.first;
      motivo = 'vazia';
    }
  } else {
    return const Dica(TipoDica.texto, 'Tudo preenchido corretamente!');
  }
  if (nivel == 2) {
    const msgs = {
      'errada': 'A casa destacada merece uma segunda olhada.',
      'unica': 'A casa destacada só aceita um símbolo. Veja o que já existe na linha e na coluna.',
      'vazia': 'Tente a casa destacada: veja quais símbolos faltam na linha e na coluna dela.',
    };
    return Dica(TipoDica.destacar, msgs[motivo]!, celula: cel);
  }
  return Dica(TipoDica.preencher,
      'Coloquei um ${simbolos[p.alvo[cel]]!.rotuloMinusculo} na casa destacada. Continue no seu ritmo.',
      celula: cel, valor: p.alvo[cel]);
}

// -----------------------------------------------------------------------------
// Validação completa (usada pelos testes). Retorna a lista de problemas.
// -----------------------------------------------------------------------------
List<String> validarCatalogo(List<Puzzle> cat) {
  final erros = <String>[];
  if (cat.length > maxPuzzles) erros.add('Catálogo acima do teto ($maxPuzzles).');
  for (var i = 0; i < cat.length; i++) {
    if (cat[i].id != i + 1) erros.add('IDs não sequenciais.');
  }
  if (cat.map((p) => p.chave).toSet().length != cat.length) {
    erros.add('Há combinações duplicadas.');
  }
  for (final cfg in niveis) {
    final lote = cat.where((p) => p.nivel == cfg.numero).toList();
    if (lote.length != cfg.qtd) {
      erros.add('Nível ${cfg.numero} com ${lote.length} puzzles (esperado ${cfg.qtd}).');
    }
    for (final p in lote) {
      final nn = p.n * p.n;
      if (p.inicial.length != nn || p.alvo.length != nn) {
        erros.add('#${p.id}: tamanho incorreto.');
        continue;
      }
      if ([...p.inicial, ...p.alvo].any((v) => v < 0 || v > p.qtdSimbolos)) {
        erros.add('#${p.id}: símbolo fora do intervalo.');
      }
      int medida;
      if (p.tipo == TipoPuzzle.logica) {
        if (!ehQuadradoLatino(p.alvo, p.n)) erros.add('#${p.id}: solução inválida.');
        for (var i = 0; i < nn; i++) {
          if (p.inicial[i] != 0 && p.inicial[i] != p.alvo[i]) {
            erros.add('#${p.id}: pistas incoerentes.');
            break;
          }
        }
        final sols = contarSolucoes(p.inicial, p.n, 3);
        if (sols != 1) erros.add('#${p.id}: $sols soluções (deveria ser 1).');
        medida = _contaNaoZero(p.inicial);
      } else {
        if (p.inicial.any((v) => v != 0)) erros.add('#${p.id}: memória com início não vazio.');
        medida = _contaNaoZero(p.alvo);
        final tipos = p.alvo.where((v) => v != 0).toSet().length;
        final esperado = p.qtdSimbolos < medida ? p.qtdSimbolos : medida;
        if (tipos != esperado) erros.add('#${p.id}: não usa todos os tipos de peça.');
      }
      if (medida < cfg.faixaMin || medida > cfg.faixaMax) {
        erros.add('#${p.id}: $medida fora da faixa ${cfg.faixaMin}-${cfg.faixaMax}.');
      }
      // Dicas: só "preencher", a partir do início e de um estado bagunçado,
      // sempre chega à solução em no máximo n*n passos.
      final rng = GeradorDeterministico(p.id * 7919);
      final bagunca = List<int>.of(p.inicial);
      for (var i = 0; i < nn; i++) {
        if (!p.fixas.contains(i) && rng.inteiro(2) == 0) {
          bagunca[i] = rng.entre(0, p.qtdSimbolos);
        }
      }
      for (final inicio in [List<int>.of(p.inicial), bagunca]) {
        final est = inicio;
        for (var passo = 0; passo <= nn; passo++) {
          if (_iguais(est, p.alvo)) break;
          final d = calcularDica(p, est, 3);
          if (d.tipo != TipoDica.preencher || p.fixas.contains(d.celula)) {
            erros.add('#${p.id}: dica inválida.');
            break;
          }
          est[d.celula!] = d.valor!;
        }
        if (!_iguais(est, p.alvo)) erros.add('#${p.id}: as dicas não levam à solução.');
      }
    }
  }
  return erros;
}

bool _iguais(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool estadosIguais(List<int> a, List<int> b) => _iguais(a, b);
