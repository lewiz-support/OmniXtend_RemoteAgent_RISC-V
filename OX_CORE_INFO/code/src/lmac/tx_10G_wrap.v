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

module tx_10G_wrap(
    usr_clk,					// i-1, clk depends on speed_mode
    x_clk,				  	    // i-1, clk depends on speed_mode
    usr_rst_,				    // i-1, reset

   	mode_10G ,				    // i-1, speed_mode (active only for 10Gig)

    mac_addr0,				    // i-48
    mac_pause_value,		    // i-32
    tx_b2b_dly,			 	    // i-2

    txfifo_dout,			    // i-256
    txfifo_empty,			    // i-1
    pre_txfifo_rd_en_10G,       // o-1

	rx_pause,				    // i-1
    rx_pvalue,				    // i-16
	pre_rx_pack_10G,		    // o-1

	xreq,					    // i-1
	xon,				        // i-1
	pre_xdone_10G,			    // o-1

    xaui_mode,				    // i-1

    pre_xgmii_txd,			    // o-64
    pre_xgmii_txc,	            // o-8

    PRE_FMAC_TX_PKT_CNT_10G,    // o-32
    PRE_FMAC_TX_BYTE_CNT_10G,	// o-32

    fmac_tx_clr_en              // i-1

    );

	input 			usr_clk;				 	// i-1, clk depends on speed_mode
	input 			x_clk;                   	// i-1, clk depends on speed_mode
	input 			usr_rst_;                	// i-1, reset

	input			mode_10G ;               	// i-1, speed_mode (active only for 10Gig)

	input [47:0] 	mac_addr0;               	// i-48
	input [31:0] 	mac_pause_value;         	// i-32
	input [1:0]  	tx_b2b_dly;              	// i-2

	input [255:0] 	txfifo_dout;             	// i-256
	input 			txfifo_empty;            	// i-1
	output 			pre_txfifo_rd_en_10G;    	// o-1

	input 			rx_pause;                	// i-1
	input [15:0] 	rx_pvalue;               	// i-16
	output 			pre_rx_pack_10G;         	// o-1

	input			xreq;                    	// i-1
	input			xon;                     	// i-1
	output			pre_xdone_10G;           	// o-1

	input			xaui_mode;               	// i-1

	output [63:0] 	pre_xgmii_txd;           	// o-64
	output [7:0]	pre_xgmii_txc;           	// o-8

	output [31:0] 	PRE_FMAC_TX_PKT_CNT_10G; 	// o-32
	output [31:0] 	PRE_FMAC_TX_BYTE_CNT_10G;	// o-32

	input			fmac_tx_clr_en;          	// i-1

	wire [255:0] 	entx2ram_wdata;
	wire [15:0] 	rbytes;
	wire 			rts_10G;
	wire 			cts_10G;


	reg	mode_10G_buf ;


    always @(posedge x_clk) begin
		//buffer
		mode_10G_buf    <=	mode_10G ;
	end




    tx_encap_10G tx_encap_10G(
        .clk					(x_clk),     				// i-1
        .rst_					(usr_rst_),                 // i-1

        .mode_10G 				(mode_10G_buf), 			// i-1, speed mode

        .rts					(rts_10G),                  // o-1, Request to send data to tx_xgmii.
        .wdata					(entx2ram_wdata),           // o-256, Data_out
        .rbytes					(rbytes),                   // o-16, holds the data size in Bytes

        .psaddr					(mac_addr0),				// i-48, pause source address, source mac address in the pause frame to transmit
        .mac_pause_value 		(mac_pause_value),			// i-32, [31:16] = tx_pause_value,	[15:0] = rx_pause_value
        .tx_b2b_dly				(tx_b2b_dly),           	// i-2

        .rx_pause				(rx_pause),               	// i-1
        .rx_pvalue				(rx_pvalue),             	// i-16
        .rx_pack				(pre_rx_pack_10G),          // o-1

        .txfifo_empty 			(txfifo_empty),      		// i-1, high if TX_FIFO is empty
        .txfifo_rd_en 			(pre_txfifo_rd_en_10G),		// o-1, read request to the TX_FIFO
        .txfifo_dout 			(txfifo_dout),        		// i-256, output of FIFO to input of this module

        .xreq					(xreq),						// i-1, need to transmit a pause frame, pause value is determined by xon
        .xon					(xon),						// i-1, 1: use tx_pause value as in register , 0: use pause value of 0 to abort the previous pause
        .xdone					(pre_xdone_10G)				// o-1, pause frame has been transmitted
	);

    tx_xgmii tx_xgmii(
        .clk250					(x_clk),					// i-1, 156.25MHz
        .clk156					(x_clk),					// i-1, 156.25MHz
        .rst_					(usr_rst_),					// i-1, RESET
        .mode_10G 				(mode_10G_buf), 	        // i-1, speed mode

        .rts					(rts_10G),					// i-1, request to send from encap
        .rdata					(entx2ram_wdata),			// i-256, data input
        .rbytes					(rbytes),					// i-16, holds the size of data in Bytes
        .cts					(cts_10G),					// o-1, enable ENCAP to read the next QWD (NOT USED, keep for I/O compatibility)

        .xgmii_txd				(pre_xgmii_txd),			// o-64, data_out
        .xgmii_txc				(pre_xgmii_txc),	        // o-8,  ctrl_out

        .FMAC_TX_PKT_CNT		(PRE_FMAC_TX_PKT_CNT_10G), 	// o-32
        .FMAC_TX_BYTE_CNT		(PRE_FMAC_TX_BYTE_CNT_10G),	// o-32

        .fmac_tx_clr_en			(fmac_tx_clr_en)            // i-1
	);

endmodule
