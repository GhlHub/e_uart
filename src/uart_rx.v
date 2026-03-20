`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Glen Lowe
// 
// Create Date: 04/30/2025 10:21:04 PM
// Design Name: e_uart
// Module Name: uart_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: UART receive logic
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_rx(
    clk,
    rst,
    en,
    rxd,
    over_sample_clk_cnt,
    rx_byte,
    rx_byte_dv
    );
    
input clk;
input rst;
input en;
input rxd;
input [9:0]  over_sample_clk_cnt;
output [7:0]   rx_byte;
output         rx_byte_dv;    


// 5x oversampling
reg [1:0] en_dly;
reg  [((10-1)*5)-1:0] rx_samples;    // 1 start bit, 8 data bits, 1 stop bit = 10 bits. But we just capture 9 bits, We don't bother with the stop bit. 5 samples per bit 
reg  [9:0]        sample_clk_cntr;
reg  [5:0]      dv_inhibit_cntr;
wire [7:0]        rx_byte;
wire  ld_sample_clk_cntr;
wire sample_clk_cntr_eq0;
wire start_det;
wire dv_inhibit_cntr_eq0;
assign dv_inhibit_cntr_eq0 = (dv_inhibit_cntr == 0);
assign ld_sample_clk_cntr  = (en_dly == 2'b01);
assign sample_clk_cntr_eq0 = (sample_clk_cntr == 0);
assign rx_byte_dv          = start_det; 
assign start_det           = (rx_samples[2:0] == 3'b001) & dv_inhibit_cntr_eq0; // The beginning of the start bit is at rx_sample[1:0]
assign rx_byte             = {rx_samples[(5*8)+2],
                              rx_samples[(5*7)+2],
                              rx_samples[(5*6)+2],
                              rx_samples[(5*5)+2],
                              rx_samples[(5*4)+2],
                              rx_samples[(5*3)+2],
                              rx_samples[(5*2)+2],
                              rx_samples[(5*1)+2]};

always@(posedge clk) begin
    en_dly <= rst ? 2'b00 : {en_dly[0], en};
    
    casex({rst | ~en, start_det, dv_inhibit_cntr_eq0, sample_clk_cntr_eq0})
        4'b1xxx: dv_inhibit_cntr <= 45;
        4'b01xx: dv_inhibit_cntr <= 45;
        4'b001x: dv_inhibit_cntr <= 0;
        4'b0001: dv_inhibit_cntr <= dv_inhibit_cntr - 1;
        default:dv_inhibit_cntr <= dv_inhibit_cntr;
    endcase
    
    casex({rst | ~en, ld_sample_clk_cntr, sample_clk_cntr_eq0})
        3'b1xx: sample_clk_cntr <= 10'b11_1111_1111;
        3'b01x: sample_clk_cntr <= over_sample_clk_cnt;
        3'b000: sample_clk_cntr <= sample_clk_cntr - 1;
        3'b001: sample_clk_cntr <= over_sample_clk_cnt;
        default: sample_clk_cntr <= sample_clk_cntr;
    endcase
    
    casex({rst, en, sample_clk_cntr_eq0})
        3'b1xx:   rx_samples <= 45'hffff_ffff_ffff;
        3'b00x:   rx_samples <= 45'hffff_ffff_ffff;
        3'b011:   rx_samples <= {rxd, rx_samples[44:1]}; // start then lsb shifted in first
        default:   rx_samples <= rx_samples;
    endcase

end

endmodule
