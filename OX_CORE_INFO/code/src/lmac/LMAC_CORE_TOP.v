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

module LMAC_CORE_TOP
	(

		// Clocks and Reset
		clk,					// i-1, User Clock, Depends on the speed_mode
		xA_clk,					// i-1, Depends on the speed_mode
		reset_,					// i-1, FMAC specific reset

		mode_10G,  		   		//i-1
		mode_25G,   		    //i-1
		mode_40G, 		        //i-1
		mode_50G,               //i-1
		mode_100G,   		    //i-1

		TCORE_MODE,	      	    //i-1, Always tie to 1

		// Interface to TX PATH
		tx_mac_wr,				// i-1
		tx_mac_data,			// i-256
		tx_mac_full,			// o-1
		tx_mac_usedw,			// o-13

		// Interface to RX PATH
		rx_mac_data,			// o-256
		rx_mac_ctrl,			// o-32, rsvd, pkt_end, pkt_start
		rx_mac_empty,			// o-1
		rx_mac_rdusedw,			// o-13
		rx_mac_rd,				// i-1

		//for field debug
		rx_mac_full_dbg,		//o-1
		rx_mac_usedw_dbg,		//o-12

		//for pre_CS/parser (I/F to RX Path/EXTR)
		cs_fifo_rd_en 	,		//i-1
		cs_fifo_empty 	,		//o-1
		ipcs_fifo_rdusedw,		//o-10
		ipcs_fifo_dout	,	    //o-64

		//CGMII-signals
		cgmii_reset_  ,			//i-1
        cgmii_txd ,	            //o-256
        cgmii_txc ,	            //o-32

		cgmii_rxd	,	       	//i-256
        cgmii_rxc ,	            //i-32
        cgmii_led_ ,	        //i-2

		xauiA_linkup,			//o-1

		// From central decoder
		host_addr_reg,			// i-16
		SYS_ADDR,				//i-4, system assigned addr for the FMAC

		// From mac_register
		fail_over,				// i-1
		fmac_ctrl,				// i-32
		fmac_ctrl1,				// i-32

		fmac_rxd_en	,			//i-1, 13jul11

		mac_pause_value,		// i-32
		mac_addr0, 				// i-48

		reg_rd_start,			// i-1
		reg_rd_done_out,		// o-1

		FMAC_REGDOUT,			// o-32
		FIFO_OV_IPEND			// o-1

	);

    parameter 	DATA_WIDTH  = 256;	//default
    parameter 	CTRL_WIDTH  = 32;
    parameter	FMAC_ID     = 10;


    input		clk;				//i-1
    input		xA_clk; 		    //i-1
    input		reset_;             //i-1

    input		mode_10G; 		    //i-1
    input		mode_25G;   		//i-1
    input		mode_40G;		    //i-1
    input		mode_50G;           //i-1
    input		mode_100G;   		//i-1

    input		TCORE_MODE;         //i-1

    input		tx_mac_wr;      	//i-1

    input 	[DATA_WIDTH - 1:0]	tx_mac_data; 		//i-256
    output						tx_mac_full;        //o-1
    output 	[12:0]				tx_mac_usedw;       //o-13

    output 	[DATA_WIDTH - 1:0]	rx_mac_data;        //o-256
    output 	[CTRL_WIDTH - 1:0]	rx_mac_ctrl;        //o-32

    output 						rx_mac_empty;       //o-1
    output	[12:0]				rx_mac_rdusedw;		//o-13
    input						rx_mac_rd;          //i-1

    output						rx_mac_full_dbg;    //o-1
    output	[11:0]				rx_mac_usedw_dbg;   //o-12

    input						cs_fifo_rd_en;		//i-1
    output						cs_fifo_empty;		//o-1
    output	[9:0]				ipcs_fifo_rdusedw;	//o-10

    output	[63:0]				ipcs_fifo_dout	;	//o-64

    input			 			cgmii_reset_  ;     //i-1
    output	[DATA_WIDTH - 1:0] 	cgmii_txd ;		    //o-256
    output	[CTRL_WIDTH - 1:0] 	cgmii_txc ;		    //o-32
    input	[DATA_WIDTH - 1:0] 	cgmii_rxd ;	        //i-256
    input	[CTRL_WIDTH - 1:0] 	cgmii_rxc ;	        //i-32
    input	[1:0]        		cgmii_led_ ;	    //i-2

    output			xauiA_linkup;					// to LED on board

    // From central decoder
    input [15:0]	host_addr_reg;
    input [3:0]		SYS_ADDR;

    // From mac_register
    input			fail_over;
    input [31:0]	fmac_ctrl;
    input [31:0]	fmac_ctrl1;

    input			fmac_rxd_en	;

    input [31:0]	mac_pause_value;	// [31:16] = tx_pause_value to send a pause frame, [15:0] = rx_pause_value (not implement)
    input [47:0]	mac_addr0;			// mac_addr to check in non-promiscuous mode

    input			reg_rd_start;

    output			reg_rd_done_out;

    output [31:0]	FMAC_REGDOUT;
    output			FIFO_OV_IPEND;



    wire 		cs_fifo_rd_en 	;
    wire 		cs_fifo_empty 	;
    wire [9:0]	ipcs_fifo_rdusedw;
    wire [63:0]	ipcs_fifo_dout	;

    wire [31:0] FMAC_TX_PKT_CNT;
    wire [31:0] FMAC_RX_PKT_CNT_LO;
    wire [31:0] FMAC_RX_PKT_CNT_HI;
    wire [31:0]	FMAC_TX_BYTE_CNT;
    wire [31:0] FMAC_RX_BYTE_CNT_LO;
    wire [31:0] FMAC_RX_BYTE_CNT_HI;
    wire [31:0]	FMAC_RX_UNDERSIZE_PKT_CNT;
    wire [31:0]	FMAC_RX_CRC_ERR_CNT;
    wire [31:0] FMAC_DCNT_OVERRUN;
    wire [31:0] FMAC_DCNT_LINK_ERR;
    wire [31:0]	FMAC_PKT_CNT_OVERSIZE;
    wire [31:0]	FMAC_PKT_CNT_JABBER;
    wire [31:0]	FMAC_PKT_CNT_FRAGMENT;
    wire [31:0]	RAW_FRAME_CNT;

    reg  [31:0]	BAD_FRAMESOF_CNT ;

    wire [32:0] FMAC_RX_PKT_CNT64_LO;
    wire [31:0] FMAC_RX_PKT_CNT64_HI;

    wire [32:0] FMAC_RX_PKT_CNT127_LO;
    wire [31:0] FMAC_RX_PKT_CNT127_HI;

    wire [32:0] FMAC_RX_PKT_CNT255_LO;
    wire [31:0] FMAC_RX_PKT_CNT255_HI;

    wire [32:0] FMAC_RX_PKT_CNT511_LO;
    wire [31:0] FMAC_RX_PKT_CNT511_HI;

    wire [32:0] FMAC_RX_PKT_CNT1023_LO;
    wire [31:0] FMAC_RX_PKT_CNT1023_HI;

    wire [32:0] FMAC_RX_PKT_CNT1518_LO;
    wire [31:0] FMAC_RX_PKT_CNT1518_HI;

    wire [32:0] FMAC_RX_PKT_CNT2047_LO;
    wire [31:0] FMAC_RX_PKT_CNT2047_HI;

    wire [32:0] FMAC_RX_PKT_CNT4095_LO;
    wire [31:0] FMAC_RX_PKT_CNT4095_HI;

    wire [32:0] FMAC_RX_PKT_CNT8191_LO;
    wire [31:0] FMAC_RX_PKT_CNT8191_HI;

    wire [32:0] FMAC_RX_PKT_CNT9018_LO;
    wire [31:0] FMAC_RX_PKT_CNT9018_HI;

    wire [32:0] FMAC_RX_PKT_CNT9022_LO;
    wire [31:0] FMAC_RX_PKT_CNT9022_HI;

    wire [32:0] FMAC_RX_PKT_CNT9199P_LO;
    wire [31:0] FMAC_RX_PKT_CNT9199P_HI;


    wire	[31:0]	STAT_GROUP_LO_DOUT	;
    wire	[31:0]	STAT_GROUP_HI_DOUT	;
    wire	[9:0]	STAT_GROUP_addr		;
    wire			STAT_GROUP_sel	;
    wire			fmac_rx_clr_en	;

    wire			fmac_tx_clr_en	;
    wire			xauiA_linkup;
    wire			linkup_100g;
    wire			linkup_50g;
    wire			x_we;

    wire			reg_rd_start;
    reg				reg_rd_done;
    reg				reg_rd_done_out;
    wire [CTRL_WIDTH - 1:0] 	rxc_reorder;
    wire [DATA_WIDTH - 1:0] 	rxd_reorder;

    wire	[7:0]	br_sof ;

    wire	[DATA_WIDTH - 1:0]	br_data_in;
    wire	[39:0]  br_ctrl_in;

    reg		tx_auto_clr_en;
    reg		rx_auto_clr_en;
    reg		[31:0]	fmac_ctrl_dly	;
    reg		[31:0]	fmac_ctrl1_dly	;

    reg		[DATA_WIDTH - 1 : 0] pre_br_data;
    reg		[CTRL_WIDTH - 1 : 0] pre_br_ctrl;

    wire	[DATA_WIDTH - 1 : 0] rx_data_in, rx_data;
    wire	[CTRL_WIDTH - 1 : 0] rx_ctrl_in, rx_ctrl;

    reg		mode_10G_buf ;
    reg		mode_25G_buf  ;
    reg		mode_40G_buf;
    reg		mode_50G_buf  ;
    reg		mode_100G_buf;

    wire [31:0] x_byte_cnt;

    wire rx_x_we, x_bcnt_we, fifo_rd_en;
    reg		linkup;

    assign xauiA_linkup = linkup ;


    //REG_IF for BAD_SOF_CNT
    reg sof0, sof1, sof2, sof3, sof4, sof5, sof6, sof7;

    reg eof0, eof1, eof2, eof3, eof4, eof5, eof6, eof7;

    reg bad_frame_nosof, bad_frame_noeof, unknown_sof_sticky;

    reg has_sof;

    reg fmac_rxd_en_reg	;

    reg [31:0] bad_framesof_cnt_reg;

    reg 		cntr_50g ;
    reg 		cntr_40g ;
    reg [1:0] 	cntr_25g ;
    reg [1:0] 	cntr_10g ;
    reg 		nxt_pkt  ;


    always @(posedge xA_clk) begin							// 20220620 change it to xA_clk from clk
        tx_auto_clr_en	<=	fmac_ctrl[6];
        rx_auto_clr_en	<=	fmac_ctrl[7];

        //rebuffering
        fmac_ctrl_dly	<=	fmac_ctrl	;

        fmac_ctrl1_dly[31:18]	<=	fmac_ctrl1[31:18]	;
        fmac_ctrl1_dly[17:16]	<=	2'b00	;
        fmac_ctrl1_dly[15:0]	<=	fmac_ctrl1[15:0]	;

    end



    always @(posedge xA_clk) begin						  	// 20220620 change it to xA_clk from clk
	    //buffer
        mode_10G_buf    <=	mode_10G;
        mode_25G_buf    <=	mode_25G;
        mode_40G_buf	<=	mode_40G;
        mode_50G_buf    <=	mode_50G;
        mode_100G_buf	<=	mode_100G;
    end


    tcore_fmac_core core (
        .usr_clk					(clk), 					// i-1	156.25 Mhz
        .x_clk 	  					(xA_clk),  			    // i-1	156.25 Mhz
        .usr_rst_ 					(reset_),    			// i-1

        .mode_10G					(mode_10G),				// i-1, speed modes
        .mode_25G					(mode_25G),		        // i-1
        .mode_40G					(mode_40G),	 	        // i-1
        .mode_50G					(mode_50G),             // i-1
        .mode_100G					(mode_100G),		    // i-1

        .TCORE_MODE					(TCORE_MODE),	     	// i-1

        // register config
        .tx_xo_en					(fmac_ctrl[0]),			// i-1
        .rx_xo_en					(fmac_ctrl[1]),			// i-1
        .bcast_en					(fmac_ctrl[11]),		// i-1
        .prom_mode					(fmac_ctrl[4]),   		// i-1
        .mac_addr0					(mac_addr0),    		// i-48
        .rx_size					(12'h100),        		// i-12
        .rx_check_crc 				(fmac_ctrl[3]),   		// i-1 , CRC_EN bit

        // txfifo interface
        .txfifo_din 				(tx_mac_data),    		// i-256
        .txfifo_wr_en 				(tx_mac_wr),    		// i-1
        .txfifo_full 				(tx_mac_full),   		// o-1
        .txfifo_usedw 				(tx_mac_usedw), 		// o-13

        // tx_encap interface
        .mac_pause_value			(mac_pause_value), 		// i-32
        .tx_b2b_dly					(fmac_ctrl[9:8]),		// i-2

        // rxfifo interface
        .rxfifo_rd_en 				(rx_mac_rd),     		// i-1
        .rxfifo_dout 				(rx_mac_data),    		// o-256
        .rxfifo_ctrl_dout			(rx_mac_ctrl),			// o-32
        .rxfifo_empty 				(rx_mac_empty),  		// o-1  (rdempty 250MHz)
        .rxfifo_rdusedw				(rx_mac_rdusedw),		// o-13

        //for debug
        .rxfifo_full_dbg			(rx_mac_full_dbg),		//o-1
        .rxfifo_usedw_dbg			(rx_mac_usedw_dbg),		//o-12

        .drx_pkt_data 				(),						//o-256
        .drx_pkt_start 				(),     				//o-1
        .drx_pkt_end 				(),     				//o-1
        .drx_pkt_we 				(),     				//o-1
        .drx_pkt_beat_bcnt 			(),  					//o-3
        .drx_pkt_be 				(),     				//o-32
        .drx_crc32 					(),     				//o-32
        .drx_crc_vld 				(),     				//o-1
        .drx_crc_err 				(),     				//o-1
        .drx_crc_err_dly1 			(),     				//o-1

        //pre-parser FIFO
        .cs_fifo_rd_en				(cs_fifo_rd_en),		//i-1
        .ipcs_fifo_dout				(ipcs_fifo_dout),  		//o-64, {32'b0, fpseudo, fast_ipsum}
        .cs_fifo_empty				(cs_fifo_empty),		//o-1, for EXTR
        .ipcs_fifo_rdusedw			(ipcs_fifo_rdusedw),	//o-10

        // rx_cgmii
        .cgmii_rxc					(rxc_reorder),			//i-32
        .cgmii_rxd					(rxd_reorder),			//i-256
        .cgmii_rxp					(8'h00),       			//i-8, intended for PORT ID but not used (use fmac_id)

        .br_sof						(br_sof),	          	//i-8

        .fmac_ctrl1_dly				(fmac_ctrl1_dly),		//i-32
        .fmac_rxd_en				(fmac_rxd_en),			//i-1

        // tx_cgmii
        .cgmii_txc					(cgmii_txc),			//o-32
        .cgmii_txd					(cgmii_txd),	        //o-256

        // to mac_register.v
        .FMAC_TX_PKT_CNT			(FMAC_TX_PKT_CNT),  	// o-32
        .FMAC_RX_PKT_CNT_LO			(FMAC_RX_PKT_CNT_LO),	// o-32
        .FMAC_RX_PKT_CNT_HI			(FMAC_RX_PKT_CNT_HI),	// o-32

        .FMAC_TX_BYTE_CNT			(FMAC_TX_BYTE_CNT),		// o-32
        .FMAC_RX_BYTE_CNT_LO		(FMAC_RX_BYTE_CNT_LO),  // o-32
        .FMAC_RX_BYTE_CNT_HI		(FMAC_RX_BYTE_CNT_HI),  // o-32

        .STAT_GROUP_LO_DOUT			(STAT_GROUP_LO_DOUT),	//o-32
        .STAT_GROUP_HI_DOUT			(STAT_GROUP_HI_DOUT),	//o-32
        .STAT_GROUP_addr			(STAT_GROUP_addr) ,		//i-10
        .STAT_GROUP_sel				(STAT_GROUP_sel) ,		//i-1
        .fmac_rx_clr_en				(fmac_rx_clr_en),		//i-1

        .fmac_tx_clr_en				(fmac_tx_clr_en),
        .FMAC_RX_UNDERSIZE_PKT_CNT	(FMAC_RX_UNDERSIZE_PKT_CNT),	// o-32	[CORE]
        .FMAC_RX_CRC_ERR_CNT		(FMAC_RX_CRC_ERR_CNT),			// o-32
        .FMAC_DCNT_OVERRUN			(FMAC_DCNT_OVERRUN),			// o-32
        .FMAC_DCNT_LINK_ERR			(FMAC_DCNT_LINK_ERR),			// o-32
        .FMAC_PKT_CNT_OVERSIZE		(FMAC_PKT_CNT_OVERSIZE),		// o-32
        .FIFO_OV_IPEND				(FIFO_OV_IPEND),				// o-1

        .FMAC_PKT_CNT_JABBER		(FMAC_PKT_CNT_JABBER),			// o-32
        .FMAC_PKT_CNT_FRAGMENT		(FMAC_PKT_CNT_FRAGMENT),		// o-32

        .FMAC_RX_PKT_CNT64_LO		(FMAC_RX_PKT_CNT64_LO   ),
        .FMAC_RX_PKT_CNT64_HI		(FMAC_RX_PKT_CNT64_HI   ),

        .FMAC_RX_PKT_CNT127_LO		(FMAC_RX_PKT_CNT127_LO  ),
        .FMAC_RX_PKT_CNT127_HI		(FMAC_RX_PKT_CNT127_HI  ),

        .FMAC_RX_PKT_CNT255_LO		(FMAC_RX_PKT_CNT255_LO  ),
        .FMAC_RX_PKT_CNT255_HI		(FMAC_RX_PKT_CNT255_HI  ),

        .FMAC_RX_PKT_CNT511_LO		(FMAC_RX_PKT_CNT511_LO  ),
        .FMAC_RX_PKT_CNT511_HI		(FMAC_RX_PKT_CNT511_HI  ),

        .FMAC_RX_PKT_CNT1023_LO		(FMAC_RX_PKT_CNT1023_LO ),
        .FMAC_RX_PKT_CNT1023_HI		(FMAC_RX_PKT_CNT1023_HI ),

        .FMAC_RX_PKT_CNT1518_LO		(FMAC_RX_PKT_CNT1518_LO ),
        .FMAC_RX_PKT_CNT1518_HI		(FMAC_RX_PKT_CNT1518_HI ),

        .FMAC_RX_PKT_CNT2047_LO		(FMAC_RX_PKT_CNT2047_LO ),
        .FMAC_RX_PKT_CNT2047_HI		(FMAC_RX_PKT_CNT2047_HI ),

        .FMAC_RX_PKT_CNT4095_LO		(FMAC_RX_PKT_CNT4095_LO ),
        .FMAC_RX_PKT_CNT4095_HI		(FMAC_RX_PKT_CNT4095_HI ),

        .FMAC_RX_PKT_CNT8191_LO		(FMAC_RX_PKT_CNT8191_LO ),
        .FMAC_RX_PKT_CNT8191_HI		(FMAC_RX_PKT_CNT8191_HI ),

        .FMAC_RX_PKT_CNT9018_LO		(FMAC_RX_PKT_CNT9018_LO ),
        .FMAC_RX_PKT_CNT9018_HI		(FMAC_RX_PKT_CNT9018_HI ),

        .FMAC_RX_PKT_CNT9022_LO		(FMAC_RX_PKT_CNT9022_LO ),
        .FMAC_RX_PKT_CNT9022_HI		(FMAC_RX_PKT_CNT9022_HI ),

        .FMAC_RX_PKT_CNT9199P_LO 	(FMAC_RX_PKT_CNT9199P_LO),
        .FMAC_RX_PKT_CNT9199P_HI 	(FMAC_RX_PKT_CNT9199P_HI)
	);


	//DONE SIGNAL GENERATION - after 5 clks.
	reg			reg_rd_delay1;
	reg			reg_rd_delay2;
	reg			reg_rd_delay3;
	reg			reg_rd_delay4;


	//buffer signal 'reg_rd_start' for 5 clocks.
	always @ (posedge xA_clk) begin
        if (!reset_) begin
	   		reg_rd_delay1		<=	1'b0;
	        reg_rd_delay2		<=	1'b0;
	        reg_rd_delay3		<=	1'b0;
			reg_rd_delay4		<=	1'b0;
	        reg_rd_done			<=	1'b0;
	        reg_rd_done_out		<=	1'b0;
        end
        else begin
	   		reg_rd_delay1		<=	reg_rd_start;
	        reg_rd_delay2		<=	reg_rd_delay1;
	        reg_rd_delay3		<=	reg_rd_delay2;
	        reg_rd_delay4		<=	reg_rd_delay3;
	        reg_rd_done			<=	reg_rd_delay4;
	        reg_rd_done_out		<=	reg_rd_delay4;
        end
	end

    reg [255:0] cgmii_rxd_bfc;
    reg [ 31:0] cgmii_rxc_bfc;

    //Bad Frame Counter (Part 1/2)
	always @ (posedge xA_clk) begin        
        if (!reset_) begin
            cgmii_rxd_bfc <= 'b0;
            cgmii_rxc_bfc <= 'b0;
        
			sof0 		<=	1'b0;
			sof1 		<=	1'b0;
			sof2 		<=	1'b0;
			sof3 		<=	1'b0;
			sof4 		<=	1'b0;
			sof5 		<=	1'b0;
			sof6 		<=	1'b0;
			sof7 		<=	1'b0;

			eof0 		<=	1'b0;
			eof1 		<=	1'b0;
			eof2 		<=	1'b0;
			eof3 		<=	1'b0;
			eof4 		<=	1'b0;
			eof5 		<=	1'b0;
			eof6 		<=	1'b0;
			eof7 		<=	1'b0;

			bad_frame_nosof     <= 1'b0;
			bad_frame_noeof     <= 1'b0;
			unknown_sof_sticky	<= 1'b0;

			fmac_rxd_en_reg		<= 1'b0;

			has_sof				<= 1'b0;

			bad_framesof_cnt_reg	<= 32'b0;

        end
        else begin
            cgmii_rxd_bfc <= cgmii_rxd;
            cgmii_rxc_bfc <= cgmii_rxc;
        
          	//valid sof
			sof0 		<= sof0 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[7:0]	== 8'hFB) & cgmii_rxc_bfc[0])  | ((cgmii_rxd_bfc[39:32]   == 8'hFB) & cgmii_rxc_bfc[4])  | ((cgmii_rxd_bfc[71:64]	== 8'hFB) & cgmii_rxc_bfc[8])  | ((cgmii_rxd_bfc[103:96] == 8'hFB) & cgmii_rxc_bfc[12]))) ;
			sof4 		<= sof4 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[135:128]== 8'hFB) & cgmii_rxc_bfc[16]) | ((cgmii_rxd_bfc[167:160] == 8'hFB) & cgmii_rxc_bfc[20]) | ((cgmii_rxd_bfc[199:192]	== 8'hFB) & cgmii_rxc_bfc[24]) | ((cgmii_rxd_bfc[231:224]== 8'hFB) & cgmii_rxc_bfc[28]))) ;

			//invalid sof
			sof1 		<= sof1 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[15:8]	== 8'hFB) & cgmii_rxc_bfc[1])  | ((cgmii_rxd_bfc[23:16]	  == 8'hFB) & cgmii_rxc_bfc[2])  | ((cgmii_rxd_bfc[31:24]	== 8'hFB) & cgmii_rxc_bfc[3])  | ((cgmii_rxd_bfc[47:40]  == 8'hFB) & cgmii_rxc_bfc[5] ))) ;
			sof2 		<= sof2 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[55:48]	== 8'hFB) & cgmii_rxc_bfc[6])  | ((cgmii_rxd_bfc[63:56]	  == 8'hFB) & cgmii_rxc_bfc[7])  | ((cgmii_rxd_bfc[79:72]	== 8'hFB) & cgmii_rxc_bfc[9])  | ((cgmii_rxd_bfc[87:80]  == 8'hFB) & cgmii_rxc_bfc[10]))) ;
			sof3 		<= sof3 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[95:88]	== 8'hFB) & cgmii_rxc_bfc[11]) | ((cgmii_rxd_bfc[111:104] == 8'hFB) & cgmii_rxc_bfc[13]) | ((cgmii_rxd_bfc[119:112]	== 8'hFB) & cgmii_rxc_bfc[14]) | ((cgmii_rxd_bfc[127:120]== 8'hFB) & cgmii_rxc_bfc[15]))) ;
			sof5 		<= sof5 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[143:136]== 8'hFB) & cgmii_rxc_bfc[17]) | ((cgmii_rxd_bfc[151:144] == 8'hFB) & cgmii_rxc_bfc[18]) | ((cgmii_rxd_bfc[159:152]	== 8'hFB) & cgmii_rxc_bfc[19]) | ((cgmii_rxd_bfc[175:168]== 8'hFB) & cgmii_rxc_bfc[21]))) ;
			sof6 		<= sof6 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[183:176]== 8'hFB) & cgmii_rxc_bfc[22]) | ((cgmii_rxd_bfc[191:184] == 8'hFB) & cgmii_rxc_bfc[23]) | ((cgmii_rxd_bfc[207:200]	== 8'hFB) & cgmii_rxc_bfc[25]) | ((cgmii_rxd_bfc[215:208]== 8'hFB) & cgmii_rxc_bfc[26]))) ;
			sof7 		<= sof7 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[223:216]== 8'hFB) & cgmii_rxc_bfc[27]) | ((cgmii_rxd_bfc[239:232] == 8'hFB) & cgmii_rxc_bfc[29]) | ((cgmii_rxd_bfc[247:240]	== 8'hFB) & cgmii_rxc_bfc[30]) | ((cgmii_rxd_bfc[255:248]== 8'hFB) & cgmii_rxc_bfc[31]))) ;

			eof0 		<= eof0 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[7:0]	== 8'hFD) & cgmii_rxc_bfc[0])  | ((cgmii_rxd_bfc[15:8]	  == 8'hFD) & cgmii_rxc_bfc[1])  | ((cgmii_rxd_bfc[23:16]	== 8'hFD) & cgmii_rxc_bfc[2])  | ((cgmii_rxd_bfc[31:24]	 == 8'hFD) & cgmii_rxc_bfc[3] ))) ;
			eof1 		<= eof1 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[39:32]	== 8'hFD) & cgmii_rxc_bfc[4])  | ((cgmii_rxd_bfc[47:40]   == 8'hFD) & cgmii_rxc_bfc[5])  | ((cgmii_rxd_bfc[55:48]	== 8'hFD) & cgmii_rxc_bfc[6])  | ((cgmii_rxd_bfc[63:56]	 == 8'hFD) & cgmii_rxc_bfc[7] ))) ;
			eof2 		<= eof2 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[71:64]	== 8'hFD) & cgmii_rxc_bfc[8])  | ((cgmii_rxd_bfc[79:72]   == 8'hFD) & cgmii_rxc_bfc[9])  | ((cgmii_rxd_bfc[87:80]	== 8'hFD) & cgmii_rxc_bfc[10]) | ((cgmii_rxd_bfc[95:88]	 == 8'hFD) & cgmii_rxc_bfc[11]))) ;
			eof3 		<= eof3 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[103:96]	== 8'hFD) & cgmii_rxc_bfc[12]) | ((cgmii_rxd_bfc[111:104] == 8'hFD) & cgmii_rxc_bfc[13]) | ((cgmii_rxd_bfc[119:112]	== 8'hFD) & cgmii_rxc_bfc[14]) | ((cgmii_rxd_bfc[127:120]== 8'hFD) & cgmii_rxc_bfc[15]))) ;
			eof4 		<= eof4 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[135:128]== 8'hFD) & cgmii_rxc_bfc[16]) | ((cgmii_rxd_bfc[143:136] == 8'hFD) & cgmii_rxc_bfc[17]) | ((cgmii_rxd_bfc[151:144]	== 8'hFD) & cgmii_rxc_bfc[18]) | ((cgmii_rxd_bfc[159:152]== 8'hFD) & cgmii_rxc_bfc[19]))) ;
			eof5 		<= eof5 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[167:160]== 8'hFD) & cgmii_rxc_bfc[20]) | ((cgmii_rxd_bfc[175:168] == 8'hFD) & cgmii_rxc_bfc[21]) | ((cgmii_rxd_bfc[183:176]	== 8'hFD) & cgmii_rxc_bfc[22]) | ((cgmii_rxd_bfc[191:184]== 8'hFD) & cgmii_rxc_bfc[23]))) ;
			eof6 		<= eof6 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[199:192]== 8'hFD) & cgmii_rxc_bfc[24]) | ((cgmii_rxd_bfc[207:200] == 8'hFD) & cgmii_rxc_bfc[25]) | ((cgmii_rxd_bfc[215:208]	== 8'hFD) & cgmii_rxc_bfc[26]) | ((cgmii_rxd_bfc[223:216]== 8'hFD) & cgmii_rxc_bfc[27]))) ;
			eof7 		<= eof7 ? 1'b0 : (((mode_25G_buf & cntr_25g == 2'b10) | (!mode_25G_buf)) & (((cgmii_rxd_bfc[231:224]== 8'hFD) & cgmii_rxc_bfc[28]) | ((cgmii_rxd_bfc[239:232] == 8'hFD) & cgmii_rxc_bfc[29]) | ((cgmii_rxd_bfc[247:240]	== 8'hFD) & cgmii_rxc_bfc[30]) | ((cgmii_rxd_bfc[255:248]== 8'hFD) & cgmii_rxc_bfc[31]))) ;

			//Asserted if sof is present
			has_sof				<=	(sof0 | sof4) ? 1'b1:
								  	(eof0 | eof1 | eof2 | eof3 | eof4 | eof5 | eof6 | eof7) ? 1'b0 :
								  	has_sof;

			fmac_rxd_en_reg		<= fmac_rxd_en;

			//bad_frame if eof comes and there is no sof
			bad_frame_nosof     <= (eof0 | eof1 | eof2 | eof3 | eof4 | eof5 | eof6 | eof7) & !has_sof;

			//bad frame if sof comes after sof and before eof of previous packet.
			bad_frame_noeof     <= (sof0  | sof1  | sof2  | sof3  | sof4  | sof5  | sof6  | sof7) & has_sof & !(eof0 | eof1 | eof2 | eof3 | eof4 | eof5 | eof6 | eof7);

			//stays high if there is any invalid packet
			unknown_sof_sticky	<= (sof1  | sof2  | sof3  | sof5  | sof6  | sof7) ? 1'b1 :
			 						unknown_sof_sticky;

			bad_framesof_cnt_reg	<= !fmac_rxd_en_reg ? 32'h0 :
									(bad_frame_nosof | bad_frame_noeof) ? bad_framesof_cnt_reg + 8'd1 :
									bad_framesof_cnt_reg;

	   end
	end

    //Bad Frame Counter (Part 2/2)
	always @ (posedge xA_clk) begin

		if(!reset_) begin
			cntr_25g			<=	 2'b0;
			BAD_FRAMESOF_CNT	<=	32'h0;
		end
		else begin
			//25G: increment counter after every clk
			cntr_25g			<=	(mode_25G_buf) ?	(cntr_25g + 1'b1)	:	2'b0;

			BAD_FRAMESOF_CNT	<=	(rx_auto_clr_en | !fmac_rxd_en) ? 32'h0 :
										{unknown_sof_sticky, bad_framesof_cnt_reg[30:0]} ;
		end
	end



    byte_reordering_wrap byte_reordering_wrap (
        .clk250			(clk),         		//i-1
        .x_clk			(xA_clk),           //i-1
        .reset_			(reset_),           //i-1
        .fmac_rxd_en	(fmac_rxd_en),	    //i-1

        .xaui_mode		(1'b1),             //i-1

        .x_we			(x_we),		        //i-1

        .data_in		(br_data_in),		//i-256, data
        .ctrl_in		(br_ctrl_in),		//i-40, ctrl-32bits + 8 bits of sof/eof markers

        .data_out		(rxd_reorder),		//o-256
        .ctrl_out		(rxc_reorder),      //o-32

        .init_done		(1'b1),             //i-1
        .br_sof			(br_sof),		    //o-8

        .RAW_FRAME_CNT	(RAW_FRAME_CNT),	//o-32
        .rx_auto_clr_en	(rx_auto_clr_en),   //i-1
        .linkup			()                  //o-1

	);

    reg [255:0] cgmii_rxd_100;
    reg [ 31:0] cgmii_rxc_100;
	always @ (posedge xA_clk) begin        
        if (!reset_) begin
            cgmii_rxd_100 <= 'b0;
            cgmii_rxc_100 <= 'b0;
        end
        else begin
            cgmii_rxd_100 <= cgmii_rxd;
            cgmii_rxc_100 <= cgmii_rxc;
	   end
	end

	always @ (posedge xA_clk) begin					// 20220620 change it to xA_clk from clk
		if (!reset_) begin
			pre_br_data <= 256'h0707070707070707070707070707070707070707070707070707070707070707;
			pre_br_ctrl <= 32'hffffffff;
			linkup		<= 1'b0;
		end
		else begin
			//if in 100Gig mode, cgmii_rxd and cgmii_rxc directly goes to the byte reordering.
			pre_br_data <= (mode_100G) ? cgmii_rxd_100 :
                            rx_data;

			pre_br_ctrl <=  (mode_100G) ? cgmii_rxc_100 :
                            rx_ctrl;

			linkup		<=  (mode_100G) ? linkup_100g :
                            (mode_50G|mode_40G|mode_25G|mode_10G) ? linkup_50g :
                            linkup;
		end
	end


    rx_100G rx_100G(
        .x_clk		(xA_clk),           //i-1, Depends on the speed of the device  	// 20220620 change it to xA_clk from clk
        .reset_		(reset_),           //i-1

        .mode_10G	(mode_10G_buf),     //i-1,  10-Gbps speed mode
        .mode_25G	(mode_25G_buf),     //i-1,  25-Gbps speed mode
        .mode_40G	(mode_40G_buf),     //i-1,  40-Gbps speed mode
        .mode_50G	(mode_50G_buf),     //i-1,  50-Gbps speed mode
        .mode_100G	(mode_100G_buf),    //i-1, 100-Gbps speed mode

        .init_done	(1'b1),             //i-1

        .data_in	(pre_br_data),      //i-256, 256-bit Input Data
        .ctrl_in	(pre_br_ctrl),      //i-32, 32-bit Input Ctrl

        .data_out	(br_data_in),       //o-256, 256-bit Output Data to the BR FIFO
        .ctrl_out	(br_ctrl_in),       //o-40, 40-bit Output Ctrl to the BR FIFO

        .x_we		(x_we),             //o-1, Write Data
        .linkup		(linkup_100g)       //o-1, Linkup
    );

    reg [255:0] cgmii_rxd_50g;
    reg [ 31:0] cgmii_rxc_50g;
	always @ (posedge xA_clk) begin        
        if (!reset_) begin
            cgmii_rxd_50g <= 'b0;
            cgmii_rxc_50g <= 'b0;
        end
        else begin
            cgmii_rxd_50g <= cgmii_rxd;
            cgmii_rxc_50g <= cgmii_rxc;
	   end
	end

    rx_50G rx_50G (
        .x_clk		(xA_clk),          	//i-1, Depends on the speed of the device  		// 20220620 change it to xA_clk from clk
        .reset_		(reset_),           //i-1

        .mode_10G	(mode_10G),         //i-1,  10-Gbps speed mode
        .mode_25G	(mode_25G),         //i-1,  25-Gbps speed mode
        .mode_40G	(mode_40G),         //i-1,  40-Gbps speed mode
        .mode_50G	(mode_50G),         //i-1,  50-Gbps speed mode
        .mode_100G	(mode_100G),        //i-1, 100-Gbps speed mode

        .init_done	(1'b1),             //i-1

        .data_in	(cgmii_rxd_50g),    //i-256, 256-bit Input  Data
        .ctrl_in	(cgmii_rxc_50g),    //i-32,   32-bit Input  Ctrl
        .data_out	(rx_data_in),       //o-256, 256-bit Output Data
        .ctrl_out	(rx_ctrl_in),       //o-32,   32-bit Output Ctrl

        .x_we		(rx_x_we),          //o-1, Write Data
        .x_bcnt_we	(x_bcnt_we),        //o-1
        .x_byte_cnt	(x_byte_cnt),       //o-32
        .linkup		(linkup_50g)        //o-1, Linkup

	);


    x2c_ctrl x2c_ctrl(
        .x_clk		(xA_clk),           //i-1, Depends on the speed of the device 	// 20220620 change it to xA_clk from clk
        .reset_		(reset_),           //i-1,

        .mode_10G	(mode_10G),         //i-1, 10-Gbps speed mode
        .mode_25G	(mode_25G),         //i-1, 25-Gbps speed mode
        .mode_40G	(mode_40G),         //i-1, 40-Gbps speed mode
        .mode_50G	(mode_50G),         //i-1, 50-Gbps speed mode
        .mode_100G	(mode_100G),        //i-1, 100-Gbps speed mode

        .data_in	(rx_data_in),       //i-256, 256-bit Input Data
        .ctrl_in	(rx_ctrl_in),       //i-32, 32-bit Input Ctrl

        .x_byte_cnt	(x_byte_cnt),       //i-32, byte count
        .x_bcnt_we	(x_bcnt_we),        //i-1, byte count write enable
        .x_we		(rx_x_we),          //i-1, write enable with data and ctrl

        .data_out	(rx_data),          //o-256, 256-bit output data from the FIFO
        .ctrl_out	(rx_ctrl),          //o-32, 32-bit output ctrl from the FIFO
        .rd_en		(fifo_rd_en)        //o-1, rd_en to the FIFO

	);


    fmac_register_if fmac_register_if(
        .clk						(clk), 							// i-1
        .reset_						(reset_),  			            // i-1

        .fmac_ctrl_dly				(fmac_ctrl_dly)	,			   	//i-32
        .fmac_ctrl1					(fmac_ctrl1)	,			    //i-32

        .FMAC_TX_PKT_CNT			(FMAC_TX_PKT_CNT),  			// i-32
        .FMAC_RX_PKT_CNT_LO			(FMAC_RX_PKT_CNT_LO),      		// i-32, (derived from SYNCLK125 [or FMAC0 clk])
        .FMAC_RX_PKT_CNT_HI			(FMAC_RX_PKT_CNT_HI),      		// i-32, (derived from SYNCLK125 [or FMAC0 clk])

        .FMAC_TX_BYTE_CNT			(FMAC_TX_BYTE_CNT),				// i-32
        .FMAC_RX_BYTE_CNT_LO		(FMAC_RX_BYTE_CNT_LO),   		// i-32, (from synclk)
        .FMAC_RX_BYTE_CNT_HI		(FMAC_RX_BYTE_CNT_HI),   		// i-32, (from synclk)

        .FMAC_RX_UNDERSIZE_PKT_CNT	(FMAC_RX_UNDERSIZE_PKT_CNT),	// i-32
        .FMAC_RX_CRC_ERR_CNT		(FMAC_RX_CRC_ERR_CNT),			// i-32
        .FMAC_DCNT_OVERRUN			(FMAC_DCNT_OVERRUN),			// i-32
        .FMAC_DCNT_LINK_ERR			(FMAC_DCNT_LINK_ERR),			// i-32
        .FMAC_PKT_CNT_OVERSIZE		(FMAC_PKT_CNT_OVERSIZE),		// i-32
        .FMAC_PHY_STAT				({31'h0, xauiA_linkup}),		// i-32

        .FMAC_PKT_CNT_JABBER		(FMAC_PKT_CNT_JABBER),			//i-32
        .FMAC_PKT_CNT_FRAGMENT		(FMAC_PKT_CNT_FRAGMENT),		//i-32
        .FMAC_RAW_FRAME_CNT			(RAW_FRAME_CNT),			    //i-32
        .FMAC_BAD_FRAMESOF_CNT		(BAD_FRAMESOF_CNT),	            //i-32

        //Interface to 64 bit Statistic register group, in DECAP
        .STAT_GROUP_LO_DOUT			(STAT_GROUP_LO_DOUT),	      	// i-32,
        .STAT_GROUP_HI_DOUT			(STAT_GROUP_HI_DOUT),	        // i-32,
        .STAT_GROUP_addr			(STAT_GROUP_addr) ,			    // o-10, address to select the register within the STAT GROUP
        .STAT_GROUP_sel				(STAT_GROUP_sel) ,			    //o-1
        .fmac_rx_clr_en				(fmac_rx_clr_en),			    //o-1

        .fmac_tx_clr_en				(fmac_tx_clr_en),

        // Interface to mac_register
        .reg_rd_start				(reg_rd_start),				   	// i-1, pulse indicating the start of a reg access
        .reg_rd_done				(reg_rd_done),					// i-1, pulse indicating the end of a reg access
        .host_addr_reg				(host_addr_reg),				// i-16
        .SYS_ADDR					(SYS_ADDR),						// i-4

        .rx_auto_clr_en				(rx_auto_clr_en),		        //i-1
        .tx_auto_clr_en				(tx_auto_clr_en),		        //i-1

        //REGISTERS
        .FMAC_REGDOUT				(FMAC_REGDOUT),

        .FMAC_RX_PKT_CNT64_LO		(FMAC_RX_PKT_CNT64_LO),
        .FMAC_RX_PKT_CNT64_HI		(FMAC_RX_PKT_CNT64_HI),

        .FMAC_RX_PKT_CNT127_LO		(FMAC_RX_PKT_CNT127_LO),
        .FMAC_RX_PKT_CNT127_HI		(FMAC_RX_PKT_CNT127_HI),

        .FMAC_RX_PKT_CNT255_LO		(FMAC_RX_PKT_CNT255_LO),
        .FMAC_RX_PKT_CNT255_HI		(FMAC_RX_PKT_CNT255_HI),

        .FMAC_RX_PKT_CNT511_LO		(FMAC_RX_PKT_CNT511_LO),
        .FMAC_RX_PKT_CNT511_HI		(FMAC_RX_PKT_CNT511_HI),

        .FMAC_RX_PKT_CNT1023_LO		(FMAC_RX_PKT_CNT1023_LO),
        .FMAC_RX_PKT_CNT1023_HI		(FMAC_RX_PKT_CNT1023_HI),

        .FMAC_RX_PKT_CNT1518_LO		(FMAC_RX_PKT_CNT1518_LO),
        .FMAC_RX_PKT_CNT1518_HI		(FMAC_RX_PKT_CNT1518_HI),

        .FMAC_RX_PKT_CNT2047_LO		(FMAC_RX_PKT_CNT2047_LO),
        .FMAC_RX_PKT_CNT2047_HI		(FMAC_RX_PKT_CNT2047_HI),

        .FMAC_RX_PKT_CNT4095_LO		(FMAC_RX_PKT_CNT4095_LO),
        .FMAC_RX_PKT_CNT4095_HI		(FMAC_RX_PKT_CNT4095_HI),

        .FMAC_RX_PKT_CNT8191_LO		(FMAC_RX_PKT_CNT8191_LO),
        .FMAC_RX_PKT_CNT8191_HI		(FMAC_RX_PKT_CNT8191_HI),

        .FMAC_RX_PKT_CNT9018_LO		(FMAC_RX_PKT_CNT9018_LO),
        .FMAC_RX_PKT_CNT9018_HI		(FMAC_RX_PKT_CNT9018_HI),

        .FMAC_RX_PKT_CNT9022_LO		(FMAC_RX_PKT_CNT9022_LO),
        .FMAC_RX_PKT_CNT9022_HI		(FMAC_RX_PKT_CNT9022_HI),

        .FMAC_RX_PKT_CNT9199P_LO	(FMAC_RX_PKT_CNT9199P_LO),
        .FMAC_RX_PKT_CNT9199P_HI	(FMAC_RX_PKT_CNT9199P_HI)

        //--

    );

endmodule