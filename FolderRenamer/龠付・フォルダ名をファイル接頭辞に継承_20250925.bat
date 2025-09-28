@echo off
chcp 65001
setlocal enabledelayedexpansion
echo フォルダの名前をファイル名の接頭辞にする.
rem 区切り文字を設定する.
  set "DELIMCHAR=_"
rem 現在地のフォルダ名を取得.
  pushd "%~dp0"
  for %%# in ("%CD%") do set PARENTNAME=%%~nx#
  set PREFIX=%PARENTNAME%%DELIMCHAR%
rem 接頭辞の長さ確認
  set PREFIXLEN=0
  set TMPSTR=%PREFIX%
:_len_loop
  if defined TMPSTR (
    set TMPSTR=!TMPSTR:~1!
    set /a PREFIXLEN+=1
    goto _len_loop
  )
rem フォルダ内のファイルを走査し、現在の名前が PREFIX+名前 の場合はそのままにする.
  for %%D in (*) do (
    set CURRNAME=%%~nxD
    set CURRHEAD=!CURRNAME:~0,%PREFIXLEN%!
    set RENAMETO=%PREFIX%%%~nxD
    set EXT=%%~xD
    if /i "!EXT!"==".bat" (
      echo スキップ（BAT）：%%D
    ) else if /i "!EXT!"==".ps1" (
      echo スキップ（PS1）：%%D
    ) else if /i "!CURRHEAD!"=="%PREFIX%" (
      echo スキップ：!CURRNAME! は%PREFIX%が既に付いています.
    ) else if exist "!RENAMETO!" (
      echo スキップ："!RENAMETO!" が既に存在します.
    ) else (
      ren "%%~fD" "!RENAMETO!"
    )
  )
popd
endlocal
