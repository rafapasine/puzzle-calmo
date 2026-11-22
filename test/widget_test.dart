// Teste de interface: abre o app num "celular" de 360 x 780 dp, inicia o
// nível 1 e resolve um puzzle de memória só com dicas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:puzzle_calmo/main.dart';
import 'package:puzzle_calmo/progresso.dart';

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pump(const Duration(milliseconds: 600)); // passa a pausa de vitória
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('menu -> nível 1 -> resolver com dicas -> concluído', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    await progresso.carregar();
    progresso.respiracao = false;

    await tester.pumpWidget(const PuzzleCalmoApp());
    await tester.pumpAndSettle();
    expect(find.text('Puzzle Calmo'), findsOneWidget);
    expect(find.text('Como jogar'), findsOneWidget);

    await tocar(tester, find.textContaining('Iniciar'));
    expect(find.text('Já memorizei'), findsOneWidget);

    await tocar(tester, find.text('Já memorizei'));
    expect(find.text('Rever padrão'), findsOneWidget);

    for (var i = 0; i < 12 && find.text('Próximo puzzle').evaluate().isEmpty; i++) {
      await tocar(tester, find.text('Dica gentil'));
    }
    expect(find.text('Próximo puzzle'), findsOneWidget);
    expect(progresso.concluidos.contains(1), isTrue);

    await tocar(tester, find.text('Próximo puzzle'));
    expect(find.text('Já memorizei'), findsOneWidget);
  });

  testWidgets('telas de nível, ajustes e como jogar abrem sem erro', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await progresso.carregar();

    await tester.pumpWidget(const PuzzleCalmoApp());
    await tester.pumpAndSettle();
    for (final nome in ['Escolher nível e ritmo', 'Como jogar', 'Ajustes']) {
      await tocar(tester, find.text(nome));
      expect(find.byType(BackButton), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
