`timescale 1ns/1ps

interface i2c_if(input logic clk);

    logic reset;

    logic cmd_start;
    logic cmd_write;
    logic cmd_read;
    logic cmd_stop;

    logic [7:0] master_tx_data;
    logic [7:0] master_rx_data;
    logic       ack_in;
    logic       ack_out;

    logic       master_busy;
    logic       master_done;

    logic [6:0] slave_addr;
    logic [7:0] slave_tx_data;
    logic [7:0] slave_rx_data;

    logic       slave_addr_match;
    logic       slave_rw_mode;
    logic       slave_master_ack;
    logic       slave_busy;
    logic       slave_done;

    clocking drv_cb @(posedge clk);
        output reset;
        output cmd_start;
        output cmd_write;
        output cmd_read;
        output cmd_stop;
        output master_tx_data;
        output ack_in;
        output slave_addr;
        output slave_tx_data;

        input master_done;
        input master_busy;
        input slave_done;
        input slave_busy;
    endclocking

    clocking mon_cb @(posedge clk);
        input reset;
        input cmd_start;
        input cmd_write;
        input cmd_read;
        input cmd_stop;

        input master_tx_data;
        input master_rx_data;
        input ack_in;
        input ack_out;
        input master_done;
        input master_busy;

        input slave_addr;
        input slave_tx_data;
        input slave_rx_data;
        input slave_addr_match;
        input slave_rw_mode;
        input slave_master_ack;
        input slave_done;
        input slave_busy;
    endclocking

endinterface


package i2c_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    class i2c_seq_item extends uvm_sequence_item;

        typedef enum int {
            I2C_WRITE,
            I2C_READ,
            I2C_WR_RD,
            I2C_WRONG_ADDR
        } i2c_op_e;

        rand i2c_op_e    op;
        rand logic [6:0] slave_addr;
        rand logic [6:0] wrong_addr;
        rand logic [7:0] write_data;
        rand logic [7:0] slave_tx_data;

        logic [7:0] master_rx_data;
        logic [7:0] slave_rx_data;
        logic       ack_out;
        logic       slave_addr_match;
        logic       slave_rw_mode;
        logic       slave_master_ack;

        constraint c_addr {
            slave_addr inside {[7'h01:7'h7E]};
            wrong_addr inside {[7'h01:7'h7E]};
            wrong_addr != slave_addr;
        }

        `uvm_object_utils_begin(i2c_seq_item)
            `uvm_field_enum(i2c_op_e, op, UVM_ALL_ON)
            `uvm_field_int(slave_addr,       UVM_ALL_ON)
            `uvm_field_int(wrong_addr,       UVM_ALL_ON)
            `uvm_field_int(write_data,       UVM_ALL_ON)
            `uvm_field_int(slave_tx_data,    UVM_ALL_ON)
            `uvm_field_int(master_rx_data,   UVM_ALL_ON)
            `uvm_field_int(slave_rx_data,    UVM_ALL_ON)
            `uvm_field_int(ack_out,          UVM_ALL_ON)
            `uvm_field_int(slave_addr_match, UVM_ALL_ON)
            `uvm_field_int(slave_rw_mode,    UVM_ALL_ON)
            `uvm_field_int(slave_master_ack, UVM_ALL_ON)
        `uvm_object_utils_end

        function new(string name = "i2c_seq_item");
            super.new(name);
        endfunction

        function string convert2string();
            return $sformatf(
                "op=%0d slave_addr=0x%02h wrong_addr=0x%02h write_data=0x%02h slave_tx_data=0x%02h master_rx=0x%02h slave_rx=0x%02h ack_out=%0b addr_match=%0b rw=%0b master_ack=%0b",
                op, slave_addr, wrong_addr, write_data, slave_tx_data,
                master_rx_data, slave_rx_data, ack_out,
                slave_addr_match, slave_rw_mode, slave_master_ack
            );
        endfunction

    endclass


    class i2c_base_seq extends uvm_sequence #(i2c_seq_item);
        `uvm_object_utils(i2c_base_seq)

        function new(string name = "i2c_base_seq");
            super.new(name);
        endfunction

        task do_write(logic [6:0] addr, logic [7:0] data);
            i2c_seq_item item;
            item = i2c_seq_item::type_id::create("item");

            start_item(item);
            item.op            = i2c_seq_item::I2C_WRITE;
            item.slave_addr    = addr;
            item.wrong_addr    = addr ^ 7'h01;
            item.write_data    = data;
            item.slave_tx_data = 8'h00;
            finish_item(item);
        endtask

        task do_read(logic [6:0] addr, logic [7:0] data);
            i2c_seq_item item;
            item = i2c_seq_item::type_id::create("item");

            start_item(item);
            item.op            = i2c_seq_item::I2C_READ;
            item.slave_addr    = addr;
            item.wrong_addr    = addr ^ 7'h01;
            item.write_data    = 8'h00;
            item.slave_tx_data = data;
            finish_item(item);
        endtask

        task do_wr_rd(logic [6:0] addr, logic [7:0] wdata, logic [7:0] rdata);
            i2c_seq_item item;
            item = i2c_seq_item::type_id::create("item");

            start_item(item);
            item.op            = i2c_seq_item::I2C_WR_RD;
            item.slave_addr    = addr;
            item.wrong_addr    = addr ^ 7'h01;
            item.write_data    = wdata;
            item.slave_tx_data = rdata;
            finish_item(item);
        endtask

        task do_wrong_addr(logic [6:0] addr, logic [6:0] wrong);
            i2c_seq_item item;
            item = i2c_seq_item::type_id::create("item");

            start_item(item);
            item.op            = i2c_seq_item::I2C_WRONG_ADDR;
            item.slave_addr    = addr;
            item.wrong_addr    = wrong;
            item.write_data    = 8'h55;
            item.slave_tx_data = 8'h00;
            finish_item(item);
        endtask

    endclass


    class i2c_basic_seq extends i2c_base_seq;
        `uvm_object_utils(i2c_basic_seq)

        function new(string name = "i2c_basic_seq");
            super.new(name);
        endfunction

        task body();
            `uvm_info(get_type_name(), "I2C basic sequence start", UVM_LOW)

            do_write(7'h50, 8'hA5);
            do_read (7'h50, 8'h3C);
            do_wr_rd(7'h50, 8'h5A, 8'hC3);
            do_wrong_addr(7'h50, 7'h51);

            `uvm_info(get_type_name(), "I2C basic sequence end", UVM_LOW)
        endtask
    endclass


    class i2c_driver extends uvm_driver #(i2c_seq_item);
        `uvm_component_utils(i2c_driver)

        virtual i2c_if i_if;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual i2c_if)::get(this, "", "i_if", i_if)) begin
                `uvm_fatal(get_type_name(), "virtual interface i_if not found")
            end
        endfunction

        task reset_bus();
            i_if.drv_cb.reset          <= 1'b1;
            i_if.drv_cb.cmd_start      <= 1'b0;
            i_if.drv_cb.cmd_write      <= 1'b0;
            i_if.drv_cb.cmd_read       <= 1'b0;
            i_if.drv_cb.cmd_stop       <= 1'b0;
            i_if.drv_cb.master_tx_data <= 8'd0;
            i_if.drv_cb.ack_in         <= 1'b1;
            i_if.drv_cb.slave_addr     <= 7'h50;
            i_if.drv_cb.slave_tx_data  <= 8'd0;

            repeat (10) @(i_if.drv_cb);
            i_if.drv_cb.reset <= 1'b0;
            repeat (5) @(i_if.drv_cb);
        endtask

        task clear_cmd();
            @(i_if.drv_cb);
            i_if.drv_cb.cmd_start <= 1'b0;
            i_if.drv_cb.cmd_write <= 1'b0;
            i_if.drv_cb.cmd_read  <= 1'b0;
            i_if.drv_cb.cmd_stop  <= 1'b0;
        endtask

        task wait_master_done();
            do begin
                @(i_if.drv_cb);
            end while (i_if.drv_cb.master_done !== 1'b1);

            @(i_if.drv_cb);
        endtask

        task send_start();
            @(i_if.drv_cb);
            i_if.drv_cb.cmd_start <= 1'b1;
            clear_cmd();
            wait_master_done();
        endtask

        task send_write(logic [7:0] data);
            @(i_if.drv_cb);
            i_if.drv_cb.master_tx_data <= data;
            i_if.drv_cb.cmd_write      <= 1'b1;
            clear_cmd();
            wait_master_done();
        endtask

        task send_read(logic ack_val);
            @(i_if.drv_cb);
            i_if.drv_cb.ack_in   <= ack_val;
            i_if.drv_cb.cmd_read <= 1'b1;
            clear_cmd();
            wait_master_done();
        endtask

        task send_stop();
            @(i_if.drv_cb);
            i_if.drv_cb.cmd_stop <= 1'b1;
            clear_cmd();
            wait_master_done();
        endtask

        task drive_write(i2c_seq_item tr);
            i_if.drv_cb.slave_addr    <= tr.slave_addr;
            i_if.drv_cb.slave_tx_data <= tr.slave_tx_data;

            send_start();
            send_write({tr.slave_addr, 1'b0});
            send_write(tr.write_data);
            send_stop();
        endtask

        task drive_read(i2c_seq_item tr);
            i_if.drv_cb.slave_addr    <= tr.slave_addr;
            i_if.drv_cb.slave_tx_data <= tr.slave_tx_data;

            send_start();
            send_write({tr.slave_addr, 1'b1});
            send_read(1'b1);
            send_stop();
        endtask

        task drive_wr_rd(i2c_seq_item tr);
            i_if.drv_cb.slave_addr    <= tr.slave_addr;
            i_if.drv_cb.slave_tx_data <= tr.slave_tx_data;

            send_start();
            send_write({tr.slave_addr, 1'b0});
            send_write(tr.write_data);
            send_stop();

            repeat (10) @(i_if.drv_cb);

            send_start();
            send_write({tr.slave_addr, 1'b1});
            send_read(1'b1);
            send_stop();
        endtask

        task drive_wrong_addr(i2c_seq_item tr);
            i_if.drv_cb.slave_addr    <= tr.slave_addr;
            i_if.drv_cb.slave_tx_data <= tr.slave_tx_data;

            send_start();
            send_write({tr.wrong_addr, 1'b0});
            send_stop();
        endtask

        task run_phase(uvm_phase phase);
            reset_bus();

            forever begin
                seq_item_port.get_next_item(req);

                `uvm_info(get_type_name(),
                    $sformatf("DRIVE: %s", req.convert2string()),
                    UVM_MEDIUM)

                case (req.op)
                    i2c_seq_item::I2C_WRITE:      drive_write(req);
                    i2c_seq_item::I2C_READ:       drive_read(req);
                    i2c_seq_item::I2C_WR_RD:      drive_wr_rd(req);
                    i2c_seq_item::I2C_WRONG_ADDR: drive_wrong_addr(req);
                    default:                      drive_write(req);
                endcase

                seq_item_port.item_done();
            end
        endtask

    endclass


    class i2c_monitor extends uvm_monitor;
        `uvm_component_utils(i2c_monitor)

        virtual i2c_if i_if;
        uvm_analysis_port #(i2c_seq_item) ap;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            ap = new("ap", this);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual i2c_if)::get(this, "", "i_if", i_if)) begin
                `uvm_fatal(get_type_name(), "virtual interface i_if not found")
            end
        endfunction

        task run_phase(uvm_phase phase);
            i2c_seq_item tr;

            forever begin
                @(i_if.mon_cb);

                if (i_if.mon_cb.master_done) begin
                    tr = i2c_seq_item::type_id::create("tr");

                    tr.slave_addr       = i_if.mon_cb.slave_addr;
                    tr.write_data       = i_if.mon_cb.master_tx_data;
                    tr.slave_tx_data    = i_if.mon_cb.slave_tx_data;
                    tr.master_rx_data   = i_if.mon_cb.master_rx_data;
                    tr.slave_rx_data    = i_if.mon_cb.slave_rx_data;
                    tr.ack_out          = i_if.mon_cb.ack_out;
                    tr.slave_addr_match = i_if.mon_cb.slave_addr_match;
                    tr.slave_rw_mode    = i_if.mon_cb.slave_rw_mode;
                    tr.slave_master_ack = i_if.mon_cb.slave_master_ack;

                    ap.write(tr);
                end
            end
        endtask

    endclass


    class i2c_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(i2c_scoreboard)

        uvm_analysis_imp #(i2c_seq_item, i2c_scoreboard) imp;

        int pass_count = 0;
        int fail_count = 0;
        int check_count = 0;

        function new(string name, uvm_component parent);
            super.new(name, parent);
            imp = new("imp", this);
        endfunction

        function void check_pass(string msg);
            pass_count++;
            check_count++;
            `uvm_info(get_type_name(), {"PASS: ", msg}, UVM_LOW)
        endfunction

        function void check_fail(string msg);
            fail_count++;
            check_count++;
            `uvm_error(get_type_name(), {"FAIL: ", msg})
        endfunction

        function void write(i2c_seq_item tr);

            if (tr.slave_addr_match && tr.slave_rw_mode == 1'b0) begin
                if (tr.ack_out === 1'b0)
                    check_pass("WRITE ACK received");
                else
                    check_fail("WRITE expected ACK=0");

                if (tr.slave_rx_data === tr.write_data)
                    check_pass($sformatf("WRITE data matched: 0x%02h", tr.write_data));
                else
                    check_fail($sformatf("WRITE data mismatch exp=0x%02h got=0x%02h",
                                         tr.write_data, tr.slave_rx_data));
            end

            if (tr.slave_addr_match && tr.slave_rw_mode == 1'b1) begin
                if (tr.master_rx_data === tr.slave_tx_data)
                    check_pass($sformatf("READ data matched: 0x%02h", tr.slave_tx_data));
                else
                    check_fail($sformatf("READ data mismatch exp=0x%02h got=0x%02h",
                                         tr.slave_tx_data, tr.master_rx_data));

                if (tr.slave_master_ack === 1'b1)
                    check_pass("READ final NACK checked");
                else
                    check_fail("READ expected final NACK=1");
            end

            if (!tr.slave_addr_match) begin
                if (tr.ack_out === 1'b1)
                    check_pass("Wrong address NACK checked");
                else
                    check_fail("Wrong address expected NACK=1");
            end
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);

            `uvm_info("SCB", "==============================", UVM_LOW)
            `uvm_info("SCB", "I2C SCOREBOARD FINAL REPORT", UVM_LOW)
            `uvm_info("SCB", $sformatf("CHECK COUNT : %0d", check_count), UVM_LOW)
            `uvm_info("SCB", $sformatf("PASS COUNT  : %0d", pass_count), UVM_LOW)
            `uvm_info("SCB", $sformatf("FAIL COUNT  : %0d", fail_count), UVM_LOW)
            `uvm_info("SCB", "==============================", UVM_LOW)
        endfunction

    endclass


    class i2c_coverage extends uvm_subscriber #(i2c_seq_item);
        `uvm_component_utils(i2c_coverage)

        i2c_seq_item tr;

        covergroup i2c_cg;
            option.per_instance = 1;

            cp_ack : coverpoint tr.ack_out {
                bins ack  = {0};
                bins nack = {1};
            }

            cp_addr_match : coverpoint tr.slave_addr_match {
                bins miss  = {0};
                bins match = {1};
            }

            cp_rw : coverpoint tr.slave_rw_mode {
                bins write = {0};
                bins read  = {1};
            }

            cp_data : coverpoint tr.write_data {
                bins zero = {8'h00};
                bins max  = {8'hFF};
                bins etc  = {[8'h01:8'hFE]};
            }

            cx_ack_rw : cross cp_ack, cp_rw;
        endgroup

        function new(string name, uvm_component parent);
            super.new(name, parent);
            i2c_cg = new();
        endfunction

        function void write(i2c_seq_item t);
            tr = t;
            i2c_cg.sample();
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);

            `uvm_info("COV", "==============================", UVM_LOW)
            `uvm_info("COV", $sformatf("I2C COVERAGE : %6.2f %%", i2c_cg.get_inst_coverage()), UVM_LOW)
            `uvm_info("COV", "==============================", UVM_LOW)
        endfunction

    endclass


    class i2c_agent extends uvm_agent;
        `uvm_component_utils(i2c_agent)

        uvm_sequencer #(i2c_seq_item) sqr;
        i2c_driver                    drv;
        i2c_monitor                   mon;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            sqr = uvm_sequencer#(i2c_seq_item)::type_id::create("sqr", this);
            drv = i2c_driver::type_id::create("drv", this);
            mon = i2c_monitor::type_id::create("mon", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction

    endclass


    class i2c_env extends uvm_env;
        `uvm_component_utils(i2c_env)

        i2c_agent      agt;
        i2c_scoreboard scb;
        i2c_coverage   cov;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);

            agt = i2c_agent::type_id::create("agt", this);
            scb = i2c_scoreboard::type_id::create("scb", this);
            cov = i2c_coverage::type_id::create("cov", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);

            agt.mon.ap.connect(scb.imp);
            agt.mon.ap.connect(cov.analysis_export);
        endfunction

    endclass


    class i2c_base_test extends uvm_test;
        `uvm_component_utils(i2c_base_test)

        i2c_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = i2c_env::type_id::create("env", this);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            uvm_top.print_topology();
        endfunction
    endclass


    class i2c_basic_test extends i2c_base_test;
        `uvm_component_utils(i2c_basic_test)

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            i2c_basic_seq seq;

            phase.raise_objection(this);

            seq = i2c_basic_seq::type_id::create("seq");
            seq.start(env.agt.sqr);

            #1000;
            phase.drop_objection(this);
        endtask
    endclass

endpackage


import uvm_pkg::*;
import i2c_pkg::*;

module tb_top;

    logic clk;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    i2c_if i_if(.clk(clk));

    top_i2c dut(
        .clk              (clk),
        .reset            (i_if.reset),

        .cmd_start        (i_if.cmd_start),
        .cmd_write        (i_if.cmd_write),
        .cmd_read         (i_if.cmd_read),
        .cmd_stop         (i_if.cmd_stop),

        .master_tx_data   (i_if.master_tx_data),
        .master_rx_data   (i_if.master_rx_data),
        .ack_in           (i_if.ack_in),
        .ack_out          (i_if.ack_out),

        .master_busy      (i_if.master_busy),
        .master_done      (i_if.master_done),

        .slave_addr       (i_if.slave_addr),
        .slave_tx_data    (i_if.slave_tx_data),
        .slave_rx_data    (i_if.slave_rx_data),

        .slave_addr_match (i_if.slave_addr_match),
        .slave_rw_mode    (i_if.slave_rw_mode),
        .slave_master_ack (i_if.slave_master_ack),
        .slave_busy       (i_if.slave_busy),
        .slave_done       (i_if.slave_done)
    );

    initial begin
        uvm_config_db#(virtual i2c_if)::set(null, "*", "i_if", i_if);
        run_test("i2c_basic_test");
    end

    initial begin
        $fsdbDumpfile("i2c_tb.fsdb");
        $fsdbDumpvars(0);
    end

endmodule