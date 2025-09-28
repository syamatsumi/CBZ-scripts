@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

rem === WinRAR パス（必要に応じて調整） ===
set WINRAR=%ProgramFiles%\WinRAR\winRAR.exe
if not exist "%WINRAR%" (
  echo [ERROR] WinRAR が見つかりません: %WINRAR%
  pause
  exit /b 1
)
for %%E in (7z arj cab lzh rar tar uue) do (
  for %%F in (*.%%E) do (
    set ORGARC=%%~fF
    set WORKDIR=%%~dpnF
  rem 開始時点の時刻を取得（以降ISO8601形式で統一）
    for /f "usebackq delims=" %%T in (`
      powershell -NoLogo -NoProfile -Command "Get-Date -Format o"
    `) do set STTISODATE=%%T
  rem アーカイブの時刻を取得（以降ISO8601形式で統一）
    for /f "usebackq delims=" %%T in (`
      powershell -NoLogo -NoProfile -Command ^
        "(Get-Item -LiteralPath \"%%~fF\").LastWriteTime.ToString('o')"
    `) do set SOURCEFILEDATE=%%T
  rem 作業フォルダを作成.
    mkdir "!WORKDIR!"
  rem アーカイブの展開.
    "%WINRAR%" x -o+ -tk -ibck "!ORGARC!" "!WORKDIR!\"

  rem WORKDIR直下にフォルダがある場合…….
    set "SUBDIRCOUNT=0"
    for /d %%D in ("!WORKDIR!\*") do set /a SUBDIRCOUNT+=1
    if !SUBDIRCOUNT! gtr 0 (
      for /f "usebackq delims=" %%T in (`
        powershell -NoLogo -NoProfile -Command ^
        "(Get-ChildItem -LiteralPath \"!WORKDIR!\" -Directory ^| " ^
        "Select-Object -First 1).LastWriteTime.ToString('o')"
      `) do set SUBDIRDATE=%%T
    rem SUBDIRDATE と STTISODATE を比較
      powershell -NoLogo -NoProfile -Command ^
        "$base=[datetime]'!STTISODATE!';" ^
        "$trgt=[datetime]'!SUBDIRDATE!';" ^
        "if ($trgt -gt $base) { exit 1 } else { exit 0 }"
      if errorlevel 1 (
        echo サブディレクトリの時刻が作業を開始した時刻よりも新しい。.
        echo アーカイブのディレクトリ タイムスタンプが機能していないようです。.
        echo ファイルを除く全ディレクトリの日付をアーカイブの日付に揃えます。.
        powershell -NoLogo -NoProfile -Command ^
          "Get-ChildItem -LiteralPath \"!WORKDIR!\" -Recurse -Directory ^| " ^
          "ForEach-Object { $_.LastWriteTime = Get-Date '!SOURCEFILEDATE!' }; " ^
          "(Get-Item -LiteralPath \"!WORKDIR!\").LastWriteTime = Get-Date '!SOURCEFILEDATE!'"
      ) else (
        echo サブディレクトリの時刻が基準時刻以前なので特に操作しない.
      )
    )
  rem ZIP形式で再圧縮（フォルダ構造は維持）.
    pushd "%%~dpF"
    "%WINRAR%" a -afzip -ep1 -t -tk -r -df -ibck "%%~nF.cbz" "%%~nF\*"
    if %errorlevel%==0 (
      popd
    rem ZIPファイルの日付を元アーカイブに揃える.
      powershell -NoLogo -NoProfile -Command ^
      "$cbzfile = \"%%~dpF%%~nF.cbz\"; " ^
      "$scfltime = [datetime]'!SOURCEFILEDATE!'; " ^
      "(Get-Item -LiteralPath $cbzfile).LastWriteTime = $scfltime"
    rem ワークフォルダを削除.
      rmdir /s /q "!WORKDIR!"
    ) else (
      popd
      echo [ERROR] 圧縮後の正常性テストに失敗しました。削除処理をスキップします。
    )
  )
)
endlocal
pause
