@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリのCBZ形式をZIPアーカイブに書き換える.
echo 対象のフォルダ：%cd%
pause

for %%f in (*.cbz) do (
  ren "%%f" "%%~nf.zip"
  if errorlevel 1 (
    echo [ERROR] Failed to rename "%%f"
    echo 何かキーを押して続行.
    pause
  )
)
echo 書換え完了。何かキーを押してウィンドウを閉じる.
pause
