# =============================================================================
#  Puzzle Calmo (Android) - prepara o projeto, valida e gera o .apk
#
#  Uso (PowerShell, dentro desta pasta):
#     .\gerar_apk.ps1              -> APK release (instalável, assinado com chave de depuração)
#     .\gerar_apk.ps1 -Modo debug  -> APK debug
#  Se o Windows bloquear o script:  Set-ExecutionPolicy -Scope Process Bypass
# =============================================================================
param([ValidateSet('release', 'debug')] [string]$Modo = 'release')

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Invoke-Passo([string]$titulo, [scriptblock]$acao) {
    Write-Host ""
    Write-Host "==> $titulo" -ForegroundColor Cyan
    & $acao
    if ($LASTEXITCODE -ne 0) { Write-Host "Falhou: $titulo" -ForegroundColor Red; exit 1 }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter não encontrado no PATH. Veja o LEIA-ME-ANDROID.md, seção 'Preparar o ambiente'." -ForegroundColor Red
    exit 1
}

# 1) Gera a pasta android/ (Gradle, manifest, ícone padrão) só na primeira vez.
#    Arquivos que já existem (lib/, test/, pubspec.yaml) NÃO são sobrescritos.
if (-not (Test-Path 'android')) {
    Invoke-Passo 'Criando a estrutura Android do projeto' {
        flutter create --platforms=android --org br.puzzlecalmo --project-name puzzle_calmo .
    }
}

# 2) Nome que aparece embaixo do ícone no celular.
$manifesto = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
$xml = [IO.File]::ReadAllText($manifesto)
$novo = $xml -replace 'android:label="[^"]*"', 'android:label="Puzzle Calmo"'
if ($novo -ne $xml) { [IO.File]::WriteAllText($manifesto, $novo, (New-Object Text.UTF8Encoding $false)) }

Invoke-Passo 'Baixando dependências (só precisa de internet aqui, no build)' { flutter pub get }
Invoke-Passo 'Validando catálogo e interface (flutter test)' { flutter test }
Invoke-Passo "Gerando APK ($Modo)" { flutter build apk --$Modo }

$origem = "build\app\outputs\flutter-apk\app-$Modo.apk"
$destino = "PuzzleCalmo-$Modo.apk"
Copy-Item $origem $destino -Force
$mb = [math]::Round((Get-Item $destino).Length / 1MB, 1)
Write-Host ""
Write-Host "Pronto! $destino ($mb MB) está nesta pasta." -ForegroundColor Green
Write-Host "Para instalar com cabo USB:  adb install -r $destino"
