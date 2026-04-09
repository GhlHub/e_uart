
`timescale 1 ns / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Glen Lowe
// 
// Create Date: 05/01/2025 07:32:38 PM
// Design Name: e_uart
// Module Name: e_uart_slave_lite_v1_0_S00_AXI
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Implement AXI-Lite interface
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

	module e_uart_slave_lite_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
        output wire [12:0] baud_clk_cnt,
        output wire [9:0]  over_sample_clk_cnt,
        output wire [10:0] rx_int_holdoff_byte_time_cnt,
        output wire [10:0] rx_int_holdoff_byte_cnt,
        output reg         rx_time_coal_intr_clr,
        output wire tx_en,
        output reg  [7:0]  tx_byte_host,
        output reg         tx_byte_host_dv,
        output wire        rx_en,
        
        input  wire [7:0]  rx_byte_host,
        input  wire        rx_byte_host_dv,
        
        output reg        rx_byte_host_rd,

        input wire [10:0] tx_byte_count,
        input wire [10:0] rx_byte_count,   
        input wire[4:0]   int_status,

		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY,
		output reg intr
	);

    reg [1:0] is_reg0_wr;
    reg [1:0] is_reg1_wr;
reg [7:0] tx_byte_mux;
reg [1:0] byte_cntr;
reg word_wr_active;
reg [31:0] rdata;
reg [31:0] rx_word_host;
reg [1:0] rd_byte_cntr;
reg       word_rd_active;
wire      word_rd_done;

wire byte_cntr_done;

wire is_reg2_rd;
wire is_reg3_rd;
wire is_reg3;
reg  is_reg3_prev;
wire is_reg3_posedge;

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] axi_wdata;
	reg [(C_S_AXI_DATA_WIDTH/8)-1 : 0] axi_wstrb;
	reg         axi_awaddr_valid;
	reg         axi_wdata_valid;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 3;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 16
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	//reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg6;
	//reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg9;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg10;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg11;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg12;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg13;
	//reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg14;
	//reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg15;
	integer	 byte_index;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	wire slv_reg_wren;
	wire [3:0] write_index;
	reg [1:0] read_state;
	// State machine local parameters
	 localparam Idle  = 2'b00,
	            Raddr = 2'b10,
	            Raddr_Latched = 2'b01,
	            Rdata = 2'b11;

	assign slv_reg_wren = axi_awaddr_valid & axi_wdata_valid & ~axi_bvalid;
	assign write_index = axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB];

	// Buffer one address and one data beat so AW and W can arrive in either order.
	always @(posedge S_AXI_ACLK)
	  begin
	     if (S_AXI_ARESETN == 1'b0)
	       begin
	         axi_awready <= 0;
	         axi_wready <= 0;
	         axi_awaddr <= 0;
	         axi_wdata <= 0;
	         axi_wstrb <= 0;
	         axi_awaddr_valid <= 1'b0;
	         axi_wdata_valid <= 1'b0;
	         axi_bvalid <= 1'b0;
	         axi_bresp <= 2'b00;
	       end
	     else
	       begin
	         axi_awready <= ~axi_awaddr_valid & ~axi_bvalid;
	         axi_wready <= ~axi_wdata_valid & ~axi_bvalid;
	         axi_bresp <= 2'b00;

	         if (axi_awready && S_AXI_AWVALID)
	           begin
	             axi_awaddr <= S_AXI_AWADDR;
	             axi_awaddr_valid <= 1'b1;
	           end

	         if (axi_wready && S_AXI_WVALID)
	           begin
	             axi_wdata <= S_AXI_WDATA;
	             axi_wstrb <= S_AXI_WSTRB;
	             axi_wdata_valid <= 1'b1;
	           end

	         if (slv_reg_wren)
	           begin
	             axi_awaddr_valid <= 1'b0;
	             axi_wdata_valid <= 1'b0;
	             axi_bvalid <= 1'b1;
	           end
	         else if (axi_bvalid && S_AXI_BREADY)
	           begin
	             axi_bvalid <= 1'b0;
	           end
	       end
	      end

	// Implement memory mapped register select and write logic generation
	// The write data is accepted only after both address and data have been handshaken.
	// Write strobes are used to select byte enables of slave registers while writing.
	 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      //slv_reg3 <= 0;
	      slv_reg4 <= 0;
	      slv_reg5 <= 0;
	      slv_reg6 <= 0;
	      //slv_reg7 <= 0;
	      slv_reg8 <= 0;
	      slv_reg9 <= 0;
	      slv_reg10 <= 0;
	      slv_reg11 <= 0;
	      slv_reg12 <= 0;
	      slv_reg13 <= 0;
	      rx_time_coal_intr_clr <= 1'b0;
		      //slv_reg14 <= 0;
		      //slv_reg15 <= 0;
		      is_reg0_wr <= 0;
		      is_reg1_wr <= 0;
		    end 
		  else begin
		    is_reg0_wr <= {is_reg0_wr[0], 1'b0};
		    is_reg1_wr <= {is_reg1_wr[0], 1'b0};
            rx_time_coal_intr_clr <= 1'b0;

		    if (slv_reg_wren)
		      begin
		        case (write_index)
		          4'h0: begin
		            is_reg0_wr <= {is_reg0_wr[0],1'b1};
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 0
		                slv_reg0[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          end
		          4'h1: begin
		            is_reg1_wr <= {is_reg1_wr[0], 1'b1};
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 1
		                slv_reg1[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          end
		          4'h2:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 2
		                slv_reg2[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end
/*	                
		          4'h3:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
*/	                
	          4'h4: begin
	            // INT_STATUS is read-only except RX_TIME_COALESCE, which is write-1-to-clear.
	            rx_time_coal_intr_clr <= axi_wstrb[0] & axi_wdata[4];
	          end
		          4'h5:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 5
		                slv_reg5[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          4'h6:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 6
		                slv_reg6[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
/*	              
		          4'h7:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 7
	                slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
*/	                
		          4'h8:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 8
		                slv_reg8[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          4'h9:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 9
		                slv_reg9[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          4'hA:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 10
		                slv_reg10[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          4'hB:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 11
		                slv_reg11[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          4'hC:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 12
		                slv_reg12[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end  
		          4'hD:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( axi_wstrb[byte_index] == 1 ) begin
		                // Respective byte enables are asserted as per write strobes 
		                // Slave register 13
		                slv_reg13[(byte_index*8) +: 8] <= axi_wdata[(byte_index*8) +: 8];
		              end
/*	                
		          4'hE:
		            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
		              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 14
	                slv_reg14[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          4'hF:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 15
	                slv_reg15[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
*/	                
		          default : begin
		                    end
		        endcase
		      end
		  end
		end    

	// Implement read state machine
	  always @(posedge S_AXI_ACLK)                                       
	    begin                                       
	      if (S_AXI_ARESETN == 1'b0)                                       
		        begin                                       
		         //asserting initial values to all 0's during reset                                       
		         axi_arready <= 1'b0;                                       
		         axi_rvalid <= 1'b0;                                       
		         axi_rresp <= 2'b00;                                       
		         read_state <= Idle;                                       
		        end                                       
	      else                                       
	        begin                                       
	          case(read_state)                                       
	            Idle:     //Initial state inidicating reset is done and ready to receive read/write transactions                                       
	              begin                                                
	                if (S_AXI_ARESETN == 1'b1)                                        
	                  begin                                       
	                    read_state <= Raddr;                                       
	                    axi_arready <= 1'b1;                                       
	                  end                                       
	                else read_state <= read_state;                                       
	              end                                       
	            Raddr:        //At this state, slave is ready to receive address along with corresponding control signals                                       
	              begin                                       
	                if (S_AXI_ARVALID && S_AXI_ARREADY)                                       
	                  begin                                       
	                    read_state <= Raddr_Latched;                                       
	                    axi_araddr <= S_AXI_ARADDR;                                       
	                    //axi_rvalid <= 1'b1;                                       
	                    axi_arready <= 1'b0;                                       
	                  end                                       
	                else read_state <= read_state;                                       
	              end
	            Raddr_Latched:
	              begin
	                if (is_reg3)
	                begin
	                   if(word_rd_done)
	                   begin
	                       read_state <= Rdata;
	                       axi_rvalid <= 1'b1;	                   
	                   end
	                end
	                else
	                   begin
	                       read_state <= Rdata;
	                       axi_rvalid <= 1'b1;
	                   end
	              end                                       
	            Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length                                       
	              begin                                           
	                if (S_AXI_RVALID && S_AXI_RREADY)                                       
	                  begin                                       
	                    axi_rvalid <= 1'b0;                                       
	                    axi_arready <= 1'b1; // & ~word_rd_active;                                       
	                    read_state <= Raddr;                                       
	                  end                                       
	                else read_state <= read_state;                                       
	              end                                       
	           endcase                                       
	          end                                       
	        end


assign S_AXI_RDATA = rdata;       
always@(*) begin
	  case(axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB])
	   4'h0: rdata = {24'h0, slv_reg0[7:0]};       // tx 1 byte
	   4'h1: rdata = slv_reg1;                     // tx 4 bytes
	   4'h2: rdata = {24'h0, rx_byte_host};        // rx 1 byte
	   4'h3: rdata = rx_word_host;                 // rx 4 bytes
	   4'h4: rdata = {27'h0, int_status};          // interrupt status
	   4'h5: rdata = {27'h0, slv_reg5[4:0]};       // interrupt mask
	   4'h6: rdata = {intr, 29'b0, slv_reg6[1:0]};       // irq pin, rx_en, tx_en
	   //4'h7: rdata = 0;
	   4'h8: rdata = {19'h0, slv_reg8[12:0]};      // baud_clk_cnt
	   4'h9: rdata = {22'h0, slv_reg9[9:0]};       // oversample clk count
	   4'ha: rdata = {5'h00, slv_reg10[26:16], 5'b00000, slv_reg10[10:0]};     // rx_int_holdoff_byte_cnt, rx_int_holdoff_byte_time_cnt
       //4'hb:
       //4'hc:
       //4'hd:
	   4'he: rdata =  {21'h0, tx_byte_count};
	   4'hf: rdata =  {21'h0, rx_byte_count};
	   default: rdata = 0;
	  endcase	  	  
end

assign is_reg2_rd = (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 4'h2) &
                    (S_AXI_RVALID && S_AXI_RREADY) &
                    (read_state == Rdata);
assign is_reg3    = (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 4'h3) &
                    (read_state == Raddr_Latched);
assign is_reg3_posedge = ~is_reg3_prev & is_reg3;                    
assign is_reg3_rd = is_reg3_posedge;                                        
//assign is_reg3_rd = (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 4'h3) &
//                    (S_AXI_RVALID && S_AXI_RREADY) &
//                    (read_state == Rdata);
                                        
assign word_rd_done = (rd_byte_cntr == 2'b11);

always@(posedge S_AXI_ACLK) begin
    is_reg3_prev <= ~S_AXI_ARESETN ? 1'b0 : is_reg3;
    
    casex({S_AXI_ARESETN, is_reg3_rd, word_rd_done})
        3'b0xx:  word_rd_active <= 1'b0;
        3'b11x:  word_rd_active <= 1'b1;
        3'b101:  word_rd_active <= 1'b0;
        default: word_rd_active <= word_rd_active;
    endcase
    casex({S_AXI_ARESETN, is_reg3_rd, word_rd_done, word_rd_active})
        4'b0xxx:  rd_byte_cntr <= 2'b11;
        4'b11xx:  rd_byte_cntr <= 2'b00;
        4'b101x:  rd_byte_cntr <= 2'b00;          
        4'b1001:  rd_byte_cntr <= rd_byte_cntr + 1;
        default:  rd_byte_cntr <= rd_byte_cntr;
    endcase
    
    casex({S_AXI_ARESETN, word_rd_active, word_rd_done})
        3'b0xx: rx_word_host <= 0;
        3'b11x: begin
                    case(rd_byte_cntr)
                        2'b00: rx_word_host[7:0]   <= rx_byte_host;
                        2'b01: rx_word_host[15:8]  <= rx_byte_host;
                        2'b10: rx_word_host[23:16] <= rx_byte_host;
                        2'b11: rx_word_host[31:24] <= rx_byte_host;
                    endcase
                end
        default: rx_word_host <= rx_word_host;                
         //default: begin end//rx_word_host <= rx_word_host;
    endcase
    
    rx_byte_host_rd <= (is_reg2_rd | is_reg3_rd | (word_rd_active & ~word_rd_done)) ? 1'b1 : 0;
    
end

wire is_reg0_wr_posedge;
wire is_reg1_wr_posedge;
assign is_reg0_wr_posedge = is_reg0_wr[0] & ~is_reg0_wr[1];
assign is_reg1_wr_posedge = is_reg1_wr[0] & ~is_reg1_wr[1];

assign byte_cntr_done = (byte_cntr == 2'b11);
always@(posedge S_AXI_ACLK) begin
    casex({S_AXI_ARESETN, is_reg1_wr_posedge, byte_cntr_done})
        3'b0xx: word_wr_active <= 1'b0;
        3'b11x: word_wr_active <= 1'b1;
        3'b101: word_wr_active <= 1'b0;
        default:word_wr_active <= word_wr_active;
    endcase
    casex({S_AXI_ARESETN, is_reg1_wr_posedge, byte_cntr_done, word_wr_active})
        4'b0xxx: byte_cntr <= 2'b00;
        4'b11xx: byte_cntr <= 2'b00;
        4'b101x: byte_cntr <= 2'b00;
        4'b1001: byte_cntr <= byte_cntr + 1;
        default: byte_cntr <= byte_cntr;    
    endcase
end

always@(*) begin
    case(byte_cntr)
        2'b00:  tx_byte_mux = slv_reg1[7:0];
        2'b01:  tx_byte_mux = slv_reg1[15:8];
        2'b10:  tx_byte_mux = slv_reg1[23:16];
        2'b11:  tx_byte_mux = slv_reg1[31:24];
    endcase
end

always@(posedge S_AXI_ACLK) begin
    tx_byte_host    <= is_reg0_wr_posedge ? slv_reg0[7:0] : tx_byte_mux;
    tx_byte_host_dv <= is_reg0_wr_posedge ? 1'b1          : word_wr_active;
end


assign tx_en                = slv_reg6[0];
assign rx_en                = slv_reg6[1];
assign baud_clk_cnt         = slv_reg8[12:0];
assign over_sample_clk_cnt  = slv_reg9[9:0]; 
assign rx_int_holdoff_byte_time_cnt = slv_reg10[10:0];
assign rx_int_holdoff_byte_cnt= slv_reg10[26:16];

always@(posedge S_AXI_ACLK) begin
    intr <= ~S_AXI_ARESETN ? 1'b0 : (int_status & slv_reg5[4:0]) != 5'b00000;   
end

	endmodule
