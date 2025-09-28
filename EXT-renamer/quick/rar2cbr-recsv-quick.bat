@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリ以下すべてのRARアーカイブをCBR形式に書き換える.
echo 対象のフォルダ：%cd%
for /R %%f in (*.rar) do ren "%%f" "%%~nf.cbr"
echo 書換え完了.
