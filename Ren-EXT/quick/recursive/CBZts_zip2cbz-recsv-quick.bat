@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリ以下すべてのZIPアーカイブをCBZ形式に書き換える.
echo 対象のフォルダ：%cd%
for /R %%f in (*.zip) do ren "%%f" "%%~nf.cbz"
echo 書換え完了.
