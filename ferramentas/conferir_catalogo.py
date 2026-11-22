#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Espelho em Python do gerador de catálogo de lib/catalogo.dart.

Serve para conferir o catálogo do app Android SEM precisar do Flutter:
usa o mesmo gerador de números (xorshift32), a mesma ordem de sorteios,
o mesmo critério de ordenação estável e a mesma impressão digital (FNV-1a).

    python ferramentas/conferir_catalogo.py

Se a impressão digital impressa aqui for igual à de test/catalogo_test.dart,
o app Android usa exatamente os puzzles validados por este script.
"""
import sys

MAX_PUZZLES = 200
SEMENTE = 20261122
MASK = 0xFFFFFFFF

NIVEIS = [
    # n, tipo, tam, simbolos, faixa_min, faixa_max, qtd
    (1, "memoria", 3, 1, 2, 3, 30),
    (2, "logica", 3, 3, 5, 6, 30),
    (3, "memoria", 3, 2, 3, 4, 30),
    (4, "logica", 4, 4, 9, 10, 30),
    (5, "memoria", 4, 3, 4, 5, 30),
    (6, "logica", 4, 4, 6, 7, 30),
]


class Gerador:
    def __init__(self, semente):
        s = semente & MASK
        self.s = s if s else 0x9E3779B9

    def proximo(self):
        x = self.s
        x ^= (x << 13) & MASK
        x ^= x >> 17
        x ^= (x << 5) & MASK
        self.s = x & MASK
        return self.s

    def inteiro(self, n):
        return self.proximo() % n

    def entre(self, a, b):
        return a + self.inteiro(b - a + 1)

    def amostra(self, m, k):
        l = list(range(m))
        for i in range(k):
            j = i + self.inteiro(m - i)
            l[i], l[j] = l[j], l[i]
        return l[:k]

    def embaralhar(self, l):
        for i in range(len(l) - 1, 0, -1):
            j = self.inteiro(i + 1)
            l[i], l[j] = l[j], l[i]

    def escolher(self, l):
        return l[self.inteiro(len(l))]


def candidatos(g, n, i):
    r, c = divmod(i, n)
    usados = set()
    for k in range(n):
        usados.add(g[r * n + k])
        usados.add(g[k * n + c])
    return [v for v in range(1, n + 1) if v not in usados]


def conflita(g, n, i, v):
    r, c = divmod(i, n)
    for k in range(n):
        j = r * n + k
        if j != i and g[j] == v:
            return True
        j = k * n + c
        if j != i and g[j] == v:
            return True
    return False


def quadrados_latinos(n):
    res, g = [], [0] * (n * n)

    def bt(i):
        if i == n * n:
            res.append(list(g))
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
    g = list(grade)
    for i, v in enumerate(g):
        if v and conflita(g, n, i, v):
            return 0
    total = [0]

    def bt():
        melhor, cands = -1, None
        for i in range(n * n):
            if g[i] == 0:
                cs = candidatos(g, n, i)
                if not cs:
                    return
                if melhor < 0 or len(cs) < len(cands):
                    melhor, cands = i, cs
        if melhor < 0:
            total[0] += 1
            return
        for v in cands:
            g[melhor] = v
            bt()
            g[melhor] = 0
            if total[0] >= limite:
                return
    bt()
    return total[0]


def eh_latino(g, n):
    alvo = set(range(1, n + 1))
    return all({g[k * n + c] for c in range(n)} == alvo and {g[r * n + k] for r in range(n)} == alvo
               for k in range(n))


def construir():
    rng = Gerador(SEMENTE)
    latinos = {3: quadrados_latinos(3), 4: quadrados_latinos(4)}
    vistos, cat = set(), []
    for (nv, tipo, tam, s, fmin, fmax, qtd) in NIVEIS:
        nn = tam * tam
        lote, tent = [], 0
        while len(lote) < qtd:
            tent += 1
            if tent > 50000:
                raise RuntimeError("nivel %d nao gerou" % nv)
            if tipo == "memoria":
                k = rng.entre(fmin, fmax)
                casas = rng.amostra(nn, k)
                alvo = [0] * nn
                for c in casas:
                    alvo[c] = rng.entre(1, s)
                if len({alvo[c] for c in casas}) != min(s, k):
                    continue
                ini = [0] * nn
            else:
                sol = rng.escolher(latinos[tam])
                meta = rng.entre(fmin, fmax)
                g = list(sol)
                ordem = list(range(nn))
                rng.embaralhar(ordem)
                for i in ordem:
                    if sum(1 for v in g if v) <= meta:
                        break
                    guard = g[i]
                    g[i] = 0
                    if contar_solucoes(g, tam, 2) != 1:
                        g[i] = guard
                if sum(1 for v in g if v) != meta:
                    continue
                ini, alvo = g, list(sol)
            chave = "%s|%d|%s|%s" % (tipo, tam, ",".join(map(str, ini)), ",".join(map(str, alvo)))
            if chave in vistos:
                continue
            vistos.add(chave)
            lote.append((ini, alvo, chave))
        if tipo == "memoria":
            chave_ord = lambda e: (sum(1 for v in e[1][1] if v), len({v for v in e[1][1] if v}), e[0])
        else:
            chave_ord = lambda e: (-sum(1 for v in e[1][0] if v), e[0])
        ordenado = [e[1] for e in sorted(enumerate(lote), key=chave_ord)]
        for k, (ini, alvo, chave) in enumerate(ordenado, start=1):
            cat.append(dict(id=len(cat) + 1, nivel=nv, tipo=tipo, n=tam, s=s, ini=ini, alvo=alvo, chave=chave,
                            fmin=fmin, fmax=fmax))
    return cat


def impressao(cat):
    h = 0x811C9DC5
    texto = "".join("%d|%d|%s;" % (p["id"], p["nivel"], p["chave"]) for p in cat)
    for b in texto.encode("ascii"):
        h ^= b
        h = (h * 0x01000193) & MASK
    return "%08x" % h


def main():
    cat = construir()
    erros = []
    if len(cat) > MAX_PUZZLES:
        erros.append("acima do teto")
    if len({p["chave"] for p in cat}) != len(cat):
        erros.append("duplicatas")
    if [p["chave"] for p in construir()] != [p["chave"] for p in cat]:
        erros.append("nao deterministico")
    for p in cat:
        if p["tipo"] == "logica":
            if not eh_latino(p["alvo"], p["n"]):
                erros.append("#%d solucao invalida" % p["id"])
            if any(v and v != p["alvo"][i] for i, v in enumerate(p["ini"])):
                erros.append("#%d pistas incoerentes" % p["id"])
            if contar_solucoes(p["ini"], p["n"], 3) != 1:
                erros.append("#%d nao tem solucao unica" % p["id"])
            q = sum(1 for v in p["ini"] if v)
        else:
            q = sum(1 for v in p["alvo"] if v)
            if len({v for v in p["alvo"] if v}) != min(p["s"], q):
                erros.append("#%d nao usa todos os tipos" % p["id"])
        if not (p["fmin"] <= q <= p["fmax"]):
            erros.append("#%d fora da faixa" % p["id"])
    print("Puzzles: %d (teto %d)" % (len(cat), MAX_PUZZLES))
    for nv in range(1, 7):
        print("  nivel %d: %d" % (nv, sum(1 for p in cat if p["nivel"] == nv)))
    print("Impressao digital (FNV-1a): %s" % impressao(cat))
    print("Primeiro puzzle de cada nivel:")
    for nv in range(1, 7):
        p = next(x for x in cat if x["nivel"] == nv)
        print("  #%d ini=%s alvo=%s" % (p["id"], p["ini"], p["alvo"]))
    print("OK" if not erros else "FALHOU: %s" % erros[:20])
    return 0 if not erros else 1


if __name__ == "__main__":
    sys.exit(main())
