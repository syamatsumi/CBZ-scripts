@echo off
chcp 65001
cd /d "%~dp0"

rem 直接実行でコケた時のための利用ヒント表示。
if "%~1"=="" (
  echo Caution
  echo For Drag and Drop only.
  echo Drag and drop the PDF into this batch.
  echo.
  pause
  exit /b 1
)

set POPPLER=poppler\Library\bin
set OUTROOT=CONVERTED
if not exist "%OUTROOT%" mkdir "%OUTROOT%"

set SRC=%~1
set BASENAME=%~n1

rem 作業用ルートは毎回ランダム名にし、存在すれば振り直す.
:mkwork
set WORK=work_%RANDOM%%RANDOM%
if exist "%WORK%" goto :mkwork
mkdir "%WORK%" || (echo 作業フォルダ作成失敗 & exit /b 1)

rem 一時PDFと一時出力フォルダ（ASCII名）も衝突回避.
:mkpdf
set TMPPDF=%WORK%\pdf_%RANDOM%%RANDOM%.pdf
if exist "%TMPPDF%" goto :mkpdf

:mkouttmp
set TMPDIR=%WORK%\out_%RANDOM%%RANDOM%
if exist "%TMPDIR%" goto :mkouttmp
mkdir "%TMPDIR%" || (echo 作業出力作成失敗 & rd /s /q "%WORK%" & rd /s /q "%OUTROOT%" & exit /b 1)

copy /y "%SRC%" "%TMPPDF%" >nul || (echo コピー失敗 & rd /s /q "%WORK%" & rd /s /q "%OUTROOT%" & exit /b 1)

"%POPPLER%\pdfimages.exe" -all "%TMPPDF%" "%TMPDIR%\img"
if errorlevel 1 (
  echo pdfimages 失敗
  del /q "%TMPPDF%" >nul 2>&1
  rd /s /q "%WORK%"
  rd /s /q "%OUTROOT%"
  exit /b 1
)
rem 最終配置: OUTROOT\BASENAME があれば _1, _2 … を付与.
set TARGET=%OUTROOT%\%BASENAME%
set /a N=0
:check_target
if exist "%TARGET%" (
  set /a N+=1
  set TARGET=%OUTROOT%\%BASENAME%_%N%
  goto :check_target
)
move "%TMPDIR%" "%TARGET%" >nul || (
  echo 配置失敗
  del /q "%TMPPDF%" >nul 2>&1
  rd /s /q "%WORK%"
  rd /s /q "%OUTROOT%"
  exit /b 1
)
del /q "%TMPPDF%" >nul 2>&1
rd /s /q "%WORK%" >nul 2>&1
echo 出力: "%TARGET%"   （この実行の出力ルート: "%OUTROOT%"）.
pause
