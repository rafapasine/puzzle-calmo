# Puzzle Calmo — guia técnico

Jogo de **lógica e memória operacional em ritmo lento**, em um único arquivo Python (`puzzle_calmo.py`), só com a biblioteca padrão. Vira um único `PuzzleCalmo.exe` no Windows.

---

## 1. Arquitetura e mecânica

### Por que tkinter (e não pygame)
| Critério | tkinter | pygame |
|---|---|---|
| Dependências | Já vem com o Python, nada a instalar | Pacote externo com SDL2 e DLLs |
| Tamanho do `.exe` | ~10–12 MB | ~25–40 MB |
| Botões, texto com quebra de linha, foco por teclado, caixas de diálogo | Prontos | Precisa construir tudo à mão |
| Uso de CPU | Só redesenha quando algo muda | Laço de quadros constante |
| PyInstaller | Suporte maduro, sem *hooks* manuais | Funciona, mas falha mais com antivírus/DLLs |

Um puzzle calmo não precisa de 60 quadros/s. Precisa de botões grandes, texto legível, acessibilidade pelo teclado e estabilidade, e o tkinter entrega isso.

### Duas mecânicas, seis níveis (alternados)
| Nível | Tipo | Grade | Carga | O que treina |
|---|---|---|---|---|
| 1 Lembrar | Memória | 3×3 | 2–3 círculos | Memória visuoespacial básica |
| 2 Completar | Lógica | 3×3 | 3 símbolos, 5–6 pistas | Regra simples de não repetir |
| 3 Lembrar mais | Memória | 3×3 | 3–4 peças, 2 tipos | Ligar posição e identidade da peça |
| 4 Completar mais | Lógica | 4×4 | 4 símbolos, 9–10 pistas | Dedução por eliminação |
| 5 Lembrar com atenção | Memória | 4×4 | 4–5 peças, 3 tipos | Mais itens na memória de trabalho |
| 6 Deduzir | Lógica | 4×4 | 6–7 pistas | Encadear deduções |

- **Memória:** a pessoa observa o padrão **pelo tempo que quiser** e clica em “Já memorizei”. Depois recria o padrão clicando nas casas: cada clique troca a peça e o botão direito volta uma. **Rever padrão** mostra a referência por 8 s (Calmo) ou 5 s (Tranquilo) e mantém tudo o que já foi feito.
- **Lógica:** é um quadrado latino. Cada linha e cada coluna têm todos os símbolos, sem repetir. As pistas fixas aparecem em casas mais escuras. Cada puzzle tem **exatamente uma solução**, comprovada por um resolvedor que conta as soluções.

### Como o teto de 200 combinações é garantido
1. `NIVEIS` fixa **30 puzzles por nível**, ou seja, **180 no total**. Se essa soma passar de `MAX_PUZZLES = 200`, o programa gera um erro e não roda.
2. O catálogo sai de `random.Random(SEMENTE_CATALOGO)`, com **semente fixa**. Por isso é sempre idêntico, e a validação gera o catálogo duas vezes e compara.
3. Puzzles repetidos (mesmo tipo, tamanho, estado inicial e alvo) são descartados.
4. O jogo **só lê puzzles do catálogo**. Nada é sorteado durante a partida.
5. `--validar` mostra uma *impressão digital* (hash SHA-256) do catálogo. Se ela mudar entre duas versões, algum puzzle mudou.

### Como cada parte ajuda a desacelerar e estimular
- **Sem relógio em nenhum lugar.** Só existem animações suaves e um tempo de revisão que a pessoa pode encerrar antes.
- **Pausa para respirar** antes de cada puzzle (pode ser desligada): um círculo que cresce e diminui em 10 s ou 8 s, com o botão “Começar agora”. Serve de âncora de atenção para quem está agitado.
- **Erro nunca pune.** “Verificar” responde com frases como “Quase lá…”, sem som de erro e sem perder pontos. Na lógica, os símbolos repetidos ganham um contorno terracota suave (é informação, não alarme).
- **Dicas em 3 degraus:** (1) um lembrete em palavras da regra ou da contagem de peças; (2) destaque de uma casa; (3) a peça certa é colocada, uma por pedido. Cada degrau ajuda um pouco mais que o anterior.
- **Desfazer** sem limite prático e **Limpar** que também pode ser desfeito, para que nenhuma ação acidental frustre.
- **Forma e cor juntas** em cada símbolo, mais a legenda com o nome (“Triângulo laranja”). Funciona para daltonismo e permite memorizar também pelo nome, o que ajuda quem tem declínio cognitivo.
- **Progressão gentil:** dentro de cada nível os puzzles vão do mais simples ao menos simples. Quando um nível termina, o jogo avisa e passa ao próximo com calma.
- **Progresso sem placar:** “Hoje: N concluídos · Nesta sessão: N · Você já explorou N de 180”. Não há recorde nem ranking.

