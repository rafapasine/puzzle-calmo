@echo off
REM ==========================================================
REM  Puzzle Calmo - gera PuzzleCalmo.exe (arquivo unico)
REM  Rode este arquivo na mesma pasta de puzzle_calmo.py
REM ==========================================================
cd /d "%~dp0"

echo [1/4] Criando ambiente virtual limpo (.venv)...
if not exist .venv ( py -3 -m venv .venv || python -m venv .venv )
call .venv\Scripts\activate.bat

echo [2/4] Instalando PyInstaller...
python -m pip install --upgrade pip pyinstaller

echo [3/4] Validando o catalogo de puzzles...
python puzzle_calmo.py --validar
if errorlevel 1 ( echo Validacao falhou. Abortando. & pause & exit /b 1 )

echo [4/4] Gerando o executavel...
pyinstaller --noconfirm --clean --onefile --windowed --name PuzzleCalmo puzzle_calmo.py
if errorlevel 1 ( echo Falha ao gerar o .exe. & pause & exit /b 1 )

echo.
echo Pronto! Executavel em: %cd%\dist\PuzzleCalmo.exe
pause
