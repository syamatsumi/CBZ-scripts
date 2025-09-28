@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

set year=
set month=
set sttval=1
set endval=10

for /L %%d in (%sttval%,1,%endval%) do (
    set "day=0%%d"
    set "day=!day:~-2!"
    set "folder=%year%.%month%.!day!_"
    echo Creating folder: !folder!
    mkdir "!folder!"
)