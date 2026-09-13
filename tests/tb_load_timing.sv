`timescale 1ns / 1ps

module tb_load_timing;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst = 1;
    logic [7:0] GPI = 0;
    tri [15:0] GPIO;
    logic rx = 1;
    wire [7:0] GPO, fnd_data;
    wire [3:0] fnd_digit;
    wire tx;
    rv32i_mcu dut (.*);

    int wait_count = 0;
    int reads = 0, writes = 0, captures = 0, writebacks = 0;
    int required_waits;
    logic response_ready;
    logic [31:0] response_data;
    logic [31:0] expected_load = 0;
    logic [31:0] previous_rd;
    logic [4:0] load_rd;
    logic wb_pending = 0;

    // Data is deliberately INVALID in SETUP and during wait cycles.
    // Only the final ACCESS cycle has valid data; after completion it changes.
    always_comb begin
        case (reads)
            0: required_waits = 0;
            1: required_waits = 1;
            default: required_waits = 4;
        endcase
        response_ready = dut.PSEL0 && dut.PENABLE &&
                         (dut.PWRITE || wait_count >= required_waits);
        response_data = 32'hdeadbeef;
        if (response_ready && !dut.PWRITE)
            response_data = dut.U_BRAM.bmem[dut.PAddr[11:2]];
    end

    always @(posedge clk) begin
        if (rst) begin
            wait_count <= 0;
            reads <= 0;
            writes <= 0;
        end else if (dut.PSEL0 && dut.PENABLE) begin
            if (response_ready) begin
                wait_count <= 0;
                if (dut.PWRITE) writes <= writes + 1;
                else begin
                    if (wait_count != required_waits)
                        $fatal(1, "Incorrect wait count %0d", wait_count);
                    reads <= reads + 1;
                end
            end else wait_count <= wait_count + 1;
        end else wait_count <= 0;
    end

    // Check both edges: response capture and the following register-file write.
    always @(posedge clk) begin
        if (rst) begin
            wb_pending = 0;
            captures = 0;
            writebacks = 0;
        end else begin
            if (dut.bus_rreq) begin
                if (dut.U_RV32I.U_CONTROLUNIT.c_state !== 4'd3 ||
                    dut.U_RV32I.rf_we !== 0)
                    $fatal(1, "Load must wait in MEM without register-file write");
            end
            if (dut.bus_rreq && dut.bus_ready) begin
                if (wb_pending)
                    $fatal(1, "Unexpected or duplicate capture");
                load_rd = dut.instr_data[11:7];
                previous_rd = dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[load_rd];
                expected_load = 32'h41 + captures;
                if (dut.bus_rdata !== expected_load)
                    $fatal(1, "Wrong response data at completion");
                captures++;
                wb_pending = 1;
                #1;
                if (dut.U_RV32I.U_DATAPATH.o_mem_drdata !== expected_load ||
                    dut.U_RV32I.U_CONTROLUNIT.c_state !== 4'd4 ||
                    dut.U_RV32I.rf_we !== 1 ||
                    dut.bus_rreq !== 0 || dut.bus_ready !== 0)
                    $fatal(1, "Bad MEM-to-WB transition");
                if (dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[load_rd] !== previous_rd)
                    $fatal(1, "Destination register was written on capture edge");
            end else if (wb_pending) begin
                if (dut.U_RV32I.U_CONTROLUNIT.c_state !== 4'd4 ||
                    dut.U_RV32I.rf_we !== 1 || dut.bus_ready !== 0 ||
                    dut.U_RV32I.U_DATAPATH.rfwb_data !== expected_load)
                    $fatal(1, "WB must use captured data independently of ready");
                #1;
                if (dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[load_rd] !== expected_load)
                    $fatal(1, "Register file did not receive completed load value");
                writebacks++;
                wb_pending = 0;
            end
        end
    end

    initial begin
        force dut.PREADY0 = response_ready;
        force dut.PRDATA0 = response_data;
        // Keep the original three stores and loads, then consume the last load.
        #1;
        dut.U_INSTRUCTION_MEM.rom[10] = 32'h00158513; // addi x10,x11,1
        dut.U_INSTRUCTION_MEM.rom[11] = 32'h00a7a623; // sw x10,12(x15)
        dut.U_INSTRUCTION_MEM.rom[12] = 32'h0000006f; // jal x0,0
        dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[13] = 32'h11111111;
        dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[12] = 32'h22222222;
        dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[11] = 32'h33333333;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (300) begin
            @(negedge clk);
            if (dut.instr_addr == 32'h30) begin
                if (reads != 3 || writes != 4 || captures != 3 || writebacks != 3)
                    $fatal(1, "Unexpected transaction/capture/WB counts: %0d/%0d/%0d/%0d",
                           reads, writes, captures, writebacks);
                if (dut.U_BRAM.bmem[3] !== 32'h44)
                    $fatal(1, "Dependent ALU/store did not use latest load");
                $display("PASS: load timing; 0/1/4 wait cycles, capture then WB, no duplicate requests, dependent ALU/store");
                $finish;
            end
        end
        $fatal(1, "Load timing timeout");
    end
endmodule
