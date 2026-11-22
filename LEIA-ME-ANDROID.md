# Puzzle Calmo para Android — guia técnico

Versão Android do Puzzle Calmo, feita em **Flutter**. É o mesmo jogo da versão para Windows: duas mecânicas, 6 níveis, 180 puzzles fixos, dicas gentis e nenhum relógio. A interface foi pensada para o toque. O app funciona **100% offline**, não tem anúncios e não pede permissão de internet.

```
puzzle_calmo_android/
├─ lib/
│  ├─ catalogo.dart      lógica pura: gerador determinístico, resolvedor, catálogo, dicas, validação
│  ├─ progresso.dart     ajustes e progresso salvos no aparelho (shared_preferences)
│  └─ main.dart          interface: menu, níveis, como jogar, ajustes, tela de jogo
├─ test/
│  ├─ catalogo_test.dart valida os 180 puzzles (teto, unicidade, solução única, dicas)
│  └─ widget_test.dart   abre o app num "celular" virtual e resolve um puzzle
├─ ferramentas/conferir_catalogo.py   espelho em Python do catálogo (confere sem o Flutter)
├─ pubspec.yaml
└─ gerar_apk.ps1         prepara, testa e gera o .apk com um comando
```

---

## 1. Arquitetura e mecânica

### Por que Flutter (e não Kivy/Buildozer)
| Critério | Flutter | Python + Kivy/Buildozer |
|---|---|---|
| Gerar o APK no Windows | Nativo: `flutter build apk` | O Buildozer só roda em Linux; no Windows exige WSL |
| Primeiro build | ~5 a 10 min | 20 a 40 min (compila Python e as receitas para Android) |
| Toque e rolagem | Nativos, 60 a 120 fps, ripple, gestos | Funciona, mas a sensação é menos nativa |
| Densidade de tela | Unidades `dp` automáticas; respeita o tamanho de fonte do sistema | Precisa de `dp()` e `sp()` manuais |
| Acessibilidade (TalkBack, "remover animações") | Pronta (`Semantics`, `disableAnimations`) | Muito limitada |
| Tamanho do APK | ~17 a 20 MB (release, várias arquiteturas) | ~25 a 40 MB |
| Estabilidade das ferramentas | SDK oficial do Google, bem mantido | Receitas do python-for-android quebram com frequência |

### Mecânicas e níveis
| Nível | Tipo | Grade | Carga |
|---|---|---|---|
| 1 Lembrar | Memória | 3×3 | 2 a 3 círculos |
| 2 Completar | Lógica | 3×3 | 3 símbolos, 5 a 6 pistas |
| 3 Lembrar mais | Memória | 3×3 | 3 a 4 peças, 2 tipos |
| 4 Completar mais | Lógica | 4×4 | 4 símbolos, 9 a 10 pistas |
| 5 Lembrar com atenção | Memória | 4×4 | 4 a 5 peças, 3 tipos |
| 6 Deduzir | Lógica | 4×4 | 6 a 7 pistas |

- **Memória:** a pessoa observa o padrão **sem limite de tempo** e toca em "Já memorizei". Depois escolhe a peça na **paleta** e toca nas casas para colocá-la. **Rever padrão** mostra a referência por 8 s (ritmo Calmo) ou 5 s (Tranquilo) e mantém tudo o que já foi feito.
- **Lógica:** é um quadrado latino. Cada linha e cada coluna têm todos os símbolos, sem repetir. As casas escuras já vêm prontas. Cada puzzle tem **exatamente uma solução**, provada pelo resolvedor.

### Como o teto de 200 é garantido
1. `niveis` fixa **30 puzzles por nível, 180 no total**. Se a soma passar de `maxPuzzles = 200`, o app gera um erro e não roda.
2. O gerador de números é **próprio** (xorshift32, só usa deslocamentos e XOR em 32 bits) e começa de uma **semente fixa**. Por isso o catálogo é idêntico em qualquer celular e em qualquer versão do Dart, o que não é garantido com o `Random` da linguagem.
3. Combinações repetidas são descartadas. A ordenação dentro de cada nível é estável, então a ordem também é sempre a mesma.
4. O app **só lê puzzles do catálogo**. Nada é sorteado durante a partida.
5. A **impressão digital** do catálogo (FNV-1a, `f74b8149`) é conferida por `flutter test` e também pelo espelho em Python. Se as duas baterem, o celular usa exatamente os puzzles validados.

