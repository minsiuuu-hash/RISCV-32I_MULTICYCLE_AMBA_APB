module uart (
    input               PCLK,
    input               PRESET,
    input        [31:0] PAddr,
    input        [31:0] PWData,
    input               PENABLE,
    input               PWRITE,
    input               PSEL,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    input              TX_BUSY,
    input              RX_DONE,
    input        [7:0] RX_OUT,
    output logic       TX_START,
    output logic [1:0] BPS,
    output logic [7:0] TX_IN
);

    localparam [11:0] UART_CTL_ADDR = 12'h000;
    localparam [11:0] UART_BAUD_ADDR = 12'h004;
    localparam [11:0] UART_STATUS_ADDR = 12'h008;
    localparam [11:0] UART_TXDATA_ADDR = 12'h00C;
    localparam [11:0] UART_RXDATA_ADDR = 12'h010;

    logic [7:0] UART_CTL_REG;
    logic [1:0] UART_BAUD_REG;
    logic [7:0] UART_TXDATA_REG;
    logic [7:0] UART_RXDATA_REG;
    logic       UART_RX_DONE_REG;

    assign PREADY = (PENABLE && PSEL) ? 1'b1 : 1'b0;

    assign TX_IN = UART_TXDATA_REG;
    assign BPS = UART_BAUD_REG;

    assign PRDATA = (PAddr[11:0] == UART_CTL_ADDR   ) ? {24'h00_0000, UART_CTL_REG} :
                    (PAddr[11:0] == UART_BAUD_ADDR  ) ? {30'h0000_0000, UART_BAUD_REG} :
                    (PAddr[11:0] == UART_STATUS_ADDR) ? {24'h00_0000, {UART_RX_DONE_REG, 6'b0, TX_BUSY}} :
                    (PAddr[11:0] == UART_TXDATA_ADDR) ? {24'h00_0000, UART_TXDATA_REG} :
                    (PAddr[11:0] == UART_RXDATA_ADDR) ? {24'h00_0000, UART_RXDATA_REG} :
                                                         32'hxxxx_xxxx;

    always_ff @(posedge PCLK or posedge PRESET) begin
        if (PRESET) begin
            UART_CTL_REG     <= 8'h00;
            UART_BAUD_REG    <= 2'b00;
            UART_TXDATA_REG  <= 8'h00;
            UART_RXDATA_REG  <= 8'h00;
            UART_RX_DONE_REG <= 1'b0;
            TX_START         <= 1'b0;
        end else begin
            TX_START <= 1'b0;
            if (RX_DONE) begin
                UART_RXDATA_REG  <= RX_OUT;
                UART_RX_DONE_REG <= 1'b1;
            end
            if (PREADY && !PWRITE && (PAddr[11:0] == UART_RXDATA_ADDR)) begin
                UART_RX_DONE_REG <= 1'b0;
            end
            if (PREADY && PWRITE) begin
                case (PAddr[11:0])
                    UART_CTL_ADDR: begin
                        UART_CTL_REG <= PWData[7:0];
                        if (PWData[0] && !TX_BUSY) begin
                            TX_START <= 1'b1;
                        end
                    end
                    UART_BAUD_ADDR: begin
                        UART_BAUD_REG <= PWData[1:0];
                    end
                    UART_TXDATA_ADDR: begin
                        UART_TXDATA_REG <= PWData[7:0];
                    end
                endcase
            end
        end
    end

endmodule
