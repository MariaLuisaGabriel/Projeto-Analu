@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Cronograma SES-DF 2027
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0servidor.ps1"
echo.
echo O servidor encerrou. Pode fechar esta janela.
pause
