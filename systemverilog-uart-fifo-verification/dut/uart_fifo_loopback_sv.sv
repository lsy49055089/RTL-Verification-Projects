module uart_fifo_loopback_sv(
    input       clk,
    input       rst,
    input       rx,     
    output      tx
);

    wire [7:0] w_rx_data, w_rx_pop_data, w_tx_pop_data;
    wire w_rx_done, w_tx_pop_empty, w_rx_pop_empty, w_tx_push_full;
    wire w_tx_busy;
    wire w_parity_error;   // 추가

    uart_top_sv U_UART_TOP_SV (
        .clk          (clk),
        .rst          (rst),       
        .tx_start     (~w_tx_pop_empty),      
        .tx_data      (w_tx_pop_data),
        .rx           (rx),
        .rx_data      (w_rx_data),
        .rx_done      (w_rx_done),
        .tx_busy      (w_tx_busy),        
        .tx           (tx),
        .parity_error (w_parity_error)   // 추가
    );


		fifo_sv U_FIFO_RX_SV (
		    .clk(clk),
		    .rst(rst),
		    .push_data(w_rx_data),
		    .push(w_rx_done & ~w_parity_error),
		    .pop(~w_tx_push_full),
		    .pop_data(w_rx_pop_data),    
		    .full(),
		    .empty(w_rx_pop_empty)
		);
		
		
    fifo_sv U_FIFO_TX_SV (
        .clk       (clk),
        .rst       (rst),
        .push_data (w_rx_pop_data),
        .push      (~w_rx_pop_empty),
        .pop       (~w_tx_busy),
        .pop_data  (w_tx_pop_data),
        .full      (w_tx_push_full),
        .empty     (w_tx_pop_empty)
    );

endmodule