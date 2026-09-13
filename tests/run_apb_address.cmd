@echo off
setlocal
if not defined VIVADO_BIN set VIVADO_BIN=C:\Xilinx\Vivado\2023.2\bin
cd /d "%~dp0"
if not exist build mkdir build
cd build
copy /y ..\..\Code\apb_bram.mem apb_bram.mem >nul
call "%VIVADO_BIN%\xvlog.bat" --sv -i ../../Code ../../Code/master.sv ../../Code/bram.sv ../../Code/gpo.sv ../../Code/gpi.sv ../../Code/gpio.sv ../../Code/fnd.sv ../../Code/fnd_controller.sv ../../Code/uart.sv ../../Code/uart_top.sv ../../Code/instruction_mem.sv ../../Code/rv32i_cpu.sv ../../Code/rv32i_datapath.sv ../../Code/rv32i_top.sv ../tb_apb_address.sv
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xelab.bat" tb_apb_address -s tb_apb_address_sim
if errorlevel 1 exit /b 1
call "%VIVADO_BIN%\xsim.bat" tb_apb_address_sim -runall
if errorlevel 1 exit /b 1
findstr /C:"Fatal:" xsim.log >nul
if not errorlevel 1 exit /b 1
findstr /C:"PASS: original program" xsim.log >nul
if errorlevel 1 exit /b 1
exit /b 0