> Os puzzles da versão Android são diferentes dos da versão Windows, porque os geradores de números são diferentes. As regras, as faixas de dificuldade e as garantias são as mesmas.

### Desaceleração, lógica e memória pensadas para o toque
- **Sem relógio em nenhuma tela.**
- **Respiração guiada** antes de cada puzzle: um círculo cresce e diminui em 10 s ou 8 s. Pode ser pulada ("Começar agora") ou desligada.
- **Paleta "pincel":** a pessoa escolhe a peça uma vez e toca nas casas; tocar de novo retira. A escolha é direta, sem ficar trocando peça a peça a cada toque, o que é mais claro para quem tem declínio cognitivo. No nível 1 basta tocar nas casas.
- **Proteção contra toque duplo** (ligada por padrão): ignora um segundo toque na mesma casa em menos de 0,45 s, o que acontece com tremor ou agitação motora. O botão "Próximo puzzle" também ignora toques repetidos.
- **Áreas de toque grandes:** botões e peças com pelo menos 64 dp de altura (a recomendação mínima do Android é 48 dp), com 10 a 14 dp de espaço entre eles. As casas da grade vão de cerca de 60 dp a 130 dp.
- **Erro nunca pune:** sem som de erro, com mensagens como "Quase lá…". Símbolos repetidos ganham borda terracota suave.
- **Dicas em 3 degraus:** um lembrete em palavras, depois o destaque de uma casa, depois uma peça colocada por pedido.
- **Desfazer** e **Limpar** (que também pode ser desfeito).
- **Forma + cor + nome** em cada peça, com a paleta servindo de legenda. Funciona para daltonismo e permite memorizar também pelo nome.
- **Leitura e fonte:** respeita o tamanho de fonte do Android (até 1,8×) e tem a opção "Texto grande" no app. O layout se adapta a celular em pé, celular deitado e tablet.
- **Acessibilidade:** o TalkBack lê cada casa ("Linha 2, coluna 3: triângulo laranja, já vem pronta") e anuncia as mensagens. O ajuste "Remover animações" do Android desliga as transições e deixa o círculo da respiração parado.
- **Som** e **vibração** vêm desligados de fábrica. O som é o clique do sistema, só ao concluir um puzzle (e só toca se os sons de toque estiverem ativos no Android).

---

## 2. Gerar o `.apk`

### 2.1 Preparar o ambiente (uma vez só, no Windows)
1. **Android Studio** (developer.android.com/studio): instale com as opções padrão. Ele já traz o Android SDK, o emulador e o Java (JDK) que o Gradle usa.
   - Abra o Android Studio → **More Actions → SDK Manager → SDK Tools** e marque **Android SDK Command-line Tools** e **Android SDK Platform-Tools**.
2. **Flutter SDK** (docs.flutter.dev → Get started → Windows → Android): baixe o `.zip` da versão estável **3.24 ou mais nova** e extraia em `C:\src\flutter`. Evite caminhos com espaços ou acentos.
3. Coloque o Flutter no PATH, abra um PowerShell **novo** e confira:
   ```powershell
   [Environment]::SetEnvironmentVariable('Path', $env:Path + ';C:\src\flutter\bin', 'User')
   ```
   ```powershell
   flutter --version
   ```
4. Aceite as licenças do Android e confira o ambiente:
   ```powershell
   flutter doctor --android-licenses
   ```
   ```powershell
   flutter doctor
   ```
   As linhas **Flutter** e **Android toolchain** precisam aparecer com ✓.

### 2.2 Compilar (um comando)
Na pasta `puzzle_calmo_android`:
```powershell
Set-ExecutionPolicy -Scope Process Bypass
```
```powershell
.\gerar_apk.ps1
```
O script:
1. cria a pasta `android/` com `flutter create`, só na primeira vez e sem sobrescrever o código;
2. coloca o nome "Puzzle Calmo" embaixo do ícone;
3. roda `flutter pub get` (é o único passo que precisa de internet, e só no build);
4. roda `flutter test`, que valida os 180 puzzles e a interface. **Se algum teste falhar, o APK não é gerado**;
5. roda `flutter build apk --release` e copia o resultado para `PuzzleCalmo-release.apk`.

Para um APK de depuração: `.\gerar_apk.ps1 -Modo debug`.

