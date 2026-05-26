AMBA APB Bus<br>

1. Simple bus structure<br>
APB does not support complex burst transfers or pipelined transfers.<br>
It performs one read or write transfer at a time.<br>

2. Bus for register access<br>
APB is mainly used to access peripheral registers, such as control registers and status registers.<br>
The processor can read from or write to these registers through the APB bus.<br>

3. Slave-ready based handshake<br>
APB uses a handshake mechanism based on the PREADY signal.<br>
When the slave peripheral is ready, it asserts PREADY, and the master completes the transfer after checking this signal.<br>

In this project, ROM, RAM, and APB peripherals were assigned to specific address ranges using a memory map. The RISC-V processor accesses each device through load/store instructions, and the address decoder selects the corresponding memory or peripheral based on the accessed address. GPO, GPI, GPIO, FND, and UART were mapped as APB peripherals, enabling the processor to control external I/O, display output, and serial communication through memory-mapped I/O.<br>

[Multi+APB.pdf](https://github.com/user-attachments/files/26392600/Multi%2BAPB.pdf)
