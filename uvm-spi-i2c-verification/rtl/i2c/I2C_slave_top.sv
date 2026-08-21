`timescale 1ns / 1ps

module I2C_slave_top(
    input  logic       clk,
    input  logic       reset,

    input  logic [6:0] slave_addr,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,

    output logic       addr_match,
    output logic       rw_mode,       // 0: write, 1: read
    output logic       master_ack,    // read 후 master가 보낸 ACK/NACK
    output logic       busy,
    output logic       done,

    input  logic       scl,
    inout  logic       sda
);

    logic sda_o;
    logic sda_i;

    assign sda_i = sda;
    assign sda   = sda_o ? 1'bz : 1'b0;

    I2C_slave u_i2c_slave(
        .*,
        .sda_o(sda_o),
        .sda_i(sda_i)
    );

endmodule


module I2C_slave(
    input  logic       clk,
    input  logic       reset,

    input  logic [6:0] slave_addr,
    input  logic [7:0] tx_data,
    output logic [7:0] rx_data,

    output logic       addr_match,
    output logic       rw_mode,
    output logic       master_ack,
    output logic       busy,
    output logic       done,

    input  logic       scl,
    output logic       sda_o,
    input  logic       sda_i
);

    typedef enum logic [2:0] {
        IDLE       = 3'd0,
        ADDR       = 3'd1,
        ADDR_ACK   = 3'd2,
        WRITE_DATA = 3'd3,
        WRITE_ACK  = 3'd4,
        READ_DATA  = 3'd5,
        READ_ACK   = 3'd6
    } i2c_slave_state_e;

    i2c_slave_state_e state;

    logic scl_d0, scl_d1;
    logic sda_d0, sda_d1;

    logic scl_rise;
    logic scl_fall;
    logic start_cond;
    logic stop_cond;

    logic [7:0] shift_reg;
    logic [7:0] tx_shift_reg;
    logic [2:0] bit_cnt;

    logic ack_drive_phase;
    logic [7:0] addr_byte;
    logic       addr_ok;
    logic       rw_bit;

    assign scl_rise   = (scl_d1 == 1'b0) && (scl_d0 == 1'b1);
    assign scl_fall   = (scl_d1 == 1'b1) && (scl_d0 == 1'b0);

    assign start_cond = (sda_d1 == 1'b1) && (sda_d0 == 1'b0) && (scl_d0 == 1'b1);
    assign stop_cond  = (sda_d1 == 1'b0) && (sda_d0 == 1'b1) && (scl_d0 == 1'b1);

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            scl_d0 <= 1'b1;
            scl_d1 <= 1'b1;
            sda_d0 <= 1'b1;
            sda_d1 <= 1'b1;
        end else begin
            scl_d0 <= scl;
            scl_d1 <= scl_d0;
            sda_d0 <= sda_i;
            sda_d1 <= sda_d0;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state           <= IDLE;
            sda_o           <= 1'b1;
            rx_data         <= 8'd0;
            addr_match      <= 1'b0;
            rw_mode         <= 1'b0;
            master_ack      <= 1'b1;
            busy            <= 1'b0;
            done            <= 1'b0;
            shift_reg       <= 8'd0;
            tx_shift_reg    <= 8'd0;
            bit_cnt         <= 3'd0;
            ack_drive_phase <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start_cond) begin
                state           <= ADDR;
                busy            <= 1'b1;
                sda_o           <= 1'b1;
                shift_reg       <= 8'd0;
                bit_cnt         <= 3'd0;
                addr_match      <= 1'b0;
                ack_drive_phase <= 1'b0;
            end else if (stop_cond) begin
                state           <= IDLE;
                busy            <= 1'b0;
                sda_o           <= 1'b1;
                bit_cnt         <= 3'd0;
                ack_drive_phase <= 1'b0;
            end else begin
                case (state)

                    IDLE: begin
                        sda_o           <= 1'b1;
                        busy            <= 1'b0;
                        ack_drive_phase <= 1'b0;
                    end

                    ADDR: begin
                        sda_o <= 1'b1;

                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda_d0};

                            if (bit_cnt == 3'd7) begin
                                addr_byte  = {shift_reg[6:0], sda_d0};
                                addr_ok = (addr_byte[7:1] == slave_addr);
                                rw_bit     = sda_d0;

                                addr_match <= addr_ok;
                                rw_mode    <= rw_bit;

                                state           <= ADDR_ACK;
                                bit_cnt         <= 3'd0;
                                ack_drive_phase <= 1'b0;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end

                    ADDR_ACK: begin
                        if (scl_fall) begin
                            if (!ack_drive_phase) begin
                                sda_o           <= addr_match ? 1'b0 : 1'b1;
                                ack_drive_phase <= 1'b1;
                            end else begin
                                sda_o           <= 1'b1;
                                ack_drive_phase <= 1'b0;
                                bit_cnt         <= 3'd0;

                                if (addr_match) begin
                                    if (rw_mode) begin
                                        tx_shift_reg <= tx_data;
                                        sda_o        <= tx_data[7] ? 1'b1 : 1'b0;
                                        state        <= READ_DATA;
                                    end else begin
                                        state <= WRITE_DATA;
                                    end
                                end else begin
                                    state <= IDLE;
                                    busy  <= 1'b0;
                                end
                            end
                        end
                    end

                    WRITE_DATA: begin
                        sda_o <= 1'b1;

                        if (scl_rise) begin
                            shift_reg <= {shift_reg[6:0], sda_d0};

                            if (bit_cnt == 3'd7) begin
                                rx_data <= {shift_reg[6:0], sda_d0};
                                done    <= 1'b1;
                                bit_cnt <= 3'd0;
                                state   <= WRITE_ACK;
                                ack_drive_phase <= 1'b0;
                            end else begin
                                bit_cnt <= bit_cnt + 1'b1;
                            end
                        end
                    end

                    WRITE_ACK: begin
                        if (scl_fall) begin
                            if (!ack_drive_phase) begin
                                sda_o           <= 1'b0;
                                ack_drive_phase <= 1'b1;
                            end else begin
                                sda_o           <= 1'b1;
                                ack_drive_phase <= 1'b0;
                                bit_cnt         <= 3'd0;
                                state           <= WRITE_DATA;
                            end
                        end
                    end

                    READ_DATA: begin
                        if (scl_fall) begin
                            if (bit_cnt == 3'd7) begin
                                sda_o   <= 1'b1;
                                bit_cnt <= 3'd0;
                                state   <= READ_ACK;
                            end else begin
                                bit_cnt      <= bit_cnt + 1'b1;
                                tx_shift_reg <= {tx_shift_reg[6:0], 1'b0};
                                sda_o        <= tx_shift_reg[6] ? 1'b1 : 1'b0;
                            end
                        end
                    end

                    READ_ACK: begin
                        sda_o <= 1'b1;

                        if (scl_rise) begin
                            master_ack <= sda_d0;
                            done       <= 1'b1;
                        end

                        if (scl_fall) begin
                            if (master_ack == 1'b0) begin
                                tx_shift_reg <= tx_data;
                                sda_o        <= tx_data[7] ? 1'b1 : 1'b0;
                                bit_cnt      <= 3'd0;
                                state        <= READ_DATA;
                            end else begin
                                sda_o <= 1'b1;
                                state <= IDLE;
                                busy  <= 1'b0;
                            end
                        end
                    end

                    default: begin
                        state <= IDLE;
                    end

                endcase
            end
        end
    end

endmodule