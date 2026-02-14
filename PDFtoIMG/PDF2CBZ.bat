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

rem 直接実行でコケた時のための利用ヒント表示.
if "%~1"=="" (
  echo Caution
  echo For Drag and Drop only.
  echo Drag and drop the PDF into this batch.
  echo.
  pause
  exit /b 1
)

set POPPLER=poppler\Library\bin
set SRCFILE=%~1
set BASENAME=%~n1

rem 作業用のフォルダを作成する.
echo create working temp folder...

:mkwork
set WORK=work_%RANDOM%%RANDOM%
if exist "%WORK%" goto :mkwork
mkdir "%WORK%" || (echo 作業フォルダ作成失敗 & exit /b 1)

:mkouttmp
set TMPDIR=%WORK%\out_%RANDOM%%RANDOM%
if exist "%TMPDIR%" goto :mkouttmp
mkdir "%TMPDIR%" || (echo 作業出力作成失敗 & rd /s /q "%WORK%" & exit /b 1)

rem 作業用のPDFをコピーする（poppler入力ファイルをASCIIのみに）.
echo create working temp PDF...
set TMPPDF=%WORK%\temp.pdf
copy /y "%SRCFILE%" "%TMPPDF%" >nul || (echo コピー失敗 & rd /s /q "%WORK%" & exit /b 1)

rem PDFの展開
echo Extracting images from a PDF...
"%POPPLER%\pdfimages.exe" -all "%TMPPDF%" "%TMPDIR%\img"
if errorlevel 1 (
  echo pdfimages 失敗
  del /q "%TMPPDF%" >nul 2>&1
  rd /s /q "%WORK%"
  exit /b 1
)

rem 一時出力フォルダを入力元名にリネーム.
ren "%TMPDIR%" "%BASENAME%"

rem 圧縮
echo Compress images...
set ZIPNAME=%BASENAME%.zip
set CBZNAME=%BASENAME%.cbz

pushd "%WORK%"
"%ZIP7%" a -tzip "%ZIPNAME%" "%BASENAME%"
"%ZIP7%" t "%ZIPNAME%" >nul
if %errorlevel% == 0 (
    ren "%ZIPNAME%" "%CBZNAME%"
    rmdir /s /q "%BASENAME%"
) else (
    echo [ERROR] %ZIPNAME% failed verification.
)
popd

rem cbz をカレントに移動（重複時は連番を付与）.
set "SRCZIP=%WORK%\%CBZNAME%"
set "DESTZIP=%CD%\%CBZNAME%"
set /a N=0

:check_dup
if exist "%DESTZIP%" (
    set /a N+=1
    set "DESTZIP=%CD%\%BASENAME%_%N%.cbz"
    goto :check_dup
)
move "%SRCZIP%" "%DESTZIP%" >nul || (
    echo [ERROR] 移動に失敗しました.
)
del /q "%TMPPDF%" >nul 2>&1
rd /s /q "%WORK%" >nul 2>&1
echo Generate Complete.
pause
