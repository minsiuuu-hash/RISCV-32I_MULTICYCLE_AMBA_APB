`timescale 1ns / 1ps
`include "define.vh"

module rv32i_cpu (
    input         clk,
    input         rst,
    input  [31:0] instr_data,
    input  [31:0] bus_rdata,
    input         bus_ready,
    output [31:0] instr_addr,
    output        bus_wreq,
    output        bus_rreq,
    output [ 2:0] o_funct3,
    output [31:0] bus_addr,
    output [31:0] bus_wdata
);

    logic pc_en, rf_we, alu_src, branch, jal, jalr;
    logic [2:0] rfwd_src;
    logic [3:0] alu_control;

    control_unit U_CONTROLUNIT (
        .clk        (clk),
        .rst        (rst),
        .funct7     (instr_data[31:25]),
        .funct3     (instr_data[14:12]),
        .opcode     (instr_data[6:0]),
        .ready      (bus_ready),
        .pc_en      (pc_en),              // for multi cycle Fetch : pc
        .rf_we      (rf_we),
        .branch     (branch),
        .jal        (jal),
        .alu_src    (alu_src),
        .jalr       (jalr),
        .rfwd_src   (rfwd_src),
        .o_funct3   (o_funct3),
        .alu_control(alu_control),
        .dwe        (bus_wreq),
        .dre        (bus_rreq)
    );

    rv32i_datapath U_DATAPATH (.*);

endmodule

module control_unit (
    input              clk,
    input              rst,
    input        [6:0] funct7,
    input        [2:0] funct3,
    input        [6:0] opcode,
    input              ready,
    output logic       pc_en,
    output logic       rf_we,
    output logic       branch,
    output logic       jal,
    output logic       alu_src,
    output logic       jalr,
    output logic [2:0] rfwd_src,
    output logic [3:0] alu_control,
    output logic [2:0] o_funct3,
    output logic       dwe,
    output logic       dre
);

    // control unit multi cycle stage
    typedef enum logic [3:0] {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;

    state_e c_state, n_state;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    // next CL
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: begin
                n_state = DECODE;
            end
            DECODE: begin
                n_state = EXECUTE;
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE, `I_TYPE, `B_TYPE, `LUI_TYPE, `AUIPC_TYPE, `JAL_TYPE, `JALR_TYPE: begin
                        n_state = FETCH;
                    end
                    `S_TYPE: begin
                        n_state = MEM;
                    end
                    `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                case (opcode)
                    `S_TYPE: begin
                        if (ready) begin
                            n_state = FETCH;
                        end
                    end
                    `IL_TYPE: begin
                        n_state = WB;
                    end
                endcase
            end
            WB: begin
                if (ready) begin
                    n_state = FETCH;
                end
            end
        endcase
    end

    //output CL
    always_comb begin
        pc_en       = 1'b0;
        rf_we       = 1'b0;
        jal         = 1'b0;
        jalr        = 1'b0;
        branch      = 1'b0;
        alu_src     = 1'b0;
        alu_control = 4'b0000;
        rfwd_src    = 3'b000;
        o_funct3    = 3'b000;  // for S TYPE, IL TYPE
        dwe         = 1'b0;  // for S TYPE
        dre         = 1'b0;  // for IL TYPE
        case (c_state)
            FETCH: begin
                pc_en = 1'b1;
            end
            DECODE: begin
            end
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we       = 1'b1;  // next FETCH
                        alu_src     = 1'b0;
                        alu_control = {funct7[5], funct3};
                        rfwd_src    = 3'b000;
                    end
                    `I_TYPE: begin
                        rf_we   = 1'b1;  // next FETCH
                        alu_src = 1'b1;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                        rfwd_src = 3'b000;
                    end
                    `B_TYPE: begin
                        branch      = 1'b1;
                        alu_src     = 1'b0;
                        alu_control = {1'b0, funct3};
                    end
                    `S_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr
                    end
                    `IL_TYPE: begin
                        alu_src     = 1'b1;
                        alu_control = 4'b0000;  // add for dwaddr
                    end
                    `LUI_TYPE: begin
                        rf_we    = 1'b1;  // next FETCH
                        rfwd_src = 3'b010;
                    end
                    `AUIPC_TYPE: begin
                        rf_we    = 1'b1;  // next FETCH
                        rfwd_src = 3'b011;
                    end
                    `JAL_TYPE: begin
                        rf_we    = 1'b1;  // next FETCH
                        jal      = 1'b1;
                        jalr     = 1'b0;
                        rfwd_src = 3'b100;
                    end
                    `JALR_TYPE: begin
                        rf_we    = 1'b1;  // next FETCH
                        jal      = 1'b1;
                        jalr     = 1'b1;
                        rfwd_src = 3'b100;
                    end
                endcase
            end
            MEM: begin
                o_funct3 = funct3;
                if (opcode == `S_TYPE) begin
                    dwe = 1'b1;
                end else begin
                    dre = 1'b1;
                end
            end
            WB: begin
                // IL TYPE
                rfwd_src = 3'b001;
                //rf_we    = 1'b1;
                if (ready) begin
                    rf_we = 1'b1;
                end else begin
                    rf_we = 1'b0;
                end
            end
        endcase
    end

endmodule
