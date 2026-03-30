`timescale 1ns / 1ps

module fnd_controller (
    input               clk,
    input               rst,
    input        [13:0] fnd_in_data,
    output logic [ 3:0] fnd_digit,
    output logic [ 7:0] fnd_data
);
    logic [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    logic [3:0] w_mux_4x1_out;
    logic [1:0] w_digit_sel;
    logic       w_1khz;

    digit_splitter U_DIGIT_SPL (
        .in_data   (fnd_in_data),
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000)
    );

    clk_div U_CLK_DIV (
        .clk   (clk),
        .rst   (rst),
        .o_1khz(w_1khz)
    );

    counter_4 U_COUNTER_4 (
        .clk      (w_1khz),
        .rst      (rst),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2X4 (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    mux_4x1 U_MUX_4X1 (
        .sel       (w_digit_sel),
        .digit_1   (w_digit_1),
        .digit_10  (w_digit_10),
        .digit_100 (w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out   (w_mux_4x1_out)
    );

    bcd U_BCD (
        .bcd     (w_mux_4x1_out),
        .fnd_data(fnd_data)
    );

endmodule

module clk_div (
    input        clk,
    input        rst,
    output logic o_1khz
);

    logic [16:0] counter_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_r <= 17'd0;
            o_1khz    <= 1'b0;
        end else begin
            if (counter_r == 17'd99999) begin
                counter_r <= 17'd0;
                o_1khz    <= 1'b1;
            end else begin
                counter_r <= counter_r + 17'd1;
                o_1khz    <= 1'b0;
            end
        end
    end

endmodule

module counter_4 (
    input              clk,
    input              rst,
    output logic [1:0] digit_sel
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            digit_sel <= 2'd0;
        end else begin
            digit_sel <= digit_sel + 2'd1;
        end
    end

endmodule

module decoder_2x4 (
    input  logic [1:0] digit_sel,
    output logic [3:0] fnd_digit
);

    always_comb begin
        case (digit_sel)
            2'b00:   fnd_digit = 4'b1110;
            2'b01:   fnd_digit = 4'b1101;
            2'b10:   fnd_digit = 4'b1011;
            2'b11:   fnd_digit = 4'b0111;
            default: fnd_digit = 4'b1111;
        endcase
    end

endmodule


module digit_splitter (
    input        [13:0] in_data,
    output logic [ 3:0] digit_1,
    output logic [ 3:0] digit_10,
    output logic [ 3:0] digit_100,
    output logic [ 3:0] digit_1000
);

    always_comb begin
        digit_1    = in_data % 10;
        digit_10   = (in_data / 10) % 10;
        digit_100  = (in_data / 100) % 10;
        digit_1000 = (in_data / 1000) % 10;
    end

endmodule


module mux_4x1 (
    input  logic [1:0] sel,
    input  logic [3:0] digit_1,
    input  logic [3:0] digit_10,
    input  logic [3:0] digit_100,
    input  logic [3:0] digit_1000,
    output logic [3:0] mux_out
);

    always_comb begin
        case (sel)
            2'b00:   mux_out = digit_1;
            2'b01:   mux_out = digit_10;
            2'b10:   mux_out = digit_100;
            2'b11:   mux_out = digit_1000;
            default: mux_out = 4'd0;
        endcase
    end

endmodule


module bcd (
    input  logic [3:0] bcd,
    output logic [7:0] fnd_data
);

    always_comb begin
        case (bcd)
            4'd0:    fnd_data = 8'hC0;
            4'd1:    fnd_data = 8'hF9;
            4'd2:    fnd_data = 8'hA4;
            4'd3:    fnd_data = 8'hB0;
            4'd4:    fnd_data = 8'h99;
            4'd5:    fnd_data = 8'h92;
            4'd6:    fnd_data = 8'h82;
            4'd7:    fnd_data = 8'hF8;
            4'd8:    fnd_data = 8'h80;
            4'd9:    fnd_data = 8'h90;
            default: fnd_data = 8'hFF;
        endcase
    end

endmodule
