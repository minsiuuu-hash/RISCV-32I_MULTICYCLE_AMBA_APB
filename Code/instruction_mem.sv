`timescale 1ns / 1ps

module instruction_mem (
    input  [31:0] instr_addr,
    output [31:0] instr_data
);

    logic [31:0] rom[0:255]; 

    initial begin
        $readmemh("apb_bram.mem", rom);  //riscv_rv32i_rom_data.mem
        // rom[0] = 32'h004182b3;  // ADD rd = X5, rs1= X3, rs2= X4
        // rom[1] = 32'h00812123;  // SW x2, 2(x8),     sw x2, x8 ,2
        // rom[2] = 32'h00212383;  // LW x7, x2 ,2
        // rom[3] = 32'h00438413;  // ADDi x8, x7, x4
        // rom[4] = 32'h00840463;  // BEQ x8, x8 ,8
        // rom[5] = 32'h004182b3;
        // rom[6] = 32'h00812123;
        // rom[1] = 32'h005201b3;
    end

    assign instr_data = rom[instr_addr[31:2]];

endmodule
