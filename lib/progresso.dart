// =============================================================================
// Puzzle Calmo (Android) - ajustes e progresso salvos só no aparelho.
// Usa shared_preferences (armazenamento local do Android). Nada vai para a
// internet: o app não pede a permissão INTERNET.
// =============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogo.dart';

class Ritmo {
  final String chave;
  final String nome;
  final int animMs; // duração das transições suaves
  final int reverS; // segundos de revisão do padrão
  final int respiroS; // duração de um ciclo de respiração
  final int vitoriaMs; // pausa antes de mostrar "concluído"
  final String descricao;
  const Ritmo(this.chave, this.nome, this.animMs, this.reverS, this.respiroS, this.vitoriaMs,
      this.descricao);
}

const Map<String, Ritmo> ritmos = {
  'calmo': Ritmo('calmo', 'Calmo', 1100, 8, 10, 500,
      'Transições lentas, revisão do padrão por 8 s, respiração de 10 s.'),
  'tranquilo': Ritmo('tranquilo', 'Tranquilo', 350, 5, 8, 200,
      'Transições curtas, revisão do padrão por 5 s, respiração de 8 s.'),
};

class Progresso extends ChangeNotifier {
  static const _chave = 'puzzle_calmo_dados_v1';
  SharedPreferences? _prefs;

  // Ajustes (valores padrão pensados para os dois públicos)
  String ritmoChave = 'calmo';
  bool som = false; // mudo por padrão
  bool vibracao = false; // sem vibração por padrão
  bool respiracao = true;
  bool textoGrande = false;
  bool protecaoToque = true; // ignora toque duplo acidental (tremor)
  int nivel = 1;

  // Progresso sem pressão
  final Set<int> concluidos = {};
  final Map<String, int> historico = {};
  int sessao = 0;

  Ritmo get ritmo => ritmos[ritmoChave] ?? ritmos['calmo']!;

  Future<void> carregar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final bruto = _prefs!.getString(_chave);
      if (bruto == null) return;
      final m = jsonDecode(bruto) as Map<String, dynamic>;
      final cfg = (m['config'] as Map?)?.cast<String, dynamic>() ?? {};
      final r = cfg['ritmo'];
      if (r is String && ritmos.containsKey(r)) ritmoChave = r;
      som = cfg['som'] == true;
      vibracao = cfg['vibracao'] == true;
      respiracao = cfg['respiracao'] != false;
      textoGrande = cfg['textoGrande'] == true;
      protecaoToque = cfg['protecaoToque'] != false;
      final n = cfg['nivel'];
      if (n is int && niveis.any((c) => c.numero == n)) nivel = n;
      concluidos
        ..clear()
        ..addAll(((m['concluidos'] as List?) ?? const []).whereType<int>());
      historico
        ..clear()
        ..addAll(((m['historico'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), v is int ? v : 0)));
    } catch (_) {
      // Dados corrompidos ou indisponíveis: segue com os padrões, sem travar.
    }
  }

  Map<String, dynamic> _paraJson() => {
        'config': {
          'ritmo': ritmoChave,
          'som': som,
          'vibracao': vibracao,
          'respiracao': respiracao,
          'textoGrande': textoGrande,
          'protecaoToque': protecaoToque,
          'nivel': nivel,
        },
        'concluidos': concluidos.toList()..sort(),
        'historico': historico,
      };

  Future<void> _salvar() async {
    try {
      await _prefs?.setString(_chave, jsonEncode(_paraJson()));
    } catch (_) {}
  }

  /// Altera ajustes/progresso, salva e avisa as telas.
  void alterar(void Function() mudanca) {
    mudanca();
    _salvar();
    notifyListeners();
  }

  static String _hoje() {
    final d = DateTime.now();
    String dois(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${dois(d.month)}-${dois(d.day)}';
  }

  int get concluidosHoje => historico[_hoje()] ?? 0;

  void marcarConcluido(int id) => alterar(() {
        concluidos.add(id);
        historico[_hoje()] = concluidosHoje + 1;
        sessao++;
      });

  void apagarTudo() => alterar(() {
        concluidos.clear();
        historico.clear();
        nivel = 1;
      });

  String textoProgresso() =>
      'Hoje: $concluidosHoje puzzle(s) concluído(s) · Nesta sessão: $sessao\n'
      'Você já explorou ${concluidos.length} dos ${catalogo.length} puzzles.';

  /// Próximo puzzle pendente do nível; se o nível acabou, segue para outro
  /// nível com pendências; se tudo acabou, repete o nível em ordem (revisão).
  (Puzzle, String) escolherPuzzle(int nivelDesejado, {Puzzle? apos}) {
    final lista = catalogo.where((p) => p.nivel == nivelDesejado).toList();
    final pendentes = lista.where((p) => !concluidos.contains(p.id)).toList();
    if (pendentes.isNotEmpty) {
      final depois = pendentes.where((p) => apos == null || p.id > apos.id).toList();
      return ((depois.isNotEmpty ? depois : pendentes).first, '');
    }
    final outros = catalogo.where((p) => !concluidos.contains(p.id)).toList();
    if (outros.isNotEmpty) {
      final seguintes = outros.where((p) => p.nivel > nivelDesejado).toList();
      final p = (seguintes.isNotEmpty ? seguintes : outros).first;
      return (
        p,
        'Você concluiu todo o Nível $nivelDesejado. Seguimos com calma para o Nível ${p.nivel}.'
      );
    }
    const revisao = 'Todos os puzzles já foram concluídos. Este é um momento de revisão.';
    if (apos != null && apos.nivel == nivelDesejado) {
      final seguintes = lista.where((p) => p.id > apos.id).toList();
      return ((seguintes.isNotEmpty ? seguintes : lista).first, revisao);
    }
    return (lista.first, revisao);
  }
}

/// Instância única usada pelo app.
final Progresso progresso = Progresso();
