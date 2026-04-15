`timescale 1ns / 1ps

module fnd (
    // BUS Global signal
    input PCLK,
    input PRESET,

    // APB Interface Signal
    input [31:0] PAddr,
    input [31:0] PWData,
    input        PENABLE,
    input        PWRITE,
    input        PSEL,

    output       [31:0] PRDATA,
    output logic        PREADY,
    output logic [15:0] FND_OUT
);

    localparam [11:0] FND_ADDR = 12'h000;

    logic [15:0] FND_ODATA_REG;

    assign FND_OUT = FND_ODATA_REG;

    assign PREADY = (PENABLE && PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PAddr[11:0] == FND_ADDR) ? {16'h0000,FND_ODATA_REG} : 32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            FND_ODATA_REG <= 16'h0000;
        end else begin
            if (PREADY && PWRITE) begin
                if (PAddr[11:0] == FND_ADDR) FND_ODATA_REG <= PWData[15:0];
            end
        end
    end

endmodule
