`timescale 1ns / 1ps
`include "define.vh"

module rv32i_datapath (
    input         clk,
    input         rst,
    input         pc_en,
    input         rf_we,
    input         branch,
    input         alu_src,
    input         jal,
    input         jalr,
    input  [ 2:0] rfwd_src,
    input  [ 3:0] alu_control,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    output [31:0] instr_addr,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);

    logic [31:0] alu_result;
    logic [31:0] imm_data;
    logic [31:0] alurs2_data;
    logic [31:0] rfwb_data;
    logic [31:0] pc_4_data;
    logic [31:0] pc_imm_data;
    logic btaken;
    //decoder
    logic [31:0] i_dec_rs1, o_dec_rs1;
    logic [31:0] i_dec_rs2, o_dec_rs2;
    logic [31:0] i_dec_imm, o_dec_imm;
    //execute
    logic [31:0] o_exe_rs2;
    logic [31:0] o_exe_alu_result;
    //mem
    logic [31:0] o_mem_drdata;

    assign bus_addr  = o_exe_alu_result;
    assign bus_wdata = o_exe_rs2;

    // fetch,exe
    program_counter U_PC (
        .clk(clk),
        .rst(rst),
        .pc_en(pc_en),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .btaken(btaken),
        .imm_data(o_dec_imm),
        .rd1(o_dec_rs1),
        .program_counter(instr_addr),
        .pc_imm_data(pc_imm_data),
        .pc_4_data(pc_4_data)
    );

    // decode
    register_file U_REG_FILE (
        .clk(clk),
        .rst(rst),
        .RA1(instr_data[19:15]),
        .RA2(instr_data[24:20]),
        .WA(instr_data[11:7]),
        .Wdata(rfwb_data),
        .rf_we(rf_we),
        .RD1(i_dec_rs1),
        .RD2(i_dec_rs2)
    );

    imm_extender U_IMM_EXTEND (
        .instr_data(instr_data),
        .imm_data  (imm_data)
    );

    register U_DEC_REG_RS1 (
        .clk(clk),
        .rst(rst),
        .data_in(i_dec_rs1),
        .data_out(o_dec_rs1)
    );

    register U_DEC_REG_RS2 (
        .clk(clk),
        .rst(rst),
        .data_in(i_dec_rs2),
        .data_out(o_dec_rs2)
    );

    register U_DEC_REG_IMM (
        .clk(clk),
        .rst(rst),
        .data_in(imm_data),
        .data_out(o_dec_imm)
    );

    //execute
    mux_2x1 U_MUX_ALUSRC_RS2 (
        .in0    (o_dec_rs2),   // sel0
        .in1    (o_dec_imm),   // sel1
        .mux_sel(alu_src),
        .out_mux(alurs2_data)
    );

    alu U_ALU (
        .rd1(o_dec_rs1),
        .rd2(alurs2_data),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .btaken(btaken)
    );

    // execute register for ALU result, RS2
    register U_EXE_REG_ALU (
        .clk(clk),
        .rst(rst),
        .data_in(alu_result),
        .data_out(o_exe_alu_result)
    );

    register U_EXE_REG_RS2 (
        .clk(clk),
        .rst(rst),
        .data_in(o_dec_rs2),  // from alu result
        .data_out(o_exe_rs2)  // to dmem_wdata
    );

    // mem to write back
    register U_MEM_REG_DRDATA (
        .clk(clk),
        .rst(rst),
        .data_in(bus_rdata),  // from alu result
        .data_out(o_mem_drdata)  // to dmem_wdata
    );


    //Write Back to Register File
    // to register file
    mux_5x1 U_WB_MUX (
        .in0    (alu_result),    // from ALU result
        .in1    (o_mem_drdata),  // sel1
        .in2    (o_dec_imm),     // sel2 imm
        .in3    (pc_imm_data),   // sel3 pc + imm
        .in4    (pc_4_data),     // sel4 pc + 4
        .mux_sel(rfwd_src),
        .out_mux(rfwb_data)
    );

