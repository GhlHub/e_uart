`timescale 1ns / 1ps

module int_holdoff_tb;

localparam int AXI_CLK_HZ = 50_000_000;
localparam int BAUD_RATE = 115_200;
localparam int BAUD_CLK_CNT = ((AXI_CLK_HZ + (BAUD_RATE / 2)) / BAUD_RATE) - 1;
localparam int CLK_PERIOD_NS = 20;

reg clk;
reg rst;
reg [12:0] baud_clk_cnt;
reg [10:0] rx_int_holdoff_byte_time_cnt;
reg [10:0] rx_int_holdoff_byte_cnt;
reg rx_time_coal_intr_clr;
reg rx_empty;
reg [10:0] rx_byte_count;

wire rx_time_coal_intr;
wire rx_byte_cnt_coal_intr;

int checks_run;
int checks_failed;

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

int_holdoff dut(
    .clk                        (clk),
    .rst                        (rst),
    .baud_clk_cnt               (baud_clk_cnt),
    .rx_int_holdoff_byte_time_cnt(rx_int_holdoff_byte_time_cnt),
    .rx_int_holdoff_byte_cnt    (rx_int_holdoff_byte_cnt),
    .rx_time_coal_intr_clr      (rx_time_coal_intr_clr),
    .rx_empty                   (rx_empty),
    .rx_byte_count              (rx_byte_count),
    .rx_time_coal_intr          (rx_time_coal_intr),
    .rx_byte_cnt_coal_intr      (rx_byte_cnt_coal_intr)
);

always #(CLK_PERIOD_NS / 2) clk = ~clk;

task automatic step;
begin
    @(posedge clk);
    #1;
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

task automatic set_rx_fifo;
    input bit next_rx_empty;
    input int next_rx_byte_count;
begin
    @(negedge clk);
    rx_empty = next_rx_empty;
    rx_byte_count = next_rx_byte_count[10:0];
end
endtask

task automatic reset_dut;
begin
    rst = 1'b1;
    rx_time_coal_intr_clr = 1'b0;
    rx_empty = 1'b1;
    rx_byte_count = 11'd0;
    rx_int_holdoff_byte_time_cnt = 11'd0;
    rx_int_holdoff_byte_cnt = 11'd0;
    repeat (4) step();
    @(negedge clk);
    rst = 1'b0;
    step();
end
endtask

task automatic reset_and_start_rx;
    input int initial_rx_count;
begin
    rst = 1'b1;
    rx_time_coal_intr_clr = 1'b0;
    rx_empty = 1'b1;
    rx_byte_count = 11'd0;
    repeat (4) step();
    @(negedge clk);
    rst = 1'b0;
    rx_empty = 1'b0;
    rx_byte_count = initial_rx_count[10:0];
    step();
end
endtask

task automatic pulse_time_interrupt_clear;
begin
    @(negedge clk);
    rx_time_coal_intr_clr = 1'b1;
    step();
    @(negedge clk);
    rx_time_coal_intr_clr = 1'b0;
end
endtask

task automatic wait_for_byte_time_count;
    input int target_count;
    input string phase_name;
    int timeout;
begin : wait_loop
    for (timeout = 0; timeout < ((BAUD_CLK_CNT + 1) * 16); timeout = timeout + 1) begin
        if (dut.byte_time_cntr == target_count[10:0]) begin
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

task automatic test_byte_threshold_exact;
begin
    log_info("Running test_byte_threshold_exact");

    reset_dut();
    rx_int_holdoff_byte_cnt = 11'd4;
    rx_int_holdoff_byte_time_cnt = 11'd7;

    set_rx_fifo(1'b0, 3);
    step();
    check(!rx_byte_cnt_coal_intr, "byte threshold interrupt stays low below threshold");
    check(!rx_time_coal_intr, "time threshold interrupt stays low during byte threshold setup");

    set_rx_fifo(1'b0, 4);
    step();
    check(rx_byte_cnt_coal_intr, "byte threshold interrupt asserts exactly at threshold");

    set_rx_fifo(1'b0, 6);
    step();
    check(rx_byte_cnt_coal_intr, "byte threshold interrupt remains asserted above threshold");

    set_rx_fifo(1'b1, 0);
    step();
    check(!rx_byte_cnt_coal_intr, "byte threshold interrupt clears when RX FIFO becomes empty");
end
endtask

task automatic test_time_threshold_exact;
begin
    log_info("Running test_time_threshold_exact");

    rx_int_holdoff_byte_cnt = 11'd1023;
    rx_int_holdoff_byte_time_cnt = 11'd3;
    reset_and_start_rx(1);

    check(!rx_time_coal_intr, "time threshold interrupt is low when RX activity starts");
    check(!rx_byte_cnt_coal_intr, "byte threshold interrupt stays low with large threshold");
    check(dut.byte_time_cntr == 11'd0, "byte time counter starts at zero");

    wait_for_byte_time_count(1, "time threshold exact test");
    check(!rx_time_coal_intr, "time threshold interrupt stays low after 1 byte time");

    wait_for_byte_time_count(2, "time threshold exact test");
    check(!rx_time_coal_intr, "time threshold interrupt stays low after 2 byte times");

    wait_for_byte_time_count(3, "time threshold exact test");
    check(!rx_time_coal_intr, "time threshold interrupt stays low in the cycle the threshold count is reached");

    step();
    check(rx_time_coal_intr, "time threshold interrupt asserts one clock after the programmed byte-time threshold");
    step();
    check(rx_time_coal_intr, "time threshold interrupt remains asserted until cleared");
end
endtask

task automatic test_time_threshold_restart_after_empty;
begin
    log_info("Running test_time_threshold_restart_after_empty");

    rx_int_holdoff_byte_cnt = 11'd1023;
    rx_int_holdoff_byte_time_cnt = 11'd2;
    reset_and_start_rx(1);

    wait_for_byte_time_count(1, "time threshold restart test");
    check(!rx_time_coal_intr, "time threshold interrupt stays low before restart");

    set_rx_fifo(1'b1, 0);
    step();
    step();
    check(!rx_time_coal_intr, "time threshold interrupt remains low after RX FIFO empties before expiry");
    check(dut.byte_time_cntr == 11'd0, "byte time counter resets when RX FIFO becomes empty");

    set_rx_fifo(1'b0, 1);
    step();
    check(dut.byte_time_cntr == 11'd0, "byte time counter restarts from zero on new RX activity");

    wait_for_byte_time_count(1, "time threshold restart test after re-arm");
    check(!rx_time_coal_intr, "time threshold interrupt stays low after restart and one byte time");

    wait_for_byte_time_count(2, "time threshold restart test after re-arm");
    check(!rx_time_coal_intr, "time threshold interrupt still waits one clock after threshold count on restart");

    step();
    check(rx_time_coal_intr, "time threshold interrupt reasserts after a full restarted holdoff interval");
end
endtask

task automatic test_time_threshold_clear_and_restart;
begin
    log_info("Running test_time_threshold_clear_and_restart");

    rx_int_holdoff_byte_cnt = 11'd1023;
    rx_int_holdoff_byte_time_cnt = 11'd2;
    reset_and_start_rx(1);

    wait_for_byte_time_count(1, "time threshold clear test");
    check(!rx_time_coal_intr, "time threshold interrupt stays low before the clear test threshold expires");

    wait_for_byte_time_count(2, "time threshold clear test");
    step();
    check(rx_time_coal_intr, "time threshold interrupt asserts before software clear");

    pulse_time_interrupt_clear();
    check(!rx_time_coal_intr, "time threshold interrupt clears on software clear pulse");
    check(dut.byte_time_cntr == 11'd0, "byte time counter resets when software clears the interrupt");
    check(dut.byte_time_cntr_en, "byte time counter re-arms immediately while RX FIFO remains non-empty");

    wait_for_byte_time_count(1, "time threshold clear test after re-arm");
    check(!rx_time_coal_intr, "time threshold interrupt stays low after clear and one byte time");

    wait_for_byte_time_count(2, "time threshold clear test after re-arm");
    check(!rx_time_coal_intr, "time threshold interrupt still waits one clock after the restarted threshold count");

    step();
    check(rx_time_coal_intr, "time threshold interrupt reasserts after software clear when RX FIFO stays non-empty");
end
endtask

initial begin
    clk = 1'b0;
    rst = 1'b1;
    baud_clk_cnt = BAUD_CLK_CNT[12:0];
    rx_int_holdoff_byte_time_cnt = 11'd0;
    rx_int_holdoff_byte_cnt = 11'd0;
    rx_time_coal_intr_clr = 1'b0;
    rx_empty = 1'b1;
    rx_byte_count = 11'd0;
    checks_run = 0;
    checks_failed = 0;

    $dumpfile("int_holdoff_tb.vcd");
    $dumpvars(0, int_holdoff_tb);

    test_byte_threshold_exact();
    test_time_threshold_exact();
    test_time_threshold_restart_after_empty();
    test_time_threshold_clear_and_restart();

    $display("[t=%0d ns] Completed %0d checks with %0d failures",
             sim_time_ns(), checks_run, checks_failed);
    if (checks_failed != 0) begin
        $fatal(1, "int_holdoff_tb failed");
    end

    $display("[t=%0d ns] PASS: int_holdoff_tb", sim_time_ns());
    $finish;
end

endmodule
