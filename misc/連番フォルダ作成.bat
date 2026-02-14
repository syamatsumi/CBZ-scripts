@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

set year=2026
set month=02
set sttval=1
set endval=30

for /L %%d in (%sttval%,1,%endval%) do (
    set "day=0%%d"
    set "day=!day:~-2!"
    set "folder=%year%.%month%.!day!a"
    echo Creating folder: !folder!
    mkdir "!folder!"
)