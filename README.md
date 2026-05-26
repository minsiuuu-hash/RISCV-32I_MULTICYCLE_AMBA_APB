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

| Address Range | Size | Region | Description |
|---|---:|---|---|
| `0x2000_5000 ~ 0x2000_5FFF` | 4 KB | Reserved | APB Extension Area |
| `0x2000_4000 ~ 0x2000_4FFF` | 4 KB | UART | Serial Communication |
| `0x2000_3000 ~ 0x2000_3FFF` | 4 KB | FND | 7-Segment Display |
| `0x2000_2000 ~ 0x2000_2FFF` | 4 KB | GPIO | General Purpose I/O |
| `0x2000_1000 ~ 0x2000_1FFF` | 4 KB | GPI | Input Peripheral |
| `0x2000_0000 ~ 0x2000_0FFF` | 4 KB | GPO | Output Peripheral |
| `0x1000_1000 ~ 0x1000_1FFF` | 4 KB | Reserved | Not Used |
| `0x1000_0000 ~ 0x1000_0FFF` | 4 KB | RAM | Data Memory |
| `0x0000_1000 ~ 0x0000_1FFF` | 4 KB | Reserved | Not Used |
| `0x0000_0000 ~ 0x0000_0FFF` | 4 KB | ROM | Instruction Memory |

[Multi+APB.pdf](https://github.com/user-attachments/files/26392600/Multi%2BAPB.pdf)
