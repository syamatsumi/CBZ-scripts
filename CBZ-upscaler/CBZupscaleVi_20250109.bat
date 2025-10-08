@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion
set "STARTTIME=%date% %time%"

set EXTFOLDER=_ext
set EXTPATH=%CD%\%EXTFOLDER%
set POSTFIX=_sc
set MAXPARAL=8

rem === 7Zip パス（必要なら調整） ===
set ZIP7=%ProgramFiles%\7-Zip\7z.exe
if not exist "%ZIP7%" (
    echo [ERROR] 7-Zip 実行ファイルが見つかりませんでした。^<%ZIP7%^>
    pause
    exit /b 1
)
rem === Powershell パス確認 ===
where pwsh >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 最新版のPowershellがインストールされていないようです。.
    echo         管理者PSコンソールで下記コマンドを試してみてください。.
    echo         winget install --id Microsoft.Powershell --source winget
    pause
    exit /b 1
)
rem === ImageMagick パス確認 ===
where magick >nul 2>nul
if errorlevel 1 (
    echo [ERROR] magick.exe のパスが通っていないようです。.
    echo         ImageMagickをインストールしてから実行してください。.
    pause
    exit /b 1
)
set MAINSCR_NAME=%~n0
for /f "tokens=1,* delims=_" %%A in ("%MAINSCR_NAME%") do set "MAINSCR_BASE=%%A"
set SUBSCR_ORCHESTR=%~dp0%MAINSCR_BASE%_orchestr.ps1
if not exist "%SUBSCR_ORCHESTR%" echo Not found: %SUBSCR_ORCHESTR% & pause & exit /b 1
set SUBSCR_UPSCALE=%~dp0%MAINSCR_BASE%_upscale.ps1
if not exist "%SUBSCR_UPSCALE%" echo Not found: %SUBSCR_UPSCALE% & pause & exit /b 1
set SUBSCR_WIPEDIR=%~dp0%MAINSCR_BASE%_wipedir.ps1
if not exist "%SUBSCR_WIPEDIR%" echo Not found: %SUBSCR_WIPEDIR% & pause & exit /b 1

for %%F in ("*.cbz") do (
  set OUTDIR=%EXTFOLDER%\%%~nF%POSTFIX%
  if not exist "!OUTDIR!" mkdir "!OUTDIR!"
  echo [EXTRACT] !OUTDIR!
  rem overwrite-aoa skip-aos rename-aou renameext-aot 
  "%ZIP7%" x "%%F" -o"!OUTDIR!" -aou -bb0 -bso0

  rem --- flatten: OUTDIR直下のアイテムが1つで、かつフォルダの場合はフラット化 ---
  for /f "delims=" %%I in ('dir /b "!OUTDIR!" 2^>nul') do set "ONLYITEM=%%I"
  for /f %%C in ('dir /b "!OUTDIR!" 2^>nul ^| find /c /v ""') do set "ITEMCNT=%%C"
  if "!ITEMCNT!"=="1" if exist "!OUTDIR!\!ONLYITEM!\" (
    echo [FLATTEN] !OUTDIR!\!ONLYITEM!
    robocopy "!OUTDIR!\!ONLYITEM!" "!OUTDIR!" /E /MOVE /NFL /NDL /NJH /NJS /NP
  )
)
rem === ゴミ（特にMac系のゴミを）掃除する PS1 を呼び出す ===
pwsh -NoProfile -ExecutionPolicy Bypass -File "%SUBSCR_WIPEDIR%" -TgtRoot "%EXTPATH%"

pushd "%EXTFOLDER%"
for /d %%D in (*) do (
  rem === アップスケール＆WebP圧縮する PS1 を呼び出す ===
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%SUBSCR_ORCHESTR%" -TgtRoot "%%D" -MxPal %MAXPARAL% -Worker "%SUBSCR_UPSCALE%"
  if not exist "%%~nxD.cbz" (
    rem === 生ファイル残存チェック ===
    dir /b /s "%%D\*.jpg" "%%D\*.jpeg" "%%D\*.png" >nul 2>nul
    if errorlevel 1 (
      set ZIPNAME=%%~nxD.zip
      set CBZNAME=%%~nxD.cbz
      pwsh -NoProfile -ExecutionPolicy Bypass -File "%SUBSCR_WIPEDIR%" -TgtRoot "%EXTPATH%"
      "%ZIP7%" a -tzip "!ZIPNAME!" "%%~nxD\" -bb0 -bso0
      "%ZIP7%" t "!ZIPNAME!" >nul
      if errorlevel 1 (
        echo [ERROR] !ZIPNAME! failed verification.
      ) else (
        ren "!ZIPNAME!" "!CBZNAME!"
        rmdir /s /q "%%~nxD"
      )
    ) else (
      echo [SKIP] %%D に未変換の JPG/PNG が残っています。.
      echo        → CBZ化処理をスキップしました。.
    )
  )else (
      echo [SKIP] %%~nxD.cbz が既に存在しています。.
      echo        → %%~nxDの処理をスキップしました。.
  )
)
popd
echo .
set "ENDTIME=%date% %time%"
echo すべての拡大処理が完了しました。.
echo すべての処理にかかった時間.
pwsh -command "$ts=[datetime]'%ENDTIME%' - [datetime]'%STARTTIME%'; '{0}day {1:hh\:mm\:ss\.ff}' -f $ts.Days,$ts"

pause
endlocal