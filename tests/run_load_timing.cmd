@echo off
setlocal
if not defined VIVADO_BIN set VIVADO_BIN=C:\Xilinx\Vivado\2023.2\bin
call "%~dp0run_apb_address.cmd"
if errorlevel 1 exit /b 1
cd /d "%~dp0build"
call "%VIVADO_BIN%\xvlog.bat" --sv ../tb_load_timing.sv
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xelab.bat" tb_load_timing -s tb_load_timing_sim
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xsim.bat" tb_load_timing_sim -runall -log load_timing.log
if errorlevel 1 exit /b 1
findstr /C:"Fatal:" load_timing.log >nul
if not errorlevel 1 exit /b 1
findstr /C:"PASS: load timing" load_timing.log >nul
if errorlevel 1 exit /b 1
exit /b 0
