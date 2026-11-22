# Puzzle Calmo

Jogo calmo de **lógica e memória operacional**, feito para pessoas com hiperatividade ou agitação mental e para pessoas com declínio cognitivo leve a moderado. Não tem relógio nem punição por erro, as dicas são gentis e o catálogo é fixo, com 180 puzzles (o teto é 200).

O repositório tem duas versões:

| Versão | Onde está | Tecnologia | Como gerar |
|---|---|---|---|
| **Android** | raiz do repositório (`lib/`, `test/`) | Flutter | Automático: cada envio para `main` gera o APK pelo GitHub Actions (aba **Actions → Gerar APK**). O APK fica no artifact da execução e no branch `apk`. |
| **Windows (PC)** | [`versao-pc/`](versao-pc/) | Python + tkinter | `versao-pc/gerar_exe.bat` gera `PuzzleCalmo.exe` com o PyInstaller |

- Guia da versão Android: [LEIA-ME-ANDROID.md](LEIA-ME-ANDROID.md)
- Guia da versão Windows: [versao-pc/LEIA-ME.md](versao-pc/LEIA-ME.md)

As duas versões seguem as mesmas regras e faixas de dificuldade. Os puzzles em si são diferentes, porque cada versão usa um gerador de números próprio, ambos com semente fixa.
