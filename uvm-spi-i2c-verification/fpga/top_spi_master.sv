`timescale 1ns / 1ps

module top_spi_master(
    input  logic       clk,
    input  logic       btn_reset,
    input  logic       btn_start,
    input  logic       btn_check,

    input  logic [7:0] sw,

    input  logic       miso,
    output logic       sclk,
    output logic       mosi,
    output logic       ss_n,

    output logic [7:0] led,
    output logic [6:0] seg,
    output logic [3:0] an,
    output logic       dp
);

    logic       spi_start;
    logic [7:0] spi_tx_data;
    logic [7:0] spi_rx_data;
    logic       spi_busy;
    logic       spi_done;

    logic       result_valid;
    logic [1:0] result_code;

    custom_ip_master u_custom_ip_master (
        .clk          (clk),
        .reset        (btn_reset),

        .sw           (sw),
        .btn_start    (btn_start),
        .btn_check    (btn_check),

        .spi_busy     (spi_busy),
        .spi_done     (spi_done),
        .spi_rx_data  (spi_rx_data),

        .spi_start    (spi_start),
        .spi_tx_data  (spi_tx_data),
        .led          (led),

        .result_valid (result_valid),
        .result_code  (result_code)
    );

    spi_master u_spi_master (
        .clk     (clk),
        .reset   (btn_reset),

        .start   (spi_start),
        .cpol    (1'b0),
        .cpha    (1'b0),
        .clk_div (8'd100),
        .tx_data (spi_tx_data),

        .miso    (miso),
        .busy    (spi_busy),
        .rx_data (spi_rx_data),
        .done    (spi_done),

        .sclk    (sclk),
        .mosi    (mosi),
        .ss_n    (ss_n)
    );

    fnd_status_display #(
        .HOLD_COUNT(300_000_000)
    ) u_fnd_status_display (
        .clk          (clk),
        .reset        (btn_reset),

        .busy         (spi_busy),
        .done         (spi_done),

        .result_valid (result_valid),
        .result_code  (result_code),

        .seg          (seg),
        .an           (an),
        .dp           (dp)
    );

endmodule