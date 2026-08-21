`timescale 1ns / 1ps

module top_spi_loopback (
    input  logic       clk,
    input  logic       reset,

    input  logic       start,
    input  logic [7:0] master_tx_data,
    input  logic [7:0] slave_tx_data,

    output logic [7:0] master_rx_data,
    output logic [7:0] slave_rx_data,

    output logic       master_busy,
    output logic       slave_busy,
    output logic       master_done,
    output logic       slave_done
);

    logic sclk;
    logic mosi;
    logic miso;
    logic ss_n;

    spi_master u_spi_master (
        .clk     (clk),
        .reset   (reset),

        .start   (start),
        .cpol    (1'b0),
        .cpha    (1'b0),
        .clk_div (8'd4),
        .tx_data (master_tx_data),

        .miso    (miso),
        .busy    (master_busy),
        .rx_data (master_rx_data),
        .done    (master_done),

        .sclk    (sclk),
        .mosi    (mosi),
        .ss_n    (ss_n)
    );

    spi_slave u_spi_slave (
        .clk     (clk),
        .reset   (reset),

        .tx_data (slave_tx_data),
        .rx_data (slave_rx_data),
        .busy    (slave_busy),
        .done    (slave_done),

        .sclk    (sclk),
        .mosi    (mosi),
        .miso    (miso),
        .ss_n    (ss_n)
    );

endmodule