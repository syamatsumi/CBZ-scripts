@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

rem 以下はユーザーが任意に設定する必要のある項目です。.
rem 接尾辞と切り分けるためのデリミタや解凍先（作業用）フォルダを設定する.
set "SPLIT_KEY= - "
set EXTFOLDER=_extract

rem === 7Zip パス（必要なら調整） ===
set ZIP7=%ProgramFiles%\7-Zip\7z.exe
if not exist "%ZIP7%" (
    echo [ERROR] 7-Zip 実行ファイルが見つかりませんでした。^<%ZIP7%^>
    pause
    exit /b 1
)
set MAINSCR_NAME=%~n0
for /f "tokens=1,* delims=_" %%A in ("%MAINSCR_NAME%") do set "MAINSCR_BASE=%%A"
set SUBSCR_DEDUPE=%~dp0%MAINSCR_BASE%_dedup.ps1
set SUBSCR_REPSYM=%~dp0%MAINSCR_BASE%_repsym.ps1
if not exist "%SUBSCR_DEDUPE%" echo Not found: %SUBSCR_DEDUPE% & pause & exit /b 1
if not exist "%SUBSCR_REPSYM%" echo Not found: %SUBSCR_REPSYM% & pause & exit /b 1

echo.
echo "%SPLIT_KEY%"より左側だけの名前（なければ全体）で解凍＆結合.
pause

for %%F in ("*.cbz") do (
  set NAME=%%~nF
  set TMPNAME=!NAME:%SPLIT_KEY%=^|!
  for /f "tokens=1 delims=|" %%A in ("!TMPNAME!") do set BASE=%%A
  if not defined BASE set BASE=!NAME!
  set OUTDIR=%EXTFOLDER%\!BASE!
  if not exist "!OUTDIR!" mkdir "!OUTDIR!"

  echo [EXTRACT] %%~nxF -> !OUTDIR!
  rem overwrite-aoa skip-aos rename-aou renameext-aot 
  "%ZIP7%" x "%%F" -o"!OUTDIR!" -aou

  set OUTFULLPATH=%CD%\!OUTDIR!
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SUBSCR_DEDUPE%" -Root "!OUTFULLPATH!"
)

set EXTFULLPATH=%CD%\%EXTFOLDER%
powershell -noprofile -executionpolicy bypass -file "%SUBSCR_REPSYM%" -Root "%EXTFULLPATH%"

pushd "%EXTFOLDER%"
for /d %%D in (*) do (
  if not exist "%%~nxD.cbz" (
  set ZIPNAME=%%~nxD.zip
  set CBZNAME=%%~nxD.cbz
    "%ZIP7%" a -tzip "!ZIPNAME!" "%%~nxD\"
    "%ZIP7%" t "!ZIPNAME!" >nul
    if !errorlevel! == 0 (
      ren "!ZIPNAME!" "!CBZNAME!"
      rmdir /s /q "%%~nxD"
    ) else (
      echo [ERROR] !ZIPNAME! failed verification.
    )
  )
)
popd

echo .
echo すべての展開が完了しました。.
pause
endlocal