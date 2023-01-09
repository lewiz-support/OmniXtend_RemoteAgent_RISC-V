//****************************************************************
// December 6, 2022
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//
// Date: N/A
// Project: LMAC 3
// Comments: N/A
//
//********************************
// File history:
//   N/A
//****************************************************************

// synopsys translate_off
`timescale 1ns/1ps
// synopsys translate_on

module x2c_ctrl (
        x_clk,                          //i-1, Depends on the speed of the device
        reset_,                         //i-1,

        mode_10G,                       //i-1,  10-Gbps speed mode
        mode_25G,                       //i-1,  25-Gbps speed mode
        mode_40G,                       //i-1,  40-Gbps speed mode
        mode_50G,                       //i-1,  50-Gbps speed mode
        mode_100G,                      //i-1, 100-Gbps speed mode

        data_in,                        //i-256, 256-bit Input Data
        ctrl_in,                        //i-32,   32-bit Input Ctrl

        x_byte_cnt,                     //i-32, byte count
        x_bcnt_we,                      //i-1,  byte count write enable
        x_we,                           //i-1,  write enable with data and ctrl

        data_out,                       //o-256, 256-bit output data from the FIFO
        ctrl_out,                       //o-32,   32-bit output ctrl from the FIFO
        rd_en                           //o-1,    rd_en to the FIFO
	);

	input x_clk;                        //i-1, Depends on the speed of the device
	input reset_;                       //i-1,

	input mode_10G;                     //i-1,  10-Gbps speed mode
	input mode_25G;                     //i-1,  25-Gbps speed mode
	input mode_40G;                     //i-1,  40-Gbps speed mode
	input mode_50G;                     //i-1,  50-Gbps speed mode
	input mode_100G;                    //i-1, 100-Gbps speed mode

	input [255:0] data_in;              //i-256, 256-bit Input Data
	input [31:0] ctrl_in;               //i-32,   32-bit Input Ctrl

	input [31:0] x_byte_cnt;            //i-32, byte count
	input x_we;                         //i-1,  byte count write enable
	input x_bcnt_we;                    //i-1,  write enable with data and ctrl

	output reg [255:0] data_out;        //o-256, 256-bit output data from the FIFO
	output reg [31:0] ctrl_out;         //o-32,   32-bit output ctrl from the FIFO
	output reg rd_en;                   //o-1,    rd_en to the FIFO
    
    
    
	wire [10:0] rdusedw_ctrl_rx_50g;


	parameter data_def = 256'h0707070707070707_0707070707070707_0707070707070707_0707070707070707;
	parameter ctrl_def = 32'hff_ff_ff_ff;

	reg [15:0] byte_cnt;

	reg rd_en_dly, rd_cnt;

	reg vld_c_bcnt;

	wire [255:0] rx_data;
	wire [31:0] rx_ctrl;

	wire [31:0] c_byte_cnt;
	wire [8:0] bcnt_usedw;

	wire bcnt_fifo_empty, rx_wr_full, rx_rd_empty;

	reg [5:0] x2c_state;

    wire 	x2c_idle_st;
    wire	x2c_bcnt_st;
    wire	x2c_wdcnt_st;
    wire	x2c_rddata_st;
    wire	x2c_done_st;


    //===================================
    //X2C State Machine
    //===================================

    parameter [5:0]
    		X2C_IDLE = 6'h01,				//Idle State
    		X2C_BCNT = 6'h02,               //Byte Count State
    		X2C_WDCNT = 6'h04,              //Word Count State
    		X2C_RDDATA = 6'h08,             //Read Data State
    		X2C_DONE = 6'h10;               //Done State

    assign x2c_idle_st   = x2c_state[0];
    assign x2c_bcnt_st   = x2c_state[1];
    assign x2c_wdcnt_st  = x2c_state[2];
    assign x2c_rddata_st = x2c_state[3];
    assign x2c_done_st   = x2c_state[4];


	always @ (posedge x_clk) begin
		if(!reset_) begin
			rd_en       <= 1'b0;
			byte_cnt    <= 16'd0;
			data_out	<= data_def;
			ctrl_out	<= ctrl_def;
			rd_en_dly	<= 1'b0;
			rd_cnt		<= 1'b0;
			vld_c_bcnt	<= 1'b0;
		end
		else begin
			rd_en_dly   <=  rd_en;
			data_out    <= (rd_en_dly) ? rx_data : data_def;
			ctrl_out    <= (rd_en_dly) ? rx_ctrl : ctrl_def;
			case (x2c_state)

				X2C_IDLE : begin
					rd_en <= 1'b0;
					byte_cnt <= 16'd0;

					rd_cnt <= (!bcnt_fifo_empty) ? 1'b1 :
							1'b0
							;
				end

				X2C_BCNT : begin
					rd_cnt 		<= 1'b0;
				end

				X2C_WDCNT : begin
					//sof n eof in same data then decrement bcnt first
					if (c_byte_cnt[23]) begin

						byte_cnt <= (c_byte_cnt[31]) ? c_byte_cnt[15:0] - 16'd4 :
					    		(c_byte_cnt[30]) ? c_byte_cnt[15:0] - 16'd8 :
					    		(c_byte_cnt[29]) ? c_byte_cnt[15:0] - 16'd12 :
					    		(c_byte_cnt[28]) ? c_byte_cnt[15:0] - 16'd16 :
					    		(c_byte_cnt[27]) ? c_byte_cnt[15:0] - 16'd20 :
					    		(c_byte_cnt[26]) ? c_byte_cnt[15:0] - 16'd24 :
					    		(c_byte_cnt[25]) ? c_byte_cnt[15:0] - 16'd28 :
					    		c_byte_cnt[15:0] - 16'd32
					    		;

					end else begin
						byte_cnt 	<= c_byte_cnt;
					end

					//used only when sof and eof not together.
					vld_c_bcnt	<= (!c_byte_cnt[23]);

				end

				X2C_RDDATA : begin
					byte_cnt <=
							(byte_cnt[15:0] <  16'd32) ? 16'd0	:
							(byte_cnt[15:0] == 16'd0)  ? 16'd0	:
							(c_byte_cnt[31] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd4 	:
							(c_byte_cnt[30] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd8 	:
							(c_byte_cnt[29] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd12 :
							(c_byte_cnt[28] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd16 :
							(c_byte_cnt[27] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd20 :
							(c_byte_cnt[26] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd24 :
							(c_byte_cnt[25] & vld_c_bcnt) ? byte_cnt[15:0] - 16'd28 :
                            (byte_cnt[15:0] - 16'd32)
							;

					//make low after one clock.
					vld_c_bcnt <= 1'b0;

					rd_en <= (byte_cnt > 16'd0) ? 1'b1 :
							1'b0
							;
				end

				X2C_DONE : begin
					byte_cnt <= 16'd0;
				end

			endcase

		end
	end

    //Byte Count FIFO for slow speeds
	fifo_nx32 #(.DEPTH(256), .PTR(8)) x2c_bcnt_fifo_256x32 (                   
    	.reset_    (reset_),

    	.wrclk     (x_clk),
    	.wren      (x_bcnt_we),
    	.wrdata    (x_byte_cnt),
    	.wrfull    (),
    	.wrempty   (),
    	.wrusedw   (),

    	.rdclk     (x_clk),
    	.rden      (rd_cnt),
    	.rddata    (c_byte_cnt),
    	.rdempty   (bcnt_fifo_empty),
    	.rdfull    (),
    	.rdusedw   (bcnt_usedw)
    );

    wire [10:0] rdusedw_data_rx_50g;

    //Data FIFO for slow speeds
	fifo_nx256 #(.DEPTH(1024), .PTR(10))  x2c_data_fifo_1024x256 (                  
    	.reset_    (reset_),

    	.wrclk     (x_clk),
    	.wren      (x_we),
    	.wrdata    (data_in),
    	.wrfull    (rx_wr_full),
    	.wrempty   (),
    	.wrusedw   (),

    	.rdclk     (x_clk),
    	.rden      (rd_en),
    	.rddata    (rx_data),
    	.rdempty   (rx_rd_empty),
    	.rdfull    (),
    	.rdusedw   (rdusedw_data_rx_50g)
    );

    //Ctrl FIFO for slow speeds
    fifo_nx32 #(.DEPTH(1024), .PTR(10)) x2c_ctrl_fifo_1024x32 (                          
    	.reset_    (reset_),

    	.wrclk     (x_clk),
    	.wren      (x_we),
    	.wrdata    (ctrl_in),
    	.wrfull    (),
    	.wrempty   (),
    	.wrusedw   (),

    	.rdclk     (x_clk),
    	.rden      (rd_en),
    	.rddata    (rx_ctrl),
    	.rdempty   (),
    	.rdfull    (),
    	.rdusedw   (rdusedw_ctrl_rx_50g)
    );



    always @ (posedge x_clk) begin
    	if (!reset_)
    		x2c_state <= X2C_IDLE;
    	else begin

    		if (x2c_idle_st)                  //Go to byte count state if
    			x2c_state <= (!bcnt_fifo_empty) ? X2C_BCNT :
    					X2C_IDLE
    					;

    		else if (x2c_bcnt_st)             //Go to wdcnt state
    			x2c_state <= X2C_WDCNT;

    		else if (x2c_wdcnt_st)            //Go to read data state
    			x2c_state <= X2C_RDDATA;

    		else if (x2c_rddata_st)           //Go to Done state if the decrementing byte count is 0
    			x2c_state <= (byte_cnt == 16'd0) ? X2C_DONE :
    					X2C_RDDATA
    					;

    		else if (x2c_done_st)             //Go to Idle state
    			x2c_state <= X2C_IDLE;

    	end
    end



    //============== Simulation ONLY =======================//
    //synopsys translate_off
    
    reg [64*8-1:0] ascii_x2c_state;
    
    always@(x2c_state) begin
            case(x2c_state)
                X2C_IDLE 	  		:  	ascii_x2c_state = "X2C_IDLE";
                X2C_BCNT 	  		:  	ascii_x2c_state = "X2C_BCNT";
                X2C_WDCNT 	 		:  	ascii_x2c_state = "X2C_WDCNT";
                X2C_RDDATA 			:	ascii_x2c_state = "X2C_RDDATA";
                X2C_DONE 	  		:   ascii_x2c_state = "X2C_DONE";
            endcase
    end
    //synopsys translate_on


endmodule