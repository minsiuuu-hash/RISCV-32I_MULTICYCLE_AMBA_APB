`timescale 1ns / 1ps

module gpo (
    // BUS Global signal
    input               PCLK,
    input               PRESET,

    // APB Interface Signal
    input       [31:0]  PAddr,
    input       [31:0]  PWData,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,

    output      [31:0]  PRDATA,
    output logic        PREADY,
    output logic [7:0]  GPO_OUT
);

    localparam [11:0] GPO_CTL_ADDR   = 12'h000;
    localparam [11:0] GPO_ODATA_ADDR = 12'h004;

    logic [7:0] GPO_CTL_REG;
    logic [7:0] GPO_ODATA_REG;

    assign PREADY = (PENABLE && PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PAddr[11:0] == GPO_CTL_ADDR)   ? {24'h000000, GPO_CTL_REG}   :
                    (PAddr[11:0] == GPO_ODATA_ADDR) ? {24'h000000, GPO_ODATA_REG} :
                    32'h0000_0000;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPO_CTL_REG   <= 8'h00;
            GPO_ODATA_REG <= 8'h00;
        end else begin
            if (PREADY && PWRITE) begin
                case (PAddr[11:0])
                    GPO_CTL_ADDR   : GPO_CTL_REG   <= PWData[7:0];
                    GPO_ODATA_ADDR : GPO_ODATA_REG <= PWData[7:0];
                    default        : ;
                endcase
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin
            assign GPO_OUT[i] = (GPO_CTL_REG[i]) ? GPO_ODATA_REG[i] : 1'b0;
        end
    endgenerate

endmodule