---

## 2. Rodar a partir do código

```powershell
python puzzle_calmo.py
```
```powershell
python puzzle_calmo.py --validar
```
```powershell
python puzzle_calmo.py --autoteste
```

O progresso fica em `%APPDATA%\PuzzleCalmo\progresso.json`. Erros inesperados são gravados em `erros.log` na mesma pasta, e o jogo volta ao menu em vez de fechar.

---

## 3. Gerar o `.exe` no Windows

### Opção rápida
Dê dois cliques em **`gerar_exe.bat`**, na mesma pasta de `puzzle_calmo.py`. Ele cria um ambiente virtual, instala o PyInstaller, valida o catálogo e gera `dist\PuzzleCalmo.exe`.

### Passo a passo manual
1. Instale o **Python 3.10 ou mais novo** pelo site python.org. Durante a instalação, marque “Add python.exe to PATH” e deixe marcado “tcl/tk and IDLE”.
2. Abra o PowerShell na pasta do jogo e crie um ambiente limpo. Isso deixa o `.exe` menor e com menos falsos positivos de antivírus:
   ```powershell
   py -3 -m venv .venv
   ```
   ```powershell
   .\.venv\Scripts\Activate.ps1
   ```
   Se o PowerShell bloquear a ativação, rode antes `Set-ExecutionPolicy -Scope Process Bypass`.
3. Instale o PyInstaller:
   ```powershell
   python -m pip install --upgrade pip pyinstaller
   ```
4. Valide antes de empacotar:
   ```powershell
   python puzzle_calmo.py --validar
   ```
5. Gere o executável único:
   ```powershell
   pyinstaller --noconfirm --clean --onefile --windowed --name PuzzleCalmo puzzle_calmo.py
   ```
   - `--onefile`: gera um único `.exe`.
   - `--windowed`: abre sem janela de console.
   - **Recursos externos (assets):** não há nenhum. Fontes, cores, formas e até o som são gerados pelo próprio código, então não é preciso usar `--add-data`.
   - Ícone (opcional): acrescente `--icon icone.ico` (precisa ser `.ico`).
