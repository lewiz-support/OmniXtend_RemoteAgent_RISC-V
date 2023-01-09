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

module byte_reordering_wrap(

	clk250,    			//i-1
	x_clk,              //i-1
	reset_,             //i-1
	fmac_rxd_en	,	    //i-1

	xaui_mode,          //i-1

	x_we,				//i-1

	data_in,			//i-256, data
	ctrl_in,		    //i-40, ctrl-32bits + 8 bits of sof/eof markers
	data_out,		    //o-256
	ctrl_out,           //o-32

	init_done,        	//i-1
	br_sof,		        //o-8

	RAW_FRAME_CNT,		//o-32
	rx_auto_clr_en,     //i-1
	linkup              //o-1

	);

	parameter DATA_WIDTH = 256;
	parameter CTRL_WIDTH = 32;

	input clk250;      			//i-1
	input x_clk;                //i-1
	input reset_;               //i-1
	input fmac_rxd_en;          //i-1

	input xaui_mode;            //i-1
	input x_we;                 //i-1

	input [DATA_WIDTH - 1:0] data_in;   	//i-256, data
	input [39:0] ctrl_in;                   //i-40, ctrl-32bits + 8 bits of sof/eof markers

	output [DATA_WIDTH - 1:0] data_out;     //o-256
	output [CTRL_WIDTH - 1:0] ctrl_out;     //o-32

	input init_done;       			//i-1

	output [7:0] br_sof;        	//o-8

	output [31:0] RAW_FRAME_CNT;	//o-32

	input		rx_auto_clr_en;   	//i-1
	output 		linkup;             //o-1

	wire [DATA_WIDTH - 1:0] data_in_br;
	wire [39:0] 			ctrl_in_br;

	wire br_wr_full_d;
	wire br_wr_full_c;
	wire br_wr_full = br_wr_full_d || br_wr_full_c;

	wire br_rd_empty;
	wire br_rd_en;

	wire br_rd_empty_d;
	wire br_rd_empty_c;

	//assign  br_rd_empty = br_rd_empty_d || br_rd_empty_c;

	wire [10:0] rdusedw_data_br;
	wire [10:0] rdusedw_ctrl_br;

	tcore_byte_reordering tcore_byte_reordering (
        .clk250			(clk250),		  		//i-1
        .x_clk			(x_clk),                //i-1
        .reset_			(reset_),               //i-1
        .fmac_rxd_en	(fmac_rxd_en),	        //i-1

        .xaui_mode		(1'b1),		            //i-1

        .data_in		(data_in_br),		    //i-256
        .ctrl_in		(ctrl_in_br),		    //i-32
        .data_out		(data_out),		        //o-256
        .ctrl_out		(ctrl_out),             //o-32

        .br_sof0		(br_sof[0]),		    //o-1, to rxgmii
        .br_sof4		(br_sof[1]),            //o-1, to rxgmii
        .br_sof8		(br_sof[2]),            //o-1, to rxgmii
        .br_sof12		(br_sof[3]),            //o-1, to rxgmii
        .br_sof16		(br_sof[4]),            //o-1, to rxgmii
        .br_sof20		(br_sof[5]),            //o-1, to rxgmii
        .br_sof24		(br_sof[6]),            //o-1, to rxgmii
        .br_sof28		(br_sof[7]),		    //o-1, to rxgmii

        .RAW_FRAME_CNT	(RAW_FRAME_CNT),        //o-32

        .rx_auto_clr_en	(rx_auto_clr_en),       //i-1
        .init_done		(init_done),		    //i-1
        .linkup			(linkup),               //o-1
        .br_rd_en		(br_rd_en),             //o-1
        .br_rd_empty	(br_rd_empty_d || br_rd_empty_c),          //i-1
        .rdusedw_data	(rdusedw_data_br),      //i-11
        .rdusedw_ctrl	(rdusedw_ctrl_br)		//i-11
	);

	fifo_nx256 #(.DEPTH(1024), .PTR(10))  br_pre_data_fifo_1024x256 (
    	.reset_    (reset_),            //i-1

    	.wrclk     (x_clk),             //i-1, Clk for writing data
    	.wren      (x_we),              //i-1, request to write
    	.wrdata    (data_in),           //i-256, Data coming in
    	.wrfull    (br_wr_full_d),      //o-1, indicates fifo is full or not (To avoid overiding)
    	.wrempty   (),
    	.wrusedw   (),

    	.rdclk     (x_clk),
    	.rden      (br_rd_en),          //i-1, Request to read from FIFO
    	.rddata    (data_in_br), 	    //o-256, Data coming out
    	.rdempty   (br_rd_empty_d),     //o-1, indicates fifo is empty or not (to avoid underflow)
    	.rdfull    (),
    	.rdusedw   (rdusedw_data_br)    //o-11, 1number of slots currently in use for reading
    );

    fifo_nx40 #(.DEPTH(1024), .PTR(10)) br_pre_ctrl_fifo_1024x40 (
    	.reset_    (reset_),		    //i-1

    	.wrclk     (x_clk),             //i-1, Clk for writing data
    	.wren      (x_we),              //i-1, request to write
    	.wrdata    (ctrl_in),           //i-40, Data coming in
    	.wrfull    (br_wr_full_c),      //o-1, indicates fifo is full or not (To avoid overiding)
    	.wrempty   (),
    	.wrusedw   (),

    	.rdclk     (x_clk),	           //i-1, Clk for reading data
    	.rden      (br_rd_en),         //i-1, Request to read from FIFO
    	.rddata    (ctrl_in_br), 	   //o-40, Data coming out
    	.rdempty   (br_rd_empty_c),    //o-1, indicates fifo is empty or not (to avoid underflow)
    	.rdfull    (),
    	.rdusedw   (rdusedw_ctrl_br)   //o-1, 1number of slots currently in use for reading
    );

endmodule