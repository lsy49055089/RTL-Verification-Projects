`timescale 1ns / 1ps

class transaction;

    rand bit [7:0] tx_data;
    rand bit       parity_error_inject;   // 0: 정상 parity, 1: 오류 parity

    bit [7:0] rx_data;
    bit       rx_done;
    bit       parity_error;

    bit [7:0] rx_fifo_push_data;
    bit [7:0] rx_fifo_pop_data;
    bit       rx_fifo_empty;

    bit [7:0] tx_fifo_push_data;
    bit [7:0] tx_fifo_pop_data;
    bit       tx_fifo_full;
    bit       tx_fifo_empty;

    bit [7:0] saved_tx_data;
    bit       tx_busy;
    bit       tx_stop_ok;

    bit       expected_parity;
    bit       sampled_tx_parity;
    bit       tx_parity_ok;

    bit       tx_should_block;

    int       test_mode;

endclass



interface uart_fifo_interface;

    logic clk;
    logic rst;
    logic rx;
    logic tx;

    logic [7:0] rx_data;
    logic       rx_done;
    logic       parity_error;

    logic       tx_busy;
    logic       b_tick;

    logic [7:0] expected_rx_data;
    logic       expected_error_inject;

    logic [7:0] rx_fifo_push_data;
    logic [7:0] rx_fifo_pop_data;
    logic       rx_fifo_empty;

    logic [7:0] tx_fifo_push_data;
    logic [7:0] tx_fifo_pop_data;
    logic       tx_fifo_full;
    logic       tx_fifo_empty;

    logic       loop_tx_start;

endinterface



class generator;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event event_gen_next;

    function new(mailbox #(transaction) gen2drv_mbox,
                 event event_gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    task run(int count);
        repeat (count) begin
            tr = new();

            assert(tr.randomize())
            else $display("%0t : [GEN FAIL] randomize fail", $time);

            gen2drv_mbox.put(tr);
            @(event_gen_next);
        end
    endtask

endclass



class driver;

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_fifo_interface uart_vif;

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual uart_fifo_interface uart_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_vif = uart_vif;
    endfunction

    task preset();
        uart_vif.rst = 1;
        uart_vif.rx  = 1;
        uart_vif.expected_rx_data = 8'h00;
        uart_vif.expected_error_inject = 1'b0;

        @(posedge uart_vif.clk);
        @(posedge uart_vif.clk);

        uart_vif.rst = 0;

        @(negedge uart_vif.clk);

        $display("   ------------------------------------");
        $display("   %0t : [DRV] RESET DONE", $time);
        $display("   ------------------------------------");
    endtask

    task tx_test(int count);
        $display("");
        $display("   *******************************************");
        $display("   * UART FIFO RANDOM PARITY LOOPBACK START  *");
        $display("   *******************************************");

        repeat (count) begin
            gen2drv_mbox.get(tr);

            uart_vif.expected_rx_data       = tr.tx_data;
            uart_vif.expected_error_inject  = tr.parity_error_inject;

            $display("%0t :  [DRV SEND] data=%h parity_error_inject=%0d",
                     $time, tr.tx_data, tr.parity_error_inject);

            send_uart_byte(tr.tx_data, tr.parity_error_inject);

            if (tr.parity_error_inject == 0) begin
                wait(uart_vif.tx_busy == 1);
                wait(uart_vif.tx_busy == 0);
            end else begin
                repeat (40) @(posedge uart_vif.b_tick);
            end
        end
    endtask

    task send_uart_byte(input bit [7:0] data,
                        input bit       error_inject);
        bit parity_bit;

        parity_bit = ~(^data);   // odd parity

        if (error_inject) begin
            parity_bit = ~parity_bit;   // 일부러 parity 오류 생성
        end

        uart_vif.rx = 0;
        repeat (16) @(posedge uart_vif.b_tick);

        for (int i = 0; i < 8; i++) begin
            uart_vif.rx = data[i];
            repeat (16) @(posedge uart_vif.b_tick);
        end

        uart_vif.rx = parity_bit;
        repeat (16) @(posedge uart_vif.b_tick);

        uart_vif.rx = 1;
        repeat (16) @(posedge uart_vif.b_tick);
    endtask

endclass



class monitor;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    virtual uart_fifo_interface uart_vif;

    function new(mailbox #(transaction) mon2scb_mbox,
                 event event_gen_next,
                 virtual uart_fifo_interface uart_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.event_gen_next = event_gen_next;
        this.uart_vif = uart_vif;
    endfunction

    task run();
        fork
            mon_rx();
            mon_rx_fifo();
            mon_tx_fifo();
            mon_tx();
            mon_parity_block();
            mon_control_timing();
        join
    endtask

    task mon_rx();
        forever begin
            @(posedge uart_vif.rx_done);

            tr = new();
            tr.tx_data              = uart_vif.expected_rx_data;
            tr.rx_data              = uart_vif.rx_data;
            tr.rx_done              = uart_vif.rx_done;
            tr.parity_error         = uart_vif.parity_error;
            tr.parity_error_inject  = uart_vif.expected_error_inject;
            tr.test_mode            = 0;

            mon2scb_mbox.put(tr);
        end
    endtask


    task mon_rx_fifo();
        logic [7:0] rx_fifo_expected_data;

        forever begin
            @(posedge uart_vif.rx_done);

            if (uart_vif.parity_error == 0) begin
                rx_fifo_expected_data = uart_vif.rx_data;

                @(negedge uart_vif.rx_fifo_empty);

                #1;

                tr = new();
                tr.rx_fifo_push_data = rx_fifo_expected_data;
                tr.rx_fifo_pop_data  = uart_vif.rx_fifo_pop_data;
                tr.rx_fifo_empty     = uart_vif.rx_fifo_empty;
                tr.test_mode         = 1;

                mon2scb_mbox.put(tr);
            end
        end
    endtask



    task mon_tx_fifo();
        forever begin
            @(negedge uart_vif.tx_fifo_empty);

            @(posedge uart_vif.clk);
            @(posedge uart_vif.clk);

            tr = new();
            tr.tx_fifo_push_data = uart_vif.tx_fifo_push_data;
            tr.tx_fifo_pop_data  = uart_vif.tx_fifo_pop_data;
            tr.tx_fifo_empty     = uart_vif.tx_fifo_empty;
            tr.tx_fifo_full      = uart_vif.tx_fifo_full;
            tr.test_mode         = 2;

            mon2scb_mbox.put(tr);
        end
    endtask



    task mon_tx();
        logic [7:0] save_data;
        logic [7:0] tx_expected_data;
        logic       sampled_parity;

        forever begin
            @(posedge uart_vif.tx_busy);

            tx_expected_data = uart_vif.tx_fifo_pop_data;

            @(negedge uart_vif.tx);

            repeat (8) @(posedge uart_vif.b_tick);

            for (int i = 0; i < 8; i++) begin
                repeat (16) @(posedge uart_vif.b_tick);
                save_data[i] = uart_vif.tx;
            end

            repeat (16) @(posedge uart_vif.b_tick);
            sampled_parity = uart_vif.tx;

            repeat (16) @(posedge uart_vif.b_tick);

            tr = new();
            tr.tx_fifo_pop_data   = tx_expected_data;
            tr.saved_tx_data      = save_data;
            tr.sampled_tx_parity  = sampled_parity;
            tr.expected_parity    = ~(^save_data);
            tr.tx_parity_ok       = (sampled_parity == ~(^save_data));
            tr.tx_stop_ok         = (uart_vif.tx == 1'b1);
            tr.tx_busy            = uart_vif.tx_busy;
            tr.test_mode          = 3;

            mon2scb_mbox.put(tr);

            -> event_gen_next;
        end
    endtask



    task mon_parity_block();
        forever begin
            @(posedge uart_vif.rx_done);

            if (uart_vif.parity_error == 1) begin
                repeat (40) @(posedge uart_vif.b_tick);

                tr = new();
                tr.tx_data             = uart_vif.expected_rx_data;
                tr.rx_data             = uart_vif.rx_data;
                tr.parity_error        = uart_vif.parity_error;
                tr.tx_busy             = uart_vif.tx_busy;
                tr.rx_fifo_empty       = uart_vif.rx_fifo_empty;
                tr.tx_fifo_empty       = uart_vif.tx_fifo_empty;
                tr.tx_should_block     = 1'b1;
                tr.test_mode           = 4;

                mon2scb_mbox.put(tr);

                -> event_gen_next;
            end
        end
    endtask



    task mon_control_timing();
        forever begin
            @(posedge uart_vif.rx_done);

            $display("%0t :  [RX DONE] rx_data=%h parity_error=%0d expected_error=%0d",
                     $time,
                     uart_vif.rx_data,
                     uart_vif.parity_error,
                     uart_vif.expected_error_inject);

            if (uart_vif.parity_error == 0) begin
                @(negedge uart_vif.rx_fifo_empty);
                $display("%0t :  [RX FIFO] HAS DATA pop_data=%h",
                         $time, uart_vif.rx_fifo_pop_data);

                @(negedge uart_vif.tx_fifo_empty);
                $display("%0t :  [TX FIFO] HAS DATA pop_data=%h",
                         $time, uart_vif.tx_fifo_pop_data);

                @(posedge uart_vif.tx_busy);
                $display("%0t :  [TX BUSY] ON tx_fifo_pop_data=%h",
                         $time, uart_vif.tx_fifo_pop_data);

                @(negedge uart_vif.tx_busy);
                $display("%0t :  [TX BUSY] OFF", $time);
            end else begin
                $display("%0t :  [PARITY ERROR] RX FIFO PUSH BLOCK EXPECTED",
                         $time);
            end
        end
    endtask

endclass



class scoreboard;

    transaction tr;
    mailbox #(transaction) mon2scb_mbox;

    int total_cnt = 0;
    int pass_cnt  = 0;
    int fail_cnt  = 0;

    function new(mailbox #(transaction) mon2scb_mbox);
        this.mon2scb_mbox = mon2scb_mbox;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            total_cnt++;

            case (tr.test_mode)

                0: begin
                    if ((tr.tx_data == tr.rx_data) &&
                        (tr.parity_error == tr.parity_error_inject)) begin
                        pass_cnt++;
                        $display("%0t :  [RX PASS] expected=%h rx_data=%h parity_error=%0d inject=%0d",
                                 $time,
                                 tr.tx_data,
                                 tr.rx_data,
                                 tr.parity_error,
                                 tr.parity_error_inject);
                    end else begin
                        fail_cnt++;
                        $display("%0t : [RX FAIL] expected=%h rx_data=%h parity_error=%0d inject=%0d",
                                 $time,
                                 tr.tx_data,
                                 tr.rx_data,
                                 tr.parity_error,
                                 tr.parity_error_inject);
                    end
                end

                1: begin
                    if (tr.rx_fifo_push_data == tr.rx_fifo_pop_data) begin
                        pass_cnt++;
                        $display("%0t :  [RX FIFO PASS] push=%h pop=%h",
                                 $time,
                                 tr.rx_fifo_push_data,
                                 tr.rx_fifo_pop_data);
                    end else begin
                        fail_cnt++;
                        $display("%0t :  [RX FIFO FAIL] push=%h pop=%h",
                                 $time,
                                 tr.rx_fifo_push_data,
                                 tr.rx_fifo_pop_data);
                    end
                end

                2: begin
                    if (tr.tx_fifo_push_data == tr.tx_fifo_pop_data) begin
                        pass_cnt++;
                        $display("%0t :  [TX FIFO PASS] push=%h pop=%h",
                                 $time,
                                 tr.tx_fifo_push_data,
                                 tr.tx_fifo_pop_data);
                    end else begin
                        fail_cnt++;
                        $display("%0t :  [TX FIFO FAIL] push=%h pop=%h",
                                 $time,
                                 tr.tx_fifo_push_data,
                                 tr.tx_fifo_pop_data);
                    end
                end

                3: begin
                    if ((tr.tx_fifo_pop_data == tr.saved_tx_data) &&
                        (tr.tx_stop_ok) &&
                        (tr.tx_parity_ok)) begin
                        pass_cnt++;
                        $display("%0t :  [TX PASS] tx_fifo_pop=%h saved_tx=%h parity=%0d expected_parity=%0d stop_ok=%0d",
                                 $time,
                                 tr.tx_fifo_pop_data,
                                 tr.saved_tx_data,
                                 tr.sampled_tx_parity,
                                 tr.expected_parity,
                                 tr.tx_stop_ok);
                        $display("");
                    end else begin
                        fail_cnt++;
                        $display("%0t : [TX FAIL] tx_fifo_pop=%h saved_tx=%h parity=%0d expected_parity=%0d stop_ok=%0d",
                                 $time,
                                 tr.tx_fifo_pop_data,
                                 tr.saved_tx_data,
                                 tr.sampled_tx_parity,
                                 tr.expected_parity,
                                 tr.tx_stop_ok);
                        $display("");
                    end
                end

                4: begin
                    if ((tr.parity_error == 1) &&
                        (tr.tx_busy == 0)) begin
                        pass_cnt++;
                        $display("%0t :  [PARITY BLOCK PASS] error_data=%h rx_data=%h -> TX NOT STARTED",
                                 $time,
                                 tr.tx_data,
                                 tr.rx_data);
                        $display("");
                    end else begin
                        fail_cnt++;
                        $display("%0t : [PARITY BLOCK FAIL] error_data=%h rx_data=%h tx_busy=%0d",
                                 $time,
                                 tr.tx_data,
                                 tr.rx_data,
                                 tr.tx_busy);
                        $display("");
                    end
                end

            endcase
        end
    endtask

endclass



class environment;

    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event event_gen_next;

    virtual uart_fifo_interface uart_vif;

    int run_count;

    function new(virtual uart_fifo_interface uart_vif);
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, event_gen_next);
        drv = new(gen2drv_mbox, uart_vif);
        mon = new(mon2scb_mbox, event_gen_next, uart_vif);
        scb = new(mon2scb_mbox);

        this.uart_vif = uart_vif;
    endfunction

    task run();
        drv.preset();

        run_count = 10;

        fork
            mon.run();
            scb.run();
        join_none

        fork
            gen.run(run_count);
            drv.tx_test(run_count);
        join

        #1000;

        $display("   *******************************************");
        $display("   * UART FIFO RANDOM PARITY LOOPBACK END    *");
        $display("   *******************************************");

        $display("   -------------------------");
        $display("   ** sram ip verfication **");
        $display("   ** total test num = %2d **", scb.total_cnt);
        $display("   ** pass  test num = %2d **", scb.pass_cnt);
        $display("   ** fail  test num = %2d **", scb.fail_cnt);
        $display("   **************************");

        $stop;
    endtask

endclass



module tb_uart_fifo_loopback_sv();

    uart_fifo_interface uart_if();

    environment env;

    uart_fifo_loopback_sv U_UART_FIFO_LOOPBACK (
        .clk (uart_if.clk),
        .rst (uart_if.rst),
        .rx  (uart_if.rx),
        .tx  (uart_if.tx)
    );

    assign uart_if.rx_data           = U_UART_FIFO_LOOPBACK.U_UART_TOP_SV.rx_data;
    assign uart_if.rx_done           = U_UART_FIFO_LOOPBACK.U_UART_TOP_SV.rx_done;
    assign uart_if.parity_error      = U_UART_FIFO_LOOPBACK.w_parity_error;
    assign uart_if.tx_busy           = U_UART_FIFO_LOOPBACK.U_UART_TOP_SV.tx_busy;
    assign uart_if.b_tick            = U_UART_FIFO_LOOPBACK.U_UART_TOP_SV.w_b_tick;

    assign uart_if.rx_fifo_push_data = U_UART_FIFO_LOOPBACK.w_rx_data;
    assign uart_if.rx_fifo_pop_data  = U_UART_FIFO_LOOPBACK.w_rx_pop_data;
    assign uart_if.rx_fifo_empty     = U_UART_FIFO_LOOPBACK.w_rx_pop_empty;

    assign uart_if.tx_fifo_push_data = U_UART_FIFO_LOOPBACK.w_rx_pop_data;
    assign uart_if.tx_fifo_pop_data  = U_UART_FIFO_LOOPBACK.w_tx_pop_data;
    assign uart_if.tx_fifo_empty     = U_UART_FIFO_LOOPBACK.w_tx_pop_empty;
    assign uart_if.tx_fifo_full      = U_UART_FIFO_LOOPBACK.w_tx_push_full;

    assign uart_if.loop_tx_start     = ~U_UART_FIFO_LOOPBACK.w_tx_pop_empty;

    always #5 uart_if.clk = ~uart_if.clk;

    initial begin
        uart_if.clk = 0;
        env = new(uart_if);
        env.run();
    end

endmodule