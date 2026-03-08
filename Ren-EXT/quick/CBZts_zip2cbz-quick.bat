@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリのZIPアーカイブをCBZ形式に書き換える.
echo 対象のフォルダ：%cd%
for %%f in (*.zip) do ren "%%f" "%%~nf.cbz"
echo 書換え完了.
