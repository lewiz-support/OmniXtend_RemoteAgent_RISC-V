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

module tx_100G_wrap(
    usr_clk,				    // i-1, clk depends on speed_mode
    x_clk,				  	    // i-1, clk depends on speed_mode
    usr_rst_,				    // i-1, reset

   	mode_100G ,				    // i-1, speed_modes
   	mode_10G ,				    // i-1
	mode_50G  ,				    // i-1
	mode_40G,	                // i-1
	mode_25G,			        // i-1

	//tx_encap interface
    mac_addr0,				    // i-48
    mac_pause_value,		    // i-32
    tx_b2b_dly,			 	    // i-2

    txfifo_dout,			    // i-256
    txfifo_empty,			    // i-1
    pre_txfifo_rd_en_100G,      // o-1, read data from tx_fifo

	rx_pause,				    // i-1
    rx_pvalue,				    // i-16
	pre_rx_pack_100G,		    // o-1, output to rx

	xreq,					    // i-1
	xon,				        // i-1
	pre_xdone_100G,			    // o-1, output to internal wire in tcore

    xaui_mode,				    // i-1

    pre_cgmii_txd,			    // o-256
    pre_cgmii_txc,	            // o-32

    PRE_FMAC_TX_PKT_CNT_100G,   // o-32
    PRE_FMAC_TX_BYTE_CNT_100G,	// o-32

    fmac_tx_clr_en	            // i-1

    );


    parameter					DATA_WIDTH = 256,
	  	  						CTRL_WIDTH = 32;

	input 						usr_clk;                    // i-1, clk depends on speed_mode
	input 						x_clk;                      // i-1, clk depends on speed_mode
	input 						usr_rst_;                   // i-1, reset

	input						mode_100G ;   		        // i-1, speed_modes
	input						mode_10G  ;                 // i-1
	input						mode_50G  ;                 // i-1
	input						mode_40G;                   // i-1
	input						mode_25G;			        // i-1

	//tx_encap interface
	input [47:0] 				mac_addr0;			        // i-48
	input [31:0] 				mac_pause_value;	        // i-32
	input [1:0]  				tx_b2b_dly;			        // i-2

	input [DATA_WIDTH - 1:0] 	txfifo_dout;                // i-256
	input 						txfifo_empty;               // i-1
	output 						pre_txfifo_rd_en_100G;      // o-1

	input 						rx_pause;			        // i-1
	input [15:0] 				rx_pvalue;			        // i-16
	output 						pre_rx_pack_100G;	        // o-1

	input						xreq;                       // i-1
	input						xon;                        // i-1
	output						pre_xdone_100G;             // o-1

	input						xaui_mode;                  // i-1

	output [DATA_WIDTH - 1:0] 	pre_cgmii_txd;              // o-256
	output [CTRL_WIDTH - 1:0]	pre_cgmii_txc;              // o-32

	output [31:0] 				PRE_FMAC_TX_PKT_CNT_100G;   // o-32
	output [31:0] 				PRE_FMAC_TX_BYTE_CNT_100G;	// o-32

	input 						fmac_tx_clr_en;             // i-1

	wire [DATA_WIDTH - 1:0] 	entx2ram_wdata;
	wire [15:0] 				rbytes;
	wire 						rts_100G;
	wire 						cts_100G;
	wire						tx_dvld;


	reg							mode_100G_buf ;
	reg							mode_10G_buf  ;
	reg							mode_50G_buf  ;
	reg							mode_40G_buf;
	reg							mode_25G_buf;


    always @(posedge x_clk) begin
	    //buffer
		mode_100G_buf    	<=	mode_100G ;
		mode_10G_buf    	<=	mode_10G ;
		mode_50G_buf     	<=	mode_50G  ;
		mode_40G_buf		<=	mode_40G;
		mode_25G_buf		<=  mode_25G;
	end


    tx_encap_100G tx_encap_100G(
        .clk					(x_clk),			        // i-1
        .rst_					(usr_rst_),			        // i-1

        .mode_100G 				(mode_100G_buf),		    // i-1, speed_modes
        .mode_10G  				(mode_10G_buf),		        // i-1
        .mode_50G				(mode_50G_buf),	            // i-1
        .mode_40G				(mode_40G_buf),             // i-1
        .mode_25G				(mode_25G_buf),	            // i-1

        .rts					(rts_100G),			        // o-1, Request to send data to tx_xgmii.
        .wdata					(entx2ram_wdata),			// o-256, Data_out
        .rbytes					(rbytes),			        // o-16, holds the data size in Bytes

        .psaddr					(mac_addr0),			    // i-48, pause source address, source mac address in the pause frame to transmit
        .mac_pause_value		(mac_pause_value),          // i-32, [31:16] = tx_pause_value,	[15:0] = rx_pause_value
        .tx_b2b_dly				(tx_b2b_dly),		        // i-2

        .rx_pause				(rx_pause),		            // i-1
        .rx_pvalue				(rx_pvalue),		        // i-16
        .rx_pack				(pre_rx_pack_100G),		    // o-1

        .txfifo_empty			(txfifo_empty),		        // indicates when the FIFO is empty
        .txfifo_rd_en			(pre_txfifo_rd_en_100G),	// read signal for FIFO
        .txfifo_dout			(txfifo_dout),	            // i-256 bits from FIFO

        .xreq					(xreq),			            // i-1, need to transmit a pause frame, pause value is determined by xon
        .xon					(xon),			            // i-1, 1: use tx_pause value as in register , 0: use pause value of 0 to abort the previous pause
        .xdone					(pre_xdone_100G),           // o-1, pause frame has been transmitted
        .tx_dvld				(tx_dvld)                   // o-1
	);


    tx_cgmii tx_cgmii(
        .clk250					(x_clk),	                // i-1, depends on speed_mode
        .clk156					(x_clk),	                // i-1, depends on speed_mode
        .rst_					(usr_rst_),  	            // i-1, RESET

        .mode_100G				(mode_100G_buf),	        // i-1, speed modes
        .mode_50G				(mode_50G_buf),             // i-1
        .mode_40G				(mode_40G_buf),	            // i-1
        .mode_25G				(mode_25G_buf),	            // i-1
        .mode_10G				(mode_10G_buf),	            // i-1

        .xaui_mode				(xaui_mode),                // i-1

        .rts					(rts_100G),                 // i-1, request to send from encap
        .rdata					(entx2ram_wdata),           // i-256, data input
        .txfifo_dout			(txfifo_dout),	            // i-256 bits from FIFO (previous data of rdata). This will help to calculate the crc earlier.
        .rbytes					(rbytes),	                // i-16, holds the size of data in Bytes
        .cts					(cts_100G),	                // o-1, enable ENCAP to read the next QWD (NOT USED, keep for I/O compatibility)

        .txd					(pre_cgmii_txd),	        // o-256, data_out
        .txc					(pre_cgmii_txc),	        // o-32,  ctrl_out

        .FMAC_TX_PKT_CNT		(PRE_FMAC_TX_PKT_CNT_100G), // o-32
        .FMAC_TX_BYTE_CNT		(PRE_FMAC_TX_BYTE_CNT_100G),// o-32

        .fmac_tx_clr_en			(fmac_tx_clr_en),           // i-1

        .tx_dvld				(tx_dvld)                   // i-1
	);

endmodule
