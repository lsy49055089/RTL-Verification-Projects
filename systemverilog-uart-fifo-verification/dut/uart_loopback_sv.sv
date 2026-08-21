`timescale 1ns / 1ps


module uart_loopback_sv(
    input       clk,
    input       rst,
    input       rx,     
    output      tx
    );


    wire [7:0] w_rx_data;
    wire w_tx_start;

    uart_top_sv U_UART_TOP_SV (
    .clk     (clk),
    .rst     (rst),       
    .tx_start(w_tx_start),      
    .tx_data (w_rx_data),
    .rx      (rx),
    .rx_data (w_rx_data),
    .rx_done (w_tx_start),
    .tx_busy (),        
    .tx      (tx)
);

endmodule





module uart_top_sv (
    input   logic  clk,
    input   logic  rst,       // reset
    input   logic  tx_start,       // tx start
    input   logic  [7:0] tx_data,
    input   logic  rx,
    output  logic  [7:0]rx_data,
    output  logic  rx_done,
    output  logic  tx_busy,        // tx_data from switches
    output  logic  tx,
    output  logic  parity_error
);

   
    logic w_b_tick;

    
    uart_tx_sv U_UART_TX_SV(
        .clk         (clk),
        .rst         (rst),
        .tx_start    (tx_start),
        .tx_data     (tx_data),
        .i_b_tick    (w_b_tick),
        .tx_busy     (tx_busy),
        .tx          (tx)
    );

    uart_rx_sv U_UART_RX_SV(
        .clk         (clk),
        .rst         (rst),
        .rx          (rx),
        .i_b_tick    (w_b_tick),
        .rx_data     (rx_data),
        .rx_done     (rx_done),
        .parity_error(parity_error)
    );

    baud_tick_gen U_BAUD_TICK_GEN(
        .clk      (clk),
        .rst      (rst),
        .o_b_tick (w_b_tick)
    );
    
endmodule




module uart_rx_sv (
    input  logic clk,
    input  logic rst,
    input  logic rx,
    input  logic i_b_tick,
    output logic [7:0] rx_data,
    output logic rx_done,
    output logic parity_error
);
    
    parameter IDLE   = 0;
    parameter START  = 1;
    parameter DATA   = 2;
    parameter PARITY = 3;
    parameter STOP   = 4;

    //reg rx_reg, rx_next;
    reg rx_done_reg, rx_done_next;
    reg [2:0] n_state, c_state;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [7:0] data_reg , data_next;
    reg parity_reg, parity_next;
    reg parity_error_reg, parity_error_next;
    
    assign parity_error = parity_error_reg;
    assign rx_done = rx_done_reg;
    assign rx_data = data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_done_reg          <= 0;
            c_state         <= IDLE;
            bit_cnt_reg     <= 0;
            b_tick_cnt_reg  <= 0;
            data_reg        <= 0;
            parity_reg      <= 0;
            parity_error_reg<= 0;
        end else begin
            rx_done_reg     <= rx_done_next;
            c_state         <= n_state;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            data_reg        <= data_next;
            parity_reg      <= parity_next;
            parity_error_reg<= parity_error_next;
        end
    end

    always @(*) begin
        rx_done_next      = rx_done_reg;
        n_state           = c_state;
        bit_cnt_next      = bit_cnt_reg;
        b_tick_cnt_next   = b_tick_cnt_reg;
        data_next         = data_reg;
        parity_next       = parity_reg;
        parity_error_next = parity_error_reg;
        case (c_state)
            IDLE:begin
                rx_done_next = 0;
                if (i_b_tick && (rx == 0)) begin
                    b_tick_cnt_next = 0;
                    n_state         = START;
                end
            end

            START:begin
                if (i_b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        bit_cnt_next    = 0;
                        b_tick_cnt_next = 0;
                        n_state         = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_next + 1;
                    end
                end
            end

            DATA:begin
                if (i_b_tick) begin                
                    if (b_tick_cnt_reg == 15) begin
                        data_next = {rx,data_reg[7:1]};
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            parity_next = ~(^data_next);
                            n_state = PARITY;
                        end else begin
                            bit_cnt_next = bit_cnt_next + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_next + 1;
                    end
                end
            end

            PARITY:begin
                if (i_b_tick) begin
                    if (b_tick_cnt_reg ==15) begin
                        b_tick_cnt_next = 0;
                        if (rx == parity_reg) begin
                            parity_error_next = 0;
                            n_state = STOP;
                        end else begin
                            parity_error_next = 1;
                            n_state = STOP;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_next + 1;
                    end
                end
            end

            STOP: begin
                if (i_b_tick) begin
                    if ((b_tick_cnt_reg == 23) || ((b_tick_cnt_next > 16) && !rx)) begin
                        b_tick_cnt_next = 0;
                        rx_done_next    = 1;
                        n_state         = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_next + 1;
                    end
                end
            end

        endcase
    end


endmodule



module uart_tx_sv(
    input clk,
    input rst,
    input i_b_tick,
    input tx_start,
    input [7:0] tx_data,
    output tx,
    output tx_busy
    );

    parameter IDLE   = 0;
    parameter START  = 1;
    parameter DATA   = 2;
    parameter PARITY = 3;
    parameter STOP   = 4;


    logic tx_reg, tx_next;
    logic tx_busy_reg, tx_busy_next;
    logic [2:0] c_state , n_state;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [7:0] data_reg, data_next;
    logic parity_reg, parity_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_reg          <= 1;      // 원래 0이었는데 루프백 구조를 할꺼니까 IDLE상태에서도 1이니 한번 1로 바꿔본것. TEST중
            tx_busy_reg     <= 0;
            c_state         <= IDLE;
            bit_cnt_reg     <= 0;
            b_tick_cnt_reg  <= 0;
            data_reg        <= 0;
            parity_reg      <= 0;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            tx_busy_reg     <= tx_busy_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            data_reg        <= data_next;
            parity_reg      <= parity_next;
        end
    end

    always @(*) begin
        n_state         = c_state;
        tx_next         = tx_reg;
        tx_busy_next    = tx_busy_reg;
        bit_cnt_next    = bit_cnt_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        data_next       = data_reg;
        parity_next     = parity_reg;
        case (c_state)
            IDLE:begin
                tx_next = 1;
                tx_busy_next = 0;
                if (tx_start) begin
                    n_state         = START;
                    tx_busy_next    = 1;
                    data_next       = tx_data;
                    parity_next     = ~(^tx_data);
                    b_tick_cnt_next = 0;
                end
            end

            START: begin
                tx_next = 0;
                if (i_b_tick) begin
                    if(b_tick_cnt_reg == 15)begin
                        n_state = DATA;
                        bit_cnt_next = 0;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next =  b_tick_cnt_next + 1;
                    end
                end
            end

            DATA: begin
                tx_next = data_reg[0];
                if (i_b_tick) begin
                    if(b_tick_cnt_reg == 15)begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            //parity_next = ~(^data_reg);
                            n_state = PARITY;
                        end else begin
                            bit_cnt_next = bit_cnt_next + 1;
                            data_next = {1'b0,data_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next =  b_tick_cnt_next + 1;
                    end
                end
            end


            PARITY: begin
                tx_next = parity_reg;
                if (i_b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        n_state = STOP;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_next + 1;
                        //n_state = PARITY;
                    end
                end
            end

            STOP: begin
                tx_next = 1;
                if (i_b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = IDLE;
                        tx_busy_next = 0;
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_next + 1;
                    end
                end
            end

        endcase
    end

endmodule





module baud_tick_gen (      //baud tick * 16
    input  logic clk,
    input  logic rst,
    output logic o_b_tick
);

    parameter F_COUNT = 100_000_000 / (9600 * 16);
    parameter WIDTH   = $clog2(F_COUNT);

    logic [WIDTH-1:0] counter_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            o_b_tick    <= 1'b0;
        end else begin
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                o_b_tick    <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1'b1;
                o_b_tick    <= 1'b0;
            end
        end
    end

endmodule