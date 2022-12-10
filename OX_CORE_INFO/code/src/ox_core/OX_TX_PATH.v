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
// Project: OmniXtend Core
// Comments: N/A
//
//********************************
// File history:
//   N/A
//****************************************************************

`timescale 1ns / 1ps

module OX_TX_PATH
    #(
        parameter DATA_WIDTH        =   64,
    	parameter TX_HEADER_PTR	    =   12,
        parameter TX_ADDR_PTR       =   12,
        parameter TX_MASK_PTR       =   12,
        parameter TX_BCNT_PTR       =   12,
        parameter TX_DATA_PTR       =   13,
        parameter RTX_CMD_PTR       =   3,
        parameter RTX_DATA_PTR      =   9,
        parameter SRC_MAC           = 48'h001232_FFFFF0,
        parameter DST_MAC           = 48'h000000_000000)
    (
        input               clk                         ,
        input               rst_                        ,
        //  TX Path to/from NOC
        input               noc_in_valid				,
        input       [63:0]  noc_in_data                 ,
        output              noc_in_ready                ,

        //	TX Path to/from LMAC
        input				m2ox_tx_fifo_full			,
        input		[12:0]	m2ox_tx_fifo_wrused			,
        output				ox2m_tx_we					,
        output		[255:0]	ox2m_tx_data				,
        // 	output		[31:0]	ox2m_tx_be					,	//(optional) Byte enable

        //  Seq Mgn
        input                           tx2rx_updateseq_done        ,
        output                          tx2rx_updateseq_req         ,
        output      [21:0]              tx2rx_seq_num               ,

        input	                     	rx2tx_updateack_req         ,
        input	 	[21:0]              rx2tx_new_ack_num           ,
        input	 	[3:0]               rx2tx_free_entries          ,
        input	 	[3:0]               rx2tx_rtx_entries           ,
        input	 	                    rx2tx_rtx_req               ,
        output	 	                    rx2tx_rtxreq_done           ,
        output    	                    rx2tx_updateack_done        ,

        input	 	                    rx2tx_send_req              ,
        input	 	                    rx2tx_ack_mode              ,
        input	 	[21:0]              rx2tx_rxack_num             ,
        output	 	                    rx2tx_sendreq_done          ,

        output                          tx_send_req                 ,  //same as external tx_req signal
        output                          tx_done                     ,
        input                           ackmtotx_busy				,

        //  Interface to/from Coherent Mgr
        input 						   coh2tl_tx_acquire_req_ack	,	// from Coherent MGR to negate acquire request
        input						   coh2tl_tx_acquire_gen_en		, 	// from Coherent MGR to generate TL AcquireBlock packet
        input                          coh2tl_gntack_gen_en         ,   // from Coherent MGR to generate a GrantAck packet
        output     					   tl2coh_tx_acquire_req		,	// to Coherent MGR
        output     					   tl2coh_tx_acquire_gen_done   , 	// to Coherent MGR
        output                         tl2coh_tx_gntack_gen_done    ,   // to Coherent MGR

        input                          coh2tl_tx_prb_flush_wait     ,   // from Coherent MGR
        input                          coh2tl_prb_ack_w_data        ,   // from Coherent MGR
        input                          coh2tl_prb_ack_no_data       ,   // from Coherent MGR
        output                         tl2coh_tx_probe_req_done     ,   // to Coherent MGR

        input                          tl2coh_tx_release_req_ack    ,   // from Coherent MGR to negate release request
        output                         tl2coh_tx_release_req        ,   // to Coherent MGR

        input      [3:0]               c_prb_ack_size               ,   // from Coherent MGR for ProbeAck TL message
        input      [25:0]              c_prb_ack_source             ,   // from Coherent MGR for ProbeAck TL message
        input      [63:0]              c_prb_ack_address            ,   // from Coherent MGR for ProbeAck TL message
        input      [25:0]              e_sink                       ,   // from Coherent MGR for GrantAck TL message

        input                          lewiz_noc_mode               ,

        input                          oxm_rtx_done                     // control signal for ProbeBlock from M2OX
    );


//	TX Path to/from FIFO
	// NOC side
	    // TX Header FIFO
	wire		[63:0]				tl2f_tx_header_i			;
	wire							tl2f_tx_header_we_i			;
	wire							f2tl_tx_header_full_i		;
	wire		[TX_HEADER_PTR-1:0]	f2tl_tx_header_wrusedw_i	;
		// TX Addr FIFO
	wire		[63:0]				tl2f_tx_addr_i				;
	wire							tl2f_tx_addr_we_i			;
	wire							f2tl_tx_addr_full_i			;
	wire		[TX_ADDR_PTR-1:0]	f2tl_tx_addr_wrusedw_i		;
		// TX Mask FIFO
	wire		[63:0]				tl2f_tx_mask_i				;
	wire							tl2f_tx_mask_we_i			;
	wire							f2tl_tx_mask_full_i			;
	wire		[TX_MASK_PTR-1:0]	f2tl_tx_mask_wrusedw_i		;
		// TX Data FIFO
	wire		[255:0]				tl2f_tx_data_i				;
	wire							tl2f_tx_data_we_i			;
	wire							f2tl_tx_data_full_i			;
	wire		[TX_DATA_PTR-1:0]	f2tl_tx_data_wrusedw_i	    ;
        // TX BCNT FIFO
    //wire        [63:0]              tl2f_tx_bcnt_i              ;
    wire        [15:0]              tl2f_tx_bcnt_i              ;		//20220503
    wire                            tl2f_tx_bcnt_we_i           ;
    wire                            f2tl_tx_bcnt_full_i         ;
    wire        [TX_BCNT_PTR-1:0]   f2tl_tx_bcnt_wrusedw_i      ;
	// LMAC side
		// TX Header FIFO
	wire		[63:0]				f2ox_tx_header_i			;
	wire							f2ox_tx_header_empty_i	    ;
	wire							ox2f_tx_header_re_i		    ;
	wire		[TX_HEADER_PTR-1:0]	f2ox_tx_header_rdusedw_i	;
		// TX Addr FIFO
	wire		[63:0]				f2ox_tx_addr_i				;
	wire		     				f2ox_tx_addr_empty_i		;
	wire							ox2f_tx_addr_re_i		    ;
    wire        [TX_ADDR_PTR-1:0]   f2ox_tx_addr_rdusedw_i      ;
		// TX Mask FIFO
	wire		[63:0]				f2ox_tx_mask_i				;
	wire		     				f2ox_tx_mask_empty_i		;
	wire							ox2f_tx_mask_re_i		    ;
    wire        [TX_MASK_PTR-1:0] 	f2ox_tx_mask_rdusedw_i      ;
		// TX Data FIFO
	wire		[255:0]				f2ox_tx_data_i				;
	wire			    			f2ox_tx_data_empty_i		;
	wire			    			ox2f_tx_data_re_i		    ;
    wire        [TX_DATA_PTR-1:0]   f2ox_tx_data_rdusedw_i      ;
        // TX Data FIFO
    wire        [15:0]              f2ox_tx_bcnt_i              ;
    wire                            f2ox_tx_bcnt_empty_i        ;
    wire                            ox2f_tx_bcnt_re_i           ;
    wire        [TX_BCNT_PTR-1:0]   f2ox_tx_bcnt_rdusedw_i      ;


    //	RTX_MGN
    wire                            rtx_mgn_tx_grant            ;
    wire                            rtx_mgn_rtx_grant           ;
//    wire                            tx_send_req                 ;
    wire        [21:0]              tx_send_seq                 ;
    wire        [15:0]              tx_local_bcnt               ;
    wire                            tx_local_bcnt_valid         ;
    wire        [11:0]              tx_buf_addr                 ;
//    wire                            tx_done                     ;
    wire        [3:0]               cmd2tx_rtx_cmd_cnt          ;
    wire                            tx_last_data                ;
    wire                            tx_entry_full               ;

    //  RTX Cmd Q FIFO
    wire                            cmd_q_full                  ;
    wire                            cmd_q_wr_en                 ;
    wire        [63:0]              cmd_q_datain                ;

    wire        [63:0]              f2ox_rtx_cmd_i              ;
    wire                            f2ox_rtx_cmd_empty_i        ;
    wire        [RTX_CMD_PTR-1:0]   f2ox_rtx_cmd_rdusedw_i      ;
    wire                            ox2f_rtx_cmd_re_i           ;

    // RTX DATA buf
    wire        [255:0]             ox2b_rtx_wrdata_i           ;
    wire        [RTX_DATA_PTR-1:0]  ox2b_rtx_wrdata_wdaddr      ;    /// 16kB RAM = 256bit * 8 * 8
    wire                            ox2b_rtx_wrdata_we_i        ;

    wire        [255:0]             b2ox_rtx_rddata_i           ;
    wire        [RTX_DATA_PTR-1:0]  ox2b_rtx_rddata_rdaddr      ;    /// 16kB RAM = 256bit * 8 * 8
    wire                            ox2b_rtx_rddata_re_i        ;

    // Reset Control
    wire							pwr2rst_rst_ctrl_start		;	// start signal for RESET_CTRL module
    wire							ox2rst_rst_ctrl_grant		;
    wire		[255:0]				rst2ox_send_pkt_data		;
    wire							rst2ox_pkt_credit_we		;	// Valid Signal for the packet credit information
    wire							rst2ox_rst_ctrl_req			;
    wire							rst2ox_pkt_done				;
    wire        [1:0]               rst2ox_qqwd_cnter           ;   //Counter for number of qqwds

    // RTX Manager
    RTX_MGR RTXM (
        .clk                    (clk),                                  // i-1
        .reset_                 (rst_),                                 // i-1
        .last_data              (tx_last_data),                         // i-1

        // ================= for TX =================
        .tx_req                 (tx_send_req),                          // i-1
        .tx_seq                 (tx_send_seq),                          // i-22
        .tx_bcnt                (tx_local_bcnt),                        // i-16
        .bcnt_valid             (tx_local_bcnt_valid),                  // i-1
        .tx_gnt                 (rtx_mgn_tx_grant),                     // o-1
        .tx_buf_addr            (tx_buf_addr),                          // o-12
        .tx_entry_full          (tx_entry_full),                        // o-1
        .tx_done                (tx_done),                              // o-1

        // ================= for RX =================
        .ack_req                (rx2tx_updateack_req),                  // i-1
        .ack_num                (rx2tx_new_ack_num),                    // i-22
        .entries2free           (rx2tx_free_entries),                   // i-4
        .ack_done               (rx2tx_updateack_done),                 // o-1
        .oxm_rtx_done           (oxm_rtx_done),         // i-1

        // ================= for RTX =================
        .rtx_req                (rx2tx_rtx_req),                        // i-1
        .rtx_done               (rx2tx_rtxreq_done),                    // o-1
        .rtx_cmd_cnt            (cmd2tx_rtx_cmd_cnt),
        .rtx_gnt                (rtx_mgn_rtx_grant),                    // i-1

        // ================= for FIFO =================
        .cmd_q_full             (cmd_q_full),                           // i-1
        .cmd_q_wr_en            (cmd_q_wr_en),                          // o-1
        .cmd_q_datain           (cmd_q_datain)                          // o-64
    );

    // NOC to TileLink Module
    N2TL    #(.DATA_WIDTH(DATA_WIDTH))
    N2TL (
        .clk                        (clk),	                            // i-1
        .reset_                     (rst_),                             // i-1

        // INPUT from NOC MASTER
        .noc_valid                  (noc_in_valid),                     // i-1  Data valid goes along with input data
        .noc_data                   (noc_in_data),                      // i-64 Data input from NOC MASTER

        // OUTPUT to NOC MASTER
        .noc_ready                  (noc_in_ready),                     // o-1  Tells NOC_MASTER it is ready to take input

        //INPUT from FIFO
        .f2tl_tx_header_full_i      (f2tl_tx_header_full_i),            // i-1  HIGH if header FIFO is full
        .f2tl_tx_addr_full_i        (f2tl_tx_addr_full_i),              // i-1  HIGH if addr FIFO is full
        .f2tl_tx_mask_full_i        (f2tl_tx_mask_full_i),              // i-1  HIGH if mask FIFO is full
        .f2tl_tx_data_full_i        (f2tl_tx_data_full_i),              // i-1  HIGH if data FIFO is full
        .f2tl_tx_bcnt_full_i        (f2tl_tx_bcnt_full_i),              // i-1  HIGH if bcnt FIFO is full

        //OUTPUT to FIFO  (N2TL)
        .tl2f_tx_header_i           (tl2f_tx_header_i),
        .tl2f_tx_header_we_i        (tl2f_tx_header_we_i),	//o-1
        .tl2f_tx_addr_i             (tl2f_tx_addr_i),
        .tl2f_tx_addr_we_i          (tl2f_tx_addr_we_i),
        .tl2f_tx_mask_i             (tl2f_tx_mask_i),
        .tl2f_tx_mask_we_i          (tl2f_tx_mask_we_i),
        .tl2f_tx_data_i             (tl2f_tx_data_i),
        .tl2f_tx_data_we_i          (tl2f_tx_data_we_i),
        .tl2f_tx_bcnt_i             (tl2f_tx_bcnt_i),			//o-16
        .tl2f_tx_bcnt_we_i          (tl2f_tx_bcnt_we_i),

        //  Interface to/from Coherent Mgr
        .coh2tl_tx_acquire_req_ack  (coh2tl_tx_acquire_req_ack),  // from Coherent MGR to negate acquire request
        .coh2tl_tx_acquire_gen_en   (coh2tl_tx_acquire_gen_en),   // from Coherent MGR to generate TL AcquireBlock packet
        .coh2tl_gntack_gen_en       (coh2tl_gntack_gen_en),       // from Coherent MGR to generate a GrantAck packet
        .tl2coh_tx_acquire_req	    (tl2coh_tx_acquire_req),	  // to Coherent MGR
        .tl2coh_tx_acquire_gen_done (tl2coh_tx_acquire_gen_done), // to Coherent MGR
        .tl2coh_tx_gntack_gen_done  (tl2coh_tx_gntack_gen_done),  // to Coherent MGR

        .coh2tl_tx_prb_flush_wait   (coh2tl_tx_prb_flush_wait),   // from Coherent MGR
        .coh2tl_prb_ack_w_data      (coh2tl_prb_ack_w_data),      // from Coherent MGR
        .coh2tl_prb_ack_no_data     (coh2tl_prb_ack_no_data),     // from Coherent MGR
        .tl2coh_tx_probe_req_done   (tl2coh_tx_probe_req_done),   // to Coherent MGR

        .tl2coh_tx_release_req_ack  (tl2coh_tx_release_req_ack),  // from Coherent MGR to negate release request
        .tl2coh_tx_release_req      (tl2coh_tx_release_req),      // to Coherent MGR

        .c_prb_ack_size             (c_prb_ack_size),             // from Coherent MGR for ProbeAck TL message
        .c_prb_ack_source           (c_prb_ack_source),           // from Coherent MGR for ProbeAck TL message
        .c_prb_ack_address          (c_prb_ack_address),          // from Coherent MGR for ProbeAck TL message
        .e_sink                     (e_sink),                     // from Coherent MGR for GrantAck TL message

        .lewiz_noc_mode             (lewiz_noc_mode)
    );


    //RTX_CMD_Q_FIFO
    //NOTE: Minimum Xilinx FIFO depth is 16   
    fifo_nx64 #(.DEPTH(16), .PTR(RTX_CMD_PTR)) rtx_cmd_fifo_8x64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (cmd_q_wr_en),              //i-1,   Write enable
        .wrdata     (cmd_q_datain),             //i-64,  Write data in
        .wrfull     (cmd_q_full),               //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (),                         //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (ox2f_rtx_cmd_re_i),        //i-1,   Read enable
        .rddata     (f2ox_rtx_cmd_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2ox_rtx_cmd_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2ox_rtx_cmd_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );


    //Header FIFO
    fifo_nx64 #(.DEPTH(4096), .PTR(TX_HEADER_PTR)) tx_header_fifo_4kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (tl2f_tx_header_we_i),      //i-1,   Write enable
        .wrdata     (tl2f_tx_header_i),         //i-64,  Write data in
        .wrfull     (f2tl_tx_header_full_i),    //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2tl_tx_header_wrusedw_i), //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (ox2f_tx_header_re_i),      //i-1,   Read enable
        .rddata     (f2ox_tx_header_i),         //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2ox_tx_header_empty_i),   //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2ox_tx_header_rdusedw_i), //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Address FIFO
    fifo_nx64 #(.DEPTH(4096), .PTR(TX_ADDR_PTR)) tx_addr_fifo_4kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (tl2f_tx_addr_we_i),        //i-1,   Write enable
        .wrdata     (tl2f_tx_addr_i),           //i-64,  Write data in
        .wrfull     (f2tl_tx_addr_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2tl_tx_addr_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (ox2f_tx_addr_re_i),        //i-1,   Read enable
        .rddata     (f2ox_tx_addr_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2ox_tx_addr_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2ox_tx_addr_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );


    //Mask FIFO
    fifo_nx64 #(.DEPTH(4096), .PTR(TX_MASK_PTR)) tx_mask_fifo_4kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (tl2f_tx_mask_we_i),        //i-1,   Write enable
        .wrdata     (tl2f_tx_mask_i),           //i-64,  Write data in
        .wrfull     (f2tl_tx_mask_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2tl_tx_mask_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (ox2f_tx_mask_re_i),        //i-1,   Read enable
        .rddata     (f2ox_tx_mask_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2ox_tx_mask_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2ox_tx_mask_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Data FIFO
    fifo_nx64 #(.DEPTH(8192), .PTR(TX_DATA_PTR)) tx_data_fifo_8kx256 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (tl2f_tx_data_we_i),        //i-1,   Write enable
        .wrdata     (tl2f_tx_data_i),           //i-64,  Write data in
        .wrfull     (f2tl_tx_data_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2tl_tx_data_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (ox2f_tx_data_re_i),        //i-1,   Read enable
        .rddata     (f2ox_tx_data_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2ox_tx_data_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2ox_tx_data_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Byte Count FIFO
    fifo_nx64 #(.DEPTH(4096), .PTR(TX_BCNT_PTR)) tx_bcnt_fifo_4kx16 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (tl2f_tx_bcnt_we_i),        //i-1,   Write enable
        .wrdata     (tl2f_tx_bcnt_i),           //i-64,  Write data in
        .wrfull     (f2tl_tx_bcnt_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2tl_tx_bcnt_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (ox2f_tx_bcnt_re_i),        //i-1,   Read enable
        .rddata     (f2ox_tx_bcnt_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2ox_tx_bcnt_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2ox_tx_bcnt_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

//	OmniXtend to LMAC
    OX2M #(
        .TX_HEADER_PTR	(TX_HEADER_PTR	),
		.TX_ADDR_PTR	(TX_ADDR_PTR	),
		.TX_MASK_PTR	(TX_MASK_PTR	),
		.TX_DATA_PTR	(TX_DATA_PTR	),
		.TX_BCNT_PTR	(TX_BCNT_PTR	),
        .SRC_MAC        (SRC_MAC        ),
        .DST_MAC        (DST_MAC        ))
    ox2m_u1 (
		.clk                        	(clk					),
		.rst_                         	(rst_					),

		.rtx_mgn_tx_grant               (rtx_mgn_tx_grant),
        .rtx_mgn_rtx_grant              (rtx_mgn_rtx_grant),
        .tx_buf_wr_addr                 (tx_buf_addr),
        .tx_rtx_entry_full              (tx_entry_full),
        .tx_send_req                    (tx_send_req),			//o-1
        .tx_send_seq                    (tx_send_seq),
        .tx_local_bcnt                  (tx_local_bcnt),
        .tx_local_bcnt_valid            (tx_local_bcnt_valid),
        .tx_done                        (tx_last_data),

		//	TX Path to/from FIFO
		// TX header FIFO
		.f2ox_tx_header_i			    (f2ox_tx_header_i),
		.f2ox_tx_header_empty_i		 	(f2ox_tx_header_empty_i),			//i-1
		.f2ox_tx_header_rdusedw_i		(f2ox_tx_header_rdusedw_i),
		.ox2f_tx_header_re_i			(ox2f_tx_header_re_i),
		// TX Address FIFO
		.f2ox_tx_addr_i				    (f2ox_tx_addr_i),
		.f2ox_tx_addr_empty_i		  	(f2ox_tx_addr_empty_i),
		.f2ox_tx_addr_rdusedw_i			(f2ox_tx_addr_rdusedw_i),
		.ox2f_tx_addr_re_i			    (ox2f_tx_addr_re_i),
		// TX Mask FIFO
		.f2ox_tx_mask_i				    (f2ox_tx_mask_i),
		.f2ox_tx_mask_empty_i		  	(f2ox_tx_mask_empty_i),
		.f2ox_tx_mask_rdusedw_i			(f2ox_tx_mask_rdusedw_i),
		.ox2f_tx_mask_re_i			    (ox2f_tx_mask_re_i),
		// TX Data FIFO
		.f2ox_tx_data_i				    (f2ox_tx_data_i),
		.f2ox_tx_data_empty_i		  	(f2ox_tx_data_empty_i),
		.f2ox_tx_data_rdusedw_i			(f2ox_tx_data_rdusedw_i),
		.ox2f_tx_data_re_i			    (ox2f_tx_data_re_i),
        // TX BCNT FIFO
        .f2ox_tx_bcnt_i                 (f2ox_tx_bcnt_i),
        .f2ox_tx_bcnt_empty_i           (f2ox_tx_bcnt_empty_i),
        .f2ox_tx_bcnt_rdusedw_i         (f2ox_tx_bcnt_rdusedw_i),
        .ox2f_tx_bcnt_re_i              (ox2f_tx_bcnt_re_i),

		//	TX Path to/from LMAC
			.m2ox_tx_fifo_full				(m2ox_tx_fifo_full	 	),
			.m2ox_tx_fifo_wrused			(m2ox_tx_fifo_wrused	),
			.ox2m_tx_we						(ox2m_tx_we			    ),
			.ox2m_tx_data					(ox2m_tx_data		    ),
        //	.ox2m_tx_be						(ox2m_tx_be			    ),

        // RTX CMD Q buf
            .f2ox_rtx_cmd_i                 (f2ox_rtx_cmd_i),
            .f2ox_rtx_cmd_empty_i           (f2ox_rtx_cmd_empty_i),
            .f2ox_rtx_cmd_rdusedw_i         (f2ox_rtx_cmd_rdusedw_i),
            .ox2f_rtx_cmd_re_i              (ox2f_rtx_cmd_re_i),

	    // RTX DATA buf
            .ox2b_rtx_wrdata_i              (ox2b_rtx_wrdata_i),
            .ox2b_rtx_wrdata_wdaddr         (ox2b_rtx_wrdata_wdaddr),    /// 16kB RAM = 256bit  * 64slot * 8entries
            .ox2b_rtx_wrdata_we_i           (ox2b_rtx_wrdata_we_i),

            .b2ox_rtx_rddata_i              (b2ox_rtx_rddata_i),
            .ox2b_rtx_rddata_rdaddr         (ox2b_rtx_rddata_rdaddr),    /// 16kB RAM = 256bit  * 64slot * 8entries
            .ox2b_rtx_rddata_re_i           (ox2b_rtx_rddata_re_i),

        //  Seq Mgn
            .tx2rx_updateseq_req            (tx2rx_updateseq_req),
            .tx2rx_seq_num                  (tx2rx_seq_num),
            .tx2rx_updateseq_done           (tx2rx_updateseq_done),

            .rx2tx_send_req                 (rx2tx_send_req),
            .rx2tx_ack_mode                 (rx2tx_ack_mode),
            .rx2tx_rxack_num                (rx2tx_rxack_num),
            .rx2tx_sendreq_done             (rx2tx_sendreq_done),

        //	Reset Control
			.rst2ox_send_pkt_data			(rst2ox_send_pkt_data),		// i-256
			.rst2ox_pkt_credit_we			(rst2ox_pkt_credit_we),		// i-1, Valid Signal for the packet credit information
			.rst2ox_rst_ctrl_req			(rst2ox_rst_ctrl_req),		// i-1
			.rst2ox_pkt_done			    (rst2ox_pkt_done),          // i-1
			.rst2ox_qqwd_cnter              (rst2ox_qqwd_cnter),        // i-2
			.ox2rst_rst_ctrl_grant			(ox2rst_rst_ctrl_grant)		// o-1
            );

    rtx_buf RB (
        .clk    (clk),
        .rst_   (rst_),

        .ox2b_rtx_wrdata_i      (ox2b_rtx_wrdata_i),
        .ox2b_rtx_wrdata_wdaddr (ox2b_rtx_wrdata_wdaddr),         /// 16kB RAM = 256bit  * 64slot * 8entries
        .ox2b_rtx_wrdata_we_i   (ox2b_rtx_wrdata_we_i),

        .b2ox_rtx_rddata_i      (b2ox_rtx_rddata_i),
        .ox2b_rtx_rddata_rdaddr (ox2b_rtx_rddata_rdaddr),         /// 16kB RAM = 256bit  * 64slot * 8entries
        .ox2b_rtx_rddata_re_i   (ox2b_rtx_rddata_re_i)
    );

    PWRUP_CTRL PWRUP_CTRL (
		.clk							(clk),
		.rst_							(rst_),
		.pwr2rst_rst_ctrl_start			(pwr2rst_rst_ctrl_start)			// o-1, start signal for RESET_CTRL module
    );

	RST_CTRL #(
        .SRC_MAC    (SRC_MAC),
        .DST_MAC    (DST_MAC)
    ) RST_CTRL (
		.clk							(clk),
		.rst_							(rst_),
		.pwr2rst_rst_ctrl_start		    (pwr2rst_rst_ctrl_start),	// i-1, start signal for RESET_CTRL module
		.ox2rst_rst_ctrl_grant			(ox2rst_rst_ctrl_grant),	// i-1
		.rst2ox_send_pkt_data			(rst2ox_send_pkt_data),		// o-256
		.rst2ox_pkt_credit_we			(rst2ox_pkt_credit_we),		// o-1, Valid Signal for the packet credit information
		.rst2ox_rst_ctrl_req			(rst2ox_rst_ctrl_req),		// o-1
		.rst2ox_pkt_done			    (rst2ox_pkt_done),	        // o-1
		.rst2ox_qqwd_cnter              (rst2ox_qqwd_cnter)         // o-2
    );
endmodule
