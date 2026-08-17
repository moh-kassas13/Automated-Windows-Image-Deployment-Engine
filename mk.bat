@echo off
:: ============================================================================
:: AUTOMATED WINPE DEPLOYMENT LAUNCHER
:: Author: Mohammad Kassas
:: Description: Auto-detects deployment drive and launches Deploy2.ps1
:: ============================================================================
title WinPE Deployment Engine - Developed by Mohammad Kassas

if exist "\Deployment\Deploy2.ps1" (powershell -ExecutionPolicy Bypass -File "\Deployment\Deploy2.ps1" & exit /b)
for %%d in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (if exist "%%d:\Deployment\Deploy2.ps1" (powershell -ExecutionPolicy Bypass -File "%%d:\Deployment\Deploy2.ps1" & exit /b))
echo [ERROR] Deployment script not found on any connected drive!
pause