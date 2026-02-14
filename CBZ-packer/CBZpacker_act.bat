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
    set "SKIP=1"

    rem フォルダに画像が含まれている場合はスキップフラグを降ろす.
    for %%E in (jpg jpeg jpe jfif bmp gif tga png tif tiff dds pcx pbm pgm ppm pnm) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            set "SKIP=0"
        )
    )

    rem フォルダに画像編集ファイルが含まれている場合はスキップフラグを降ろす.
    for %%E in (psd psb clip) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            set "SKIP=0"
        )
    )

    rem フォルダに新しい画像形式が含まれている場合はスキップフラグを降ろす.
    for %%E in (jp2 jpc jpx j2k j2c jpf jpm jxr hdp wdp webp heic heif hif avif avifs bpg ugoira apng qoi exr jxl svg) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            set "SKIP=0"
        )
    )

    rem フォルダにRAWファイルが含まれている場合はスキップフラグを降ろす.
    for %%E in (dng cr2 cr3 crw nef nrw orf rw2 pef sr2 srw 3fr arw erf kdc mef mos raf x3f mrw) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            set "SKIP=0"
        )
    )

    rem アーカイブが含まれていたらスキップフラグを立てる.
    for %%E in (7z cb7 cbr cbt cbz tar pdf rar zip) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 動画が含まれていたらスキップフラグを立てる.
    for %%E in (264 265 3gp 3gpp asf avi divx flv h264 h265 hdmov hevc hm10 mkv mov mp4 mpe mpeg mpg ogm ogv swf vc1 vob wm wmp wmv) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 動画が含まれていたらスキップフラグを立てる.
    for %%E in (3g2 3ga 3gp2 evo ifo ismv m1v m2p m2t m2ts m2v mp2v mpv2 mts pva rec sfd ssif tp trp ts) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 動画が含まれていたらスキップフラグを立てる.
    for %%E in (amv bik dav dsa dsm dss dsv dvr-ms f4v flc fli flic ivf m4v mk3d mp4v mpv4 mxf nut obu ram rm rmm rmvb roq smk webm wtv y4m) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 音声が含まれていたらスキップフラグを立てる.
    for %%E in (ac3 aiff alac ape asx dsf flac mid midi mp3 mpa ogg opus tta wav weba wma) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 音声が含まれていたらスキップフラグを立てる.
    for %%E in (aif aifc amr aob apl au avs awb cda dff dts dtshd dtsma eac3 ec3 snd vpy) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 音声が含まれていたらスキップフラグを立てる.
    for %%E in (aac m1a m2a m4a m4b mka mlp mp2 mpc ofr ofs oga ra rmi spx tak w64 wv) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem プレイリストが含まれていたらスキップフラグを立てる.
    for %%E in (bdmv cue m3u m3u8 mpcpl mpls pls wpl xspf) do (
        dir /b /s "%%D\*.%%E" >nul 2>nul && (
            echo %%D に .%%E ファイルが含まれています。スキップ.
            set "SKIP=1"
        )
    )

    rem 実行ファイル等が含まれていたらスキップフラグを立てる.
    for %%E in (exe dll msi) do (
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
        set CBZNAME=%%~nxD.cbz
        powershell -NoProfile -ExecutionPolicy Bypass -File "%SUBSCR_WIPEDIR%" -TgtRoot "%%~fD"
            "%ZIP7%" a -tzip "!ZIPNAME!" "%%~nxD\"
            "%ZIP7%" t "!ZIPNAME!" >nul
            if !errorlevel! == 0 (
                ren "!ZIPNAME!" "!CBZNAME!"
                rmdir /s /q "%%~nxD"
            ) else (
                echo [ERROR] !ZIPNAME! failed verification.
            )
        )
    )
)
endlocal

echo 圧縮完了。何かキーを押してウィンドウを閉じる.
pause
