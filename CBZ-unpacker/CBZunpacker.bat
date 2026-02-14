@echo off
chcp 65001
cd /d "%~dp0"
setlocal enabledelayedexpansion

rem === 7Zip パス（必要なら調整） ===
set ZIP7=%ProgramFiles%\7-Zip\7z.exe
if not exist "%ZIP7%" (
    echo [ERROR] 7-Zip 実行ファイルが見つかりませんでした。^<%ZIP7%^>
    pause
    exit /b 1
)

rem === ここでパスワードを指定 ===
set "ZIPPASS=passwords"

echo 展開前に、バッチ実行に邪魔な文字がある場合はファイル名を書き換えます。
pause

echo === 記号の置換 ===
set ps1file=記号書き換え_repsym.ps1
set ps1path=%~dp0%ps1file%
pwsh -noprofile -executionpolicy bypass -file "%ps1path%"

rem 展開先と一時展開用フォルダの作成
set EXTDIR=_extract
set TEMPDIR=_tmp%RANDOM%
if not exist "%EXTDIR%" mkdir "%EXTDIR%"
if not exist "%TEMPDIR%" mkdir "%TEMPDIR%"

rem 先頭スペース回避のため時刻時のゼロ詰め（衝突回避サフィックス用）
set HH=%TIME:~0,2%
set HH=%HH: =0%
set TS=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%%HH%%TIME:~3,2%%TIME:~6,2%%TIME:~9,2%

for %%F in (*.cbz) do (
    rem overwrite-aoa skip-aos rename-aou renameext-aot 
    "%ZIP7%" x "%%F" -o"%TEMPDIR%" -aou -p"%ZIPPASS%"

    echo === 記号の置換 %TEMPDIR% ===
    copy "%ps1path%" "%TEMPDIR%"
    pushd "%TEMPDIR%"
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%ps1file%"
    del /Q "%ps1file%"
    popd

    rem 展開内容の数を数える
    set /a ITEMCOUNT=0
    pushd "!TEMPDIR!"
    for /f "delims=" %%I in ('dir /b /a') do set /a ITEMCOUNT+=1
    popd

    rem 展開した結果が単体のファイルかフォルダならそのまま移動
    if !ITEMCOUNT!==1 (
        for /f "delims=" %%X in ('dir /b /a "%TEMPDIR%"') do (
            set DEST=%EXTDIR%\%%X
            if not exist "!DEST!" (
                move "%TEMPDIR%\%%X" "%EXTDIR%\"
            ) else (
                set DEST=%EXTDIR%\%%X_!TS!
                move "%TEMPDIR%\%%X" "!DEST!"
            )
            rem 単一項目がフォルダなら更新日時をアーカイブに合わせる
            if exist "!DEST!\NUL" powershell -NoProfile -Command ^
              "(Get-Item -LiteralPath '!DEST!').LastWriteTime=(Get-Item -LiteralPath '%%~fF').LastWriteTime"
            rmdir /s /q "%TEMPDIR%"
        )
    ) else (
        rem 複数項目：移動後の最終フォルダに対して適用
        set DEST2=%EXTDIR%\%%~nF
        if not exist "!DEST2!" (
            move "%TEMPDIR%" "!DEST2!"
        ) else (
            set DEST2=%EXTDIR%\%%~nF_!TS!
            move "%TEMPDIR%" "!DEST2!"
        )
        powershell -NoProfile -Command ^
          "(Get-Item -LiteralPath '!DEST2!').LastWriteTime=(Get-Item -LiteralPath '%%~fF').LastWriteTime"
    )
)
echo .
echo すべての展開が完了しました。
pause
endlocal
