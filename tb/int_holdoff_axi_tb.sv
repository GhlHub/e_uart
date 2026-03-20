`timescale 1ns / 1ps

module int_holdoff_axi_tb;

localparam int AXI_CLK_HZ = 50_000_000;
localparam int BAUD_RATE = 115_200;
localparam int BAUD_CLK_CNT = ((AXI_CLK_HZ + (BAUD_RATE / 2)) / BAUD_RATE) - 1;
localparam int CLK_PERIOD_NS = 20;

localparam int REG_INT_STAT = 32'h0000_0010;
localparam int REG_INT_MASK = 32'h0000_0014;
localparam int REG_CTRL = 32'h0000_0018;
localparam int REG_BAUD = 32'h0000_0020;
localparam int REG_HOLDOFF = 32'h0000_0028;
localparam int REG_TX_BYTE = 32'h0000_0000;
localparam int REG_TX_WORD = 32'h0000_0004;
localparam int REG_RX_BYTE = 32'h0000_0008;
localparam int REG_RX_WORD = 32'h0000_000C;
localparam logic [1:0] AXI_READ_STATE_RADDR = 2'b10;

localparam int INT_RX_TIME = 16;
localparam int INT_RX_BYTES = 8;

reg clk;
reg rst;

reg [5:0] s_axi_awaddr;
reg [2:0] s_axi_awprot;
reg s_axi_awvalid;
wire s_axi_awready;
reg [31:0] s_axi_wdata;
reg [3:0] s_axi_wstrb;
reg s_axi_wvalid;
wire s_axi_wready;
wire [1:0] s_axi_bresp;
wire s_axi_bvalid;
reg s_axi_bready;
reg [5:0] s_axi_araddr;
reg [2:0] s_axi_arprot;
reg s_axi_arvalid;
wire s_axi_arready;
wire [31:0] s_axi_rdata;
wire [1:0] s_axi_rresp;
wire s_axi_rvalid;
reg s_axi_rready;

wire [12:0] baud_clk_cnt;
wire [9:0] over_sample_clk_cnt;
wire [10:0] rx_int_holdoff_byte_time_cnt;
wire [10:0] rx_int_holdoff_byte_cnt;
wire tx_en;
wire [7:0] tx_byte_host;
wire tx_byte_host_dv;
wire rx_en;
reg [7:0] rx_byte_host;
reg rx_byte_host_dv;
wire rx_byte_host_rd;
reg [10:0] tx_byte_count;
reg [10:0] rx_byte_count;
wire intr;

reg rx_empty;
wire rx_time_coal_intr;
wire rx_byte_cnt_coal_intr;
wire [4:0] int_status;

int checks_run;
int checks_failed;
byte unsigned tx_observed[$];
byte unsigned rx_feed_queue[$];
int rx_rd_pulse_count;

assign int_status = {rx_time_coal_intr, rx_byte_cnt_coal_intr, 3'b000};

function automatic int sim_time_ns;
begin
    sim_time_ns = $rtoi($realtime + 0.5);
end
endfunction

task automatic log_info;
    input string message;
begin
    $display("[t=%0d ns] %s", sim_time_ns(), message);
end
endtask

task automatic check;
    input bit condition;
    input string message;
begin
    checks_run = checks_run + 1;
    if (!condition) begin
        checks_failed = checks_failed + 1;
        $display("[t=%0d ns] FAIL: %s", sim_time_ns(), message);
    end
end
endtask

always #(CLK_PERIOD_NS / 2) clk = ~clk;

always @(posedge clk) begin
    if (tx_byte_host_dv) begin
        tx_observed.push_back(tx_byte_host);
    end
end

always @(posedge clk) begin
    if (rx_byte_host_rd) begin
        rx_rd_pulse_count = rx_rd_pulse_count + 1;
        if (rx_feed_queue.size() != 0) begin
            rx_byte_host <= rx_feed_queue.pop_front();
        end
    end
end

e_uart_slave_lite_v1_0_S00_AXI dut_axi(
    .baud_clk_cnt                (baud_clk_cnt),
    .over_sample_clk_cnt         (over_sample_clk_cnt),
    .rx_int_holdoff_byte_time_cnt(rx_int_holdoff_byte_time_cnt),
    .rx_int_holdoff_byte_cnt     (rx_int_holdoff_byte_cnt),
    .tx_en                       (tx_en),
    .tx_byte_host                (tx_byte_host),
    .tx_byte_host_dv             (tx_byte_host_dv),
    .rx_en                       (rx_en),
    .rx_byte_host                (rx_byte_host),
    .rx_byte_host_dv             (rx_byte_host_dv),
    .rx_byte_host_rd             (rx_byte_host_rd),
    .tx_byte_count               (tx_byte_count),
    .rx_byte_count               (rx_byte_count),
    .int_status                  (int_status),
    .S_AXI_ACLK                  (clk),
    .S_AXI_ARESETN               (~rst),
    .S_AXI_AWADDR                (s_axi_awaddr),
    .S_AXI_AWPROT                (s_axi_awprot),
    .S_AXI_AWVALID               (s_axi_awvalid),
    .S_AXI_AWREADY               (s_axi_awready),
    .S_AXI_WDATA                 (s_axi_wdata),
    .S_AXI_WSTRB                 (s_axi_wstrb),
    .S_AXI_WVALID                (s_axi_wvalid),
    .S_AXI_WREADY                (s_axi_wready),
    .S_AXI_BRESP                 (s_axi_bresp),
    .S_AXI_BVALID                (s_axi_bvalid),
    .S_AXI_BREADY                (s_axi_bready),
    .S_AXI_ARADDR                (s_axi_araddr),
    .S_AXI_ARPROT                (s_axi_arprot),
    .S_AXI_ARVALID               (s_axi_arvalid),
    .S_AXI_ARREADY               (s_axi_arready),
    .S_AXI_RDATA                 (s_axi_rdata),
    .S_AXI_RRESP                 (s_axi_rresp),
    .S_AXI_RVALID                (s_axi_rvalid),
    .S_AXI_RREADY                (s_axi_rready),
    .intr                        (intr)
);

int_holdoff dut_holdoff(
    .clk                         (clk),
    .rst                         (rst),
    .baud_clk_cnt                (baud_clk_cnt),
    .rx_int_holdoff_byte_time_cnt(rx_int_holdoff_byte_time_cnt),
    .rx_int_holdoff_byte_cnt     (rx_int_holdoff_byte_cnt),
    .rx_empty                    (rx_empty),
    .rx_byte_count               (rx_byte_count),
    .rx_time_coal_intr           (rx_time_coal_intr),
    .rx_byte_cnt_coal_intr       (rx_byte_cnt_coal_intr)
);

task automatic step;
begin
    @(posedge clk);
    #1;
end
endtask

task automatic reset_bus_master;
begin
    s_axi_awaddr = 6'd0;
    s_axi_awprot = 3'd0;
    s_axi_awvalid = 1'b0;
    s_axi_wdata = 32'd0;
    s_axi_wstrb = 4'h0;
    s_axi_wvalid = 1'b0;
    s_axi_bready = 1'b0;
    s_axi_araddr = 6'd0;
    s_axi_arprot = 3'd0;
    s_axi_arvalid = 1'b0;
    s_axi_rready = 1'b0;
end
endtask

task automatic reset_dut;
begin
    rst = 1'b1;
    reset_bus_master();
    rx_empty = 1'b1;
    rx_byte_count = 11'd0;
    tx_byte_count = 11'd0;
    rx_byte_host = 8'h00;
    rx_byte_host_dv = 1'b0;
    tx_observed.delete();
    rx_feed_queue.delete();
    rx_rd_pulse_count = 0;
    repeat (4) step();
    @(negedge clk);
    rst = 1'b0;
    step();
end
endtask

task automatic clear_tx_observed;
begin
    tx_observed.delete();
end
endtask

task automatic clear_rx_feed;
begin
    rx_feed_queue.delete();
    rx_rd_pulse_count = 0;
end
endtask

task automatic set_rx_fifo;
    input bit next_rx_empty;
    input int next_rx_byte_count;
begin
    @(negedge clk);
    rx_empty = next_rx_empty;
    rx_byte_count = next_rx_byte_count[10:0];
end
endtask

task automatic axi_write;
    input [5:0] addr;
    input [31:0] data;
    bit b_seen;
    int timeout;
begin
    b_seen = 1'b0;

    @(negedge clk);
    s_axi_awaddr = addr;
    s_axi_awprot = 3'd0;
    s_axi_awvalid = 1'b1;
    s_axi_bready = 1'b0;

    for (timeout = 0; timeout < 64; timeout = timeout + 1) begin
        step();
        if (dut_axi.axi_awaddr_valid) begin
            s_axi_awvalid = 1'b0;
            break;
        end
    end

    if (!dut_axi.axi_awaddr_valid) begin
        checks_failed = checks_failed + 1;
        $display("[t=%0d ns] FAIL: AXI write address capture timeout for addr 0x%02h", sim_time_ns(), addr);
        $fatal(1);
    end

    @(negedge clk);
    s_axi_wdata = data;
    s_axi_wstrb = 4'hF;
    s_axi_wvalid = 1'b1;

    for (timeout = 0; timeout < 64; timeout = timeout + 1) begin
        step();
        if (dut_axi.axi_wdata_valid) begin
            s_axi_wvalid = 1'b0;
            break;
        end
    end

    if (!dut_axi.axi_wdata_valid) begin
        checks_failed = checks_failed + 1;
        $display("[t=%0d ns] FAIL: AXI write data capture timeout for addr 0x%02h", sim_time_ns(), addr);
        $fatal(1);
    end

    for (timeout = 0; timeout < 64; timeout = timeout + 1) begin
        step();
        if (s_axi_bvalid) begin
            b_seen = 1'b1;
            @(negedge clk);
            s_axi_bready = 1'b1;
            step();
            s_axi_bready = 1'b0;
            break;
        end
    end

    if (!b_seen) begin
        checks_failed = checks_failed + 1;
        $display("[t=%0d ns] FAIL: AXI write response timeout for addr 0x%02h", sim_time_ns(), addr);
        $display("[t=%0d ns] DEBUG: awready=%0b wready=%0b bvalid=%0b awaddr_valid=%0b wdata_valid=%0b slv_reg_wren=%0b write_index=0x%0h",
                 sim_time_ns(),
                 dut_axi.axi_awready,
                 dut_axi.axi_wready,
                 dut_axi.axi_bvalid,
                 dut_axi.axi_awaddr_valid,
                 dut_axi.axi_wdata_valid,
                 dut_axi.slv_reg_wren,
                 dut_axi.write_index);
        $fatal(1);
    end
end
endtask

task automatic axi_read;
    input [5:0] addr;
    output [31:0] data;
    bit r_seen;
    int timeout;
begin
    data = 32'h0;
    r_seen = 1'b0;

    @(negedge clk);
    s_axi_araddr = addr;
    s_axi_arprot = 3'd0;
    s_axi_arvalid = 1'b1;
    s_axi_rready = 1'b0;

    for (timeout = 0; timeout < 64; timeout = timeout + 1) begin
        step();
        if (dut_axi.read_state != AXI_READ_STATE_RADDR) begin
            s_axi_arvalid = 1'b0;
            break;
        end
    end

    if (dut_axi.read_state == AXI_READ_STATE_RADDR) begin
        checks_failed = checks_failed + 1;
        $display("[t=%0d ns] FAIL: AXI read address timeout for addr 0x%02h", sim_time_ns(), addr);
        $display("[t=%0d ns] DEBUG: arready=%0b rvalid=%0b read_state=0x%0h bvalid=%0b",
                 sim_time_ns(),
                 dut_axi.axi_arready,
                 dut_axi.axi_rvalid,
                 dut_axi.read_state,
                 dut_axi.axi_bvalid);
        $fatal(1);
    end

    for (timeout = 0; timeout < 64; timeout = timeout + 1) begin
        step();
        if (s_axi_rvalid) begin
            r_seen = 1'b1;
            data = s_axi_rdata;
            @(negedge clk);
            s_axi_rready = 1'b1;
            step();
            s_axi_rready = 1'b0;
            break;
        end
    end

    if (!r_seen) begin
        checks_failed = checks_failed + 1;
        $display("[t=%0d ns] FAIL: AXI read data timeout for addr 0x%02h", sim_time_ns(), addr);
        $fatal(1);
    end
end
endtask

task automatic program_holdoff;
    input int byte_threshold;
    input int time_threshold;
    input int mask_bits;
    reg [31:0] readback;
    reg [31:0] expected_holdoff;
begin
    expected_holdoff = ((byte_threshold & 'h7ff) << 16) | (time_threshold & 'h7ff);

    axi_write(REG_BAUD[5:0], BAUD_CLK_CNT[31:0]);
    axi_write(REG_HOLDOFF[5:0], expected_holdoff);
    axi_write(REG_INT_MASK[5:0], mask_bits[31:0]);

    axi_read(REG_BAUD[5:0], readback);
    check(readback[12:0] == BAUD_CLK_CNT[12:0], "AXI readback matches programmed baud counter");

    axi_read(REG_HOLDOFF[5:0], readback);
    check(readback == expected_holdoff, "AXI readback matches programmed holdoff register");

    axi_read(REG_INT_MASK[5:0], readback);
    check(readback[4:0] == mask_bits[4:0], "AXI readback matches programmed interrupt mask");
end
endtask

task automatic wait_for_tx_observed_count;
    input int expected_count;
    input string phase_name;
    int timeout;
begin
    for (timeout = 0; timeout < 16; timeout = timeout + 1) begin
        if (tx_observed.size() == expected_count) begin
            return;
        end
        step();
    end

    checks_failed = checks_failed + 1;
    $display("[t=%0d ns] FAIL: timed out waiting for %0d TX bytes during %s (saw %0d)",
             sim_time_ns(), expected_count, phase_name, tx_observed.size());
    $fatal(1);
end
endtask

task automatic wait_for_rx_rd_pulses;
    input int expected_count;
    input string phase_name;
    int timeout;
begin
    for (timeout = 0; timeout < 16; timeout = timeout + 1) begin
        if (rx_rd_pulse_count == expected_count) begin
            return;
        end
        step();
    end

    checks_failed = checks_failed + 1;
    $display("[t=%0d ns] FAIL: timed out waiting for %0d RX read pulses during %s (saw %0d)",
             sim_time_ns(), expected_count, phase_name, rx_rd_pulse_count);
    $fatal(1);
end
endtask

task automatic wait_for_byte_time_count;
    input int target_count;
    input string phase_name;
    int timeout;
begin : wait_loop
    for (timeout = 0; timeout < ((BAUD_CLK_CNT + 1) * 16); timeout = timeout + 1) begin
        if (dut_holdoff.byte_time_cntr == target_count[10:0]) begin
            disable wait_loop;
        end
        step();
    end

    checks_failed = checks_failed + 1;
    $display("[t=%0d ns] FAIL: timed out waiting for byte_time_cntr=%0d during %s",
             sim_time_ns(), target_count, phase_name);
    $fatal(1);
end
endtask

task automatic wait_for_intr_high;
    input string phase_name;
    int timeout;
begin
    for (timeout = 0; timeout < 8; timeout = timeout + 1) begin
        if (intr) begin
            return;
        end
        step();
    end

    checks_failed = checks_failed + 1;
    $display("[t=%0d ns] FAIL: timed out waiting for intr during %s",
             sim_time_ns(), phase_name);
    $fatal(1);
end
endtask

task automatic test_axi_programming_readback;
    reg [31:0] readback;
begin
    log_info("Running test_axi_programming_readback");

    reset_dut();
    program_holdoff(5, 3, INT_RX_TIME | INT_RX_BYTES);

    axi_read(REG_INT_STAT[5:0], readback);
    check(readback[4:0] == 5'b0, "interrupt status is clear after reset and before RX activity");
    check(!intr, "interrupt output is low before RX activity");
end
endtask

task automatic test_axi_tx_fifo_byte_write;
    reg [31:0] readback;
begin
    log_info("Running test_axi_tx_fifo_byte_write");

    reset_dut();
    clear_tx_observed();

    axi_write(REG_TX_BYTE[5:0], 32'h0000_00A5);
    wait_for_tx_observed_count(1, "AXI TX byte write");

    check(tx_observed[0] == 8'hA5, "TX byte register forwards the written byte to the host interface");

    axi_read(REG_TX_BYTE[5:0], readback);
    check(readback[7:0] == 8'hA5, "TX byte register readback reflects the last written byte");
end
endtask

task automatic test_axi_tx_fifo_word_write;
    reg [31:0] readback;
begin
    log_info("Running test_axi_tx_fifo_word_write");

    reset_dut();
    clear_tx_observed();

    axi_write(REG_TX_WORD[5:0], 32'h4433_2211);
    wait_for_tx_observed_count(4, "AXI TX word write");

    check(tx_observed[0] == 8'h11, "TX word register emits byte 0 first");
    check(tx_observed[1] == 8'h22, "TX word register emits byte 1 second");
    check(tx_observed[2] == 8'h33, "TX word register emits byte 2 third");
    check(tx_observed[3] == 8'h44, "TX word register emits byte 3 fourth");

    axi_read(REG_TX_WORD[5:0], readback);
    check(readback == 32'h4433_2211, "TX word register readback reflects the last written word");
end
endtask

task automatic test_axi_rx_fifo_byte_read;
    reg [31:0] readback;
begin
    log_info("Running test_axi_rx_fifo_byte_read");

    reset_dut();
    clear_rx_feed();
    @(negedge clk);
    rx_byte_host = 8'h5A;

    axi_read(REG_RX_BYTE[5:0], readback);
    wait_for_rx_rd_pulses(1, "AXI RX byte read");

    check(readback[7:0] == 8'h5A, "RX byte register returns the current host byte");
    check(rx_rd_pulse_count == 1, "RX byte register issues one host read pulse");
end
endtask

task automatic test_axi_rx_fifo_word_read;
    reg [31:0] readback;
begin
    log_info("Running test_axi_rx_fifo_word_read");

    reset_dut();
    clear_rx_feed();
    @(negedge clk);
    rx_byte_host = 8'h11;
    rx_feed_queue.push_back(8'h22);
    rx_feed_queue.push_back(8'h33);
    rx_feed_queue.push_back(8'h44);

    axi_read(REG_RX_WORD[5:0], readback);
    wait_for_rx_rd_pulses(4, "AXI RX word read");

    check(readback == 32'h4433_2211, "RX word register assembles four host bytes in little-endian order");
    check(rx_rd_pulse_count == 4, "RX word register issues four host read pulses");
    check(rx_feed_queue.size() == 0, "RX word read consumes the staged host byte sequence");
end
endtask

task automatic test_axi_byte_holdoff_interrupt;
    reg [31:0] readback;
begin
    log_info("Running test_axi_byte_holdoff_interrupt");

    reset_dut();
    program_holdoff(4, 20, INT_RX_BYTES);

    set_rx_fifo(1'b0, 3);
    step();
    axi_read(REG_INT_STAT[5:0], readback);
    check(readback[4:0] == 5'b0, "byte interrupt status stays low below threshold");
    check(!intr, "interrupt output stays low below byte threshold");

    set_rx_fifo(1'b0, 4);
    step();
    axi_read(REG_INT_STAT[5:0], readback);
    check(readback[3], "byte interrupt status bit asserts exactly at threshold");
    check(intr, "interrupt output asserts when byte threshold status is masked in");

    set_rx_fifo(1'b1, 0);
    step();
    axi_read(REG_INT_STAT[5:0], readback);
    check(!readback[3], "byte interrupt status clears when RX FIFO empties");
    check(!intr, "interrupt output clears when byte interrupt status clears");
end
endtask

task automatic test_axi_time_holdoff_interrupt;
    reg [31:0] readback;
begin
    log_info("Running test_axi_time_holdoff_interrupt");

    reset_dut();
    program_holdoff(1023, 3, INT_RX_TIME);

    set_rx_fifo(1'b0, 1);
    step();
    axi_read(REG_INT_STAT[5:0], readback);
    check(!readback[4], "time interrupt status is low when RX activity starts");
    check(!intr, "interrupt output is low when RX activity starts");

    wait_for_byte_time_count(1, "AXI time threshold");
    axi_read(REG_INT_STAT[5:0], readback);
    check(!readback[4], "time interrupt status stays low after one byte time");

    wait_for_byte_time_count(2, "AXI time threshold");
    axi_read(REG_INT_STAT[5:0], readback);
    check(!readback[4], "time interrupt status stays low after two byte times");

    wait_for_byte_time_count(3, "AXI time threshold");
    check(!rx_time_coal_intr, "time interrupt source is still low when the threshold count is first reached");
    check(!intr, "interrupt output is still low when the threshold count is first reached");

    step();
    check(rx_time_coal_intr, "time interrupt source asserts one clock after the threshold count");
    wait_for_intr_high("AXI time threshold interrupt propagation");
    check(intr, "interrupt output eventually asserts after the masked time interrupt status bit");

    set_rx_fifo(1'b1, 0);
    step();
    axi_read(REG_INT_STAT[5:0], readback);
    check(!readback[4], "time interrupt status clears when RX FIFO empties");
    check(!intr, "interrupt output clears after RX FIFO empties");
end
endtask

initial begin
    clk = 1'b0;
    checks_run = 0;
    checks_failed = 0;

    $dumpfile("int_holdoff_axi_tb.vcd");
    $dumpvars(0, int_holdoff_axi_tb);

    test_axi_programming_readback();
    test_axi_tx_fifo_byte_write();
    test_axi_tx_fifo_word_write();
    test_axi_rx_fifo_byte_read();
    test_axi_rx_fifo_word_read();
    test_axi_byte_holdoff_interrupt();
    test_axi_time_holdoff_interrupt();

    $display("[t=%0d ns] Completed %0d checks with %0d failures",
             sim_time_ns(), checks_run, checks_failed);
    if (checks_failed != 0) begin
        $fatal(1, "int_holdoff_axi_tb failed");
    end

    $display("[t=%0d ns] PASS: int_holdoff_axi_tb", sim_time_ns());
    $finish;
end

endmodule
