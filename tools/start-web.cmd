@echo off
title Numblop Web
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve-web.ps1" -Open
if errorlevel 1 pause
