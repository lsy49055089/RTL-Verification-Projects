`timescale 1ns / 1ps

module spi_slave (
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    output logic       busy,
    output logic       done,

    input  logic       sclk,
    input  logic       mosi,
    output logic       miso,
    input  logic       ss_n
);

    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [2:0] rx_bit_cnt;
    logic [2:0] tx_bit_cnt;

    logic sclk_d;
    logic ss_n_d;

    logic sclk_pos;
    logic sclk_neg;
    logic ss_n_fall;
    logic ss_n_rise;

    assign sclk_pos  = (sclk_d == 1'b0) && (sclk == 1'b1);
    assign sclk_neg  = (sclk_d == 1'b1) && (sclk == 1'b0);
    assign ss_n_fall = (ss_n_d == 1'b1) && (ss_n == 1'b0);
    assign ss_n_rise = (ss_n_d == 1'b0) && (ss_n == 1'b1);

    assign busy = ~ss_n;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            sclk_d <= 1'b0;
            ss_n_d <= 1'b1;
        end else begin
            sclk_d <= sclk;
            ss_n_d <= ss_n;
        end
    end

    // MOSI sampling : Mode 0 기준 sclk posedge 감지 시 수신
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_shift_reg <= 8'd0;
            rx_data      <= 8'd0;
            rx_bit_cnt   <= 3'd0;
            done         <= 1'b0;
        end else begin
            done <= 1'b0;

            if (ss_n_rise) begin
                rx_shift_reg <= 8'd0;
                rx_bit_cnt   <= 3'd0;
            end else if (!ss_n && sclk_pos) begin
                rx_shift_reg <= {rx_shift_reg[6:0], mosi};

                if (rx_bit_cnt == 3'd7) begin
                    rx_data    <= {rx_shift_reg[6:0], mosi};
                    done       <= 1'b1;
                    rx_bit_cnt <= 3'd0;
                end else begin
                    rx_bit_cnt <= rx_bit_cnt + 1'b1;
                end
            end
        end
    end

    // MISO 준비 : ss_n falling 때 첫 bit 준비, 이후 sclk negedge 감지 시 다음 bit 준비
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_shift_reg <= 8'd0;
            tx_bit_cnt   <= 3'd0;
            miso         <= 1'b1;
        end else begin
            if (ss_n_rise) begin
                tx_shift_reg <= 8'd0;
                tx_bit_cnt   <= 3'd0;
                miso         <= 1'b1;
            end else if (ss_n_fall) begin
                miso         <= tx_data[7];
                tx_shift_reg <= {tx_data[6:0], 1'b0};
                tx_bit_cnt   <= 3'd1;
            end else if (!ss_n && sclk_neg) begin
                miso         <= tx_shift_reg[7];
                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};

                if (tx_bit_cnt == 3'd7)
                    tx_bit_cnt <= 3'd0;
                else
                    tx_bit_cnt <= tx_bit_cnt + 1'b1;
            end
        end
    end

endmodule