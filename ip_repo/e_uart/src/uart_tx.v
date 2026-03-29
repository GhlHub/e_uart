`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/30/2025 08:25:37 PM
// Design Name: e_uart
// Module Name: uart_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Uart transmit
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_tx(
    clk,
    rst,
    txd,
    baud_clk_cnt,
    en,
    tx_byte,
    tx_byte_dv,
    tx_byte_rd
    );
    
input clk;
input rst;
output txd;
input [12:0] baud_clk_cnt;
input       en;
input [7:0] tx_byte;
input       tx_byte_dv;
output      tx_byte_rd;

    
parameter [2:0] IDLE        = 3'b000,
                START       = 3'b001,
                TX_B        = 3'b010,
                STOP        = 3'b011,
                DONE        = 3'b100;

reg       txd;
reg       tx_byte_rd, tx_byte_rd_d;
reg [7:0] tx_byte_q;
reg [12:0] clk_cntr;
reg [2:0] current_state, next_state;
reg        ld_clk_cntr, ld_clk_cntr_s;
reg        ld_tx_bit_cntr;
reg [2:0]  tx_bit_cntr;
wire clk_cntr_eq0;
wire cs_eq_start;
wire cs_eq_tx_b;
wire cs_eq_stop;
wire tx_bit_cntr_eq0;

assign clk_cntr_eq0 = (clk_cntr == 13'b000_0000_0000);
assign cs_eq_start  = (current_state == START);
assign cs_eq_tx_b   = (current_state == TX_B);
assign cs_eq_stop   = (current_state == STOP);
assign tx_bit_cntr_eq0 = (tx_bit_cntr == 0);
                
always @(*) begin
    ld_clk_cntr    = 1'b0;
    ld_clk_cntr_s  = 1'b0;
    tx_byte_rd_d   = 1'b0;
    ld_tx_bit_cntr = 1'b0;
    next_state = current_state;
    
    case(current_state)
        IDLE: begin
            if(tx_byte_dv & en) begin
                tx_byte_rd_d = 1'b1;
                next_state = START;
                ld_clk_cntr = 1'b1;
            end
        end
        START: begin
            if(clk_cntr_eq0) begin
                next_state = TX_B;
                ld_clk_cntr = 1'b1;
                ld_tx_bit_cntr = 1'b1;
            end
        end
        TX_B: begin
            if(clk_cntr_eq0 & tx_bit_cntr_eq0) begin
                next_state = STOP;
                ld_clk_cntr = 1'b1;
            end else begin
                if(clk_cntr_eq0 & ~tx_bit_cntr_eq0) begin
                    ld_clk_cntr = 1'b1;
                end
            end
        end
        STOP: begin                     // Previous state setup for 1 stop bit
            if(clk_cntr_eq0) begin
                next_state = DONE;      // Setup next state for 1/2 stop bit
                ld_clk_cntr_s = 1'b1;   // Load half bit time counter value 
            end
        end
        DONE: begin
            if(clk_cntr_eq0) begin
                next_state = IDLE;
            end
        end
        
        default: begin
            next_state = current_state;
        end
    endcase
end


always@(posedge clk) begin
    tx_byte_rd    <= (rst | ~en) ? 1'b0 : tx_byte_rd_d;
    current_state <= (rst | ~en) ? IDLE : next_state;     

    casex({rst | ~en, cs_eq_start, cs_eq_tx_b, cs_eq_stop})
        4'b1xxx:  txd <= 1'b1;
        4'b01xx:  txd <= 1'b0;          // Start bit is a zero
        4'b001x:  txd <= tx_byte_q[0];
        4'b0001:  txd <= 1'b1;          // stop bit is a 1
        default: txd <= txd;
    endcase
    
end

always@(posedge clk) begin
    casex({rst | ~en, ld_clk_cntr, ld_clk_cntr_s, clk_cntr_eq0})    // counter to generate baudrate
        4'b1xxx: clk_cntr <= 0;
        4'b01xx: clk_cntr <= baud_clk_cnt;
        4'b001x: clk_cntr <= {1'b0, baud_clk_cnt[12:1]};
        4'b0001: clk_cntr <= 0;
        default: clk_cntr <= clk_cntr-1;
    endcase
    
    casex({rst | ~en, ld_tx_bit_cntr, cs_eq_tx_b, clk_cntr_eq0})    // counter for number of bits to send
        4'b1xxx: tx_bit_cntr <= 3'b000;
        4'b01xx: tx_bit_cntr <= 3'b111;
        4'b0011: tx_bit_cntr <= tx_bit_cntr - 1;
        default: tx_bit_cntr <= tx_bit_cntr;
    endcase
    
    casex({rst | ~en, tx_byte_rd, cs_eq_tx_b, clk_cntr_eq0})        // shift register for tx byte
        4'b1xxx: tx_byte_q <= 8'h00;
        4'b01xx: tx_byte_q <= tx_byte;
        4'b0011: tx_byte_q <= {1'b0,tx_byte_q[7:1]};
        default: tx_byte_q <= tx_byte_q;
    endcase 
end


    
endmodule
