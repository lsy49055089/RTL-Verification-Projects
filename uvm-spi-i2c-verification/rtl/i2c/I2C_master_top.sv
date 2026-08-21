`timescale 1ns / 1ps

module I2C_master_top(
    input  logic clk,
    input  logic reset,
    input  logic cmd_start,
    input  logic cmd_write,
    input  logic cmd_read,
    input  logic cmd_stop,

    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    input  logic ack_in,
    output logic ack_out,
    output logic busy,
    output logic done,

    output logic scl,
    inout  logic sda
);

    logic sda_o, sda_i;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    I2C_master u_i2c_master(
        .*,
        .sda_o(sda_o),
        .sda_i(sda_i)
    );

endmodule


module I2C_master(
    input  logic clk,
    input  logic reset,
    input  logic cmd_start,
    input  logic cmd_write,
    input  logic cmd_read,
    input  logic cmd_stop,

    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,
    input  logic ack_in,
    output logic ack_out,
    output logic busy,
    output logic done,

    output logic scl,
    output logic sda_o,
    input  logic sda_i
);

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        START,
        WAIT_CMD,
        DATA,
        DATA_ACK,
        STOP
    } i2c_state_e;

    i2c_state_e state;

    logic [7:0] div_cnt;
    logic       qtr_tick;
    logic       scl_r;
    logic       sda_r;
    logic [1:0] step;

    logic [7:0] tx_shift_reg;
    logic [7:0] rx_shift_reg;
    logic [2:0] bit_cnt;
    logic       is_read;
    logic       ack_in_r;

    assign scl   = scl_r;
    assign sda_o = sda_r;
    assign busy  = (state != IDLE);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            div_cnt  <= 0;
            qtr_tick <= 1'b0;
        end else begin
            if (div_cnt == 8'd249) begin
                div_cnt  <= 0;
                qtr_tick <= 1'b1;
            end else begin
                div_cnt  <= div_cnt + 1;
                qtr_tick <= 1'b0;
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            scl_r        <= 1'b1;
            sda_r        <= 1'b1;
            step         <= 0;
            done         <= 1'b0;
            ack_out      <= 1'b1;
            rx_data      <= 8'd0;
            tx_shift_reg <= 8'd0;
            rx_shift_reg <= 8'd0;
            is_read      <= 1'b0;
            bit_cnt      <= 3'd0;
            ack_in_r     <= 1'b1;
        end else begin
            done <= 1'b0;

            case (state)

                IDLE: begin
                    scl_r <= 1'b1;
                    sda_r <= 1'b1;

                    if (cmd_start) begin
                        state <= START;
                        step  <= 0;
                    end
                end

                START: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd1;
                            end

                            2'd1: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end

                            2'd2: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd3;
                            end

                            2'd3: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end

                WAIT_CMD: begin
                    if (cmd_write) begin
                        tx_shift_reg <= tx_data;
                        bit_cnt      <= 3'd0;
                        is_read      <= 1'b0;
                        step         <= 2'd0;
                        state        <= DATA;
                    end else if (cmd_read) begin
                        rx_shift_reg <= 8'd0;
                        bit_cnt      <= 3'd0;
                        is_read      <= 1'b1;
                        ack_in_r     <= ack_in;
                        step         <= 2'd0;
                        state        <= DATA;
                    end else if (cmd_stop) begin
                        step  <= 2'd0;
                        state <= STOP;
                    end else if (cmd_start) begin
                        step  <= 2'd0;
                        state <= START;
                    end
                end

                DATA: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;
                                sda_r <= is_read ? 1'b1 : tx_shift_reg[7];
                                step  <= 2'd1;
                            end

                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end

                            2'd2: begin
                                scl_r <= 1'b1;

                                if (is_read) begin
                                    rx_shift_reg <= {rx_shift_reg[6:0], sda_i};
                                end

                                step <= 2'd3;
                            end

                            2'd3: begin
                                scl_r <= 1'b0;
                                step  <= 2'd0;

                                if (!is_read) begin
                                    tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                end

                                if (bit_cnt == 3'd7) begin
                                    state <= DATA_ACK;
                                end else begin
                                    bit_cnt <= bit_cnt + 1'b1;
                                end
                            end
                        endcase
                    end
                end

                DATA_ACK: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                scl_r <= 1'b0;

                                if (is_read) begin
                                    sda_r <= ack_in_r;
                                end else begin
                                    sda_r <= 1'b1;
                                end

                                step <= 2'd1;
                            end

                            2'd1: begin
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end

                            2'd2: begin
                                scl_r <= 1'b1;

                                if (!is_read) begin
                                    ack_out <= sda_i;
                                end else begin
                                    rx_data <= rx_shift_reg;
                                end

                                step <= 2'd3;
                            end

                            2'd3: begin
                                scl_r <= 1'b0;
                                sda_r <= 1'b1;
                                done  <= 1'b1;
                                step  <= 2'd0;
                                state <= WAIT_CMD;
                            end
                        endcase
                    end
                end

                STOP: begin
                    if (qtr_tick) begin
                        case (step)
                            2'd0: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b0;
                                step  <= 2'd1;
                            end

                            2'd1: begin
                                sda_r <= 1'b0;
                                scl_r <= 1'b1;
                                step  <= 2'd2;
                            end

                            2'd2: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd3;
                            end

                            2'd3: begin
                                sda_r <= 1'b1;
                                scl_r <= 1'b1;
                                step  <= 2'd0;
                                done  <= 1'b1;
                                state <= IDLE;
                            end
                        endcase
                    end
                end

                default: begin
                    state <= IDLE;
                end

            endcase
        end
    end

endmodule