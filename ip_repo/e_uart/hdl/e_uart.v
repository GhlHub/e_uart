
`timescale 1 ns / 1 ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Glen Lowe
// 
// Create Date: 05/01/2025 07:32:38 PM
// Design Name: e_uart
// Module Name: e_uart
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Top level with axi-4 lite interface
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


	module e_uart #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
        output  txd,
        input   rxd,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,
		output wire intr,					// Interrupt pin
		output wire [4:0] int_status		// Individual interrupt status - for debug or performance monitor
	);
	


wire  [12:0] baud_clk_cnt;
wire  [9:0]  over_sample_clk_cnt;
wire  [10:0] rx_int_holdoff_byte_time_cnt;
wire  [10:0]  rx_int_holdoff_byte_cnt;
wire         rx_time_coal_intr_clr;
wire  tx_en;
wire  [7:0]  tx_byte_host;
wire         tx_byte_host_dv;
wire  rx_en;
wire [7:0]  rx_byte_host;
wire        rx_byte_host_dv;
wire         rx_byte_host_rd;
wire [10:0] tx_byte_count;
wire [10:0] rx_byte_count;

	
	
// Instantiation of Axi Bus Interface S00_AXI
	e_uart_slave_lite_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) e_uart_slave_lite_v1_0_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		.intr(intr),
		
        .baud_clk_cnt               (baud_clk_cnt),
        .over_sample_clk_cnt        (over_sample_clk_cnt),
        .rx_int_holdoff_byte_time_cnt     (rx_int_holdoff_byte_time_cnt),
        .rx_int_holdoff_byte_cnt    (rx_int_holdoff_byte_cnt),
        .rx_time_coal_intr_clr      (rx_time_coal_intr_clr),
        .tx_en                      (tx_en),
        .tx_byte_host               (tx_byte_host),
        .tx_byte_host_dv            (tx_byte_host_dv),
        .rx_en                      (rx_en),
        .rx_byte_host               (rx_byte_host),
        .rx_byte_host_dv            (rx_byte_host_dv),
        .rx_byte_host_rd            (rx_byte_host_rd),
        .tx_byte_count              (tx_byte_count),
        .rx_byte_count              (rx_byte_count),
        .int_status                 (int_status)
	);

	// Add user logic here

uart_top uart_top(
    .clk        (s00_axi_aclk),
    .rst        (~s00_axi_aresetn),
    .txd        (txd),
    .rxd        (rxd),
    .baud_clk_cnt                   (baud_clk_cnt),
    .over_sample_clk_cnt            (over_sample_clk_cnt),
    .rx_int_holdoff_byte_time_cnt         (rx_int_holdoff_byte_time_cnt),
    .rx_int_holdoff_byte_cnt        (rx_int_holdoff_byte_cnt),
    .rx_time_coal_intr_clr          (rx_time_coal_intr_clr),
    .tx_en                          (tx_en),
    .tx_byte_host                   (tx_byte_host),
    .tx_byte_host_dv                (tx_byte_host_dv),
    .rx_en                          (rx_en),
    .rx_byte_host                   (rx_byte_host),
    .rx_byte_host_dv                (rx_byte_host_dv),
    .rx_byte_host_rd                (rx_byte_host_rd),
    // status
    .tx_byte_count                  (tx_byte_count),
    .rx_byte_count                  (rx_byte_count),
    .int_status                     (int_status)
    );


	// User logic ends

	endmodule