#### Comandos manuais equivalentes
```powershell
flutter create --platforms=android --org br.puzzlecalmo --project-name puzzle_calmo .
```
```powershell
flutter pub get
```
```powershell
flutter test
```
```powershell
flutter build apk --debug
```
```powershell
flutter build apk --release
```
```powershell
flutter build apk --release --split-per-abi
```
- Os arquivos gerados ficam em `build\app\outputs\flutter-apk\`.
- O `--split-per-abi` gera um APK menor (~7 MB) para cada arquitetura. A maioria dos celulares atuais usa `app-arm64-v8a-release.apk`.
- O release gerado assim é **assinado com a chave de depuração**. Ele instala normalmente por arquivo, mas não serve para a Play Store.

#### (Opcional) Assinatura própria para distribuir ou publicar
1. Crie a chave uma vez e guarde o arquivo e a senha em lugar seguro:
   ```powershell
   keytool -genkey -v -keystore $env:USERPROFILE\puzzle-calmo.jks -keyalg RSA -keysize 2048 -validity 10000 -alias puzzlecalmo
   ```
   (O `keytool` vem com o Android Studio, em `C:\Program Files\Android\Android Studio\jbr\bin`.)
2. Crie `android\key.properties` com `storePassword`, `keyPassword`, `keyAlias=puzzlecalmo` e `storeFile=C:/Users/SEU_USUARIO/puzzle-calmo.jks`.
3. Em `android\app\build.gradle` (ou `build.gradle.kts`), crie um `signingConfigs.release` que lê esse arquivo e use-o no `buildTypes.release`. A receita oficial está em docs.flutter.dev → Deployment → Android → "Signing the app".
4. Para a Play Store, gere `flutter build appbundle` (`.aab`).

### 2.3 Instalar no celular ou tablet
**Opção A: transferir o arquivo (sem cabo de dados)**
1. Envie `PuzzleCalmo-release.apk` para o celular por cabo USB (modo "Transferência de arquivos"), Google Drive, e-mail ou mensagem para si mesmo.
2. No celular, abra o arquivo com o app **Arquivos** (ou pelo download).
3. Na primeira vez, o Android pede permissão: **Configurações → Instalar apps desconhecidos →** escolha o app usado para abrir o arquivo (Arquivos, Chrome, Drive) **→ Permitir desta fonte**. Nas versões 7 e anteriores do Android, a opção fica em **Segurança → Fontes desconhecidas**.
4. Toque em **Instalar**. Se o Play Protect avisar "app desconhecido", toque em **Mais detalhes → Instalar mesmo assim**. O aviso aparece porque o app não veio da Play Store.
5. Depois de instalar, pode desligar de novo a permissão "Instalar apps desconhecidos".

**Opção B: cabo USB com ADB (recomendado para testar)**
1. No celular: **Configurações → Sobre o telefone → toque 7 vezes em "Número da versão"** para liberar as Opções do desenvolvedor. Depois, **Opções do desenvolvedor → Depuração USB: ligada**.
2. Conecte o cabo e aceite a pergunta "Permitir depuração USB?".
3. No PC:
   ```powershell
   adb devices
   ```
   ```powershell
   adb install -r PuzzleCalmo-release.apk
   ```
   Ou, para rodar direto do código com recarga rápida: `flutter run --release`.

**Opção C: emulador**
1. No Android Studio: **More Actions → Virtual Device Manager → Create device**. Escolha, por exemplo, um "Pixel 6" com uma imagem recente do Android, e um "Medium Tablet" para testar telas maiores.
2. Com o emulador aberto, rode `flutter run` na pasta do projeto, ou arraste o `.apk` para a janela do emulador.

### Problemas comuns
| Sintoma | Solução |
|---|---|
| `flutter` não é reconhecido | Abra um PowerShell novo depois de mudar o PATH e confira com `flutter --version`. |
| `Android license status unknown` | Rode `flutter doctor --android-licenses` e aceite tudo. |
| `cmdline-tools component is missing` | No SDK Manager do Android Studio, aba SDK Tools, marque "Android SDK Command-line Tools". |
| O Gradle demora muito no primeiro build | É normal (ele baixa dependências). Os builds seguintes levam menos de 1 min. |
| Erro de versão do Java ou Gradle | Rode `flutter doctor -v` e confira se o JDK é o do Android Studio: `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"`. |
| "App não instalado" | Já existe uma versão assinada com outra chave. Desinstale a antiga e instale de novo. |
| `adb devices` não mostra o celular | Troque por um cabo de dados, aceite o aviso de depuração no celular e, em alguns aparelhos, instale o driver USB do fabricante. |
| Um teste falhou no `gerar_apk.ps1` | Leia a mensagem: ela mostra o número do puzzle e o problema. Não publique até corrigir. |

