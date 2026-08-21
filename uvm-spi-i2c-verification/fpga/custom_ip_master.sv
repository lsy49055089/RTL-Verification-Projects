`timescale 1ns / 1ps

module custom_ip_master (
    input  logic       clk,
    input  logic       reset,

    input  logic [7:0] sw,
    input  logic       btn_start,
    input  logic       btn_check,

    input  logic       spi_busy,
    input  logic       spi_done,
    input  logic [7:0] spi_rx_data,

    output logic       spi_start,
    output logic [7:0] spi_tx_data,
    output logic [7:0] led,

    output logic       result_valid,
    output logic [1:0] result_code
);

    localparam integer THREE_SEC = 300_000_000;
    localparam integer BLINK_CNT = 25_000_000;

    localparam logic [1:0] RESULT_PASS = 2'd0;
    localparam logic [1:0] RESULT_SAME = 2'd1;
    localparam logic [1:0] RESULT_FAIL = 2'd2;

    logic btn_start_pulse;
    logic btn_check_pulse;

    logic [7:0] prev_tx_data;
    logic       valid_prev;
    logic       check_mode;

    logic       result_pending;
    logic       result_active;
    logic [31:0] result_cnt;
    logic [31:0] blink_cnt;
    logic        blink_toggle;

    button_debounce u_button_debounce_start (
        .clk   (clk),
        .rst   (reset),
        .i_btn (btn_start),
        .o_btn (btn_start_pulse)
    );

    button_debounce u_button_debounce_check (
        .clk   (clk),
        .rst   (reset),
        .i_btn (btn_check),
        .o_btn (btn_check_pulse)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            spi_start      <= 1'b0;
            spi_tx_data    <= 8'd0;
            prev_tx_data   <= 8'd0;
            valid_prev     <= 1'b0;
            check_mode     <= 1'b0;

            led            <= 8'd0;
            result_valid   <= 1'b0;
            result_code    <= RESULT_PASS;
            result_pending <= 1'b0;
            result_active  <= 1'b0;
            result_cnt     <= 32'd0;
            blink_cnt      <= 32'd0;
            blink_toggle   <= 1'b0;
        end else begin
            spi_start      <= 1'b0;
            result_valid   <= result_pending;
            result_pending <= 1'b0;

            if (btn_start_pulse && !spi_busy) begin
                spi_tx_data <= sw;
                spi_start   <= 1'b1;
                check_mode  <= 1'b0;
            end else if (btn_check_pulse && !spi_busy) begin
                spi_tx_data <= sw;
                spi_start   <= 1'b1;
                check_mode  <= 1'b1;
            end

            if (spi_done) begin
                result_active  <= 1'b1;
                result_pending <= 1'b1;
                result_cnt     <= 32'd0;
                blink_cnt      <= 32'd0;
                blink_toggle   <= 1'b0;

                if (check_mode) begin
                    if (spi_rx_data == spi_tx_data)
                        result_code <= RESULT_SAME;
                    else
                        result_code <= RESULT_FAIL;
                end else begin
                    if (!valid_prev)
                        result_code <= RESULT_PASS;
                    else if (spi_tx_data == prev_tx_data)
                        result_code <= RESULT_SAME;
                    else
                        result_code <= RESULT_PASS;
                end

                prev_tx_data <= spi_tx_data;
                valid_prev   <= 1'b1;
            end

            if (result_active) begin
                if (result_cnt == THREE_SEC - 1) begin
                    result_active <= 1'b0;
                    result_cnt    <= 32'd0;
                    led           <= 8'd0;
                end else begin
                    result_cnt <= result_cnt + 1'b1;

                    if (result_code != RESULT_FAIL) begin
                        led <= 8'b1111_1111;
                    end else begin
                        if (blink_cnt == BLINK_CNT - 1) begin
                            blink_cnt    <= 32'd0;
                            blink_toggle <= ~blink_toggle;
                        end else begin
                            blink_cnt <= blink_cnt + 1'b1;
                        end

                        if (blink_toggle)
                            led <= 8'b1010_1010;
                        else
                            led <= 8'b0101_0101;
                    end
                end
            end
        end
    end

endmodule


module button_debounce (
    input  logic clk,
    input  logic rst,
    input  logic i_btn,
    output logic o_btn
);

    parameter F_COUNT = 100_000_000 / 100_000;

    logic [$clog2(F_COUNT)-1:0] r_counter;
    logic clk_100khz;

    logic [7:0] sync_reg;
    logic       edge_reg;
    logic       debounce;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            r_counter  <= '0;
            clk_100khz <= 1'b0;
        end else begin
            if (r_counter == F_COUNT - 1) begin
                r_counter  <= '0;
                clk_100khz <= 1'b1;
            end else begin
                r_counter  <= r_counter + 1'b1;
                clk_100khz <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            sync_reg <= 8'd0;
        else if (clk_100khz)
            sync_reg <= {i_btn, sync_reg[7:1]};
    end

    assign debounce = &sync_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            edge_reg <= 1'b0;
        else
            edge_reg <= debounce;
    end

    assign o_btn = debounce & ~edge_reg;

endmodule