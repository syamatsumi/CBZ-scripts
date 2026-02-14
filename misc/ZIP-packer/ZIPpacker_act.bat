@echo off
chcp 65001
cd /d "%~dp0"

rem === 7Zip パス（必要なら調整） ===
set ZIP7=%ProgramFiles%\7-Zip\7z.exe
if not exist "%ZIP7%" (
    echo [ERROR] 7-Zip 実行ファイルが見つかりませんでした。^<%ZIP7%^>
    pause
    exit /b 1
)
set MAINSCR_NAME=%~n0
for /f "tokens=1,* delims=_" %%A in ("%MAINSCR_NAME%") do set "MAINSCR_BASE=%%A"
set SUBSCR_REPSYM=%~dp0%MAINSCR_BASE%_repsym.ps1
set SUBSCR_WIPEDIR=%~dp0%MAINSCR_BASE%_wipedir.ps1
if not exist "%SUBSCR_REPSYM%" echo Not found: %SUBSCR_REPSYM% & pause & exit /b 1
if not exist "%SUBSCR_WIPEDIR%" echo Not found: %SUBSCR_DEDUPE% & pause & exit /b 1

echo フォルダの圧縮と削除を実施（7-Zip使用）.
echo 対象のフォルダ：%cd%
pause

powershell -noprofile -executionpolicy bypass -file "%SUBSCR_REPSYM%"

setlocal enabledelayedexpansion
for /d %%D in (*) do (
    set "SKIP=0"

    rem アーカイブが含まれていたらスキップフラグを立てる.
    for %%E in (7z cb7 cbr cbt cbz tar rar zip) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )
    rem フォルダ内のファイル数が1以下ならスキップフラグを立てる.
    set "COUNT=0"
    for /f %%F in ('dir /b /s /a-d "%%D" 2^>nul') do (
        set /a COUNT+=1
    )
    if !COUNT! leq 1 set "SKIP=1"

    if !SKIP! EQU 0 (
        if not exist "%%~nxD.cbz" (
        set ZIPNAME=%%~nxD.zip
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SUBSCR_WIPEDIR%" -TgtRoot "%%~fD"
            "%ZIP7%" a -tzip "!ZIPNAME!" "%%~nxD\"
            "%ZIP7%" t "!ZIPNAME!" >nul
            if !errorlevel! == 0 (
               REM rmdir /s /q "%%~nxD"
            ) else (
                echo [ERROR] !ZIPNAME! failed verification.
            )
        )
    )
)
endlocal

echo 圧縮完了。何かキーを押してウィンドウを閉じる.
pause