---

## 3. Checklist de validação

### A. Integridade dos puzzles (automática)
- [ ] `flutter test` passa em todos os testes de `catalogo_test.dart`:
  - o gerador xorshift32 reproduz a sequência de referência;
  - são 180 puzzles (teto de 200), 30 por nível;
  - o catálogo é determinístico (gerado duas vezes, idêntico);
  - as 180 combinações são únicas;
  - `validarCatalogo` não encontra problemas: cada puzzle de lógica tem solução de quadrado latino, pistas coerentes, **exatamente 1 solução** e número de pistas dentro da faixa; cada puzzle de memória está na faixa de peças e usa todos os tipos; e as dicas de nível 3, partindo do início e de um estado bagunçado, **sempre levam à solução**;
  - a impressão digital é `f74b8149`, igual à do conferidor em Python.
- [ ] `python ferramentas/conferir_catalogo.py` mostra **OK** e a mesma impressão digital (dá para conferir sem o Flutter).
- [ ] `widget_test.dart` passa: abre o app num celular virtual de 360×780 dp, resolve o nível 1 só com dicas e abre todas as telas.

### B. Teto de 200 combinações
- [ ] Mude temporariamente um `qtd` em `niveis` para 60: o app e os testes devem falhar com "excede o teto de 200".
- [ ] Procure no código por `GeradorDeterministico`: ele só é usado em `construirCatalogo()` e na validação. A tela de jogo não sorteia nada.

### C. Toque e ergonomia (celular real e tablet)
- [ ] Todos os botões e peças são fáceis de acertar com o polegar, sem esbarrar no vizinho. Teste com a mão não dominante.
- [ ] **Tremor simulado:** toque duas vezes bem rápido na mesma casa. Com a proteção ligada, a peça deve ficar (o segundo toque é ignorado).
- [ ] Toque várias vezes seguidas em "Próximo puzzle": deve avançar só **um** puzzle.
- [ ] Gire o aparelho: o layout deitado mostra a grade à esquerda e os controles à direita, sem cortar nada.
- [ ] Em **Configurações → Tela → Tamanho da fonte** no máximo e com "Texto grande" ligado, nada fica cortado; no máximo, a tela rola.
- [ ] Teste num celular pequeno (~5") e num tablet de 10".

### D. Perfil com hiperatividade / agitação mental
- [ ] Nenhum número de contagem regressiva aparece em nenhuma tela.
- [ ] A respiração pode ser pulada e desligada; o ritmo Tranquilo encurta as transições sem criar tempo-limite.
- [ ] Som e vibração vêm desligados; não existe som nem vibração de erro.
- [ ] Nada pisca nem se mexe sem uma ação da pessoa, fora o círculo da respiração.

### E. Perfil com declínio cognitivo leve a moderado
- [ ] As instruções têm 1 ou 2 frases curtas e ficam sempre acima da grade.
- [ ] A paleta mostra o nome das peças, e a peça escolhida tem borda grossa e texto em negrito.
- [ ] As peças são distinguíveis sem cor: teste com **Acessibilidade → Correção de cor / Escala de cinza**.
- [ ] "Rever padrão" não apaga nada; "Limpar" pode ser desfeito.
- [ ] Ao fechar e reabrir, "Iniciar" continua do nível onde a pessoa parou, e o progresso continua salvo.
- [ ] Sessão observada com 2 ou 3 pessoas de cada perfil: anote hesitações, dicas pedidas por nível e se o nível 1 é concluído sem ajuda depois de ler "Como jogar".

### F. Acessibilidade e privacidade
- [ ] Com o **TalkBack** ligado, cada casa e cada peça é lida com um nome claro, o toque duplo coloca a peça e a mensagem do topo é anunciada.
- [ ] Com **Acessibilidade → Remover animações** ligado, não há transições e o círculo da respiração fica parado.
- [ ] Com o **modo avião** ligado, o app funciona completo.
- [ ] Em Configurações → Apps → Puzzle Calmo → Permissões: **nenhuma permissão** é pedida.
