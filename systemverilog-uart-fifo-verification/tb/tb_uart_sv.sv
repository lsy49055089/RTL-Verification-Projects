`timescale 1ns / 1ps

class transaction;
    rand bit [7:0] tx_data;
    bit      [7:0] saved_tx_data;
    bit      [7:0] loop_rx_data;
    bit      [7:0] rx_data;
    bit            loop_tx_start;
    bit            tx_busy;
    bit            rx_done;
    bit            tx_stop_ok;
    int            test_mode;

    function void debug_print(string name);
        $display(
            "%0t : [%s] tx_data=%0h saved_tx_data=%0h loop_rx_data=%0h rx_data=%0h loop_tx_start=%0d tx_busy=%0d rx_done=%0d tx_stop_ok=%0d",
            $time, name, tx_data, saved_tx_data, loop_rx_data, rx_data,
            loop_tx_start, tx_busy, rx_done, tx_stop_ok
        );
    endfunction
endclass


interface uart_interface;
    logic       clk;
    logic       rst;
    logic       tx;
    logic       rx;
    logic       tx_busy;
    logic       rx_done;
    logic [7:0] rx_data;
    logic       b_tick;
    logic       loop_tx_start;
    logic [7:0] loop_rx_data;
    logic [7:0] expected_rx_data;
endinterface


class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event event_gen_next;

    function new(mailbox #(transaction) gen2drv_mbox, event event_gen_next);
        this.gen2drv_mbox = gen2drv_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    task run(int count);
        repeat (count) begin
            tr = new();

            assert(tr.randomize())
            else $display("%0t : [GEN] randomize fail", $time);

            gen2drv_mbox.put(tr);
            @(event_gen_next);
        end
    endtask
endclass


class driver;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_interface uart_vif;

    function new(mailbox #(transaction) gen2drv_mbox,
                 virtual uart_interface uart_vif);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_vif = uart_vif;
    endfunction

    task preset();
        uart_vif.rst = 1;
        uart_vif.rx  = 1;
        uart_vif.expected_rx_data = 8'h00;

        @(posedge uart_vif.clk);
        @(posedge uart_vif.clk);

        uart_vif.rst = 0;

        @(negedge uart_vif.clk);

        assert(uart_vif.tx == 1) begin
            $display("----------------------------------------------");
            $display("        [DRV] reset pass : tx idle!");
        end else begin
            $display("        [DRV Assert] reset fail : tx = %0d", uart_vif.tx);
        end

        assert(uart_vif.rx_done == 0)
            $display("        [DRV] reset pass : rx_done!");
        else
            $display("        [DRV Assert] reset fail : rx_done = %0d", uart_vif.rx_done);

        assert(uart_vif.tx_busy == 0) begin
            $display("        [DRV] reset pass : tx_busy!");
            $display("----------------------------------------------");
        end else begin
            $display("        [DRV Assert] reset fail : tx_busy = %0d", uart_vif.tx_busy);
        end
    endtask

    task tx_test(int count);
        $display("");
        $display("   ******************************");
        $display("   * | UART LOOPBACK TEST START |");
        $display("   ******************************");

        repeat (count) begin
            gen2drv_mbox.get(tr);

            uart_vif.expected_rx_data = tr.tx_data;

            send_uart_byte(tr.tx_data);

            wait(uart_vif.tx_busy == 1);
            wait(uart_vif.tx_busy == 0);
        end
    endtask

    task send_uart_byte(input bit [7:0] data);
        uart_vif.rx = 0;
        repeat (16) @(posedge uart_vif.b_tick);

        for (int i = 0; i < 8; i++) begin
            uart_vif.rx = data[i];
            repeat (16) @(posedge uart_vif.b_tick);
        end

        uart_vif.rx = 1;
        repeat (16) @(posedge uart_vif.b_tick);
    endtask
endclass


class monitor;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    virtual uart_interface uart_vif;

    function new(mailbox #(transaction) mon2scb_mbox,
                 virtual uart_interface uart_vif);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_vif = uart_vif;
    endfunction

    task run();
        fork
            mon_rx();
            mon_tx();
            mon_control_timing();
        join
    endtask

    task mon_rx();
        forever begin
            @(posedge uart_vif.rx_done);

            tr = new();
            tr.tx_data       = uart_vif.expected_rx_data;
            tr.rx_data       = uart_vif.rx_data;
            tr.loop_rx_data  = uart_vif.loop_rx_data;
            tr.rx_done       = uart_vif.rx_done;
            tr.loop_tx_start = uart_vif.loop_tx_start;
            tr.tx_busy       = uart_vif.tx_busy;
            tr.test_mode     = 0;

            mon2scb_mbox.put(tr);
        end
    endtask

    task mon_tx();

        logic [7:0] save_data;

        forever begin

            @(posedge uart_vif.tx_busy);

            // START 중앙 정렬
            repeat (8) @(posedge uart_vif.b_tick);

            // DATA 8bit 샘플링
            for (int i = 0; i < 8; i++) begin
                repeat (16) @(posedge uart_vif.b_tick);
                save_data[i] = uart_vif.tx;
            end

            // PARITY bit 지나가기
            repeat (16) @(posedge uart_vif.b_tick);

            // STOP bit 위치 이동
            repeat (16) @(posedge uart_vif.b_tick);

            tr = new();
            tr.saved_tx_data = save_data;
            tr.loop_rx_data  = uart_vif.loop_rx_data;

            // STOP bit 검증
            tr.tx_stop_ok = (uart_vif.tx == 1'b1);

            tr.tx_busy   = uart_vif.tx_busy;
            tr.rx_done   = uart_vif.rx_done;
            tr.rx_data   = uart_vif.rx_data;
            tr.test_mode = 1;

            mon2scb_mbox.put(tr);

        end

    endtask

    task mon_control_timing();
        forever begin
            @(posedge uart_vif.rx_done);

            $display("%t : [RX DONE ON]  | rx_done=%0d loop_tx_start=%0d tx_busy=%0d rx_data=%h",
                     $time,
                     uart_vif.rx_done,
                     uart_vif.loop_tx_start,
                     uart_vif.tx_busy,
                     uart_vif.rx_data);

            @(posedge uart_vif.tx_busy);

            $display("%t : [TX BUSY ON]  | rx_done=%0d loop_tx_start=%0d tx_busy=%0d loop_rx_data=%h",
                     $time,
                     uart_vif.rx_done,
                     uart_vif.loop_tx_start,
                     uart_vif.tx_busy,
                     uart_vif.loop_rx_data);

            @(negedge uart_vif.tx_busy);

            $display("%t : [TX BUSY OFF] | tx_busy=%0d TX succes",
                     $time,
                     uart_vif.tx_busy);
        end
    endtask
endclass


class scoreboard;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    event event_gen_next;
    int total_cnt = 0, pass_cnt = 0, fail_cnt = 0;

    function new(mailbox #(transaction) mon2scb_mbox, event event_gen_next);
        this.mon2scb_mbox = mon2scb_mbox;
        this.event_gen_next = event_gen_next;
    endfunction

    task run();
        forever begin
            mon2scb_mbox.get(tr);
            total_cnt++;
            if (tr.test_mode == 0) begin
                if (tr.tx_data == tr.rx_data) begin
                    pass_cnt++;
                    $display("%t : [RX PASS]     input_rx_data=%h dut_rx_data=%h",
                             $time, tr.tx_data, tr.rx_data);
                end else begin
                    fail_cnt++;
                    $display("%t : [RX FAIL] input_rx_data=%h dut_rx_data=%h",
                             $time, tr.tx_data, tr.rx_data);
                end
            end
            else begin
                if ((tr.loop_rx_data == tr.saved_tx_data) && tr.tx_stop_ok) begin
                    pass_cnt++;
                    $display("%t : [TX PASS]     loop_rx_data=%h saved_tx_data=%h tx_stop_ok=%0d",
                             $time, tr.loop_rx_data, tr.saved_tx_data, tr.tx_stop_ok);
                    $display("");
                end else begin
                    fail_cnt++;
                    $display("%t : [TX FAIL] loop_rx_data=%h saved_tx_data=%h tx_stop_ok=%0d",
                             $time, tr.loop_rx_data, tr.saved_tx_data, tr.tx_stop_ok);
                    $display("");
                end

                -> event_gen_next;
            end
        end
    endtask
endclass


class environment;
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) gen2drv_mbox;

    event event_gen_next;

    virtual uart_interface uart_vif;

    int run_count;

    function new(virtual uart_interface uart_vif);
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new(gen2drv_mbox, event_gen_next);
        drv = new(gen2drv_mbox, uart_vif);
        mon = new(mon2scb_mbox, uart_vif);
        scb = new(mon2scb_mbox, event_gen_next);

        this.uart_vif = uart_vif;
    endfunction

    task run();
        drv.preset();

        run_count = 6;

        fork
            mon.run();
            scb.run();
        join_none

        fork
            gen.run(run_count);
            drv.tx_test(run_count);
        join

        #1000;

        $display("  ******************************");
        $display("  *  | UART LOOPBACK TEST END |");
        $display("  ******************************");

        $display("   -------------------------");
        $display("   ** sram ip verfication **");
        $display("   ** total test num = %2d **", scb.total_cnt);
        $display("   ** pass  test num = %2d **", scb.pass_cnt);
        $display("   ** fail  test num = %2d **", scb.fail_cnt);
        $display("   **************************");
        $stop;
    endtask
endclass


module tb_uart_sv();

    uart_interface uart_if();
    environment env;

    uart_loopback_sv U_UART_LOOPBACK_SV(
        .clk(uart_if.clk),
        .rst(uart_if.rst),
        .rx (uart_if.rx),
        .tx (uart_if.tx)
    );

    assign uart_if.rx_data       = U_UART_LOOPBACK_SV.w_rx_data;
    assign uart_if.rx_done       = U_UART_LOOPBACK_SV.w_tx_start;
    assign uart_if.loop_tx_start = U_UART_LOOPBACK_SV.w_tx_start;
    assign uart_if.loop_rx_data  = U_UART_LOOPBACK_SV.w_rx_data;
    assign uart_if.tx_busy       = U_UART_LOOPBACK_SV.U_UART_TOP_SV.tx_busy;
    assign uart_if.b_tick        = U_UART_LOOPBACK_SV.U_UART_TOP_SV.w_b_tick;

    always #5 uart_if.clk = ~uart_if.clk;

    initial begin
        uart_if.clk = 0;
        env = new(uart_if);
        env.run();
    end

endmodule