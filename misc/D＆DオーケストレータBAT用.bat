@echo off
chcp 65001
setlocal enabledelayedexpansion
set root=%~dp0

rem 実行対象のバッチが指定されていない場合は警告して終了.
if "%~1"=="" (
  echo 実行対象のバッチファイルをドラッグ＆ドロップしてください。
  pause
  exit /b
)

rem D&Dされたバッチを実行対象として設定.
set batpath=%~f1
set batfile=%~nx1

for /d /r "%root%" %%D in (*) do (
  echo 実行中: %%D
  copy "%batpath%" "%%D\"
  pushd "%%D"
  call "%batfile%"
  del /Q "%batfile%"
  popd
)
echo 完了しました.
pause
endlocal