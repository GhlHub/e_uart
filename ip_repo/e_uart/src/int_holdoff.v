`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Glen Lowe
// 
// Create Date: 05/01/2025 07:32:38 PM
// Design Name: e_uart
// Module Name: int_holdoff
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Counters for interrupt coalescing
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module int_holdoff(
    clk,
    rst,
    baud_clk_cnt,
    rx_int_holdoff_byte_time_cnt,
    rx_int_holdoff_byte_cnt,
    rx_empty,
    rx_byte_count,
    
    rx_time_coal_intr,
    rx_byte_cnt_coal_intr
    );



input clk;
input rst;
input [12:0] baud_clk_cnt;
input [10:0] rx_int_holdoff_byte_time_cnt;
input [10:0] rx_int_holdoff_byte_cnt;
input rx_empty;
input [10:0] rx_byte_count;

output rx_time_coal_intr;
output rx_byte_cnt_coal_intr;


reg         rx_empty_d1;
reg         rx_byte_cnt_coal_intr;
reg         rx_time_coal_intr;
reg         byte_time_cntr_en;
reg [10:0]  byte_time_cntr;
reg [3:0]   bit_times_elapsed;
reg [12:0]  bit_time_cntr;

wire rx_empty_negedge;
wire rx_empty_posedge;
wire elapsed_bit_time_eq_9;
wire bit_time_cntr_eq_baud_clk_cnt;
wire bit_time_tick;

assign rx_empty_negedge  =  rx_empty_d1 & ~rx_empty;
assign rx_empty_posedge  = ~rx_empty_d1 &  rx_empty;
assign elapsed_bit_time_eq_9 = (bit_times_elapsed == 9);
assign bit_time_cntr_eq_baud_clk_cnt = (bit_time_cntr == baud_clk_cnt);
assign bit_time_tick = bit_time_cntr_eq_baud_clk_cnt;

// Logic to perform interrupt coalescing
always@(posedge clk) begin
    rx_empty_d1           <= rst ? 1'b1 :  rx_empty;
    rx_byte_cnt_coal_intr <= rst ? 1'b0 : ((rx_byte_count != 0) && (rx_byte_count >= rx_int_holdoff_byte_cnt));
end

always@(posedge clk) begin
    casex({rst, bit_time_tick})     // Free running counter. bit_time_tick is when the time elapsed for a single bit to be send or received
        2'b1x: bit_time_cntr <= 0;  // Reset to zero when a bit time has elapsed
        2'b01: bit_time_cntr <= 0;
        default: bit_time_cntr <= bit_time_cntr + 1;
    endcase
    
    casex({rst, bit_time_tick, elapsed_bit_time_eq_9}) // Counter that increments at every bit time. When 10 bit times has elapsed, reset to zero
        3'b1xx: bit_times_elapsed <= 0;
        3'b010: bit_times_elapsed <= bit_times_elapsed + 1;
        3'b001: bit_times_elapsed <= 0;
        default: bit_times_elapsed <= bit_times_elapsed;
    endcase
end

always@(posedge clk) begin
    casex({rst, rx_empty_negedge, rx_empty_posedge, rx_time_coal_intr})
        4'b1xxx:  byte_time_cntr_en <= 1'b0;
        4'b0001:  byte_time_cntr_en <= 1'b0;
        4'b01xx:  byte_time_cntr_en <= 1'b1;
        4'b001x:  byte_time_cntr_en <= 1'b0;
        default:  byte_time_cntr_en <= byte_time_cntr_en;    
    endcase
    
    casex({rst, rx_empty_posedge, (byte_time_cntr_en & elapsed_bit_time_eq_9 & ~rx_time_coal_intr)})
        3'b1xx:  byte_time_cntr <= 0;
        3'b01x:  byte_time_cntr <= 0;
        3'b001:  byte_time_cntr <= byte_time_cntr + 1;
        default: byte_time_cntr <= byte_time_cntr;
    endcase

    rx_time_coal_intr <= rst ? 1'b0 : (byte_time_cntr_en && (byte_time_cntr >= rx_int_holdoff_byte_time_cnt));    
end


endmodule
