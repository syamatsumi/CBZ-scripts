@echo off
chcp 65001
setlocal enabledelayedexpansion
set root=%~dp0

rem 実行対象のPS1が指定されていない場合は警告して終了.
if "%~1"=="" (
  echo 実行対象のPS1ファイルをドラッグ＆ドロップしてください。
  pause
  exit /b
)

rem D&DされたPS1を実行対象として設定.
set ps1path=%~f1
set ps1file=%~nx1

for /d /r "%root%" %%D in (*) do (
  echo 実行中: %%D
  copy "%ps1path%" "%%D\"
  pushd "%%D"
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ps1file%"
  del /Q "%ps1file%"
  popd
)

echo 完了しました.
pause
endlocal