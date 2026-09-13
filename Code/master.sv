`timescale 1ns / 1ps

module master (
    // BUS Global signal
    input PCLK,
    input PRESET,

    // SoC Internal signal with CPU
    input [31:0] Addr,   // from cpu
    input [31:0] Wdata,  // from cpu
    input        WREQ,   // from cpu, write request, signal cpu : dwe
    input        RREQ,   // from cpu, read request, signal cpu : dre

    output [31:0] Rdata,
    output        Ready,

    // APB Interface signal
    output logic [31:0] PAddr,    // need register
    output logic [31:0] PWData,   // need register
    output logic        PENABLE,
    output logic        PWRITE,   // need register

    output logic PSEL0,  // RAM
    output logic PSEL1,  // GPO
    output logic PSEL2,  // GPI
    output logic PSEL3,  // GPIO
    output logic PSEL4,  // FND
    output logic PSEL5,  // UART

    input [31:0] PRDATA0,  // RAM
    input [31:0] PRDATA1,  // GPO
    input [31:0] PRDATA2,  // GPI
    input [31:0] PRDATA3,  // GPIO
    input [31:0] PRDATA4,  // FND
    input [31:0] PRDATA5,  // UART

    input PREADY0,  // RAM
    input PREADY1,  // GPO
    input PREADY2,  // GPI
    input PREADY3,  // GPIO
    input PREADY4,  // FND
    input PREADY5   // UART

);

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } apb_state_e;

    apb_state_e c_state, n_state;

    logic decode_en;
    logic [31:0] PAddr_next, PWData_next;
    logic PWRITE_next;

    // synthesis translate_off
    always @(posedge PCLK) begin
        if (!PRESET && PENABLE &&
            ({PSEL5, PSEL4, PSEL3, PSEL2, PSEL1, PSEL0} == 6'b0))
            $warning("APB: unmapped address %h (write=%b); completing with zero data",
                     PAddr, PWRITE);
    end
    // synthesis translate_on

    // SL
    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            c_state <= IDLE;
            PAddr   <= 32'h0;
            PWData  <= 32'h0;
            PWRITE  <= 1'b0;
        end else begin
            c_state <= n_state;
            PAddr   <= PAddr_next;
            PWData  <= PWData_next;
            PWRITE  <= PWRITE_next;
        end
    end

    // NEXT STATE
    always_comb begin
        n_state     = c_state;
        decode_en   = 1'b0;
        PENABLE     = 1'b0;
        PAddr_next  = PAddr;
        PWData_next = PWData;
        PWRITE_next = PWRITE;
        case (c_state)
            IDLE: begin
                decode_en   = 1'b0;  // PSELx
                PENABLE     = 1'b0;
                PAddr_next  = 32'h0000_0000;
                PWData_next = 32'h0000_0000;
                PWRITE_next = 1'b0;
                if (WREQ || RREQ) begin
                    PAddr_next  = Addr;
                    PWData_next = Wdata;
                    if (WREQ) begin
                        PWRITE_next = 1'b1;
                    end else begin
                        PWRITE_next = 1'b0;
                    end
                    n_state = SETUP;
                end
            end
            SETUP: begin
                decode_en = 1'b1;  // PSELx
                PENABLE   = 1'b0;
                n_state   = ACCESS;
            end
            ACCESS: begin
                decode_en = 1'b1;
                PENABLE   = 1'b1;
                if (Ready) begin // PREADY0 || PREADY1 || PREADY2 || PREADY3 || PREADY4 || PREADY5
                    n_state = IDLE;
                end
            end
        endcase
    end

    addr_decoder U_ADDR_DECODER (
        .en   (decode_en),
        .addr (PAddr),
        .psel0(PSEL0),
        .psel1(PSEL1),
        .psel2(PSEL2),
        .psel3(PSEL3),
        .psel4(PSEL4),
        .psel5(PSEL5)
    );

    apb_mux U_APB_MUX (
        .sel    ({PSEL5, PSEL4, PSEL3, PSEL2, PSEL1, PSEL0}),
        .access (PENABLE),
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
        .PREADY5(PREADY5),  // UART
        .Rdata  (Rdata),
        .Ready  (Ready)
    );

endmodule

module addr_decoder (
    input               en,
    input        [31:0] addr,
    output logic        psel0,
    output logic        psel1,
    output logic        psel2,
    output logic        psel3,
    output logic        psel4,
    output logic        psel5
);

    always_comb begin
        psel0 = 1'b0;  // idle : 0 RAM
        psel1 = 1'b0;  // idle : 0 GPO
        psel2 = 1'b0;  // idle : 0 GPI
        psel3 = 1'b0;  // idle : 0 GPIO
        psel4 = 1'b0;  // idle : 0 FND
        psel5 = 1'b0;  // idle : 0 UART
        if (en) begin
            // Each slave occupies exactly one 4 KiB page.
            case (addr[31:12])
                20'h10000: psel0 = 1'b1;  // RAM
                20'h20000: psel1 = 1'b1;  // GPO
                20'h20001: psel2 = 1'b1;  // GPI
                20'h20002: psel3 = 1'b1;  // GPIO
                20'h20003: psel4 = 1'b1;  // FND
                20'h20004: psel5 = 1'b1;  // UART
                default: ;  // Unmapped: no physical slave selected.
            endcase
        end
    end

endmodule

module apb_mux (
    input [5:0] sel,
    input       access,

    input [31:0] PRDATA0,  // RAM
    input [31:0] PRDATA1,  // GPO
    input [31:0] PRDATA2,  // GPI
    input [31:0] PRDATA3,  // GPIO
    input [31:0] PRDATA4,  // FND
    input [31:0] PRDATA5,  // UART 

    input PREADY0,  // RAM
    input PREADY1,  // GPO
    input PREADY2,  // GPI
    input PREADY3,  // GPIO
    input PREADY4,  // FND
    input PREADY5,  // UART

    output logic [31:0] Rdata,
    output logic        Ready
);

    always_comb begin
        Rdata = 32'h0000_0000;
        Ready = 1'b0;
        // Use the decoder's one-hot selection for both response signals.
        // Keep read data available in SETUP; only complete during ACCESS.
        case (sel)
            6'b000001: begin
                Rdata = PRDATA0;
                Ready = access && PREADY0;
            end
            6'b000010: begin
                Rdata = PRDATA1;
                Ready = access && PREADY1;
            end
            6'b000100: begin
                Rdata = PRDATA2;
                Ready = access && PREADY2;
            end
            6'b001000: begin
                Rdata = PRDATA3;
                Ready = access && PREADY3;
            end
            6'b010000: begin
                Rdata = PRDATA4;
                Ready = access && PREADY4;
            end
            6'b100000: begin
                Rdata = PRDATA5;
                Ready = access && PREADY5;
            end
            6'b000000: begin
                // Default response: read zero / ignore writes, no wait forever.
                Ready = access;
            end
            default: ;
        endcase
    end

endmodule
