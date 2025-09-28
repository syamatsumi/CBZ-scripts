@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリのCBZ形式をZIPアーカイブに書き換える.
echo 対象のフォルダ：%cd%
for %%f in (*.cbz) do ren "%%f" "%%~nf.zip"
echo 書換え完了.
