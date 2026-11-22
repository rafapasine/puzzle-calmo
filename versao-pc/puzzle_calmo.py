#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Puzzle Calmo  -  jogo de lógica e memória operacional em ritmo lento.

Público:
  * pessoas com hiperatividade / agitação mental (foco calmo, sem relógio);
  * pessoas com declínio cognitivo leve a moderado (clareza, baixo ruído,
    progressão gentil).

Mecânicas (duas, alternadas ao longo de 6 níveis):
  1. MEMÓRIA  - observe um padrão de peças numa grade 3x3 ou 4x4 (sem limite
                de tempo), esconda-o e recrie-o. Pode rever o padrão quando
                quiser sem perder o progresso.
  2. LÓGICA   - complete a grade de modo que cada linha e cada coluna tenham
                todos os símbolos sem repetir (quadrado latino 3x3 / 4x4).
                Cada puzzle tem solução ÚNICA, verificada por um resolvedor.

Garantia de no máximo 200 combinações:
  * o catálogo é gerado de forma determinística a partir de uma SEMENTE FIXA,
    com quantidade fixa por nível (6 x 30 = 180);
  * duplicatas são descartadas; o total é verificado contra MAX_PUZZLES = 200;
  * o jogo NUNCA cria puzzles fora do catálogo durante a partida.

Uso:
  python puzzle_calmo.py              -> abre o jogo
  python puzzle_calmo.py --validar    -> valida o catálogo e o sistema de dicas
  python puzzle_calmo.py --autoteste  -> abre a janela e joga sozinho (teste de fumaça)

