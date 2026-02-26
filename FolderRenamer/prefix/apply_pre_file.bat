@echo off
chcp 65001
setlocal enabledelayedexpansion
echo フォルダ名をファイル名の接頭辞に継承する.
rem 区切り文字を設定する.
  set "DELIMCHAR=_"
rem 現在地のフォルダ名を取得.
  pushd "%~dp0"
  for %%# in ("%CD%") do set PARENTNAME=%%~nx#
  set FIXCHAR=%PARENTNAME%%DELIMCHAR%
rem 接辞の長さ確認
  set TMPSTR=%FIXCHAR%
  set FIXLEN=0
:_len_loop
  if defined TMPSTR (
    set TMPSTR=!TMPSTR:~1!
    set /a FIXLEN+=1
    goto _len_loop
  )
rem フォルダ内のファイルを処理する.
for %%D in (*) do (
  set EXT=%%~xD
  if exist "%%~fD\" (
    echo スキップ（ディレクトリ）
  ) else if /i "!EXT!"==".bat" (
    echo スキップ（BAT）：%%D
  ) else if /i "!EXT!"==".ps1" (
    echo スキップ（PS1）：%%D
  ) else if /i "!EXT!"==".lnk" (
    echo スキップ（リンク）：%%D
  ) else (
    set CURRNAME=%%~nD
    set CURRHEAD=!CURRNAME:~0,%FIXLEN%!
    set RENAMETO=%FIXCHAR%!CURRNAME!!EXT!
    if /i "!CURRHEAD!"=="%FIXCHAR%" (
      echo スキップ：!CURRNAME! は%FIXCHAR%が既に付いています.
    ) else if exist "!RENAMETO!" (
      echo スキップ："!RENAMETO!" が既に存在します.
    ) else (
      ren "%%~fD" "!RENAMETO!"
    )
  )
)
popd
endlocal
