`timescale 1ns / 1ps

module bram (
    // BUS Global signal
    input PCLK,

    // APB Interface Signal
    input [31:0] PAddr,
    input [31:0] PWData,
    input        PENABLE,
    input        PWRITE,
    input        PSEL,

    output logic [31:0] PRDATA,
    output logic        PREADY
);

    logic [31:0] bmem[0:1023];  // 1024 * 4byte

    assign PREADY = (PENABLE && PSEL) ? 1'b1 : 1'b0;

    always_ff @(posedge PCLK) begin
        if (PSEL && PENABLE && PWRITE) begin
            bmem[PAddr[11:2]] <= PWData;
        end
    end

    assign PRDATA = bmem[PAddr[11:2]];

endmodule
