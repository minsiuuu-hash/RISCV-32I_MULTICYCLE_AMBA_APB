`timescale 1ns / 1ps

module tb_apb_address;
    logic clk = 0;
    always #5 clk = ~clk;
    logic rst = 1;
    logic [7:0] GPI = 8'h5a;
    tri [15:0] GPIO;
    assign GPIO = 16'h1234;  // GPIO remains configured as input in this test.
    logic rx = 1;
    wire [7:0] GPO, fnd_data;
    wire [3:0] fnd_digit;
    wire tx;
    rv32i_mcu dut (.*);

    logic [31:0] request_addr = 0, request_data = 0;
    logic request_write = 0, request_read = 0;
    logic ram_ready_override = 0;
    wire [5:0] selected = {dut.PSEL5, dut.PSEL4, dut.PSEL3,
                           dut.PSEL2, dut.PSEL1, dut.PSEL0};
    int transactions = 0;
    int last_waits = 0;

    task automatic transfer(input bit wr, input logic [31:0] addr,
                            input logic [31:0] data,
                            input logic [31:0] expected,
                            input logic [5:0] expected_sel);
        @(negedge clk);
        request_addr = addr;
        request_data = data;
        request_write = wr;
        request_read = !wr;
        @(posedge clk); #1;  // SETUP
        if (selected !== expected_sel || dut.PENABLE !== 0 || dut.bus_ready !== 0)
            $fatal(1, "Bad SETUP at %h: sel=%b ready=%b", addr, selected, dut.bus_ready);
        @(negedge clk);
        request_write = 0;
        request_read = 0;
        @(posedge clk); #1;  // ACCESS
        last_waits = 0;
        while (dut.bus_ready !== 1'b1) begin
            if (last_waits >= 12) $fatal(1, "Timeout at %h", addr);
            if (selected !== expected_sel || dut.PENABLE !== 1 ||
                dut.PAddr !== addr || dut.PWData !== data || dut.PWRITE !== wr)
                $fatal(1, "Unstable waiting transfer at %h", addr);
            last_waits++;
            @(negedge clk); #1; // Observe readiness before the completion edge.
        end
        if (selected !== expected_sel || dut.PENABLE !== 1)
            $fatal(1, "Bad ACCESS at %h", addr);
        if (!wr && dut.bus_rdata !== expected)
            $fatal(1, "Read %h got %h expected %h", addr, dut.bus_rdata, expected);
        @(posedge clk); #1;  // Completion edge, then IDLE.
        if (selected !== 0 || dut.PENABLE !== 0 || dut.bus_ready !== 0)
            $fatal(1, "Bad IDLE after %h", addr);
        transactions++;
    endtask

    task automatic read_word(input logic [31:0] addr, expected,
                             input logic [5:0] sel);
        transfer(0, addr, 0, expected, sel);
    endtask
    task automatic write_word(input logic [31:0] addr, data,
                              input logic [5:0] sel);
        transfer(1, addr, data, 0, sel);
    endtask

    initial begin
        // Isolate the CPU request interface, retain actual top-level APB wiring.
        force dut.bus_addr = request_addr;
        force dut.bus_wdata = request_data;
        force dut.bus_wreq = request_write;
        force dut.bus_rreq = request_read;
        repeat (3) @(negedge clk);
        rst = 0;

        write_word(32'h10000000, 32'h12345678, 6'b000001);
        write_word(32'h10000ffc, 32'h87654321, 6'b000001);
        read_word(32'h10000000, 32'h12345678, 6'b000001);
        read_word(32'h10000ffc, 32'h87654321, 6'b000001);

        // Reserved/foreign pages must not alias the first/last RAM word.
        write_word(32'h10001000, 32'hbad00001, 0);
        read_word(32'h10001000, 0, 0);
        write_word(32'h1ffffffc, 32'hbad00002, 0);
        read_word(32'h1ffffffc, 0, 0);
        read_word(32'h10000000, 32'h12345678, 6'b000001);
        read_word(32'h10000ffc, 32'h87654321, 6'b000001);
        read_word(32'h0ffffffc, 0, 0);
        read_word(32'h00000000, 0, 0); // ROM is not on this data bus.
        read_word(32'h30000000, 0, 0);
        read_word(32'hffffffff, 0, 0);

        write_word(32'h20000000, 32'hff, 6'b000010);
        write_word(32'h20000004, 32'ha5, 6'b000010);
        read_word(32'h20000004, 32'ha5, 6'b000010);
        if (GPO !== 8'ha5) $fatal(1, "GPO output mismatch");
        write_word(32'h20010004, 0, 0); // Used to alias GPO.
        write_word(32'h21000004, 0, 0); // Used to alias GPO.
        read_word(32'h20010004, 0, 0);
        read_word(32'h21000004, 0, 0);
        read_word(32'h20000004, 32'ha5, 6'b000010);

        write_word(32'h20001000, 32'hff, 6'b000100);
        read_word(32'h20001004, 32'h5a, 6'b000100);
        write_word(32'h20002004, 32'h5678, 6'b001000);
        read_word(32'h20002004, 32'h5678, 6'b001000);
        read_word(32'h20002008, 32'h1234, 6'b001000);
        write_word(32'h20003000, 32'h1234, 6'b010000);
        read_word(32'h20003000, 32'h1234, 6'b010000);
        write_word(32'h20004004, 1, 6'b100000);
        write_word(32'h2000400c, 32'h41, 6'b100000);
        read_word(32'h20004004, 1, 6'b100000);
        read_word(32'h2000400c, 32'h41, 6'b100000);
        read_word(32'h20004008, 0, 6'b100000);

        // Every peripheral page: invalid aligned, unaligned and last offsets.
        for (int i = 0; i < 5; i++) begin
            read_word(32'h20000020 + i*4096, 0, 6'b000010 << i);
            write_word(32'h20000020 + i*4096, 32'hffffffff, 6'b000010 << i);
            read_word(32'h20000001 + i*4096, 0, 6'b000010 << i);
            write_word(32'h20000001 + i*4096, 32'hffffffff, 6'b000010 << i);
            read_word(32'h20000fff + i*4096, 0, 6'b000010 << i);
            write_word(32'h20000fff + i*4096, 32'hffffffff, 6'b000010 << i);
        end
        // Invalid writes must preserve valid registers and UART side effects.
        read_word(32'h20000000, 32'hff, 6'b000010);
        read_word(32'h20000004, 32'ha5, 6'b000010);
        read_word(32'h20001000, 32'hff, 6'b000100);
        read_word(32'h20002000, 0, 6'b001000);
        read_word(32'h20002004, 32'h5678, 6'b001000);
        read_word(32'h20003000, 32'h1234, 6'b010000);
        read_word(32'h20004000, 0, 6'b100000);
        read_word(32'h20004004, 1, 6'b100000);
        read_word(32'h2000400c, 32'h41, 6'b100000);
        read_word(32'h20004008, 0, 6'b100000);
        read_word(32'h20005000, 0, 0);
        write_word(32'h20005000, 32'hffffffff, 0);

        // Mapped slave wait states must NOT use the default completion path.
        force dut.PREADY0 = ram_ready_override;
        fork
            read_word(32'h10000000, 32'h12345678, 6'b000001);
            begin
                repeat (7) @(negedge clk);
                ram_ready_override = 1;
            end
        join
        release dut.PREADY0;
        if (last_waits < 2) $fatal(1, "Wait-state test did not wait");
        $display("PASS: %0d APB transfers; boundaries, aliasing, offsets, waits", transactions);

        // Restore the CPU and run the original apb_bram.mem program.
        @(negedge clk); rst = 1;
        release dut.bus_addr;
        release dut.bus_wdata;
        release dut.bus_wreq;
        release dut.bus_rreq;
        repeat (3) @(negedge clk);
        rst = 0;
        repeat (200) begin
            @(negedge clk);
            if (dut.instr_addr == 32'h28) begin
                if (dut.U_BRAM.bmem[0] !== 32'h41 ||
                    dut.U_BRAM.bmem[1] !== 32'h42 ||
                    dut.U_BRAM.bmem[2] !== 32'h43 ||
                    dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[13] !== 32'h41 ||
                    dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[12] !== 32'h42 ||
                    dut.U_RV32I.U_DATAPATH.U_REG_FILE.register_file[11] !== 32'h43)
                    $fatal(1, "Original CPU/RAM program regression");
                $display("PASS: original program apb_bram.mem stores and loads 41/42/43");
                $finish;
            end
        end
        $fatal(1, "CPU program timeout");
    end

    initial begin
        #100000;
        $fatal(1, "Global timeout");
    end
endmodule
