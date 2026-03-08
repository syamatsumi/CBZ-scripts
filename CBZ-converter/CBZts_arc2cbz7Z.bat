@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

rem ### 7Zip パス（必要に応じて調整） ###
set ZIP7=%ProgramFiles%\7-Zip\7z.exe
if not exist "%ZIP7%" (
  echo [ERROR] 7-Zip が見つかりません: %ZIP7%
  pause
  exit /b 1
)
rem #### Settings ####
set ZIPPASS=passwords
set EXTDIR=_extarc
set TEMPDIR=_tmp%RANDOM%
set PS1RESY=CBZts_repsym.ps1
set PS1WIPE=CBZts_wipedir.ps1

rem #### パスの導出 ####
set EXDPATH=%~dp0%EXTDIR%
set TPDPATH=%EXDPATH%\%TEMPDIR%
set RESYPATH=%~dp0%PS1RESY%
set WIPEPATH=%~dp0%PS1WIPE%

rem ### 事前対応処理 ###
echo バッチ処理の邪魔になる文字の書換え。
if not exist "%RESYPATH%" (
  echo %PS1RESY% がみあたらないのでエラー対策を省略します。
) else (
  echo === 問題のあるファイル名を探しています ===
  pwsh -noprofile -executionpolicy bypass -file "%RESYPATH%"
  echo === 事前対応完了 ===
)
rem ### 展開先と一時展開用フォルダの作成 ###
if not exist "%EXDPATH%" mkdir "%EXDPATH%"
if not exist "%TPDPATH%" (
  mkdir "%TPDPATH%"
) else (
  echo .
  echo 作業用のランダム名ディレクトリが既に存在しているようです.
  echo 余計なディレクトリの無い環境で実行することをおすすめします.
  echo 続行する場合は、このまま進めてください.
  pause
  set TEMPDIR=_tmp%RANDOM%
  set TPDPATH=%EXDPATH%\%TEMPDIR%
  mkdir "%TPDPATH%"
)
rem ### 先頭スペース回避のため時刻時のゼロ詰め（衝突回避サフィックス用）.
set HH=%TIME:~0,2%
set HH=%HH: =0%
set TIMESTAMP=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%%HH%%TIME:~3,2%%TIME:~6,2%%TIME:~9,2%

