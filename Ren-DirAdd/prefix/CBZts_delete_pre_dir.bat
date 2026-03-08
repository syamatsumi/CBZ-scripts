@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

echo フォルダ名をサブフォルダの接頭辞から削除する.
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
rem サブフォルダを処理する.
  for /d %%D in (*) do (
    set CURRNAME=%%~nD
    set CURRHEAD=!CURRNAME:~0,%FIXLEN%!
    set RENAMETO=!CURRNAME:~%FIXLEN%!
    if /i "!CURRHEAD!"=="%FIXCHAR%" (
      echo 処理対象：!CURRNAME! には%FIXCHAR%が付いています.
      if exist "!RENAMETO!" (
        echo スキップ："!RENAMETO!" が既に存在します.
      ) else (
        ren "%%~fD" "!RENAMETO!"
      )
    )
  )
popd
endlocal
