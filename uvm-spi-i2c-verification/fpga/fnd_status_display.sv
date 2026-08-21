`timescale 1ns / 1ps

module fnd_status_display #(
    parameter integer HOLD_COUNT = 300_000_000
)(
    input  logic clk,
    input  logic reset,

    input  logic busy,
    input  logic done,

    input  logic       result_valid,
    input  logic [1:0] result_code,

    output logic [6:0] seg,
    output logic [3:0] an,
    output logic       dp
);

    localparam integer REFRESH_MAX = 100_000;

    localparam logic [1:0] RESULT_PASS = 2'd0;
    localparam logic [1:0] RESULT_SAME = 2'd1;
    localparam logic [1:0] RESULT_FAIL = 2'd2;

    typedef enum logic [2:0] {
        DISP_DASH = 3'd0,
        DISP_BUSY = 3'd1,
        DISP_DONE = 3'd2,
        DISP_PASS = 3'd3,
        DISP_SAME = 3'd4,
        DISP_FAIL = 3'd5
    } disp_state_e;

    disp_state_e disp_state;

    logic [31:0] hold_cnt;

    logic [$clog2(REFRESH_MAX)-1:0] refresh_cnt;
    logic [1:0] digit_sel;

    logic [6:0] seg_data [0:3];

    assign dp = 1'b1;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            disp_state <= DISP_DASH;
            hold_cnt   <= 32'd0;
        end else begin
            if (busy) begin
                disp_state <= DISP_BUSY;
                hold_cnt   <= 32'd0;
            end else if (result_valid) begin
                case (result_code)
                    RESULT_PASS: disp_state <= DISP_PASS;
                    RESULT_SAME: disp_state <= DISP_SAME;
                    RESULT_FAIL: disp_state <= DISP_FAIL;
                    default:     disp_state <= DISP_FAIL;
                endcase
                hold_cnt <= 32'd0;
            end else if (done) begin
                disp_state <= DISP_DONE;
                hold_cnt   <= 32'd0;
            end else begin
                if (disp_state != DISP_DASH) begin
                    if (hold_cnt == HOLD_COUNT - 1) begin
                        disp_state <= DISP_DASH;
                        hold_cnt   <= 32'd0;
                    end else begin
                        hold_cnt <= hold_cnt + 1'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            refresh_cnt <= '0;
            digit_sel   <= 2'd0;
        end else begin
            if (refresh_cnt == REFRESH_MAX - 1) begin
                refresh_cnt <= '0;
                digit_sel   <= digit_sel + 1'b1;
            end else begin
                refresh_cnt <= refresh_cnt + 1'b1;
            end
        end
    end

    always_comb begin
        case (disp_state)
            DISP_BUSY: begin
                seg_data[3] = 7'b0000011; // b
                seg_data[2] = 7'b1000001; // U
                seg_data[1] = 7'b0010010; // S
                seg_data[0] = 7'b0010001; // Y
            end

            DISP_DONE: begin
                seg_data[3] = 7'b0100001; // d
                seg_data[2] = 7'b0100011; // o
                seg_data[1] = 7'b0101011; // n
                seg_data[0] = 7'b0000110; // E
            end

            DISP_PASS: begin
                seg_data[3] = 7'b0001100; // P
                seg_data[2] = 7'b0001000; // A
                seg_data[1] = 7'b0010010; // S
                seg_data[0] = 7'b0010010; // S
            end

            DISP_SAME: begin
                seg_data[3] = 7'b0010010; // S
                seg_data[2] = 7'b0001000; // A
                seg_data[1] = 7'b1001000; // M 비슷하게
                seg_data[0] = 7'b0000110; // E
            end

            DISP_FAIL: begin
                seg_data[3] = 7'b0001110; // F
                seg_data[2] = 7'b0001000; // A
                seg_data[1] = 7'b1111001; // I
                seg_data[0] = 7'b1000111; // L
            end

            default: begin
                seg_data[3] = 7'b0111111; // -
                seg_data[2] = 7'b0111111; // -
                seg_data[1] = 7'b0111111; // -
                seg_data[0] = 7'b0111111; // -
            end
        endcase
    end

    always_comb begin
        case (digit_sel)
            2'd0: begin
                an  = 4'b1110;
                seg = seg_data[0];
            end
            2'd1: begin
                an  = 4'b1101;
                seg = seg_data[1];
            end
            2'd2: begin
                an  = 4'b1011;
                seg = seg_data[2];
            end
            default: begin
                an  = 4'b0111;
                seg = seg_data[3];
            end
        endcase
    end

endmodule