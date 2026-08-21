`timescale 1ns / 1ps

module top_spi_slave (
    input  logic       clk,
    input  logic       btn_reset,

    input  logic       sclk,
    input  logic       mosi,
    output logic       miso,
    input  logic       ss_n,

    output logic [7:0] led,
    output logic [6:0] seg,
    output logic [3:0] an,
    output logic       dp
);

    logic [7:0] slave_tx_data;
    logic [7:0] slave_rx_data;
    logic       slave_busy;
    logic       slave_done;

    spi_slave u_spi_slave (
        .clk     (clk),
        .reset   (btn_reset),

        .tx_data (slave_tx_data),
        .rx_data (slave_rx_data),
        .busy    (slave_busy),
        .done    (slave_done),

        .sclk    (sclk),
        .mosi    (mosi),
        .miso    (miso),
        .ss_n    (ss_n)
    );

    custom_ip_slave u_custom_ip_slave (
        .clk         (clk),
        .reset       (btn_reset),

        .spi_rx_data (slave_rx_data),
        .spi_done    (slave_done),

        .spi_tx_data (slave_tx_data),
        .led         (led)
    );

    fnd_status_display #(
        .HOLD_COUNT(100_000_000)
    ) u_fnd_status_display (
        .clk          (clk),
        .reset        (btn_reset),

        .busy         (slave_busy),
        .done         (slave_done),

        .result_valid (1'b0),
        .result_code  (2'd0),

        .seg          (seg),
        .an           (an),
        .dp           (dp)
    );

endmodule