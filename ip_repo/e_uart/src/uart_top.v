`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Glen Lowe
// 
// Create Date: 04/30/2025 09:32:13 PM
// Design Name: e_uart
// Module Name: uart_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Top level of E_Uart with processor indepedant interface
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_top(
    clk,
    rst,
    txd,                    // tx pin
    rxd,                    // rx pin
    baud_clk_cnt,           // baud rate counter
    over_sample_clk_cnt,    // 5x oversample rate counter
    rx_int_holdoff_byte_time_cnt,
    rx_int_holdoff_byte_cnt,
    tx_en,
    tx_byte_host,           // tx byte from host
    tx_byte_host_dv,        // data valid flag from host
    rx_en,
    rx_byte_host,           // rx byte from host
    rx_byte_host_dv,        // data valid flag to host
    rx_byte_host_rd,        // data read by host
    // status
    tx_byte_count,          // number of bytes in tx fifo
    rx_byte_count,
    int_status              // interrupt status to host
    );
    
input clk;
input rst;
output txd;
input  rxd;    
input  [12:0] baud_clk_cnt;
input  [9:0]  over_sample_clk_cnt;
input  [10:0] rx_int_holdoff_byte_time_cnt;
input  [10:0] rx_int_holdoff_byte_cnt;
input  tx_en;
input  [7:0]  tx_byte_host;
input         tx_byte_host_dv;
input  rx_en;
output [7:0]  rx_byte_host;
output        rx_byte_host_dv;
input         rx_byte_host_rd;

output [10:0] tx_byte_count;
output [10:0] rx_byte_count;   
output [4:0]  int_status;

wire        txd;
wire [7:0]  tx_byte, rx_byte;
wire        tx_byte_dv, rx_byte_dv;
wire        tx_byte_rd;

wire        tx_full, tx_empty, tx_almost_empty;
wire [10:0] tx_byte_count;

reg rx_empty;

wire [4:0] int_status;
wire rx_time_coal_intr;
wire rx_byte_cnt_coal_intr;

assign int_status = {
    rx_time_coal_intr,
    rx_byte_cnt_coal_intr,
    ~rx_empty,      // not empty
    tx_almost_empty,
    tx_empty};

always@(posedge clk) begin
    rx_empty <= rst ? 1'b1 : (rx_byte_count == 0);
end

fifo_generator_0 fifo_tx(
    .clk            (clk),
    .srst           (rst),
    .din            (tx_byte_host),
    .wr_en          (tx_byte_host_dv),
    
    .rd_en          (tx_byte_rd),
    .dout           (tx_byte),
    .valid          (tx_byte_dv),
    .full           (tx_full),
    .empty          (tx_empty),
    .almost_empty   (tx_almost_empty),
    .data_count     (tx_byte_count)
);

uart_tx uart_tx(
    .clk            (clk),
    .rst            (rst),
    .txd            (txd),
    .en             (tx_en),
    .baud_clk_cnt   (baud_clk_cnt),
    .tx_byte        (tx_byte),
    .tx_byte_dv     (tx_byte_dv),
    .tx_byte_rd     (tx_byte_rd)
    );

uart_rx uart_rx(
    .clk            (clk),
    .rst            (rst),
    .en             (rx_en),
    .rxd            (rxd),
    .over_sample_clk_cnt (over_sample_clk_cnt),
    .rx_byte        (rx_byte),
    .rx_byte_dv     (rx_byte_dv)
    );

fifo_generator_0 fifo_rx(
    .clk            (clk),
    .srst           (rst),
    .din            (rx_byte),
    .wr_en          (rx_byte_dv),
    
    .rd_en          (rx_byte_host_rd),
    .dout           (rx_byte_host),
    .valid          (rx_byte_host_dv),
    .full           (),
    .empty          (),
    .almost_empty   (),
    .data_count     (rx_byte_count)
);


int_holdoff int_holdoff(
    .clk            (clk),
    .rst            (rst),
    .baud_clk_cnt   (baud_clk_cnt),
    .rx_int_holdoff_byte_time_cnt     (rx_int_holdoff_byte_time_cnt),
    .rx_int_holdoff_byte_cnt    (rx_int_holdoff_byte_cnt),
    .rx_empty                   (rx_empty),
    .rx_byte_count              (rx_byte_count),
    
    .rx_time_coal_intr          (rx_time_coal_intr),
    .rx_byte_cnt_coal_intr      (rx_byte_cnt_coal_intr)
    );
        
endmodule
