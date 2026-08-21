`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*;



interface spi_if(input logic clk, input logic reset);
    logic       start;
    logic [7:0] master_tx_data;
    logic [7:0] slave_tx_data;
    logic [7:0] master_rx_data;
    logic [7:0] slave_rx_data;
    logic       master_busy;
    logic       slave_busy;
    logic       master_done;
    logic       slave_done;
endinterface



class spi_seq_item extends uvm_sequence_item;

    rand logic [7:0] master_tx_data;
    rand logic [7:0] slave_tx_data;

    logic [7:0] master_rx_data;
    logic [7:0] slave_rx_data;

    logic master_busy;
    logic slave_busy;
    logic master_done;
    logic slave_done;

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf(
            "M_TX=%02h S_TX=%02h | M_RX=%02h S_RX=%02h | MASTER: busy=%0b done=%0b | SLAVE: busy=%0b done=%0b",
            master_tx_data,
            slave_tx_data,
            master_rx_data,
            slave_rx_data,
            master_busy,
            master_done,
            slave_busy,
            slave_done
        );
    endfunction

    `uvm_object_utils_begin(spi_seq_item)
        `uvm_field_int(master_tx_data , UVM_ALL_ON)
        `uvm_field_int(slave_tx_data  , UVM_ALL_ON)
        `uvm_field_int(master_rx_data , UVM_ALL_ON)
        `uvm_field_int(slave_rx_data  , UVM_ALL_ON)
        `uvm_field_int(master_busy    , UVM_ALL_ON)
        `uvm_field_int(slave_busy     , UVM_ALL_ON)
        `uvm_field_int(master_done    , UVM_ALL_ON)
        `uvm_field_int(slave_done     , UVM_ALL_ON)
    `uvm_object_utils_end

endclass



class spi_sequence extends uvm_sequence #(spi_seq_item);
    `uvm_object_utils(spi_sequence)

    function new(string name = "spi_sequence");
        super.new(name);
    endfunction

    task body();
        spi_seq_item item;

        logic [7:0] m_patterns[$] = '{8'hAA, 8'h55, 8'h00, 8'hFF, 8'h0F, 8'hF0, 8'hA5, 8'h5A};
        logic [7:0] s_patterns[$] = '{8'h11, 8'h22, 8'h33, 8'h44, 8'h55, 8'h66, 8'h77, 8'h88};

        foreach (m_patterns[i]) begin
            item = spi_seq_item::type_id::create("item");
            start_item(item);
            item.master_tx_data = m_patterns[i];
            item.slave_tx_data  = s_patterns[i];
            finish_item(item);
        end

        repeat (30) begin
            item = spi_seq_item::type_id::create("item");
            start_item(item);
            assert(item.randomize());
            finish_item(item);
        end
    endtask

endclass