Somente biblioteca padrão (tkinter, json, wave, winsound). Python 3.8+.
"""

import sys
import os
import json
import math
import time
import random
import hashlib
import struct
import wave
import tempfile
import datetime
import traceback
from dataclasses import dataclass

import tkinter as tk
from tkinter import font as tkfont
from tkinter import messagebox

# =============================================================================
# 1. CONSTANTES GERAIS
# =============================================================================

APP_NOME = "Puzzle Calmo"
APP_VERSAO = "1.0"
MAX_PUZZLES = 200            # teto absoluto de combinações únicas
SEMENTE_CATALOGO = 20261122  # semente fixa -> catálogo sempre idêntico

# Paleta suave, sem neon, com contraste de texto >= 4.5:1 (WCAG AA).
COR = {
    "fundo": "#F3F0E8",          # creme claro, reduz brilho
    "celula": "#FFFFFF",
    "celula_fixa": "#E2DCCE",    # casas que já vêm prontas (lógica)
    "borda": "#B3AB9B",
    "texto": "#2B2F33",          # contraste ~12:1 sobre o fundo
    "texto_suave": "#555B61",    # contraste ~6:1
    "primario": "#3F6896",       # azul acinzentado (texto branco ~5.9:1)
    "primario_ativo": "#355A82",
    "botao": "#E0D9CB",
    "botao_ativo": "#D2C9B8",
    "destaque": "#C28E25",       # âmbar suave para dicas
    "conflito": "#C9825A",       # terracota suave para repetições
    "sucesso": "#4B7A55",        # verde sálvia escuro
    "foco": "#3F6896",
    "respiro": "#A9BFD6",
}

# Símbolos: forma + cor (nunca só cor -> acessível para daltonismo).
# valor -> (nome, cor por extenso, hex, forma)
SIMBOLOS = {
    1: ("Círculo", "azul", "#4F7CAC", "circulo"),
    2: ("Quadrado", "verde", "#5E8C61", "quadrado"),
    3: ("Triângulo", "laranja", "#C07A45", "triangulo"),
    4: ("Losango", "lilás", "#7E6BA8", "losango"),
}

# Definição dos níveis: alternam memória e lógica, com carga crescente.
NIVEIS = [
    dict(n=1, titulo="Lembrar", tipo="memoria", tam=3, simbolos=1, faixa=(2, 3), qtd=30,
         desc="Memória · grade 3×3 · 2 a 3 círculos"),
    dict(n=2, titulo="Completar", tipo="logica", tam=3, simbolos=3, faixa=(5, 6), qtd=30,
         desc="Lógica · grade 3×3 · 3 símbolos, muitas pistas"),
    dict(n=3, titulo="Lembrar mais", tipo="memoria", tam=3, simbolos=2, faixa=(3, 4), qtd=30,
         desc="Memória · grade 3×3 · 3 a 4 peças de 2 tipos"),
    dict(n=4, titulo="Completar mais", tipo="logica", tam=4, simbolos=4, faixa=(9, 10), qtd=30,
         desc="Lógica · grade 4×4 · 4 símbolos, muitas pistas"),
    dict(n=5, titulo="Lembrar com atenção", tipo="memoria", tam=4, simbolos=3, faixa=(4, 5), qtd=30,
         desc="Memória · grade 4×4 · 4 a 5 peças de 3 tipos"),
    dict(n=6, titulo="Deduzir", tipo="logica", tam=4, simbolos=4, faixa=(6, 7), qtd=30,
         desc="Lógica · grade 4×4 · poucas pistas"),
]
NIVEL_POR_NUM = {c["n"]: c for c in NIVEIS}

# Ritmos: afetam animações e tempo de revisão; NUNCA há tempo-limite.
RITMOS = {
    "calmo": dict(nome="Calmo", anim_ms=1100, rever_s=8, respiro_s=10, vitoria_ms=500,
                  desc="Transições lentas, revisão do padrão por 8 s, respiração de 10 s."),
    "tranquilo": dict(nome="Tranquilo", anim_ms=350, rever_s=5, respiro_s=8, vitoria_ms=200,
                      desc="Transições curtas, revisão do padrão por 5 s, respiração de 8 s."),
}


# =============================================================================
# 2. LÓGICA PURA (sem interface) - quadrados latinos, resolvedor, catálogo
# =============================================================================

def candidatos(grade, n, i):
    """Símbolos que podem ir na casa i sem repetir na linha/coluna."""
    r, c = divmod(i, n)
    usados = set()
    for k in range(n):
        usados.add(grade[r * n + k])
        usados.add(grade[k * n + c])
    return {v for v in range(1, n + 1) if v not in usados}


def conflita(grade, n, i, v):
    """True se o valor v na casa i repete na mesma linha ou coluna."""
    r, c = divmod(i, n)
    for k in range(n):
        j = r * n + k
        if j != i and grade[j] == v:
            return True
        j = k * n + c
        if j != i and grade[j] == v:
            return True
    return False


def celulas_em_conflito(grade, n):
    """Conjunto de casas preenchidas que repetem símbolo na linha/coluna."""
    return {i for i, v in enumerate(grade) if v and conflita(grade, n, i, v)}


def eh_quadrado_latino(grade, n):
    alvo = set(range(1, n + 1))
    for k in range(n):
        if {grade[k * n + c] for c in range(n)} != alvo:
            return False
        if {grade[r * n + k] for r in range(n)} != alvo:
            return False
    return True


def quadrados_latinos(n):
    """Enumera todos os quadrados latinos de ordem n (3 -> 12, 4 -> 576)."""
    res = []
    g = [0] * (n * n)

    def bt(i):
        if i == n * n:
            res.append(tuple(g))
            return
        r, c = divmod(i, n)
        for v in range(1, n + 1):
            if all(g[r * n + k] != v for k in range(c)) and all(g[k * n + c] != v for k in range(r)):
                g[i] = v
                bt(i + 1)
                g[i] = 0

    bt(0)
    return res


def contar_solucoes(grade, n, limite=2):
    """Conta soluções (até 'limite') por backtracking com heurística MRV."""
    g = list(grade)
    for i, v in enumerate(g):
        if v and conflita(g, n, i, v):
            return 0
    total = [0]

    def bt():
        melhor, cands = None, None
        for i in range(n * n):
            if g[i] == 0:
                cs = candidatos(g, n, i)
                if not cs:
                    return
                if melhor is None or len(cs) < len(cands):
                    melhor, cands = i, cs
        if melhor is None:
            total[0] += 1
            return
        for v in sorted(cands):
            g[melhor] = v
            bt()
            g[melhor] = 0
            if total[0] >= limite:
                return

    bt()
    return total[0]


@dataclass(frozen=True)
class Puzzle:
    id: int
    nivel: int
    indice_no_nivel: int   # 1..30
    tipo: str              # "memoria" | "logica"
    n: int                 # lado da grade
    simbolos: int          # quantos símbolos diferentes existem
    inicial: tuple         # estado inicial (0 = vazio)
    alvo: tuple            # solução / padrão a recriar

    @property
    def fixas(self):
        return frozenset(i for i, v in enumerate(self.inicial) if v)

    @property
    def chave(self):
        return (self.tipo, self.n, self.inicial, self.alvo)


def _gerar_memoria(rng, cfg):
    n, s = cfg["tam"], cfg["simbolos"]
    k = rng.randint(*cfg["faixa"])
    casas = rng.sample(range(n * n), k)
    alvo = [0] * (n * n)
    for c in casas:
        alvo[c] = rng.randint(1, s)
    if len({alvo[c] for c in casas}) != min(s, k):   # usa todos os tipos de peça
        return None
    return tuple([0] * (n * n)), tuple(alvo)


def _gerar_logica(rng, cfg, latinos):
    n = cfg["tam"]
    solucao = rng.choice(latinos[n])
    meta = rng.randint(*cfg["faixa"])
    grade = list(solucao)
    ordem = list(range(n * n))
    rng.shuffle(ordem)
    for i in ordem:
        if sum(1 for v in grade if v) <= meta:
            break
        guardado = grade[i]
        grade[i] = 0
        if contar_solucoes(grade, n, 2) != 1:   # retirar quebraria a unicidade
            grade[i] = guardado
    if sum(1 for v in grade if v) != meta:
        return None
    return tuple(grade), tuple(solucao)


def construir_catalogo():
    """Gera o catálogo determinístico e limitado (<= MAX_PUZZLES)."""
    if sum(c["qtd"] for c in NIVEIS) > MAX_PUZZLES:
        raise ValueError("Configuração de níveis excede o teto de %d puzzles." % MAX_PUZZLES)
    rng = random.Random(SEMENTE_CATALOGO)
    latinos = {3: quadrados_latinos(3), 4: quadrados_latinos(4)}
    vistos = set()
    catalogo = []
    for cfg in NIVEIS:
        lote, tentativas = [], 0
        while len(lote) < cfg["qtd"]:
            tentativas += 1
            if tentativas > 50000:
                raise RuntimeError("Não foi possível gerar o nível %d." % cfg["n"])
            if cfg["tipo"] == "memoria":
                r = _gerar_memoria(rng, cfg)
            else:
                r = _gerar_logica(rng, cfg, latinos)
            if r is None:
                continue
            chave = (cfg["tipo"], cfg["tam"], r[0], r[1])
            if chave in vistos:
                continue
            vistos.add(chave)
            lote.append(r)
        # Progressão gentil dentro do nível: do mais simples ao menos simples.
        if cfg["tipo"] == "memoria":
            lote.sort(key=lambda r: (sum(1 for v in r[1] if v), len(set(r[1]))))
        else:
            lote.sort(key=lambda r: -sum(1 for v in r[0] if v))
        for k, (ini, alv) in enumerate(lote, start=1):
            catalogo.append(Puzzle(len(catalogo) + 1, cfg["n"], k, cfg["tipo"], cfg["tam"],
                                   cfg["simbolos"], ini, alv))
    if len(catalogo) > MAX_PUZZLES:
        raise RuntimeError("Catálogo excede o teto de %d puzzles." % MAX_PUZZLES)
    return tuple(catalogo)


def impressao_digital(catalogo):
    """Hash curto do catálogo: muda se qualquer puzzle mudar."""
    bruto = repr([(p.id, p.nivel, p.chave) for p in catalogo]).encode("utf-8")
    return hashlib.sha256(bruto).hexdigest()[:16]


_CATALOGO = None


def obter_catalogo():
    global _CATALOGO
    if _CATALOGO is None:
        _CATALOGO = construir_catalogo()
    return _CATALOGO


# -----------------------------------------------------------------------------
# Sistema de dicas graduais (puro, testável)
#   nível 1 -> lembrete verbal (regra ou contagem de peças)
#   nível 2 -> destaca UMA casa a observar
#   nível 3+ -> coloca UMA peça correta (uma por pedido)
# -----------------------------------------------------------------------------

def nome_simbolo(v):
    nome, cor, _, _ = SIMBOLOS[v]
    return "%s %s" % (nome.lower(), cor)


def calcular_dica(p, estado, nivel):
    nn = p.n * p.n
    if p.tipo == "memoria":
        if nivel <= 1:
            cont = {}
            for v in p.alvo:
                if v:
                    cont[v] = cont.get(v, 0) + 1
            partes = ["%d %s" % (q, nome_simbolo(v)) for v, q in sorted(cont.items())]
            total = sum(cont.values())
            return dict(tipo="texto", celula=None, valor=None,
                        msg="Dica: o padrão tem %d peças (%s). Se quiser, use “Rever padrão”."
                            % (total, ", ".join(partes)))
        errada = next((i for i in range(nn) if estado[i] != p.alvo[i]), None)
        if errada is None:
            return dict(tipo="texto", celula=None, valor=None,
                        msg="Seu tabuleiro já está igual ao padrão.")
        if nivel == 2:
            return dict(tipo="destacar", celula=errada, valor=None,
                        msg="Observe com calma a casa destacada: ela está diferente do padrão.")
        if p.alvo[errada] == 0:
            msg = "Esta casa deveria ficar vazia. Retirei a peça para você."
        else:
            msg = "Coloquei um %s na casa destacada. Continue no seu ritmo." % nome_simbolo(p.alvo[errada])
        return dict(tipo="preencher", celula=errada, valor=p.alvo[errada], msg=msg)

    # ---- lógica ----
    if nivel <= 1:
        return dict(tipo="texto", celula=None, valor=None,
                    msg="Regra: em cada linha (deitada) e em cada coluna (em pé), cada símbolo "
                        "aparece uma única vez. Comece pela linha ou coluna mais cheia.")
    conflitos = celulas_em_conflito(estado, p.n)
    erradas = [i for i in range(nn) if estado[i] and estado[i] != p.alvo[i]]
    vazias = [i for i in range(nn) if estado[i] == 0]
    if erradas:
        prefer = [i for i in erradas if i in conflitos]
        cel, motivo = (prefer or erradas)[0], "errada"
    elif vazias:
        unicas = [i for i in vazias if len(candidatos(estado, p.n, i)) == 1]
        cel, motivo = (unicas[0], "unica") if unicas else (vazias[0], "vazia")
    else:
        return dict(tipo="texto", celula=None, valor=None, msg="Tudo preenchido corretamente!")
    if nivel == 2:
        msgs = {
            "errada": "A casa destacada merece uma segunda olhada.",
            "unica": "A casa destacada só aceita um símbolo. Veja o que já existe na linha e na coluna.",
            "vazia": "Tente a casa destacada: veja quais símbolos faltam na linha e na coluna dela.",
        }
        return dict(tipo="destacar", celula=cel, valor=None, msg=msgs[motivo])
    return dict(tipo="preencher", celula=cel, valor=p.alvo[cel],
                msg="Coloquei um %s na casa destacada. Continue no seu ritmo." % nome_simbolo(p.alvo[cel]))


# -----------------------------------------------------------------------------
# Validação completa (usada por --validar)
# -----------------------------------------------------------------------------

def validar_catalogo(saida=print):
    erros = []
    cat = construir_catalogo()
    cat2 = construir_catalogo()
    saida("=" * 64)
    saida("%s %s - validação do catálogo" % (APP_NOME, APP_VERSAO))
    saida("=" * 64)
    saida("Total de puzzles ............ %d (teto: %d)" % (len(cat), MAX_PUZZLES))
    if len(cat) > MAX_PUZZLES:
        erros.append("Catálogo acima do teto.")
    if cat != cat2:
        erros.append("Catálogo NÃO é determinístico.")
    saida("Determinístico .............. %s" % ("sim" if cat == cat2 else "NÃO"))
    if [p.id for p in cat] != list(range(1, len(cat) + 1)):
        erros.append("IDs não sequenciais.")
    chaves = [p.chave for p in cat]
    if len(set(chaves)) != len(chaves):
        erros.append("Há combinações duplicadas.")
    saida("Combinações únicas .......... %d de %d" % (len(set(chaves)), len(chaves)))
    saida("Impressão digital ........... %s" % impressao_digital(cat))
    saida("")

    for cfg in NIVEIS:
        lote = [p for p in cat if p.nivel == cfg["n"]]
        if len(lote) != cfg["qtd"]:
            erros.append("Nível %d com %d puzzles (esperado %d)." % (cfg["n"], len(lote), cfg["qtd"]))
        medidas = []
        for p in lote:
            nn = p.n * p.n
            if len(p.inicial) != nn or len(p.alvo) != nn:
                erros.append("#%d: tamanho incorreto." % p.id)
                continue
            if any(not (0 <= v <= p.simbolos) for v in p.inicial + p.alvo):
                erros.append("#%d: símbolo fora do intervalo." % p.id)
            if p.tipo == "logica":
                if not eh_quadrado_latino(p.alvo, p.n):
                    erros.append("#%d: solução não é quadrado latino." % p.id)
                if any(v and v != p.alvo[i] for i, v in enumerate(p.inicial)):
                    erros.append("#%d: pistas incoerentes com a solução." % p.id)
                sols = contar_solucoes(p.inicial, p.n, 3)
                if sols != 1:
                    erros.append("#%d: %d soluções (deveria ser 1)." % (p.id, sols))
                pistas = sum(1 for v in p.inicial if v)
                if not (cfg["faixa"][0] <= pistas <= cfg["faixa"][1]):
                    erros.append("#%d: %d pistas fora da faixa." % (p.id, pistas))
                medidas.append(pistas)
            else:
                if any(p.inicial):
                    erros.append("#%d: memória com estado inicial não vazio." % p.id)
                pecas = sum(1 for v in p.alvo if v)
                if not (cfg["faixa"][0] <= pecas <= cfg["faixa"][1]):
                    erros.append("#%d: %d peças fora da faixa." % (p.id, pecas))
                if len({v for v in p.alvo if v}) != min(p.simbolos, pecas):
                    erros.append("#%d: não usa todos os tipos de peça." % p.id)
                medidas.append(pecas)
            # Dicas: aplicar só "preencher" a partir de estados variados deve
            # sempre chegar à solução em no máximo n*n passos.
            rng = random.Random(p.id)
            estados = [list(p.inicial)]
            ruim = list(p.inicial)
            for i in range(nn):
                if i not in p.fixas and rng.random() < 0.5:
                    ruim[i] = rng.randint(0, p.simbolos)
            estados.append(ruim)
            for est in estados:
                for _ in range(nn + 1):
                    if tuple(est) == p.alvo:
                        break
                    d = calcular_dica(p, est, 3)
                    if d["tipo"] != "preencher" or d["celula"] in p.fixas:
                        erros.append("#%d: dica inválida." % p.id)
                        break
                    est[d["celula"]] = d["valor"]
                if tuple(est) != p.alvo:
                    erros.append("#%d: as dicas não levam à solução." % p.id)
        rot = "pistas" if cfg["tipo"] == "logica" else "peças"
        saida("Nível %d  %-10s %dx%d  %2d puzzles  %s: %d-%d" % (
            cfg["n"], cfg["tipo"], cfg["tam"], cfg["tam"], len(lote), rot,
            min(medidas) if medidas else 0, max(medidas) if medidas else 0))

    saida("")
    if erros:
        saida("FALHOU - %d problema(s):" % len(erros))
        for e in erros[:50]:
            saida("  - " + e)
    else:
        saida("OK - nenhum puzzle impossível, ambíguo ou duplicado; dicas sempre resolvem.")
    return not erros


# =============================================================================
# 3. PERSISTÊNCIA LOCAL (progresso sem pressão)
# =============================================================================

def pasta_dados():
    base = os.environ.get("APPDATA") or os.path.expanduser("~")
    return os.path.join(base, "PuzzleCalmo")


PADRAO_DADOS = {
    "versao": 1,
    "config": {"ritmo": "calmo", "som": False, "respiracao": True, "texto": "normal", "nivel": 1},
    "concluidos": [],
    "historico": {},
}


def carregar_dados():
    dados = json.loads(json.dumps(PADRAO_DADOS))  # cópia profunda
    try:
        with open(os.path.join(pasta_dados(), "progresso.json"), "r", encoding="utf-8") as f:
            lido = json.load(f)
        if isinstance(lido, dict):
            dados["config"].update(lido.get("config", {}))
            dados["concluidos"] = [int(x) for x in lido.get("concluidos", [])]
            dados["historico"] = dict(lido.get("historico", {}))
    except (OSError, ValueError, TypeError):
        pass
    if dados["config"].get("ritmo") not in RITMOS:
        dados["config"]["ritmo"] = "calmo"
    if dados["config"].get("nivel") not in NIVEL_POR_NUM:
        dados["config"]["nivel"] = 1
    return dados


def salvar_dados(dados):
    try:
        pasta = pasta_dados()
        os.makedirs(pasta, exist_ok=True)
        destino = os.path.join(pasta, "progresso.json")
        tmp = destino + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(dados, f, ensure_ascii=False, indent=2)
        os.replace(tmp, destino)  # escrita atômica
    except OSError:
        pass


def registrar_erro(texto):
    try:
        os.makedirs(pasta_dados(), exist_ok=True)
        with open(os.path.join(pasta_dados(), "erros.log"), "a", encoding="utf-8") as f:
            f.write("[%s]\n%s\n" % (datetime.datetime.now().isoformat(), texto))
    except OSError:
        pass


# =============================================================================
# 4. SOM SUAVE (opcional, desligado por padrão)
# =============================================================================

class Som:
    """Gera um sino curto e baixo (WAV) e toca de forma assíncrona."""

    def __init__(self):
        self.caminho = None

    def _preparar(self):
        if self.caminho and os.path.exists(self.caminho):
            return self.caminho
        taxa, dur = 22050, 0.9
        quadros = bytearray()
        for k in range(int(taxa * dur)):
            t = k / taxa
            ataque = min(1.0, t / 0.03)
            env = ataque * math.exp(-4.0 * t)
            s = 0.6 * math.sin(2 * math.pi * 523.25 * t)          # dó
            if t > 0.18:
                s += 0.5 * math.sin(2 * math.pi * 659.25 * t) * math.exp(-4.0 * (t - 0.18))  # mi
            valor = int(32767 * 0.12 * env * s)                  # volume baixo (12%)
            quadros += struct.pack("<h", max(-32767, min(32767, valor)))
        caminho = os.path.join(tempfile.gettempdir(), "puzzle_calmo_sino.wav")
        with wave.open(caminho, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(taxa)
            w.writeframes(bytes(quadros))
        self.caminho = caminho
        return caminho

    def tocar(self):
        try:
            import winsound
            winsound.PlaySound(self._preparar(),
                               winsound.SND_FILENAME | winsound.SND_ASYNC | winsound.SND_NODEFAULT)
        except Exception:
            pass  # sem som não é erro


# =============================================================================
# 5. DESENHO (utilitários de canvas)
# =============================================================================

def _hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def misturar(c1, c2, t):
    """Interpola duas cores (t=0 -> c1, t=1 -> c2)."""
    a, b = _hex_rgb(c1), _hex_rgb(c2)
    return "#%02x%02x%02x" % tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def escurecer(c, f):
    return misturar(c, "#000000", f)


def suavizar(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def retangulo_arredondado(cv, x1, y1, x2, y2, r, **kw):
    pts = [x1 + r, y1, x2 - r, y1, x2, y1, x2, y1 + r, x2, y2 - r, x2, y2,
           x2 - r, y2, x1 + r, y2, x1, y2, x1, y2 - r, x1, y1 + r, x1, y1]
    return cv.create_polygon(pts, smooth=True, **kw)


def desenhar_simbolo(cv, v, cx, cy, r, fundo, t=1.0):
    _, _, cor, forma = SIMBOLOS[v]
    preench = misturar(fundo, cor, t)
    contorno = misturar(fundo, escurecer(cor, 0.35), t)
    lw = max(2, int(r * 0.09))
    if forma == "circulo":
        cv.create_oval(cx - r, cy - r, cx + r, cy + r, fill=preench, outline=contorno, width=lw)
    elif forma == "quadrado":
        s = r * 0.86
        retangulo_arredondado(cv, cx - s, cy - s, cx + s, cy + s, s * 0.25,
                              fill=preench, outline=contorno, width=lw)
    elif forma == "triangulo":
        cv.create_polygon(cx, cy - r, cx + r * 0.98, cy + r * 0.78, cx - r * 0.98, cy + r * 0.78,
                          fill=preench, outline=contorno, width=lw, joinstyle="round")
    else:  # losango
        cv.create_polygon(cx, cy - r, cx + r, cy, cx, cy + r, cx - r, cy,
                          fill=preench, outline=contorno, width=lw, joinstyle="round")


# =============================================================================
# 6. INTERFACE (tkinter)
# =============================================================================

def botao(pai, texto, comando, app, primario=False, pequeno=False):
    """Botão grande, plano, com cores suaves e ativável por teclado."""
    b = tk.Button(
        pai, text=texto, command=comando,
        font=app.fontes["pequeno" if pequeno else "botao"],
        bg=COR["primario"] if primario else COR["botao"],
        fg="#FFFFFF" if primario else COR["texto"],
        activebackground=COR["primario_ativo"] if primario else COR["botao_ativo"],
        activeforeground="#FFFFFF" if primario else COR["texto"],
        relief="flat", bd=0, cursor="hand2",
        padx=14 if pequeno else 22, pady=6 if pequeno else 12,
        highlightthickness=3, highlightbackground=COR["fundo"], highlightcolor=COR["foco"],
        takefocus=1,
    )
    b.bind("<Return>", lambda e: comando())
    b.bind("<KP_Enter>", lambda e: comando())
    return b


class Tela(tk.Frame):
    """Base de telas: gerencia timers com 'token' (evita callbacks atrasados)."""

    def __init__(self, app):
        super().__init__(app.container, bg=COR["fundo"])
        self.app = app
        self.vivo = True
        self.token = 0

    def agendar(self, ms, fn):
        tok = self.token

        def executar():
            if self.vivo and tok == self.token:
                fn()
        return self.after(ms, executar)

    def ao_sair(self):
        self.vivo = False


class TelaMenu(Tela):
    def __init__(self, app):
        super().__init__(app)
        f = app.fontes
        caixa = tk.Frame(self, bg=COR["fundo"])
        caixa.place(relx=0.5, rely=0.5, anchor="center")
        tk.Label(caixa, text=APP_NOME, font=f["titulo"], bg=COR["fundo"], fg=COR["texto"]).pack()
        tk.Label(caixa, text="Um passo de cada vez. Sem pressa, sem relógio.", font=f["subtitulo"],
                 bg=COR["fundo"], fg=COR["texto_suave"]).pack(pady=(4, 26))
        nivel = app.dados["config"]["nivel"]
        itens = [
            ("Iniciar  ·  Nível %d" % nivel, app.iniciar, True),
            ("Escolher nível e ritmo", lambda: app.trocar_tela(TelaNiveis), False),
            ("Como jogar", lambda: app.trocar_tela(TelaComoJogar), False),
            ("Ajustes (som, texto, respiração)", lambda: app.trocar_tela(TelaAjustes), False),
            ("Sair", app.ao_fechar, False),
        ]
        primeiro = None
        for texto, cmd, prim in itens:
            b = botao(caixa, texto, cmd, app, primario=prim)
            b.pack(fill="x", pady=6, ipadx=30)
            primeiro = primeiro or b
        tk.Label(caixa, text=app.texto_progresso(), font=f["texto"], bg=COR["fundo"],
                 fg=COR["texto_suave"], justify="center").pack(pady=(26, 0))
        primeiro.focus_set()


class TelaNiveis(Tela):
    def __init__(self, app):
        super().__init__(app)
        f = app.fontes
        cfg = app.dados["config"]
        topo = tk.Frame(self, bg=COR["fundo"])
        topo.pack(fill="x", padx=28, pady=(20, 6))
        tk.Label(topo, text="Nível e ritmo", font=f["titulo"], bg=COR["fundo"], fg=COR["texto"]).pack(side="left")
        botao(topo, "Voltar", app.mostrar_menu, app, pequeno=True).pack(side="right")

        tk.Label(self, text="Ritmo (não existe tempo-limite em nenhum dos dois):", font=f["subtitulo"],
                 bg=COR["fundo"], fg=COR["texto"]).pack(anchor="w", padx=32, pady=(10, 4))
        linha = tk.Frame(self, bg=COR["fundo"])
        linha.pack(fill="x", padx=28)
        for chave, r in RITMOS.items():
            caixa = tk.Frame(linha, bg=COR["fundo"])
            caixa.pack(side="left", expand=True, fill="x", padx=6)
            botao(caixa, ("✓ " if cfg["ritmo"] == chave else "") + r["nome"],
                  lambda k=chave: self._ritmo(k), app, primario=(cfg["ritmo"] == chave)).pack(fill="x")
            tk.Label(caixa, text=r["desc"], font=f["pequeno"], bg=COR["fundo"], fg=COR["texto_suave"],
                     wraplength=int(400 * app.escala), justify="left").pack(anchor="w", pady=(4, 0))

        tk.Label(self, text="Escolha um nível para começar:", font=f["subtitulo"],
                 bg=COR["fundo"], fg=COR["texto"]).pack(anchor="w", padx=32, pady=(20, 6))
        grade = tk.Frame(self, bg=COR["fundo"])
        grade.pack(fill="both", expand=True, padx=28, pady=(0, 20))
        conc = set(app.dados["concluidos"])
        primeiro = None
        for k, nv in enumerate(NIVEIS):
            feitos = sum(1 for p in app.catalogo if p.nivel == nv["n"] and p.id in conc)
            texto = "Nível %d · %s\n%s\n%d de %d feitos" % (nv["n"], nv["titulo"], nv["desc"], feitos, nv["qtd"])
            b = botao(grade, texto, lambda n=nv["n"]: app.iniciar(n), app, primario=(nv["n"] == cfg["nivel"]))
            b.configure(justify="left", anchor="w")
            b.grid(row=k // 2, column=k % 2, sticky="nsew", padx=6, pady=6)
            primeiro = primeiro or b
        grade.columnconfigure(0, weight=1, uniform="c")
        grade.columnconfigure(1, weight=1, uniform="c")
        primeiro.focus_set()

    def _ritmo(self, chave):
        self.app.dados["config"]["ritmo"] = chave
        self.app.salvar()
        self.app.trocar_tela(TelaNiveis)


class TelaComoJogar(Tela):
    TEXTO = (
        "COMO JOGAR\n\n"
        "Não há relógio, nem pontos perdidos. Jogue no seu ritmo.\n\n"
        "PUZZLES DE MEMÓRIA (níveis 1, 3 e 5)\n"
        "  1. Olhe o padrão de peças com calma. Fique o tempo que quiser.\n"
        "  2. Clique em “Já memorizei”. A grade fica vazia.\n"
        "  3. Clique nas casas para colocar as peças. Cada clique troca a peça;\n"
        "     mais um clique apaga. (Botão direito volta uma peça.)\n"
        "  4. Esqueceu? Use “Rever padrão”: ele aparece por alguns segundos\n"
        "     e o que você já fez continua guardado.\n\n"
        "PUZZLES DE LÓGICA (níveis 2, 4 e 6)\n"
        "  Complete a grade para que cada linha e cada coluna tenham todos\n"
        "  os símbolos, sem repetir. As casas mais escuras já vêm prontas.\n\n"
        "DICAS GENTIS\n"
        "  1º pedido: um lembrete da regra ou do padrão.\n"
        "  2º pedido: uma casa é destacada para você olhar.\n"
        "  3º pedido em diante: uma peça certa é colocada para você.\n\n"
        "TECLADO (opcional)\n"
        "  Setas movem a seleção · Espaço ou Enter troca a peça\n"
        "  Números 1 a 4 escolhem a peça · 0 ou Delete apagam\n\n"
        "Respire. Errar faz parte. O objetivo é praticar com calma, não correr."
    )

    def __init__(self, app):
        super().__init__(app)
        f = app.fontes
        topo = tk.Frame(self, bg=COR["fundo"])
        topo.pack(fill="x", padx=28, pady=(20, 6))
        tk.Label(topo, text="Como jogar", font=f["titulo"], bg=COR["fundo"], fg=COR["texto"]).pack(side="left")
        b = botao(topo, "Voltar", app.mostrar_menu, app, pequeno=True)
        b.pack(side="right")
        corpo = tk.Frame(self, bg=COR["fundo"])
        corpo.pack(fill="both", expand=True, padx=32, pady=(6, 24))
        barra = tk.Scrollbar(corpo)
        barra.pack(side="right", fill="y")
        txt = tk.Text(corpo, wrap="word", font=f["texto"], bg=COR["fundo"], fg=COR["texto"],
                      relief="flat", bd=0, highlightthickness=0, yscrollcommand=barra.set,
                      padx=8, pady=8, spacing1=2, spacing3=2, cursor="arrow")
        txt.insert("1.0", self.TEXTO)
        txt.configure(state="disabled")
        txt.pack(side="left", fill="both", expand=True)
        barra.configure(command=txt.yview)
        b.focus_set()


class TelaAjustes(Tela):
    def __init__(self, app):
        super().__init__(app)
        f = app.fontes
        cfg = app.dados["config"]
        topo = tk.Frame(self, bg=COR["fundo"])
        topo.pack(fill="x", padx=28, pady=(20, 6))
        tk.Label(topo, text="Ajustes", font=f["titulo"], bg=COR["fundo"], fg=COR["texto"]).pack(side="left")
        voltar = botao(topo, "Voltar", app.mostrar_menu, app, pequeno=True)
        voltar.pack(side="right")
        caixa = tk.Frame(self, bg=COR["fundo"])
        caixa.pack(pady=20)
        opcoes = [
            ("Som: %s" % ("suave" if cfg["som"] else "desligado"), "som",
             "Um sino baixo apenas ao concluir um puzzle. Nunca há som de erro."),
            ("Tamanho do texto: %s" % ("grande" if cfg["texto"] == "grande" else "normal"), "texto",
             "Aumenta todas as letras e botões."),
            ("Pausa para respirar: %s" % ("ligada" if cfg["respiracao"] else "desligada"), "respiracao",
             "Um círculo que cresce e diminui devagar antes de cada puzzle."),
            ("Ritmo: %s" % RITMOS[cfg["ritmo"]]["nome"], "ritmo", RITMOS[cfg["ritmo"]]["desc"]),
        ]
        primeiro = None
        for texto, chave, ajuda in opcoes:
            b = botao(caixa, texto, lambda k=chave: self._alternar(k), app)
            b.pack(fill="x", pady=(10, 2), ipadx=30)
            tk.Label(caixa, text=ajuda, font=f["pequeno"], bg=COR["fundo"], fg=COR["texto_suave"]).pack(anchor="w")
            primeiro = primeiro or b
        botao(caixa, "Testar o som", app.som.tocar, app, pequeno=True).pack(anchor="w", pady=(18, 4))
        botao(caixa, "Apagar meu progresso", self._apagar, app, pequeno=True).pack(anchor="w", pady=4)
        tk.Label(caixa, text="Seu progresso fica salvo só neste computador:\n" + pasta_dados(),
                 font=f["pequeno"], bg=COR["fundo"], fg=COR["texto_suave"], justify="left").pack(anchor="w", pady=(14, 0))
        primeiro.focus_set()

    def _alternar(self, chave):
        cfg = self.app.dados["config"]
        if chave == "som":
            cfg["som"] = not cfg["som"]
            if cfg["som"]:
                self.app.som.tocar()
        elif chave == "texto":
            cfg["texto"] = "normal" if cfg["texto"] == "grande" else "grande"
            self.app.aplicar_fontes()
        elif chave == "respiracao":
            cfg["respiracao"] = not cfg["respiracao"]
        elif chave == "ritmo":
            cfg["ritmo"] = "tranquilo" if cfg["ritmo"] == "calmo" else "calmo"
        self.app.salvar()
        self.app.trocar_tela(TelaAjustes)

    def _apagar(self):
        if messagebox.askyesno(APP_NOME, "Deseja recomeçar do zero?\nOs puzzles concluídos serão desmarcados.",
                               parent=self):
            self.app.dados["concluidos"] = []
            self.app.dados["historico"] = {}
            self.app.dados["config"]["nivel"] = 1
            self.app.salvar()
            self.app.trocar_tela(TelaAjustes)


class TelaJogo(Tela):
    """Tela de uma partida. Fases:
       respirar -> (memória) observar -> recriar <-> revendo -> concluido
       respirar -> (lógica)  resolver -> concluido
    """
    EDITAVEIS = ("recriar", "resolver")

    def __init__(self, app, puzzle, aviso=""):
        super().__init__(app)
        self.p = puzzle
        self.estado = list(puzzle.inicial)
        self.fixas = puzzle.fixas
        self.fase = None
        self.nivel_dica = 0
        self.destaque = None
        self.desfazer_pilha = []
        self.mostrar_conflitos = False
        self.cursor = 0
        self.cursor_visivel = False
        self.anim = 1.0
        self.geo = None
        self.vencendo = False
        self.aviso = aviso
        self.ritmo = RITMOS[app.dados["config"]["ritmo"]]
        f = app.fontes

        topo = tk.Frame(self, bg=COR["fundo"])
        topo.pack(fill="x", padx=24, pady=(16, 2))
        nv = NIVEL_POR_NUM[puzzle.nivel]
        tk.Label(topo, text="Nível %d · %s  —  puzzle %d de %d" % (nv["n"], nv["titulo"], puzzle.indice_no_nivel, nv["qtd"]),
                 font=f["subtitulo"], bg=COR["fundo"], fg=COR["texto_suave"]).pack(side="left")
        botao(topo, "Menu", app.mostrar_menu, app, pequeno=True).pack(side="right")

        self.lbl_msg = tk.Label(self, text="", font=f["texto"], bg=COR["fundo"], fg=COR["texto"],
                                justify="center", wraplength=800)
        self.lbl_msg.pack(fill="x", padx=32, pady=(6, 4))
        self.canvas = tk.Canvas(self, bg=COR["fundo"], highlightthickness=0, takefocus=1)
        self.canvas.pack(fill="both", expand=True, padx=16)
        self.barra = tk.Frame(self, bg=COR["fundo"])
        self.barra.pack(pady=(6, 18))

        self.canvas.bind("<Configure>", lambda e: self.desenhar())
        self.canvas.bind("<Button-1>", lambda e: self._clique(e, +1))
        self.canvas.bind("<Button-3>", lambda e: self._clique(e, -1))
        self.bind("<Configure>", lambda e: self.lbl_msg.configure(wraplength=max(300, e.width - 80)))
        self._id_tecla = app.bind("<Key>", self._tecla, add="+")
        self.after_idle(self._comecar)

    # ---------------------------------------------------------------- fases
    def ao_sair(self):
        super().ao_sair()
        try:
            self.app.unbind("<Key>", self._id_tecla)
        except tk.TclError:
            pass

    def _comecar(self):
        if self.app.dados["config"]["respiracao"]:
            self._mudar_fase("respirar")
        else:
            self._fase_do_puzzle()

    def _fase_do_puzzle(self):
        self._mudar_fase("observar" if self.p.tipo == "memoria" else "resolver")

    def _texto_padrao(self):
        return {
            "respirar": "Antes de começar, acompanhe o círculo e respire devagar.",
            "observar": "Observe o padrão com calma. Quando sentir que memorizou, clique em “Já memorizei”. Não há pressa.",
            "recriar": "Agora recrie o padrão. Clique numa casa para colocar ou trocar a peça.",
            "revendo": "Este é o padrão de referência. O que você já fez continua guardado.",
            "resolver": "Complete a grade: em cada linha e cada coluna, cada símbolo aparece uma vez. "
                        "Casas mais escuras já vêm prontas.",
        }.get(self.fase, "")

    def _msg(self, texto, cor=None):
        self.lbl_msg.configure(text=texto, fg=cor or COR["texto"])

    def _mudar_fase(self, fase):
        self.token += 1                 # invalida timers da fase anterior
        self.fase = fase
        for w in self.barra.winfo_children():
            w.destroy()
        a = self.app
        botoes = []
        if fase == "respirar":
            botoes = [("Começar agora", self._fase_do_puzzle, True)]
        elif fase == "observar":
            botoes = [("Já memorizei", lambda: self._mudar_fase("recriar"), True)]
        elif fase == "revendo":
            botoes = [("Voltar ao meu tabuleiro", lambda: self._mudar_fase("recriar"), True)]
        elif fase in self.EDITAVEIS:
            if self.p.tipo == "memoria":
                botoes.append(("Rever padrão", lambda: self._mudar_fase("revendo"), False))
            botoes += [("Dica gentil", self._dica, False), ("Desfazer", self._desfazer, False),
                       ("Limpar", self._limpar, False), ("Verificar", self._verificar, True)]
        elif fase == "concluido":
            botoes = [("Próximo puzzle", lambda: a.proximo(self.p), True), ("Voltar ao menu", a.mostrar_menu, False)]
        colunas = 3 if a.dados["config"]["texto"] == "grande" else 5
        primeiro = None
        for k, (txt, cmd, prim) in enumerate(botoes):
            b = botao(self.barra, txt, cmd, a, primario=prim)
            b.grid(row=k // colunas, column=k % colunas, padx=6, pady=4, sticky="ew")
            if prim or primeiro is None:
                primeiro = b if prim else (primeiro or b)
        texto = self._texto_padrao()
        if self.aviso and fase in ("respirar", "observar", "resolver"):
            texto = self.aviso + "\n" + texto
        if fase != "concluido":
            self._msg(texto)
        # foco: na grade quando editável, senão no botão principal
        if fase in self.EDITAVEIS:
            self.canvas.focus_set()
        elif primeiro is not None:
            primeiro.focus_set()

        if fase == "respirar":
            self.resp_inicio = time.time()
            self._tick_respiro()
        elif fase in ("observar", "revendo"):
            self._animar_entrada()
            if fase == "revendo":
                self.agendar(self.ritmo["rever_s"] * 1000, lambda: self._mudar_fase("recriar"))
        else:
            self.anim = 1.0
            self.desenhar()

    def _tick_respiro(self):
        if time.time() - self.resp_inicio >= self.ritmo["respiro_s"]:
            self._fase_do_puzzle()
            return
        self.desenhar()
        self.agendar(33, self._tick_respiro)

    def _animar_entrada(self):
        self.anim_inicio = time.time()
        self.anim = 0.0
        self._tick_anim()

    def _tick_anim(self):
        t = (time.time() - self.anim_inicio) * 1000.0 / self.ritmo["anim_ms"]
        self.anim = suavizar(t)
        self.desenhar()
        if t < 1.0:
            self.agendar(30, self._tick_anim)

    # ------------------------------------------------------------- jogadas
    def _definir(self, i, v):
        if self.fase not in self.EDITAVEIS or self.vencendo:
            return
        if i in self.fixas:
            self._msg("Esta casa já vem pronta e não muda. Escolha uma casa clara.")
            return
        if self.estado[i] == v:
            return
        self.desfazer_pilha.append(list(self.estado))
        del self.desfazer_pilha[:-300]
        self.estado[i] = v
        if self.destaque == i:
            self.destaque = None
        self._msg(self._texto_padrao())
        self.desenhar()
        self._checar_vitoria()

    def _ciclar(self, i, passo):
        if i in self.fixas:
            self._definir(i, 0)
            return
        self._definir(i, (self.estado[i] + passo) % (self.p.simbolos + 1))

    def _clique(self, e, passo):
        self.canvas.focus_set()
        if not self.geo or self.fase not in self.EDITAVEIS:
            return
        x0, y0, cel, n = self.geo
        col, lin = int((e.x - x0) // cel), int((e.y - y0) // cel)
        if 0 <= col < n and 0 <= lin < n:
            self.cursor = lin * n + col
            self.cursor_visivel = False
            self._ciclar(self.cursor, passo)

    def _tecla(self, e):
        if isinstance(e.widget, tk.Button) or self.fase not in self.EDITAVEIS:
            return
        n, k = self.p.n, e.keysym
        movs = {"Left": (0, -1), "Right": (0, 1), "Up": (-1, 0), "Down": (1, 0)}
        if k in movs:
            lin, col = divmod(self.cursor, n)
            dl, dc = movs[k]
            self.cursor = ((lin + dl) % n) * n + (col + dc) % n
            self.cursor_visivel = True
            self.desenhar()
        elif k in ("space", "Return", "KP_Enter"):
            self.cursor_visivel = True
            self._ciclar(self.cursor, +1)
        elif k in ("BackSpace", "Delete", "0", "KP_0"):
            self.cursor_visivel = True
            self._definir(self.cursor, 0)
        elif e.char and e.char.isdigit() and 1 <= int(e.char) <= self.p.simbolos:
            self.cursor_visivel = True
            self._definir(self.cursor, int(e.char))

    def _desfazer(self):
        if self.fase not in self.EDITAVEIS:
            return
        if not self.desfazer_pilha:
            self._msg("Não há nada para desfazer.")
            return
        self.estado = self.desfazer_pilha.pop()
        self._msg(self._texto_padrao())
        self.desenhar()

    def _limpar(self):
        if self.fase not in self.EDITAVEIS:
            return
        novo = list(self.p.inicial)
        if novo != self.estado:
            self.desfazer_pilha.append(list(self.estado))
            self.estado = novo
        self.destaque = None
        self._msg("Grade limpa. Se mudar de ideia, use “Desfazer”.")
        self.desenhar()

    def _dica(self):
        if self.fase not in self.EDITAVEIS:
            return
        self.nivel_dica += 1
        d = calcular_dica(self.p, self.estado, self.nivel_dica)
        if d["tipo"] == "destacar":
            self.destaque = d["celula"]
        elif d["tipo"] == "preencher":
            self.desfazer_pilha.append(list(self.estado))
            self.estado[d["celula"]] = d["valor"]
            self.destaque = d["celula"]
            self.cursor = d["celula"]
        if self.p.tipo == "logica" and self.nivel_dica >= 2:
            self.mostrar_conflitos = True
        self._msg(d["msg"])
        self.desenhar()
        self._checar_vitoria()

    def _verificar(self):
        if self.fase not in self.EDITAVEIS:
            return
        if self.estado == list(self.p.alvo):
            self._vitoria()
            return
        if self.p.tipo == "logica":
            self.mostrar_conflitos = True
            vazias = self.estado.count(0)
            if celulas_em_conflito(self.estado, self.p.n):
                txt = "Quase lá. Há símbolos repetidos (contorno laranja). Sem pressa: ajuste quando quiser."
            elif vazias:
                txt = "Até aqui, sem repetições. Ainda faltam %d casa(s) para preencher." % vazias
            else:
                txt = "Quase lá. Algo ainda não se encaixa. Se quiser, peça uma dica."
        else:
            txt = "Quase lá. Ainda há alguma diferença. Você pode rever o padrão ou pedir uma dica."
        self._msg(txt)
        self.desenhar()

    def _checar_vitoria(self):
        if self.estado == list(self.p.alvo) and not self.vencendo:
            self.vencendo = True
            self.agendar(self.ritmo["vitoria_ms"], self._vitoria)

    def _vitoria(self):
        if self.estado != list(self.p.alvo):
            self.vencendo = False
            return
        self.vencendo = True
        self.destaque = None
        self.app.marcar_concluido(self.p.id)
        frases = ["Muito bem! Puzzle concluído.",
                  "Pronto! Você chegou lá no seu ritmo.",
                  "Belo trabalho de atenção. Concluído!"]
        extra = "  Respire. Quando quiser, siga para o próximo." if self.ritmo is RITMOS["calmo"] else ""
        self._mudar_fase("concluido")
        self._msg(frases[self.p.id % len(frases)] + extra, COR["sucesso"])

    # -------------------------------------------------------------- desenho
    def desenhar(self):
        cv = self.canvas
        if not self.vivo:
            return
        cv.delete("all")
        w, h = cv.winfo_width(), cv.winfo_height()
        if w < 20 or h < 20:
            return
        esc = self.app.escala
        if self.fase == "respirar":
            self._desenhar_respiro(w, h, esc)
            return
        n = self.p.n
        leg_h = int(70 * esc)
        lado = min(w - 40, h - leg_h - 20)
        cel = max(30, min(lado // n, int(130 * esc)))
        total = cel * n
        x0 = (w - total) // 2
        y0 = max(6, (h - leg_h - total) // 2)
        self.geo = (x0, y0, cel, n)

        mostrar_alvo = self.fase in ("observar", "revendo")
        grade = self.p.alvo if mostrar_alvo else self.estado
        conflitos = celulas_em_conflito(self.estado, n) if (self.mostrar_conflitos and not mostrar_alvo) else set()
        pad = max(3, int(cel * 0.05))

        if mostrar_alvo:   # moldura que sinaliza "referência"
            retangulo_arredondado(cv, x0 - 10, y0 - 10, x0 + total + 10, y0 + total + 10, 18,
                                  fill=misturar(COR["fundo"], COR["respiro"], 0.35), outline="")
        if self.fase == "concluido":
            retangulo_arredondado(cv, x0 - 10, y0 - 10, x0 + total + 10, y0 + total + 10, 18,
                                  fill="", outline=COR["sucesso"], width=4)

        for i in range(n * n):
            lin, col = divmod(i, n)
            x1, y1 = x0 + col * cel + pad, y0 + lin * cel + pad
            x2, y2 = x0 + (col + 1) * cel - pad, y0 + (lin + 1) * cel - pad
            fixa = (i in self.fixas) and not mostrar_alvo
            fundo = COR["celula_fixa"] if fixa else COR["celula"]
            contorno, larg, traco = COR["borda"], 2, None
            if i in conflitos and i not in self.fixas:
                contorno, larg, traco = COR["conflito"], 4, (6, 4)
            if self.destaque == i and not mostrar_alvo:
                contorno, larg, traco = COR["destaque"], 6, None
            retangulo_arredondado(cv, x1, y1, x2, y2, cel * 0.12, fill=fundo, outline=contorno,
                                  width=larg, dash=traco or ())
            v = grade[i]
            if v:
                t = self.anim if mostrar_alvo else 1.0
                desenhar_simbolo(cv, v, (x1 + x2) / 2, (y1 + y2) / 2, cel * 0.29, fundo, t)
            if self.cursor_visivel and self.cursor == i and self.fase in self.EDITAVEIS:
                cv.create_rectangle(x1 + 4, y1 + 4, x2 - 4, y2 - 4, outline=COR["foco"], width=3, dash=(5, 4))

        # Legenda: nome + forma + cor (apoio verbal à memória)
        f = self.app.fontes["pequeno"]
        r = int(13 * esc)
        itens = [(v, "%s %s" % (SIMBOLOS[v][0], SIMBOLOS[v][1])) for v in range(1, self.p.simbolos + 1)]
        larguras = [2 * r + 8 + f.measure(t) for _, t in itens]
        esp = int(28 * esc)
        largura_total = sum(larguras) + esp * (len(itens) - 1)
        x = (w - largura_total) / 2
        yl = y0 + total + leg_h / 2 + 4
        for (v, t), lw in zip(itens, larguras):
            desenhar_simbolo(cv, v, x + r, yl, r, COR["fundo"])
            cv.create_text(x + 2 * r + 8, yl, text=t, anchor="w", font=f, fill=COR["texto"])
            x += lw + esp

    def _desenhar_respiro(self, w, h, esc):
        cv = self.canvas
        T = float(self.ritmo["respiro_s"])
        t = time.time() - self.resp_inicio
        fase = (t % T) / T                       # 0..1 (metade inspira, metade expira)
        k = 0.5 - 0.5 * math.cos(2 * math.pi * fase)
        rmin, rmax = 40 * esc, min(w, h) * 0.33
        r = rmin + (rmax - rmin) * k
        cx, cy = w / 2, h / 2 - 10 * esc
        cv.create_oval(cx - rmax, cy - rmax, cx + rmax, cy + rmax, outline=misturar(COR["fundo"], COR["respiro"], 0.6), width=2)
        cv.create_oval(cx - r, cy - r, cx + r, cy + r, fill=misturar(COR["fundo"], COR["respiro"], 0.75), outline="")
        texto = "Inspire devagar..." if fase < 0.5 else "Solte o ar devagar..."
        cv.create_text(cx, cy, text=texto, font=self.app.fontes["subtitulo"], fill=COR["texto"])


class App(tk.Tk):
    def __init__(self, persistir=True):
        super().__init__()
        self.persistir = persistir
        self.dados = carregar_dados() if persistir else json.loads(json.dumps(PADRAO_DADOS))
        self.catalogo = obter_catalogo()
        self.sessao = 0
        self.som = Som()
        self.escala = max(1.0, self.winfo_fpixels("1i") / 96.0)

        familias = set(tkfont.families(self))
        fam = next((x for x in ("Segoe UI", "Verdana", "DejaVu Sans", "Helvetica") if x in familias), "TkDefaultFont")
        self.fontes = {k: tkfont.Font(self, family=fam) for k in ("titulo", "subtitulo", "texto", "botao", "pequeno")}
        self.aplicar_fontes()

        self.title(APP_NOME)
        self.configure(bg=COR["fundo"])
        sw, sh = self.winfo_screenwidth(), self.winfo_screenheight()
        w = min(int(1040 * self.escala), int(sw * 0.92))
        h = min(int(780 * self.escala), int(sh * 0.88))
        self.geometry("%dx%d+%d+%d" % (w, h, (sw - w) // 2, max(0, (sh - h) // 2 - 20)))
        self.minsize(min(w, int(760 * self.escala)), min(h, int(600 * self.escala)))

        self.container = tk.Frame(self, bg=COR["fundo"])
        self.container.pack(fill="both", expand=True)
        self.tela = None
        self.protocol("WM_DELETE_WINDOW", self.ao_fechar)
        self.mostrar_menu()

    def report_callback_exception(self, exc, val, tb):
        registrar_erro("".join(traceback.format_exception(exc, val, tb)))
        try:
            self.mostrar_menu()
        except Exception:
            pass

    # -------------------------------------------------------------- dados
    def aplicar_fontes(self):
        grande = self.dados["config"]["texto"] == "grande"
        tamanhos = {"titulo": 28, "subtitulo": 17, "texto": 15, "botao": 15, "pequeno": 13}
        for k, s in tamanhos.items():
            self.fontes[k].configure(size=s + (5 if grande else 0),
                                     weight="bold" if k in ("titulo", "botao") else "normal")

    def salvar(self):
        if self.persistir:
            salvar_dados(self.dados)

    def marcar_concluido(self, pid):
        if pid not in self.dados["concluidos"]:
            self.dados["concluidos"].append(pid)
        hoje = datetime.date.today().isoformat()
        self.dados["historico"][hoje] = self.dados["historico"].get(hoje, 0) + 1
        self.sessao += 1
        self.salvar()
        if self.dados["config"]["som"]:
            self.som.tocar()

    def texto_progresso(self):
        hoje = self.dados["historico"].get(datetime.date.today().isoformat(), 0)
        total = len(set(self.dados["concluidos"]))
        return ("Hoje: %d puzzle(s) concluído(s)  ·  Nesta sessão: %d\n"
                "Você já explorou %d dos %d puzzles." % (hoje, self.sessao, total, len(self.catalogo)))

    # ---------------------------------------------------------- navegação
    def trocar_tela(self, cls, *a, **kw):
        if self.tela is not None:
            self.tela.ao_sair()
            self.tela.destroy()
        self.tela = cls(self, *a, **kw)
        self.tela.pack(fill="both", expand=True)

    def mostrar_menu(self):
        self.trocar_tela(TelaMenu)

    def escolher_puzzle(self, nivel, apos=None):
        """Próximo puzzle pendente do nível; se o nível acabou, segue para outro nível
        com pendências; se tudo acabou, repete o nível em ordem (revisão)."""
        conc = set(self.dados["concluidos"])
        lista = [p for p in self.catalogo if p.nivel == nivel]
        pend = [p for p in lista if p.id not in conc]
        if pend:
            depois = [p for p in pend if apos is None or p.id > apos.id]
            return (depois or pend)[0], ""
        outros = [p for p in self.catalogo if p.id not in conc]
        if outros:
            seguintes = [p for p in outros if p.nivel > nivel] or outros
            p = seguintes[0]
            return p, "Você concluiu todo o Nível %d. Seguimos com calma para o Nível %d." % (nivel, p.nivel)
        if apos is not None and apos.nivel == nivel:
            seguintes = [p for p in lista if p.id > apos.id]
            return (seguintes or lista)[0], "Todos os puzzles já foram concluídos. Este é um momento de revisão."
        return lista[0], "Todos os puzzles já foram concluídos. Este é um momento de revisão."

    def iniciar(self, nivel=None):
        nivel = nivel or self.dados["config"]["nivel"]
        p, aviso = self.escolher_puzzle(nivel)
        self._jogar(p, aviso)

    def proximo(self, atual):
        p, aviso = self.escolher_puzzle(atual.nivel, apos=atual)
        self._jogar(p, aviso)

    def _jogar(self, p, aviso=""):
        self.dados["config"]["nivel"] = p.nivel
        self.salvar()
        self.trocar_tela(TelaJogo, p, aviso)

    def ao_fechar(self):
        self.salvar()
        self.destroy()


# =============================================================================
# 7. AUTOTESTE DE INTERFACE (joga sozinho, sem salvar progresso)
# =============================================================================

def autoteste():
    app = App(persistir=False)
    app.dados["config"]["respiracao"] = True
    estado = {"resolvidos": 0, "passos": 0, "nivel": 1, "inicio": time.time(), "reviu": False}
    log = []

    def passo():
        estado["passos"] += 1
        if time.time() - estado["inicio"] > 90:
            log.append("TEMPO ESGOTADO")
            app.destroy()
            return
        t = app.tela
        if isinstance(t, TelaJogo):
            if t.fase == "respirar":
                t._fase_do_puzzle()
            elif t.fase == "observar":
                t._mudar_fase("recriar")
            elif t.fase == "recriar" and not estado["reviu"]:
                estado["reviu"] = True
                t._ciclar(0, +1)
                t._mudar_fase("revendo")
                app.after(150, lambda: t._mudar_fase("recriar") if t.vivo else None)
            elif t.fase in TelaJogo.EDITAVEIS:
                t._verificar()
                t._dica()
            elif t.fase == "concluido":
                estado["resolvidos"] += 1
                log.append("Nível %d puzzle #%d resolvido" % (t.p.nivel, t.p.id))
                estado["nivel"] += 1
                estado["reviu"] = False
                if estado["nivel"] > len(NIVEIS):
                    app.dados["config"]["texto"] = "grande"
                    app.aplicar_fontes()
                    for cls in (TelaNiveis, TelaComoJogar, TelaAjustes, TelaMenu):
                        app.trocar_tela(cls)
                        app.update()
                    app.after(300, app.destroy)
                    return
                app.iniciar(estado["nivel"])
        app.after(40, passo)

    app.after(300, lambda: app.iniciar(1))
    app.after(600, passo)
    app.mainloop()
    for linha in log:
        print(linha)
    ok = estado["resolvidos"] == len(NIVEIS)
    print("AUTOTESTE %s: %d de %d níveis resolvidos pela interface." % ("OK" if ok else "FALHOU",
                                                                       estado["resolvidos"], len(NIVEIS)))
    return ok


# =============================================================================
# 8. PONTO DE ENTRADA
# =============================================================================

def ativar_dpi():
    """Texto nítido em telas com escala (125%, 150%...) no Windows."""
    if sys.platform == "win32":
        try:
            import ctypes
            try:
                ctypes.windll.shcore.SetProcessDpiAwareness(1)
            except Exception:
                ctypes.windll.user32.SetProcessDPIAware()
        except Exception:
            pass


def main():
    args = sys.argv[1:]
    if "--validar" in args:
        if sys.stdout is None:  # executável --windowed não tem console
            caminho = os.path.join(pasta_dados(), "validacao.txt")
            os.makedirs(pasta_dados(), exist_ok=True)
            with open(caminho, "w", encoding="utf-8") as f:
                ok = validar_catalogo(lambda s: f.write(s + "\n"))
        else:
            ok = validar_catalogo()
        sys.exit(0 if ok else 1)
    ativar_dpi()
    if "--autoteste" in args:
        sys.exit(0 if autoteste() else 1)
    App().mainloop()


if __name__ == "__main__":
    main()
