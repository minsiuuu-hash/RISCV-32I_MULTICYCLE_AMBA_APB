`timescale 1ns / 1ps

module apb_gpio (
    // BUS Global signal
    input               PCLK,
    input               PRESET,
    input        [31:0] PAddr,
    input        [31:0] PWData,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    //external port
    inout  logic [15:0] GPIO
);

    localparam [11:0] GPIO_CTL_ADDR = 12'h000;
    localparam [11:0] GPIO_ODATA_ADDR = 12'h004;
    localparam [11:0] GPIO_IDATA_ADDR = 12'h008;
    logic [15:0]
        GPIO_ODATA_REG, GPIO_CTL_REG, GPIO_IDATA_REG;  //, GPIO_IDATA_NEXT;

    assign PREADY = (PENABLE && PSEL) ? 1'b1 : 1'b0;

    assign PRDATA = (PAddr[11:0] == GPIO_CTL_ADDR) ? {16'h0000,GPIO_CTL_REG} :
                    (PAddr[11:0] == GPIO_ODATA_ADDR) ? {16'h0000,GPIO_ODATA_REG} :
                    (PAddr[11:0] == GPIO_IDATA_ADDR) ? {16'h0000,GPIO_IDATA_REG} :
                    32'hxxxx_xxxx;

    always_ff @(posedge PCLK, posedge PRESET) begin
        if (PRESET) begin
            GPIO_CTL_REG   <= 16'h0000;
            GPIO_ODATA_REG <= 16'h0000;
            //GPIO_IDATA_REG <= 16'h0000;
        end else begin
            if (PREADY) begin
                if (PWRITE) begin
                    case (PAddr[11:0])
                        GPIO_CTL_ADDR: begin
                            GPIO_CTL_REG <= PWData[15:0];
                        end
                        GPIO_ODATA_ADDR: begin
                            GPIO_ODATA_REG <= PWData[15:0];
                        end
                    endcase
                end
                // else begin
                // GPIO_IDATA_REG <= GPIO_IDATA_NEXT;
                // end
            end
        end
    end

    gpio U_GPIO (
        .ctl(GPIO_CTL_REG),
        .o_data(GPIO_ODATA_REG),
        .i_data(GPIO_IDATA_REG),
        .gpio(GPIO)
    );

endmodule

module gpio (
    input        [15:0] ctl,
    input        [15:0] o_data,
    output logic [15:0] i_data,
    inout  logic [15:0] gpio
);
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin
            assign gpio[i]   = ctl[i] ? o_data[i] : 1'bz;
            assign i_data[i] = ~ctl[i] ? gpio[i] : 1'bz;
        end
    endgenerate

endmodule
