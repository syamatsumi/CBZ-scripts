@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

rem ### WinRAR パス（必要に応じて調整） ###
set WINRAR=%ProgramFiles%\WinRAR\winRAR.exe
if not exist "%WINRAR%" (
  echo [ERROR] WinRAR が見つかりません: %WINRAR%
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

echo フォルダの圧縮と削除を実施（WinRAR使用）.
echo 対象のフォルダ：%cd%
if exist "%RESYPATH%" (echo ※　ファイル名の書き換えが有効です。無効にする場合は%PS1RESY%を別フォルダへ。)
if exist "%WIPEPATH%" (echo ※　空フォルダ等のゴミ掃除が有効です。無効にする場合は%PS1WIPE%を別フォルダへ。)
pause

rem ### 事前対応処理 ###
echo バッチ処理の邪魔になる文字の書換え。
if not exist "%RESYPATH%" (
  echo %PS1RESY% がみあたらないのでエラー対策を省略します。
) else (
  echo === 問題のあるファイル名を探しています ===
  pwsh -noprofile -executionpolicy bypass -file "%RESYPATH%"
  echo === 事前対応完了 ===
)
echo ゴミ掃除する場合
if not exist "%WIPEPATH%" (
  echo %PS1WIPE% がみあたらないのでゴミ掃除を省略します。
) else (
  echo === ゴミ掃除中 ===
  pwsh -NoProfile -executionPolicy bypass -file "%WIPEPATH%"
  echo === ゴミ掃除完了 ===
)
rem ### 先頭スペース回避のため時刻時のゼロ詰め（衝突回避サフィックス用）.
set HH=%TIME:~0,2%
set HH=%HH: =0%
set TIMESTAMP=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%%HH%%TIME:~3,2%%TIME:~6,2%%TIME:~9,2%

for /d %%D in (*) do (
  set "SKIP=0"
  rem フォルダ内のファイル数が1以下ならスキップフラグを立てる.
  set "COUNT=0"
  for /f %%F in ('dir /b /s /a-d "%%D" 2^>nul') do (
    set /a COUNT+=1
  )
  if !COUNT! leq 1 set "SKIP=1"

  if !SKIP! EQU 0 (
    if not exist "%%~nD.rar" (
      set OUTPUTARCPATH=%%~nD.rar
    ) else (
      set OUTPUTARCPATH=%%~nD%TIMESTAMP%.rar
    )
    echo !OUTPUTARCPATH!
    "%WINRAR%" a -m5 -md8g -rr5p -ep1 -r -ibck "!OUTPUTARCPATH!" "%%~fD"
      if !errorlevel! == 0 (
        rem rmdir /s /q "%%~nxD"
      ) else (
        echo [ERROR] !ZIPNAME! failed verification.
      )
    )
  )
)
endlocal

echo 圧縮完了。何かキーを押してウィンドウを閉じる.
pause
