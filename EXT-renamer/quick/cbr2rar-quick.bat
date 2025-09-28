@echo off
chcp 65001
cd /d "%~dp0"

echo カレントディレクトリのCBR形式をRARアーカイブに書き換える.
echo 対象のフォルダ：%cd%
for %%f in (*.cbr) do ren "%%f" "%%~nf.rar"
echo 書換え完了.