6. O resultado fica em **`dist\PuzzleCalmo.exe`**. As pastas `build\` e o arquivo `PuzzleCalmo.spec` podem ser apagados.

### Testar o `.exe`
1. Copie `dist\PuzzleCalmo.exe` para **outra pasta**, por exemplo a Área de Trabalho, e, se possível, para **outro PC sem Python**.
2. Abra o jogo, conclua um puzzle, feche e abra de novo: o contador “Você já explorou…” deve continuar.
3. Confira se `%APPDATA%\PuzzleCalmo\progresso.json` foi criado.
4. Teste com a escala do Windows em 100%, 125% e 150% (Configurações → Tela). O texto deve continuar nítido.

### Problemas comuns
| Sintoma | Causa | Solução |
|---|---|---|
| Aviso “O Windows protegeu o computador” (SmartScreen) | O `.exe` não tem assinatura digital | Clique em **Mais informações → Executar assim mesmo**. Para distribuir sem esse aviso, assine o executável com um certificado de *code signing* (`signtool sign …`). |
| Antivírus coloca o `.exe` em quarentena | Falso positivo comum com `--onefile` do PyInstaller | Gere o executável num venv limpo, atualize o PyInstaller e envie o arquivo como falso positivo ao fabricante (no Microsoft Defender, pelo portal de envio de arquivos). Se não resolver, use `--onedir` no lugar de `--onefile` e distribua a pasta compactada. |
| O `.exe` demora 2 a 5 s para abrir | O `--onefile` descompacta tudo numa pasta temporária a cada abertura | É normal. Para abrir mais rápido, use `--onedir`. |
| `ModuleNotFoundError: tkinter` | Python instalado sem Tcl/Tk | Reinstale o Python marcando “tcl/tk and IDLE”. |
| Nada aparece ao abrir | Erro antes de a janela abrir | Gere uma vez **sem** `--windowed` para ver o erro no console e consulte `%APPDATA%\PuzzleCalmo\erros.log`. |
| O progresso não é salvo | Sem permissão na pasta | O jogo grava em `%APPDATA%`, nunca na pasta do `.exe`. Então ele funciona até em `Program Files` ou num pendrive somente leitura. |
| `--validar` no `.exe` não mostra nada | Um `.exe` com `--windowed` não tem console | O relatório é gravado em `%APPDATA%\PuzzleCalmo\validacao.txt`. |

---

## 4. Checklist de validação

### A. Integridade dos puzzles (automática)
- [ ] `python puzzle_calmo.py --validar` termina com **OK** e código de saída 0. Ele confere:
  - total de 180 puzzles, até o teto de 200;
  - catálogo determinístico (gerado duas vezes, resultados idênticos);
  - 180 combinações únicas, sem duplicatas;
  - em cada puzzle de lógica: a solução é um quadrado latino, as pistas batem com a solução, há **exatamente 1 solução** (o resolvedor procura até 3) e o número de pistas está dentro da faixa do nível;
  - em cada puzzle de memória: o estado inicial está vazio, a quantidade de peças está na faixa e todos os tipos de peça são usados;
  - **dicas**: partindo do estado inicial e de um estado bagunçado, só as dicas de nível 3 sempre levam à solução.
- [ ] Anote a impressão digital (`Impressão digital ...`). Se ela mudar sem que você tenha mexido em `NIVEIS`, na semente ou nos geradores, investigue.
- [ ] `python puzzle_calmo.py --autoteste` responde “AUTOTESTE OK: 6 de 6”. Ele abre a janela, passa pela respiração, memorização, revisão, verificação e dicas em um puzzle de cada nível, abre todas as telas com texto grande e fecha, sem salvar progresso.

### B. Teto de 200 combinações
- [ ] Mude temporariamente um `qtd` em `NIVEIS` para 60: o jogo deve recusar com “excede o teto de 200”.
- [ ] Procure no código por `random`: ele só é usado em `construir_catalogo()` (com semente fixa) e no teste interno das dicas. A tela de jogo não sorteia nada.

### C. Usabilidade — perfil com hiperatividade / agitação mental
- [ ] Nenhum número de contagem regressiva aparece em nenhuma tela.
- [ ] A pausa para respirar pode ser **pulada** (“Começar agora”) e **desligada** (Ajustes).
- [ ] O som vem **desligado** de fábrica e, quando ligado, toca só um sino baixo ao concluir. Nunca há som de erro.
- [ ] O modo Tranquilo reduz animações e esperas para quem se irrita com lentidão, sem criar tempo-limite.
- [ ] Teste de foco: jogar 5 puzzles seguidos sem que nada na tela pisque ou se mexa sem uma ação da pessoa (fora a respiração).

### D. Usabilidade — perfil com declínio cognitivo leve a moderado
- [ ] Botões com pelo menos ~44 px de altura e espaço entre eles. Com “Tamanho do texto: grande”, nada fica cortado na janela padrão.
- [ ] Toda instrução cabe em uma ou duas frases curtas, no topo da tela de jogo.
- [ ] Peças distinguíveis **sem cor**: teste com o filtro de tons de cinza do Windows (Configurações → Acessibilidade → Filtros de cor).
- [ ] “Rever padrão” não apaga nada do que a pessoa já fez.
- [ ] “Limpar” pode ser desfeito com “Desfazer”.
- [ ] Ao fechar e reabrir, “Iniciar” continua do nível onde a pessoa parou.
- [ ] Sessão observada com 2 ou 3 pessoas de cada perfil: anote onde hesitam, quantas dicas pedem por nível e se o nível 1 é concluído **sem ajuda** depois de ler “Como jogar”.

### E. Teclado e acessibilidade
- [ ] É possível jogar só com o teclado: Tab entre botões; setas, Espaço/Enter e as teclas 1–4 e 0 na grade.
- [ ] O texto continua nítido com a escala do Windows em 125% e 150%.
- [ ] Contraste: o texto principal (#2B2F33 sobre #F3F0E8) fica em torno de 12:1, e o botão principal (branco sobre #3F6896) em torno de 5,9:1. Ambos atendem ao nível WCAG AA.
