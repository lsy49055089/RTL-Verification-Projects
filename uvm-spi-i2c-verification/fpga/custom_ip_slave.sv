`timescale 1ns / 1ps

module custom_ip_slave (
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] spi_rx_data,
    input  logic       spi_done,

    output logic [7:0] spi_tx_data,
    output logic [7:0] led
);

    localparam integer THREE_SEC = 300_000_000;

    logic [31:0] led_cnt;
    logic        led_active;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            led         <= 8'd0;
            spi_tx_data <= 8'd0;
            led_cnt     <= 32'd0;
            led_active  <= 1'b0;
        end else begin
            if (spi_done) begin
                led         <= spi_rx_data;
                spi_tx_data <= spi_rx_data;
                led_cnt     <= 32'd0;
                led_active  <= 1'b1;
            end else if (led_active) begin
                if (led_cnt == THREE_SEC - 1) begin
                    led        <= 8'd0;
                    led_cnt    <= 32'd0;
                    led_active <= 1'b0;
                end else begin
                    led_cnt <= led_cnt + 1'b1;
                end
            end
        end
    end

endmodule