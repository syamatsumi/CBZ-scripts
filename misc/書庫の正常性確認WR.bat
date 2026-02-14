@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

rem === WinRAR パス（必要なら調整） ===
set WINRAR=%ProgramFiles%\WinRAR\WinRAR.exe
if not exist "%WINRAR%" (
  echo [ERROR] WinRAR が見つかりません: %WINRAR%
  pause
  exit /b 1
)

rem === ここで一括パスワードを指定 ===
set "ZIPPASS="

REM === 記号の置換 ===
REM powershell -noprofile -executionpolicy bypass -file "記号書き換え.ps1"

set /a CNT_ALL=0, CNT_OK=0, CNT_WARN=0, CNT_NG=0
echo === WinRAR Test (ZIP/CBZ/RAR/7Z) ===
call :TEST_SET "*.zip"
call :TEST_SET "*.cbz"
call :TEST_SET "*.rar"
call :TEST_SET "*.cbr"
call :TEST_SET "*.7z"
call :TEST_SET "*.cb7"
call :TEST_SET "*.lzh"

if "!CNT_ALL!"=="0" (
  echo 対象なし。
) else (
  echo.
  echo --- Summary ---
  echo  対象数: !CNT_ALL!  /  OK: !CNT_OK!  WARN: !CNT_WARN!  NG: !CNT_NG!
)
echo.
echo エラー表記の凡例.
echo RC=0：正常終了（エラーなし）.
echo RC=1：警告（部分的に問題があったが致命的でない）.
echo RC=2：致命的エラー（CRC エラーなど、完全に壊れている）.
echo RC=3：一致しないファイル、または部分的なエラー.
echo RC=4：メモリ不足.
echo RC=5：ユーザーが中断.
echo RC=6：ファイルを開けない.
echo RC=7：コマンドラインエラー.
echo RC=8：未知のエラー.
echo.
pause
exit /b

:TEST_SET
set PAT=%~1
for %%F in (%PAT%) do (
  if exist "%%~fF" call :TEST_ONE "%%~fF"
)
exit /b

:TEST_ONE
set FILE=%~1
set /a CNT_ALL+=1

rem -idq:静穏、-y:全てYes、-p:パスワード
"%WINRAR%" t -ibck -idq -y -p%ZIPPASS% "!FILE!" >nul 2>&1
set RC=%ERRORLEVEL%

if "!RC!"=="0" (
  echo [OK  ] !FILE!
  set /a CNT_OK+=1
) else if "!RC!"=="1" (
  echo [WARN] !FILE!
  set /a CNT_WARN+=1
) else (
  echo [NG  ] !FILE!  RC=!RC!
  set /a CNT_NG+=1
)
exit /b
