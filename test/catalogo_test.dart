// Validação do catálogo: rode com `flutter test`.
// O script gerar_apk.ps1 executa estes testes ANTES de gerar o .apk.

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_calmo/catalogo.dart';

void main() {
  final cat = construirCatalogo();

  test('gerador xorshift32 produz a sequência de referência', () {
    final g = GeradorDeterministico(sementeCatalogo);
    expect([g.proximo(), g.proximo(), g.proximo()], [649222664, 3550409425, 3042857555]);
  });

  test('no máximo 200 puzzles, 30 por nível', () {
    expect(cat.length, lessThanOrEqualTo(maxPuzzles));
    expect(cat.length, 180);
    for (final nv in niveis) {
      expect(cat.where((p) => p.nivel == nv.numero).length, nv.qtd, reason: 'nível ${nv.numero}');
    }
  });

  test('catálogo determinístico (gerado duas vezes, idêntico)', () {
    expect(construirCatalogo().map((p) => p.chave).toList(), cat.map((p) => p.chave).toList());
  });

  test('todas as combinações são únicas', () {
    expect(cat.map((p) => p.chave).toSet().length, cat.length);
  });

  test('validação completa: solução única, faixas, e dicas sempre resolvem', () {
    expect(validarCatalogo(cat), isEmpty);
  });

  test('impressão digital igual à do conferidor em Python', () {
    expect(impressaoDigital(cat), impressaoEsperada);
  });

  test('primeiro puzzle de lógica bate com o conferidor em Python', () {
    final p = cat.firstWhere((x) => x.nivel == 2);
    expect(p.id, 31);
    expect(p.inicial, [2, 1, 3, 0, 2, 0, 1, 0, 2]);
    expect(p.alvo, [2, 1, 3, 3, 2, 1, 1, 3, 2]);
  });

  test('dicas de lógica seguem os 3 degraus', () {
    final p = cat.firstWhere((x) => x.tipo == TipoPuzzle.logica);
    final est = List<int>.of(p.inicial);
    expect(calcularDica(p, est, 1).tipo, TipoDica.texto);
    final d2 = calcularDica(p, est, 2);
    expect(d2.tipo, TipoDica.destacar);
    expect(p.fixas.contains(d2.celula), isFalse);
    final d3 = calcularDica(p, est, 3);
    expect(d3.tipo, TipoDica.preencher);
    expect(d3.valor, p.alvo[d3.celula!]);
  });
}
