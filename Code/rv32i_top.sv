`timescale 1ns / 1ps

module rv32i_mcu (
    input         clk,
    input         rst,
    input  [ 7:0] GPI,
    inout  [15:0] GPIO,
    input         rx,
    output [ 7:0] GPO,
    output [ 3:0] fnd_digit,
    output [ 7:0] fnd_data,
    output        tx
);
    logic [2:0] o_funct3;
    logic [31:0] instr_addr, instr_data, bus_addr, bus_wdata, bus_rdata;
    logic bus_wreq, bus_rreq, bus_ready;
    logic [31:0] PAddr, PWData;
    logic PENABLE, PWRITE;
    logic PSEL0, PSEL1, PSEL2, PSEL3, PSEL4, PSEL5;
    logic [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3, PRDATA4, PRDATA5;
    logic PREADY0, PREADY1, PREADY2, PREADY3, PREADY4, PREADY5;

    logic [15:0] FND_CNT_IN;
    logic [ 7:0] TX_IN;
    logic TX_BUSY, RX_DONE, TX_START, b_tick;
    logic [1:0] BPS;
    logic [7:0] RX_OUT;
    instruction_mem U_INSTRUCTION_MEM (.*);

    rv32i_cpu U_RV32I (.*);

    master U_APB_MASTER (
        .PCLK   (clk),
        .PRESET (rst),
        .Addr   (bus_addr),   // from cpu
        .Wdata  (bus_wdata),  // from cpu
        .WREQ   (bus_wreq),   // from cpu, write request, signal cpu : dwe
        .RREQ   (bus_rreq),   // from cpu, read request, signal cpu : dre
        .Rdata  (bus_rdata),
        .Ready  (bus_ready),
        // to APB slave
        .PAddr  (PAddr),      // need register
        .PWData (PWData),     // need register
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),     // need register
        // from APB slave
        .PSEL0  (PSEL0),      // RAM
        .PSEL1  (PSEL1),      // GPO
        .PSEL2  (PSEL2),      // GPI
        .PSEL3  (PSEL3),      // GPIO
        .PSEL4  (PSEL4),      // FND
        .PSEL5  (PSEL5),      // UART

        .PRDATA0(PRDATA0),  // RAM
        .PRDATA1(PRDATA1),  // GPO
        .PRDATA2(PRDATA2),  // GPI
        .PRDATA3(PRDATA3),  // GPIO
        .PRDATA4(PRDATA4),  // FND
        .PRDATA5(PRDATA5),  // UART

        .PREADY0(PREADY0),  // RAM
        .PREADY1(PREADY1),  // GPO
        .PREADY2(PREADY2),  // GPI
        .PREADY3(PREADY3),  // GPIO
        .PREADY4(PREADY4),  // FND
        .PREADY5(PREADY5)   // UART
    );

    bram U_BRAM (
        .*,
        .PAddr  (PAddr),
        .PWData (PWData),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PCLK   (clk),
        .PSEL   (PSEL0),
        .PRDATA (PRDATA0),
        .PREADY (PREADY0)
    );

    gpo U_APB_GPO (
        .PCLK   (clk),
        .PRESET (rst),
        .PAddr  (PAddr),
        .PWData (PWData),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL1),
        .PRDATA (PRDATA1),
        .PREADY (PREADY1),
        .GPO_OUT(GPO)
    );

    gpi U_APB_GPI (
        .PCLK   (clk),
        .PRESET (rst),
        .PAddr  (PAddr),
        .PWData (PWData),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL2),
        .GPI    (GPI),
        .PRDATA (PRDATA2),
        .PREADY (PREADY2)
    );

    apb_gpio U_APB_GPIO (
        .PCLK   (clk),
        .PRESET (rst),
        .PAddr  (PAddr),
        .PWData (PWData),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL3),
        .PRDATA (PRDATA3),
        .PREADY (PREADY3),
        .GPIO   (GPIO)
    );

    fnd U_APB_FND (
        .PCLK   (clk),
        .PRESET (rst),
        .PAddr  (PAddr),
        .PWData (PWData),
        .PENABLE(PENABLE),
        .PWRITE (PWRITE),
        .PSEL   (PSEL4),
        .PRDATA (PRDATA4),
        .PREADY (PREADY4),
        .FND_OUT(FND_CNT_IN)
    );

    fnd_controller U_FND_CNT (
        .clk        (clk),
        .rst        (rst),
        .fnd_in_data(FND_CNT_IN[13:0]),
        .fnd_digit  (fnd_digit),
        .fnd_data   (fnd_data)
    );

    uart U_APB_UART (
        .PCLK    (clk),
        .PRESET  (rst),
        .PAddr   (PAddr),
        .PWData  (PWData),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PSEL    (PSEL5),
        .PRDATA  (PRDATA5),
        .PREADY  (PREADY5),
        .TX_BUSY (TX_BUSY),
        .RX_DONE (RX_DONE),
        .RX_OUT  (RX_OUT),
        .TX_START(TX_START),
        .BPS     (BPS),
        .TX_IN   (TX_IN)
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(TX_START),
        .b_tick  (b_tick),
        .tx_data (TX_IN),
        .uart_tx (tx),
        .tx_busy (TX_BUSY),
        .tx_done ()
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .BPS(BPS),
        .b_tick(b_tick)
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(b_tick),
        .rx_data(RX_OUT),
        .rx_done(RX_DONE)
    );

endmodule