class spi_driver extends uvm_driver #(spi_seq_item);
    `uvm_component_utils(spi_driver)

    virtual spi_if vif;

    function new(string name, uvm_component c);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual spi_if)::get(this, "", "a_if", vif)) begin
            `uvm_fatal("DRV", "virtual interface get failed")
        end
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item req;

        vif.start          <= 1'b0;
        vif.master_tx_data <= 8'd0;
        vif.slave_tx_data  <= 8'd0;

        wait(vif.reset == 1'b0);
        repeat (5) @(posedge vif.clk);

        forever begin
            seq_item_port.get_next_item(req);

            wait(vif.master_busy == 1'b0);
            @(posedge vif.clk);

            vif.master_tx_data <= req.master_tx_data;
            vif.slave_tx_data  <= req.slave_tx_data;

            @(posedge vif.clk);
            vif.start <= 1'b1;

            @(posedge vif.clk);
            vif.start <= 1'b0;

            wait(vif.master_done == 1'b1);
            @(posedge vif.clk);

            seq_item_port.item_done();
        end
    endtask

endclass



class spi_monitor extends uvm_monitor;
    `uvm_component_utils(spi_monitor)

    virtual spi_if vif;
    uvm_analysis_port #(spi_seq_item) ap;

    function new(string name, uvm_component c);
        super.new(name, c);
        ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual spi_if)::get(this, "", "a_if", vif)) begin
            `uvm_fatal("MON", "virtual interface get failed")
        end
    endfunction

    task run_phase(uvm_phase phase);
        spi_seq_item item;

        wait(vif.reset == 1'b0);

        forever begin
            @(posedge vif.clk);

            if (vif.start) begin

                // start를 본 같은 posedge에서 RTL의 busy/ss_n은 NBA로 갱신됨
                // 그래서 #1 후에 찍어야 busy=1, slave_busy=1이 보임
                #1;

                `uvm_info("MON", $sformatf(
                    "TRANSFER START | M_TX=%02h S_TX=%02h | MASTER: busy=%0b done=%0b | SLAVE: busy=%0b done=%0b",
                    vif.master_tx_data,
                    vif.slave_tx_data,
                    vif.master_busy,
                    vif.master_done,
                    vif.slave_busy,
                    vif.slave_done
                ), UVM_LOW)

                @(posedge vif.clk);

                while (!vif.master_done) begin
                    if (vif.master_busy !== 1'b1) begin
                        `uvm_error("MON", "During transfer, master_busy should be 1")
                    end

                    if (vif.master_done !== 1'b0) begin
                        `uvm_error("MON", "During transfer, master_done should be 0")
                    end

                    if (vif.slave_busy !== 1'b1) begin
                        `uvm_error("MON", "During transfer, slave_busy should be 1")
                    end

                    @(posedge vif.clk);
                end

                // master_done이 1 된 시점의 값 저장
                item = spi_seq_item::type_id::create("item");

                item.master_tx_data = vif.master_tx_data;
                item.slave_tx_data  = vif.slave_tx_data;
                item.master_rx_data = vif.master_rx_data;
                item.slave_rx_data  = vif.slave_rx_data;

                item.master_busy    = vif.master_busy;
                item.master_done    = vif.master_done;
                item.slave_busy     = vif.slave_busy;
                item.slave_done     = vif.slave_done;

                `uvm_info("MON", $sformatf(
                    "TRANSFER DONE  | %s",
                    item.convert2string()
                ), UVM_LOW)

                ap.write(item);
            end
        end
    endtask

endclass



class spi_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(spi_scoreboard)

    uvm_analysis_imp #(spi_seq_item, spi_scoreboard) imp;

    int pass_count;
    int fail_count;

    function new(string name, uvm_component c);
        super.new(name, c);
        imp = new("imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        pass_count = 0;
        fail_count = 0;
    endfunction

    function void write(spi_seq_item item);
        bit pass_mosi;
        bit pass_miso;
        bit pass_master_status;
        bit pass_slave_status;

        pass_mosi = (item.slave_rx_data  == item.master_tx_data);
        pass_miso = (item.master_rx_data == item.slave_tx_data);

        pass_master_status = (item.master_busy == 1'b0) &&
                             (item.master_done == 1'b1);

        pass_slave_status  = (item.slave_busy == 1'b0);

        if (pass_mosi && pass_miso && pass_master_status && pass_slave_status) begin
            pass_count++;

            `uvm_info("SCB", $sformatf(
                "PASS | MOSI: M_TX=%02h S_RX=%02h | MISO: S_TX=%02h M_RX=%02h | MASTER: busy=%0b done=%0b | SLAVE: busy=%0b done=%0b",
                item.master_tx_data,
                item.slave_rx_data,
                item.slave_tx_data,
                item.master_rx_data,
                item.master_busy,
                item.master_done,
                item.slave_busy,
                item.slave_done
            ), UVM_LOW)
        end else begin
            fail_count++;

            `uvm_error("SCB", $sformatf(
                "FAIL | MOSI: M_TX=%02h S_RX=%02h | MISO: S_TX=%02h M_RX=%02h | MASTER: busy=%0b done=%0b | SLAVE: busy=%0b done=%0b",
                item.master_tx_data,
                item.slave_rx_data,
                item.slave_tx_data,
                item.master_rx_data,
                item.master_busy,
                item.master_done,
                item.slave_busy,
                item.slave_done
            ))
        end

        `uvm_info("===================================================", "", UVM_LOW)
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("SCB", "================================", UVM_LOW)
        `uvm_info("SCB", "=== SPI TRANSFER FINAL REPORT ===", UVM_LOW)
        `uvm_info("SCB", $sformatf("PASS count : %0d", pass_count), UVM_LOW)
        `uvm_info("SCB", $sformatf("FAIL count : %0d", fail_count), UVM_LOW)
        `uvm_info("SCB", "================================", UVM_LOW)
    endfunction

endclass


class spi_agent extends uvm_agent;
    `uvm_component_utils(spi_agent)

    uvm_sequencer #(spi_seq_item) sqr;
    spi_driver                  drv;
    spi_monitor                 mon;

    function new(string name, uvm_component c);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        sqr = uvm_sequencer#(spi_seq_item)::type_id::create("sqr", this);
        drv = spi_driver::type_id::create("drv", this);
        mon = spi_monitor::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction

endclass


class spi_env extends uvm_env;
    `uvm_component_utils(spi_env)

    spi_agent      agt;
    spi_scoreboard scb;

    function new(string name, uvm_component c);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agt = spi_agent::type_id::create("agt", this);
        scb = spi_scoreboard::type_id::create("scb", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agt.mon.ap.connect(scb.imp);
    endfunction

endclass


class spi_test extends uvm_test;
    `uvm_component_utils(spi_test)

    spi_env env;

    function new(string name, uvm_component c);
        super.new(name, c);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = spi_env::type_id::create("env", this);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);
        spi_sequence seq;

        phase.raise_objection(this);

        seq = spi_sequence::type_id::create("seq");
        seq.start(env.agt.sqr);

        #1000;

        phase.drop_objection(this);
    endtask

endclass


module tb_top_spi_loopback();

    logic clk;
    logic reset;

    spi_if a_if (
        .clk   (clk),
        .reset (reset)
    );

    top_spi_loopback dut (
        .clk            (clk),
        .reset          (reset),

        .start          (a_if.start),
        .master_tx_data (a_if.master_tx_data),
        .slave_tx_data  (a_if.slave_tx_data),

        .master_rx_data (a_if.master_rx_data),
        .slave_rx_data  (a_if.slave_rx_data),

        .master_busy    (a_if.master_busy),
        .slave_busy     (a_if.slave_busy),
        .master_done    (a_if.master_done),
        .slave_done     (a_if.slave_done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
    end

    initial begin
        reset = 1'b1;

        a_if.start          = 1'b0;
        a_if.master_tx_data = 8'd0;
        a_if.slave_tx_data  = 8'd0;

        #100;
        reset = 1'b0;
    end

    initial begin
        uvm_config_db#(virtual spi_if)::set(null, "*", "a_if", a_if);
        run_test("spi_test");
    end

    initial begin
        $fsdbDumpfile("wave.fsdb");
        $fsdbDumpvars(0, tb_top_spi_loopback);
        $fsdbDumpvars(0, tb_top_spi_loopback.dut.u_spi_master);
        $fsdbDumpvars(0, tb_top_spi_loopback.dut.u_spi_slave);
    end

endmodule