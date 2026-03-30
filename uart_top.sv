`timescale 1ns / 1ps

module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } state_t;

    state_t c_state, n_state;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic done_reg, done_next;
    logic [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    always_comb begin
        n_state         = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        done_next       = done_reg;
        buf_next        = buf_reg;

        case (c_state)
            IDLE: begin
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 5'd0;
                done_next       = 1'b0;
                buf_next        = 8'd0;

                if (b_tick && !rx) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end

            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 5'd7) begin
                        b_tick_cnt_next = 5'd0;
                        if (rx == 1'b0)
                            n_state = DATA;
                        else
                            n_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 5'd1;
                    end
                end
            end

            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 5'd15) begin
                        buf_next = {rx, buf_reg[7:1]};

                        if (bit_cnt_reg == 3'd7) begin
                            b_tick_cnt_next = 5'd0;
                            bit_cnt_next    = 3'd0;
                            n_state         = STOP;
                        end else begin
                            b_tick_cnt_next = 5'd0;
                            bit_cnt_next    = bit_cnt_reg + 3'd1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 5'd1;
                    end
                end
            end

            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 5'd15) begin
                        b_tick_cnt_next = 5'd0;
                        done_next       = 1'b1;
                        n_state         = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 5'd1;
                    end
                end
            end

            default: begin
                n_state = IDLE;
            end
        endcase
    end

endmodule


module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       uart_tx,
    output       tx_busy,
    output       tx_done
);

    typedef enum logic [1:0] {
        IDLE  = 2'd0,
        START = 2'd1,
        DATA  = 2'd2,
        STOP  = 2'd3
    } state_t;

    state_t c_state, n_state;
    logic tx_reg, tx_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic busy_reg, busy_next;
    logic done_reg, done_next;
    logic [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 3'd0;
            b_tick_cnt_reg  <= 4'd0;
            busy_reg        <= 1'b0;
            done_reg        <= 1'b0;
            data_in_buf_reg <= 8'h00;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    always_comb begin
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;

        case (c_state)
            IDLE: begin
                tx_next         = 1'b1;
                bit_cnt_next    = 3'd0;
                b_tick_cnt_next = 4'd0;
                done_next       = 1'b0;

                if (tx_start) begin
                    n_state          = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end

            START: begin
                tx_next = 1'b0;

                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        n_state         = DATA;
                        b_tick_cnt_next = 4'd0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 4'd1;
                    end
                end
            end

            DATA: begin
                tx_next = data_in_buf_reg[0];

                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        if (bit_cnt_reg == 3'd7) begin
                            b_tick_cnt_next = 4'd0;
                            bit_cnt_next    = 3'd0;
                            n_state         = STOP;
                        end else begin
                            b_tick_cnt_next  = 4'd0;
                            bit_cnt_next     = bit_cnt_reg + 3'd1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 4'd1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;

                if (b_tick) begin
                    if (b_tick_cnt_reg == 4'd15) begin
                        b_tick_cnt_next = 4'd0;
                        done_next       = 1'b1;
                        busy_next       = 1'b0;
                        n_state         = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 4'd1;
                    end
                end
            end

            default: begin
                n_state = IDLE;
            end
        endcase
    end

endmodule


module baud_tick (
    input              clk,
    input              rst,
    input        [1:0] BPS,
    output logic       b_tick
);

    parameter int BAUDRATE_9600   = 9600   * 16;
    parameter int BAUDRATE_19200  = 19200  * 16;
    parameter int BAUDRATE_115200 = 115200 * 16;

    parameter int F_COUNT_9600   = 100_000_000 / BAUDRATE_9600;
    parameter int F_COUNT_19200  = 100_000_000 / BAUDRATE_19200;
    parameter int F_COUNT_115200 = 100_000_000 / BAUDRATE_115200;

    logic [ $clog2(F_COUNT_9600):0]   counter_reg_9600;
    logic [$clog2(F_COUNT_19200):0]   counter_reg_19200;
    logic [$clog2(F_COUNT_115200):0]  counter_reg_115200;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg_9600   <= 0;
            counter_reg_19200  <= 0;
            counter_reg_115200 <= 0;
            b_tick             <= 1'b0;
        end else begin
            b_tick <= 1'b0;

            case (BPS)
                2'b00: begin
                    counter_reg_19200  <= 0;
                    counter_reg_115200 <= 0;

                    if (counter_reg_9600 == (F_COUNT_9600 - 1)) begin
                        counter_reg_9600 <= 0;
                        b_tick           <= 1'b1;
                    end else begin
                        counter_reg_9600 <= counter_reg_9600 + 1'b1;
                    end
                end

                2'b01: begin
                    counter_reg_9600   <= 0;
                    counter_reg_115200 <= 0;

                    if (counter_reg_19200 == (F_COUNT_19200 - 1)) begin
                        counter_reg_19200 <= 0;
                        b_tick            <= 1'b1;
                    end else begin
                        counter_reg_19200 <= counter_reg_19200 + 1'b1;
                    end
                end

                2'b10: begin
                    counter_reg_9600  <= 0;
                    counter_reg_19200 <= 0;

                    if (counter_reg_115200 == (F_COUNT_115200 - 1)) begin
                        counter_reg_115200 <= 0;
                        b_tick             <= 1'b1;
                    end else begin
                        counter_reg_115200 <= counter_reg_115200 + 1'b1;
                    end
                end

                default: begin
                    counter_reg_9600   <= 0;
                    counter_reg_19200  <= 0;
                    counter_reg_115200 <= 0;
                    b_tick             <= 1'b0;
                end
            endcase
        end
    end

endmodule