endmodule

module mux_5x1 (
    input        [31:0] in0,
    input        [31:0] in1,
    input        [31:0] in2,
    input        [31:0] in3,
    input        [31:0] in4,
    input        [ 2:0] mux_sel,
    output logic [31:0] out_mux
);

    always_comb begin
        out_mux = 32'b0;
        case (mux_sel)
            3'b000: out_mux = in0;
            3'b001: out_mux = in1;
            3'b010: out_mux = in2;
            3'b011: out_mux = in3;
            3'b100: out_mux = in4;
        endcase
    end

endmodule

module mux_2x1 (
    input        [31:0] in0,      // sel0
    input        [31:0] in1,      // sel1
    input               mux_sel,
    output logic [31:0] out_mux
);

    assign out_mux = (mux_sel) ? in1 : in0;

endmodule

module imm_extender (
    input        [31:0] instr_data,  // imm data
    output logic [31:0] imm_data
);

    always_comb begin
        imm_data = 32'd0;
        case (instr_data[6:0])  // opcode
            `B_TYPE: begin
                imm_data = {
                    {19{instr_data[31]}},
                    instr_data[31],
                    instr_data[7],
                    instr_data[30:25],
                    instr_data[11:8],
                    1'b0
                };
            end
            `S_TYPE: begin
                imm_data = {
                    {20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]
                };
            end
            `JALR_TYPE, `I_TYPE, `IL_TYPE: begin
                imm_data = {{20{instr_data[31]}}, instr_data[31:20]};
            end
            `LUI_TYPE, `AUIPC_TYPE: begin
                imm_data = {instr_data[31:12], 12'b0};
            end
            `JAL_TYPE: begin
                imm_data = {
                    {11{instr_data[31]}},
                    instr_data[31],
                    instr_data[19:12],
                    instr_data[20],
                    instr_data[30:21],
                    1'b0
                };
            end
        endcase
    end

endmodule


module register_file (
    input         clk,
    input         rst,
    input  [ 4:0] RA1,    // instruction code RS1
    input  [ 4:0] RA2,    // instruction code RS2
    input  [ 4:0] WA,     // instruction code RD
    input  [31:0] Wdata,  // instruction RD write data
    input         rf_we,  // Register File write Enable
    output [31:0] RD1,    // Register File RS1 output
    output [31:0] RD2     // Register File RS2 output
);

    logic [31:0] register_file[1:31];  // X0 MUST HAVE ZERO

`ifdef SIMULATION
    initial begin
        for (int i = 1; i < 32; i++) begin
            register_file[i] = i;
        end
    end
`endif

    always_ff @(posedge clk) begin
        if (!rst && rf_we && (WA != 0)) begin
            register_file[WA] <= Wdata;
        end
    end

    assign RD1 = (RA1 != 0) ? register_file[RA1] : 0;
    assign RD2 = (RA2 != 0) ? register_file[RA2] : 0;

endmodule

