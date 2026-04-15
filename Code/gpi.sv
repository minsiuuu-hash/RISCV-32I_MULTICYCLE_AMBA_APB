`timescale 1ns / 1ps

module gpi (
    // BUS Global signal
    input               PCLK,
    input               PRESET,

    // APB Interface Signal
    input       [31:0]  PAddr,
    input       [31:0]  PWData,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,

    input       [7:0]   GPI,
    output logic        PREADY,
    output logic [31:0] PRDATA
);

    localparam [11:0] GPI_CTL_ADDR   = 12'h000;
    localparam [11:0] GPI_IDATA_ADDR = 12'h004;

    logic [7:0] GPI_CTL_REG;
    logic [7:0] GPI_IDATA_REG;

    assign PREADY = (PENABLE && PSEL) ? 1'b1 : 1'b0;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPI_CTL_REG <= 8'h00;
        end else begin
            if (PREADY && PWRITE) begin
                case (PAddr[11:0])
                    GPI_CTL_ADDR : GPI_CTL_REG <= PWData[7:0];
                    default      : ;
                endcase
            end
        end
    end

    always_comb begin
        GPI_IDATA_REG = GPI & GPI_CTL_REG;
    end

    always_comb begin
        case (PAddr[11:0])
            GPI_CTL_ADDR   : PRDATA = {24'h000000, GPI_CTL_REG};
            GPI_IDATA_ADDR : PRDATA = {24'h000000, GPI_IDATA_REG};
            default        : PRDATA = 32'h0000_0000;
        endcase
    end

endmodule