rem ### 展開対象の事前カウント.
set TOTAL=0
set COUNT=0
for %%C in (7z arj cab lzh rar tar uue zip) do (
  for %%A in (*.%%C) do set /a TOTAL+=1
)
rem # Current directory loop.
for %%C in (7z arj cab lzh rar tar uue zip) do (
  rem # Archive loop
  for %%A in (*.%%C) do (
    set /a COUNT+=1
    rem # 作業フォルダを作成.
    set ORGARCNAME=%%~nA
    set ORGARCPATH=%%~fA
    set WORKPATH=%TPDPATH%\!ORGARCNAME!
    if not exist "!WORKPATH!" mkdir "!WORKPATH!"

    rem # Time loop 1 開始時点の時刻を取得（以降ISO8601形式で統一）.
    for /f "usebackq delims=" %%T in (`
      pwsh -NoLogo -NoProfile -Command "Get-Date -Format o"
    `) do set STTISODATE=%%T
    rem ## Time loop 2 アーカイブの時刻を取得.
    for /f "usebackq delims=" %%T in (`
      pwsh -NoLogo -NoProfile -Command ^
      "(Get-Item -LiteralPath \"%%~fA\").LastWriteTime.ToString('o')"
    `) do set SOURCEFILEDATE=%%T

    rem # アーカイブの展開.
    echo.
    echo ######################################################################
    echo TRY EXTRACT !COUNT!/!TOTAL!
    echo !ORGARCNAME! → !WORKPATH!
    echo ######################################################################
    echo.
    rem overwrite-aoa skip-aos rename(to)-aot rename(from)-aou
    "%ZIP7%" x "!ORGARCPATH!" -o"!WORKPATH!" -aou -p"%ZIPPASS%"
    rem ## 展開後ファイル名の問題を起こす記号を置換、ゴミファイルの削除.
    if exist "%RESYPATH%" (
      pwsh -NoProfile -ExecutionPolicy Bypass -File "%RESYPATH%" -NoConfirm -TgtRoot "!WORKPATH!"
    )
    if exist "%WIPEPATH%" (
      pwsh -NoProfile -ExecutionPolicy Bypass -File "%WIPEPATH%" -TgtRoot "!WORKPATH!"
    )

    rem # WORKPATH直下のフォルダを数える.
    set "SUBDIRCOUNT=0"
    for /d %%D in ("!WORKPATH!\*") do set /a SUBDIRCOUNT+=1
    if !SUBDIRCOUNT! gtr 0 (
      rem ## フォルダが存在する場合は、内ひとつの最終変更日を取得.
      for /f "usebackq delims=" %%T in (`
        pwsh -NoLogo -NoProfile -Command ^
          "(Get-ChildItem -LiteralPath \"!WORKPATH!\" -Directory | " ^
          "Select-Object -First 1).LastWriteTime.ToString('o')"
        `) do set SUBDIRDATE=%%T
      rem ## SUBDIRDATE と STTISODATE を比較.
      pwsh -NoLogo -NoProfile -Command ^
        "$base=[datetime]'!STTISODATE!';" ^
        "$trgt=[datetime]'!SUBDIRDATE!';" ^
        "if ($trgt -gt $base) { exit 1 } else { exit 0 }"
      rem ## サブディレクトリの時刻が作業を開始した時刻よりも新しい.
      if errorlevel 1 (
        echo !ORGARCNAME! のサブディレクトリ時刻は復元できないと思われる.
        echo 全ディレクトリの日付をアーカイブの更新日付に揃えます.
        pwsh -NoLogo -NoProfile -Command ^
          "Get-ChildItem -LiteralPath \"!WORKPATH!\" -Recurse -Directory | " ^
          "ForEach-Object { " ^
            "$_.LastWriteTime = Get-Date '!SOURCEFILEDATE!'; " ^
            "$_.CreationTime = Get-Date '!SOURCEFILEDATE!' " ^
            "}; " ^
          "(Get-Item -LiteralPath \"!WORKPATH!\").LastWriteTime = Get-Date '!SOURCEFILEDATE!';" ^
          "(Get-Item -LiteralPath \"!WORKPATH!\").CreationTime = Get-Date '!SOURCEFILEDATE!'"
      ) else (
        echo !ORGARCNAME! のサブディレクトリ時刻は復元できていると思われる.
        pwsh -NoLogo -NoProfile -Command ^
          "(Get-Item -LiteralPath \"!WORKPATH!\").LastWriteTime = Get-Date '!SOURCEFILEDATE!';" ^
          "(Get-Item -LiteralPath \"!WORKPATH!\").CreationTime = Get-Date '!SOURCEFILEDATE!'"
      )
    ) else (
      echo !ORGARCNAME! にはサブディレクトリがありません.
      pwsh -NoLogo -NoProfile -Command ^
        "(Get-Item -LiteralPath \"!WORKPATH!\").LastWriteTime = Get-Date '!SOURCEFILEDATE!';" ^
        "(Get-Item -LiteralPath \"!WORKPATH!\").CreationTime = Get-Date '!SOURCEFILEDATE!'"
    )
    rem # アーカイブへ書き出し
    if not exist "%EXDPATH%\!ORGARCNAME!.cbz" (
      set OUTPUTARCPATH=%EXDPATH%\!ORGARCNAME!
    ) else (
      set OUTPUTARCPATH=%EXDPATH%\!ORGARCNAME!!TIMESTAMP!
    )
    rem ## ZIP形式で圧縮.
    echo.
    echo ######################################################################
    echo TRY COMPRESS !COUNT!/!TOTAL!
    echo !WORKPATH!
    echo ↓
    echo !OUTPUTARCPATH!.cbz
    echo ######################################################################
    echo.
    "%ZIP7%" a -tzip -r "!OUTPUTARCPATH!.zip" "!WORKPATH!\*"
    "%ZIP7%" t "!OUTPUTARCPATH!.zip" >nul
    if %errorlevel%==0 (
      ren "!OUTPUTARCPATH!.zip" "!ORGARCNAME!.cbz"
      rem ## CBZファイルの日付を元アーカイブに揃える.
      pwsh -NoLogo -NoProfile -Command ^
        "$scfltime = [datetime]'!SOURCEFILEDATE!'; " ^
        "$cbzfile = \"!OUTPUTARCPATH!.cbz\"; " ^
        "(Get-Item -LiteralPath $cbzfile).CreationTime = $scfltime; " ^
        "(Get-Item -LiteralPath $cbzfile).LastWriteTime = $scfltime; " ^
        " Write-Host "source file path :" $cbzfile; " ^
        " Write-Host "source file time :" $scfltime; " ^
        "(Get-Item -LiteralPath $cbzfile).CreationTime; " ^
        "(Get-Item -LiteralPath $cbzfile).LastWriteTime"
      rem ## ワークフォルダを削除.
      rmdir /s /q "!WORKPATH!"
    ) else echo [ERROR] 圧縮後の正常性テストに失敗しました。削除処理をスキップします。
  )
)
rem # (残っている場合は)tempディレクトリを削除。
if exist "%TPDPATH%" rmdir /q "%TPDPATH%"
echo すべての処理が完了しました。
endlocal
pause