module alu (
    input        [31:0] rd1,          // RS1
    input        [31:0] rd2,          // RS2
    input        [ 3:0] alu_control,  // funct7[5], funct3
    output logic [31:0] alu_result,
    output logic        btaken
);

    always_comb begin
        alu_result = 32'b0;
        btaken = 1'b0;
        case (alu_control)
            `ADD: begin
                alu_result = rd1 + rd2;  // add RD = RS1 + RS2
                btaken = (rd1 == rd2) ? 1'b1 : 1'b0;  // B-TYPE beq
            end
            `SUB: alu_result = rd1 - rd2;  // sub RD = RS1 - RS2
            `SLL: begin
                alu_result = rd1 << rd2[4:0];  // sll RD = RS1 << RS2
                btaken = (rd1 != rd2) ? 1'b1 : 1'b0;  // B-TYPE bne
            end
            `SLT:
            alu_result = ($signed(rd1) < $signed(rd2)) ? 1 :
                0;  // slt RD = (RS1 < RS2) ? 1 : 0 , signed
            `SLTU:
            alu_result = (rd1 < rd2) ? 1 :
                0;  // sltu RD = (RS1 < RS2) ? 1 : 0 , unsigned
            `XOR: begin
                alu_result = rd1 ^ rd2;  // xor RD = RS1 ^ RS2
                btaken = ($signed(rd1) < $signed(rd2)) ? 1'b1 :
                    1'b0;  // B-TYPE blt
            end
            `SRL: begin
                alu_result = rd1 >> rd2[4:0];  // srl RD = RS1 >> RS2
                btaken = ($signed(rd1) >= $signed(rd2)) ? 1'b1 :
                    1'b0;  // B-TYPE bge
            end
            `SRA:
            alu_result = $signed(rd1) >>>
                rd2[4:0];  // sra RD = RS1 >>> RS2 , msb extention
            `OR: begin
                alu_result = rd1 | rd2;  // or RD = RS1 | RS2
                btaken = (rd1 < rd2) ? 1'b1 : 1'b0;  // B-TYPE bltu
            end
            `AND: begin
                alu_result = rd1 & rd2;  // and RD = RS1 & RS2
                btaken = (rd1 >= rd2) ? 1'b1 : 1'b0;  // B-TYPE bgeu
            end
        endcase
    end
endmodule

module program_counter (
    input         clk,
    input         rst,
    input         pc_en,
    input         jal,
    input         jalr,
    input         branch,
    input         btaken,
    input  [31:0] imm_data,
    input  [31:0] rd1,
    output [31:0] program_counter,
    output [31:0] pc_imm_data,
    output [31:0] pc_4_data
);

    logic [31:0] pc_4_out;
    logic [31:0] pc_imm_out;
    logic [31:0] jalr_mux_out;
    logic [31:0] mux_in;
    logic [31:0] pc_next;
    logic [31:0] o_exe_pcnext;

    assign pc_imm_data = (jalr == 0) ? pc_imm_out : 32'b0;
    assign pc_4_data = pc_4_out;
    assign mux_in = (jalr) ? {pc_imm_out[31:1], 1'b0} : pc_imm_out;

    //execute
    mux_2x1 U_MUX_JALR_RS1 (
        .in0    (program_counter),  // sel0
        .in1    (rd1),              // sel1
        .mux_sel(jalr),
        .out_mux(jalr_mux_out)
    );

    pc_alu U_PC_4 (
        .a(32'd4),
        .b(program_counter),
        .pc_alu_out(pc_4_out)
    );

    pc_alu U_PC_IMM_RS1 (
        .a         (imm_data),
        .b         (jalr_mux_out),  // RS1,PC 
        .pc_alu_out(pc_imm_out)
    );

    mux_2x1 U_PC_NEXT_MUX (
        .in0    (pc_4_out),                   // sel0
        .in1    (mux_in),                     // sel1
        .mux_sel((branch && btaken) || jal),
        .out_mux(pc_next)
    );

    register U_PC_NEXT_REG (
        .clk(clk),
        .rst(rst),
        .data_in(pc_next),
        .data_out(o_exe_pcnext)
    );
    // fetch
    register_en U_PC_REG (
        .clk(clk),
        .rst(rst),
        .en(pc_en),
        .data_in(o_exe_pcnext),
        .data_out(program_counter)
    );

endmodule

module pc_alu (
    input  [31:0] a,
    input  [31:0] b,
    output [31:0] pc_alu_out
);

    assign pc_alu_out = a + b;

endmodule

module register (
    input         clk,
    input         rst,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            register <= data_in;
        end
    end

    assign data_out = register;

endmodule


module register_en (
    input         clk,
    input         rst,
    input         en,
    input  [31:0] data_in,
    output [31:0] data_out
);
    logic [31:0] register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            if (en) register <= data_in;
        end
    end

    assign data_out = register;

endmodule
