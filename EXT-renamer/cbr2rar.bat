@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリのCBR形式をRARアーカイブに書き換える.
echo 対象のフォルダ：%cd%
pause

for %%f in (*.cbr) do (
  ren "%%f" "%%~nf.rar"
  if errorlevel 1 (
    echo [ERROR] Failed to rename "%%f"
    echo 何かキーを押して続行.
    pause
  )
)
echo 書換え完了。何かキーを押してウィンドウを閉じる.
pause
