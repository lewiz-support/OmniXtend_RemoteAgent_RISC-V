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

module TL2N
    #(
        parameter TL_HEADER_WIDTH   =   64,
        parameter TL_DATA_WIDTH     =   256,
        parameter NOC_DATA_WIDTH    =   64
    )
    (
        input                           clk,
        input                           reset_,

        // OUTPUT to NOC_MASTER
        output  reg                         noc_out_valid,
        output  reg [NOC_DATA_WIDTH-1:0]    noc_out_data,
        input                               noc_out_ready,              // ready signal from NOC_MASTER


        // INPUT from FIFO
        input       [TL_HEADER_WIDTH-1:0]   f2tl_rx_header_i,           // Header from Header FIFO
        input                               f2tl_rx_header_empty_i,     // HIGH when Header FIFO is empty (Channel B ONLY)
        input       [TL_HEADER_WIDTH-1:0]   f2tl_rx_addr_i,             // Addr from Addr FIFO            (Channel B ONLY)
        input                               f2tl_rx_addr_empty_i,       // HIGH when Addr FIFO is empty   (Channel B ONLY)
        input       [TL_HEADER_WIDTH-1:0]   f2tl_rx_mask_i,             // Mask from Mask FIFO            (Channel B ONLY)
        input                               f2tl_rx_mask_empty_i,       // HIGH when Mask FIFO is empty
        input       [TL_DATA_WIDTH-1:0]     f2tl_rx_data_i,             // Data from Data FIFO
        input                               f2tl_rx_data_empty_i,       // HIGH when Data FIFO is empty
        input       [15:0]                  f2tl_rx_bcnt_i,             // Exact byte cnt for pkt
        input                               f2tl_rx_bcnt_empty_i,       // HIGH when bcnt FIFO is empty

        // OUTPUT to FIFO
        output reg                          tl2f_rx_header_re_i,        // Read enable for Header FIFO
        output reg                          tl2f_rx_addr_re_i,          // Read enable for Addr FIFO
        output reg                          tl2f_rx_mask_re_i,          // Read enable for Mask FIFO
        output reg                          tl2f_rx_data_re_i,          // Read enable for Data FIFO
        output reg                          tl2f_rx_bcnt_re_i,          // Read enable for Bcnt FIFO

        // Interface to/from Coherent Mgr for ACQUIRE function
        input                          		tx2rx_rcv_tlgnt_ack,     	// if 1, coherent mgr ACK TL Logic TL GNT indication
        output reg                     		rx2tx_rcv_tlgnt,            // if 1, TL Logic seen a TL GNT for ACQUIRE_REQ

        // Interface to/from Coherent Mgr for PROBE function
        input                               coh2tl_rx_probe_req_ack,
        input                               coh2tl_rx_prb_displ_gen_en,
        input                               coh2tl_prb_ack_w_data,
        input                               coh2tl_prb_ack_no_data,
        output reg                          tl2coh_rx_probe_req,
        output reg                          tl2coh_rx_prb_displ_gen_ack,

        // Interface to/from COHERENT MGR for RELEASE function
        output reg                          tl2coh_rx_release_ack_rcvd, // to Coherent MGR

        output reg [3:0]                    b_size,                     // to Coherent MGR for ProbeAck TL message
        output reg [25:0]                   b_source,                   // to Coherent MGR for ProbeAck TL message
        output reg [TL_HEADER_WIDTH-1:0]    b_address,                  // to Coherent MGR for ProbeAck TL message
        output reg [25:0]                   d_sink,                     // to Coherent MGR for GrantAck TL message


        // Inputs from M2OX to diff aquire and release response
        input                               ox2tl_aquire_gnt,
        input                               ox2tl_release_ack,
        input                               ox2tl_acc_ack,
        input                               ox2tl_acc_ack_data,
        input                               ox2tl_probe
    );


    //================================================================//
    //  Convenience Parameters

    // CHANNELS
    localparam CH_A                   = 3'd1;
    localparam CH_B                   = 3'd2;
    localparam CH_C                   = 3'd3;
    localparam CH_D                   = 3'd4;
    localparam CH_E                   = 3'd5;

    // NOC MSG_TYPE
    localparam LOAD_MEM_ACK           = 8'd24;
    localparam STORE_MEM_ACK          = 8'd25;
    localparam L2_DIS_FLUSH_REQ       = 8'd35;

    // TileLink OPCODE
    localparam OPCODE_ACCESS_ACK      = 3'd0;
    localparam OPCODE_ACCESS_ACK_DATA = 3'd1;
    //grant
    localparam OPCODE_PROBE_BLOCK	  =	3'd6;
    localparam OPCODE_GRANT	 		  = 3'd4;
    localparam OPCODE_GRANT_DATA	  = 3'd5;
    localparam OPCODE_RELEASE_ACK	  =	3'd6;


    //================================================================//
    //  State Machine Encoding and State Signals

    //Header SM
    reg  [7:0]  tl2n_header_state;
    localparam  H_IDLE_ST       = 8'h01;
    localparam  H_RDEN_ST       = 8'h02;
    localparam  H_DECO_ST       = 8'h04;
    localparam  H_WAIT_ST       = 8'h08;
    localparam  H_OUTP_ST       = 8'h10;
    localparam  H_DONE_ST       = 8'h80;

    wire        header_idle_st  = tl2n_header_state[0];
    wire        header_rden_st  = tl2n_header_state[1];
    wire        header_deco_st  = tl2n_header_state[2];
    wire        header_wait_st  = tl2n_header_state[3];
    wire        header_outp_st  = tl2n_header_state[4];
    wire        header_done_st  = tl2n_header_state[7];


    //Data SM
    reg  [7:0]  tl2n_data_state;
    localparam  D_IDLE_ST       = 8'h01;
    localparam  D_RDEN_ST       = 8'h02;
    localparam  D_LOAD_ST       = 8'h04;
    localparam  D_WAIT_ST       = 8'h08;
    localparam  D_DONE_ST       = 8'h80;

    wire        data_idle_st    = tl2n_data_state[0];
    wire        data_rden_st    = tl2n_data_state[1];
    wire        data_load_st    = tl2n_data_state[2];
    wire        data_wait_st    = tl2n_data_state[3];
    wire        data_done_st    = tl2n_data_state[7];


    //FIFO Read enable SM
    reg  [3:0]  tl2n_fifo_state;
    localparam  F_IDLE_ST       = 4'h1;
    localparam  F_RDEN_ST       = 4'h2;
    localparam  F_DONE_ST       = 4'h4;
    localparam  F_DONE2_ST      = 4'h8;

    wire        fifo_idle_st    = tl2n_fifo_state[0];
    wire        fifo_rden_st    = tl2n_fifo_state[1];
    wire        fifo_done_st    = tl2n_fifo_state[2];
    wire        fifo_done2_st   = tl2n_fifo_state[3];

    //================================================================//

    // Buffer for all inputs from FIFO
    reg     [TL_HEADER_WIDTH-1:0]   header_buf;
    reg     [TL_HEADER_WIDTH-1:0]   addr_buf;
    reg     [TL_HEADER_WIDTH-1:0]   mask_buf;
    reg     [TL_DATA_WIDTH-1:0]     data_buf;
    reg     [15:0]                  bcnt_buf;               // buffer for incoming bcnt

    reg     [11:0]                  actual_bcnt ;           // taking only the lower 12b to see the expected bcnt number
    reg     [63:0]                  actual_mask;            // Mask only the data, Not padding. M2OX sends out 64b mask with padding
  //reg     [255:0]                 actual_data;            // Data Buffer includes padding. Remove padding before o/p to NOC
    wire    [2:0]                   channel;                // to see the channel
    reg     [15:0]                  payload_bcnt;           // Stores 2^n size of byte cnt
    reg     [3:0]                   delay_cnt ;             // number of clk cycle delay until NOC CMD is ready
    reg                             cmd_done ;              // HIGH when cmd is read for output, allowing data rden

// ============================ OUTPUT DATA REG ============================
	reg		[3:0]					data_reg_cnt;
	reg		[3:0]					data_reg_cnt_bkup;

	reg		[63:0]					data_reg_01;
	reg		[63:0]					data_reg_02;
	reg		[63:0]					data_reg_03;
	reg		[63:0]					data_reg_04;
	reg		[63:0]					data_reg_05;
	reg		[63:0]					data_reg_06;
	reg		[63:0]					data_reg_07;
	reg		[63:0]					data_reg_08;
	reg		[63:0]					data_reg_09;

// =================== OUTPUT REG BUFFER ============================
    reg     [63:0]                  output_data   ;         // store data before going into FIFO
    reg                             output_data_wren ;      // write enable for output data FIFO
    reg     [7:0]                   output_rden_cnt;        // count the number of read enable cycle to control the output FIFO state machine
	reg		[7:0]					rden_cnt_buf;
    reg     [7:0]                   wren_cnt    ;           // count the number of wr enable cycle to control the number of read enable cycle

// =================== FIFO SIGNALS ===================================
    wire    [5:0]                   output_fifo_wrusedw;    // FIFO write used word
    wire                            output_fifo_full;       // high when FIFO is full
    reg                             output_fifo_rden;       // read enable
    wire                            output_fifo_empty;      // output FIFO empty
    wire    [5:0]                   ouptut_fifo_rdusedw;    // FIFO read used word
    wire    [63:0]                  output_rd_data;         // FIFO output data
    reg                             fifo_rden_buf_1;        // buffer rden to become noc_out_valid
    reg                             fifo_rden_buf_2;        // buffer rden to become noc_out_valid

    // ============== NOC Register =====================
    reg     [5:0]                   src_chipid;             // destination chip ID  (low 6 bits only)
    reg     [7:0]                   src_xpos;               // destination x position
    reg     [7:0]                   src_ypos;               // destination y position
    reg     [3:0]                   fbits;                  // final destination bits
    reg     [7:0]                   payload_length;         // payload length (with or w/out data)
    reg     [7:0]                   msg_type;               // message type
    reg     [3:0]                   tag;                    // MSHR/tag (low 4 bits only)

    // ============== Channel B =====================
//  reg  [25:0]  b_source;          // {TAG, DST_CHIPID}        (Needs to be the same as the request side?)
//  reg  [63:0]  b_address;
//  reg  [3:0]   b_size;            // PAYLOAD_LENGTH
    reg  [2:0]   b_opcode;          // MSG_TYPE
    reg  [3:0]   b_param;           // zero for now
    reg  [255:0] b_data;            //{DATA_4, DATA_3, DATA_2, DATA_1}
    reg          b_corrupt;
//  reg          b_valid;           // Using Rd_en instead
//  reg          b_ready;           // Using Rd_en instead

    // ============== Channel D =====================
    reg     [25:0]                  d_source;               // {TAG, DST_CHIPID}        (Needs to be the same as the request side?)
    reg     [3:0]                   d_size;                 // PAYLOAD_LENGTH
    reg     [2:0]                   d_opcode;               // MSG_TYPE
    reg     [3:0]                   d_param;                // zero for now
    reg     [255:0]                 d_data;                 //{DATA_4, DATA_3, DATA_2, DATA_1}
    reg                             d_corrupt;
//  reg  [25:0]  d_sink;            //Slave sink identifier  (CH D and E only)
    reg                             d_denied;               //Slave unable to service the request
//  reg          d_valid;           // Using Rd_en instead
//  reg          d_ready;           // Using Rd_en instead

    wire                            is_empty;               // if any of the input FIFOs are empty [HIGH when it's empty]
    wire                            end_of_pkt;             // Indicates the end of the pkt (along with the last beat)
    wire                            is_ch_b;                // Channel B identifier, changes state machine
    wire                            ch_d_data;              // Channel D identifier, changes state machine
    wire                            ch_d_no_data;           // Channel D identifier, changes state machine (HIGH when no payload)

//  reg     [TL_HEADER_WIDTH-1:0]   header_store_reg ;      // store header until ready to output
//  reg     [TL_DATA_WIDTH-1:0]     data_store_reg_1 ;      // store 1st QQWord of data until ready to output
//  reg     [TL_DATA_WIDTH-1:0]     data_store_reg_2 ;      // store 2nd QQWord of data until ready to output

    reg                             aquire_gnt;             // buff acquire gnt signal from M2OX
    reg                             gnt_data;               // buffer for gnt data signal
    reg                             release_ack;            // buff release ack signal from M2OX
    reg                             acc_ack;                // buff acc ack signal from M2OX
    reg                             acc_ack_data;           // buff acc ack signal from M2OX
    reg                             probe;                  // buff probe signal

// =========================== DATA STATE MACHINE REG ======================================
    reg     [7:0]                   data_rden_cnt ;         // Counts number of rden required to read all data
    reg     [7:0]                   data_bcnt     ;         // number of byte output by FIFO already
    reg     [3:0]                   wait_cnt      ;         // wait 4 cycles before going to next state
    reg     [3:0]                   data_delay    ;         // cnt the cycle it takes to latch buff
    wire                            pkt_done      ;         // data transfer finished

	reg								busy;					// busy signal to avoid collision of packet coming in


//  assign is_empty     = (f2tl_rx_header_empty_i | f2tl_rx_addr_empty_i | f2tl_rx_mask_empty_i | f2tl_rx_data_empty_i) ? 1'b1 :
    assign is_empty     = (!reset_) ? 1'b0 : ((f2tl_rx_header_empty_i) ? 1'b1 : 1'b0);

    assign is_ch_b      = (!reset_) ? 1'b0 : ((header_buf[62:60] == CH_B) ? 1'b1 : 1'b0) ;

    assign ch_d_no_data = (!reset_) ? 1'b0 : (!(bcnt_buf[12]) ? 1'b1 : 1'b0) ;

    assign ch_d_data    = (!reset_) ? 1'b0 : (bcnt_buf[12]) ? 1'b1 : 1'b0 ;

    assign end_of_pkt   = (!reset_) ? 1'b0 :
                          (ch_d_no_data ) ? 1'b1 :
                          (ch_d_data) ? (data_done_st ? 1'b0 : 1'b0) :
                          end_of_pkt ;       //TODO: add payload length cnt later!!!

    assign channel      = header_buf[62:60] ;

    assign pkt_done     = (data_done_st) ? 1'b1 : 1'b0 ;


    fifo_nx64 #(.DEPTH(64), .PTR(6)) tl_data_fifo_64x64 (
        .reset_     (reset_),

        .wrclk      (clk),                  //i-1,   Write port clock
        .wren       (output_data_wren),     //i-1,   Write enable
        .wrdata     (output_data),          //i-64,  Write data in
        .wrfull     (output_fifo_full),     //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                     //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (output_fifo_wrusedw),  //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                  //i-1,   Read port clock
        .rden       (output_fifo_rden),     //i-1,   Read enable
        .rddata     (output_rd_data),       //i-64,  Read data out
        .rdfull     (),                     //o-1,   Read Full Flag (DATA AVAILABLE FOR READ is == DEPTH)
        .rdempty    (output_fifo_empty),    //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (ouptut_fifo_rdusedw),  //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );


    always@ (posedge clk) begin     // Header SM
        if(!reset_) begin
            tl2n_header_state <= H_IDLE_ST;
        end
        else begin
            case(tl2n_header_state)
              //H_IDLE_ST   :       tl2n_header_state <= (noc_out_ready & !is_empty) ? H_RDEN_ST : H_IDLE_ST ;
                H_IDLE_ST   :       tl2n_header_state <= (!f2tl_rx_header_empty_i & fifo_idle_st) ? H_RDEN_ST : H_IDLE_ST ;
                H_RDEN_ST   :       tl2n_header_state <= H_DECO_ST ;
                H_DECO_ST   :       tl2n_header_state <= (is_ch_b) ? H_RDEN_ST :                            // CH_B Have to read Mask & Addr
                                                         H_WAIT_ST ;                                      // otherwise: CH_D/AccessAckData
                H_WAIT_ST   :       tl2n_header_state <= (delay_cnt == 4'd2) ? H_OUTP_ST : H_WAIT_ST ;
                H_OUTP_ST   :       tl2n_header_state <= H_DONE_ST ;
              //H_DONE_ST   :       tl2n_header_state <= (pkt_done || msg_type== 8'd25) ? H_IDLE_ST : H_DONE_ST;
                H_DONE_ST   :       tl2n_header_state <= (pkt_done || msg_type == STORE_MEM_ACK  ||
                                                          msg_type == L2_DIS_FLUSH_REQ)              ? H_IDLE_ST :
                                                          H_DONE_ST;
                default     :       tl2n_header_state <= H_IDLE_ST ;
            endcase
        end // else
    end // always clk


    always@ (posedge clk) begin
        if(!reset_)
            tl2n_data_state <= D_IDLE_ST ;
        else begin
            case(tl2n_data_state)
                D_IDLE_ST   :       tl2n_data_state <= (cmd_done && !f2tl_rx_data_empty_i && msg_type == LOAD_MEM_ACK) ? D_RDEN_ST : D_IDLE_ST ;
                D_RDEN_ST   :       tl2n_data_state <= D_LOAD_ST ;
                D_LOAD_ST   :       tl2n_data_state <= (data_delay == 4'd1) ? D_WAIT_ST : D_LOAD_ST ;
                D_WAIT_ST   :       tl2n_data_state <= (data_bcnt <= 8'd8) ? D_DONE_ST :
                                                       (wait_cnt == 4'd3) ? (data_rden_cnt > 8'b0 && data_bcnt > 8'b0) ? D_RDEN_ST :
                                                       D_DONE_ST :
                                                       D_WAIT_ST ;
                D_DONE_ST   :       tl2n_data_state <= D_IDLE_ST ;
                default     :       tl2n_data_state <= D_IDLE_ST ;
            endcase
        end
    end // always data state machine



    // OUPUT FIFO STATE MACHINE: F_IDLE changing conditions needs to include signals for all operations
    always@ (posedge clk) begin
        if(!reset_) begin
            tl2n_fifo_state <= F_IDLE_ST ;
        end // if(!rst)
        else begin
            case(tl2n_fifo_state)
            //  F_IDLE_ST   :       tl2n_fifo_state <= ((data_done_st & aquire_gnt) || (header_done_st & data_idle_st & release_ack)) ? F_RDEN_ST : F_IDLE_ST ;
                F_IDLE_ST   :       tl2n_fifo_state <= (data_done_st & (acc_ack_data | aquire_gnt | gnt_data) | (header_done_st & data_idle_st & (release_ack | acc_ack)) |
                                                        (header_done_st & data_idle_st & probe))            ? F_RDEN_ST :
                                                        F_IDLE_ST ;
                F_RDEN_ST   :       tl2n_fifo_state <= (acc_ack | release_ack | probe) ? F_DONE_ST :
                                                       (output_rden_cnt < wren_cnt ) ? F_RDEN_ST : F_DONE_ST ;     // wren_cnt -2 to account for the delay to make sure rden doesnt exceed the wren cnt
                F_DONE_ST   :       tl2n_fifo_state <= F_DONE2_ST ;
                F_DONE2_ST  :       tl2n_fifo_state <= (data_reg_cnt == output_rden_cnt) ? F_IDLE_ST : F_DONE2_ST;
                default     :       tl2n_fifo_state <= F_IDLE_ST ;
            endcase
        end // else
    end // always

    always@ (posedge clk) begin
        if(!reset_) begin
            output_rden_cnt <= 8'b0 ;
            output_fifo_rden    <= 1'b0;
        end // if reset

        else begin
            case(tl2n_fifo_state)
                F_IDLE_ST   :   begin
                    output_rden_cnt     <= 8'b0 ;
                end
                F_RDEN_ST   :   begin
                    output_rden_cnt     <= output_rden_cnt + 8'd1 ;
                    output_fifo_rden    <= 1'b1 ;
                end
                F_DONE_ST   :   begin
                    output_fifo_rden    <= 1'b0;

                end
				F_DONE2_ST	:	begin

				end
            endcase
        end
    end // always


    always@ (posedge clk) begin // comb logics
        if(!reset_) begin
			rden_cnt_buf			<= 8'b0;
// ============================== DATA_REG_FOR OUTPUT ==============================
			data_reg_cnt			<= 4'b0;
			data_reg_cnt_bkup		<= 4'b0;

			data_reg_01				<= 64'b0;
			data_reg_02				<= 64'b0;
			data_reg_03				<= 64'b0;
			data_reg_04				<= 64'b0;
			data_reg_05				<= 64'b0;
			data_reg_06				<= 64'b0;
			data_reg_07				<= 64'b0;
			data_reg_08				<= 64'b0;
			data_reg_09				<= 64'b0;

// ============================== HEADER/ CMD reg ==============================
        //  header_buf              <=      `TL_HEADER_WIDTH'b0;
            addr_buf                <=      64'b0;
            mask_buf                <=      64'b0;
        //  data_buf                <=      256'b0; //-/2022-10-27 Shankar: To avoid multiple drivers
        //  bcnt_buf                <=      16'b0;  //-/

            b_source                <=      26'b0;
            b_address               <=      64'b0;
            b_size                  <=      4'b0;
            b_opcode                <=      3'b0;
            b_param                 <=      4'b0;
            b_data                  <=      256'b0;
            b_corrupt               <=      1'b0;

            payload_bcnt            <=      16'b0;
            d_source                <=      26'b0;
            d_size                  <=      4'b0;
            d_opcode                <=      3'b0;
            d_param                 <=      4'b0;
            d_data                  <=      256'b0;
            d_corrupt               <=      1'b0;
            d_sink                  <=      26'b0;
            d_denied                <=      1'b0;
//          d_valid                 <=      1'b0;

        //  tl2f_rx_header_re_i     <=      1'b0;   //-/2022-10-27 Shankar: To avoid multiple drivers
        //  tl2f_rx_bcnt_re_i       <=      1'b0;   //-/
        //  tl2f_rx_addr_re_i       <=      1'b0;   //-/
        //  tl2f_rx_mask_re_i       <=      1'b0;   //-/
        //  tl2f_rx_data_re_i       <=      1'b0;   //-/


        //  cmd_done                <=      1'b0;   //-/2022-10-27 Shankar: To avoid multiple drivers

            src_chipid              <=      4'b0;
            src_xpos                <=      8'b0;
            src_ypos                <=      8'b0;
            payload_length          <=      8'b0;
            msg_type                <=      8'b0;
            tag                     <=      8'b0;
            fbits                   <=      4'b0;
 // ============================== DATA Related reg ==============================

            output_data             <=      64'b0;
            output_data_wren        <=      1'b0;
            wren_cnt                <=      8'b0;


// ============================== NOC_OUTPUT  ==============================
            fifo_rden_buf_1         <=      1'b0;
            fifo_rden_buf_2         <=      1'b0;
            noc_out_data            <=      64'b0;
            noc_out_valid           <=      1'b0;

            //------ for coherent mgr
            tl2coh_rx_probe_req         <=  1'b0;
            tl2coh_rx_prb_displ_gen_ack <=  1'b0;

            rx2tx_rcv_tlgnt		        <=  1'b0;
            tl2coh_rx_release_ack_rcvd  <=	1'b0;

            aquire_gnt              <=      1'b0;
            gnt_data                <=      1'b0;
            release_ack             <=      1'b0;
			acc_ack					<=		1'b0;
			acc_ack_data            <=      1'b0;
            probe                   <=      1'b0;

			busy					<=		1'b0;

        end // reset
        else begin
			rden_cnt_buf			<= output_rden_cnt ;
			data_reg_cnt			<= (|data_reg_01 & noc_out_ready)  ? data_reg_cnt + 8'd1 :
									   (|data_reg_01 & !noc_out_ready & noc_out_valid)  ? data_reg_cnt_bkup :
									   (|data_reg_01 & !noc_out_ready) ? data_reg_cnt :
									   8'd0 ;

  		    data_reg_cnt_bkup   	<= data_reg_cnt;

			data_reg_01				<= (rden_cnt_buf == 8'd1) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_01 ;
			data_reg_02				<= (rden_cnt_buf == 8'd2) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_02 ;
			data_reg_03				<= (rden_cnt_buf == 8'd3) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_03 ;
			data_reg_04				<= (rden_cnt_buf == 8'd4) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_04 ;
			data_reg_05				<= (rden_cnt_buf == 8'd5) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_05 ;
			data_reg_06				<= (rden_cnt_buf == 8'd6) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_06 ;
			data_reg_07				<= (rden_cnt_buf == 8'd7) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_07 ;
			data_reg_08				<= (rden_cnt_buf == 8'd8) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_08 ;
			data_reg_09				<= (rden_cnt_buf == 8'd9) ? output_rd_data :
									   (rden_cnt_buf == 8'd0) ? 64'b0 :
									   data_reg_09 ;

            tl2coh_rx_probe_req <=
                    coh2tl_rx_probe_req_ack                                     ? 1'b0  :       // negate
                    header_wait_st & (delay_cnt == 4'd1) & (channel == CH_B)
            			& (b_opcode == OPCODE_PROBE_BLOCK)                      ? 1'b1  :       // assert
                    tl2coh_rx_probe_req;                                                        // keep

            tl2coh_rx_prb_displ_gen_ack <=
                    header_done_st & (channel == CH_B)
            			& (b_opcode == OPCODE_PROBE_BLOCK)   ?   1'b1    :
                    1'b0;
//    localparam OPCODE_ACCESS_ACK      = 3'd0;
//    localparam OPCODE_ACCESS_ACK_DATA = 3'd1;
//    //grant
//    localparam OPCODE_PROBE_BLOCK	  =	3'd6;
//    localparam OPCODE_GRANT	 		  = 3'd4;
//    localparam OPCODE_GRANT_DATA	  = 3'd5;
//    localparam OPCODE_RELEASE_ACK	  =	3'd6;
            aquire_gnt          <= (ox2tl_aquire_gnt) ? 1'b1 :
                                   (fifo_done_st)     ? 1'b0 :
                                   aquire_gnt;

            gnt_data            <= (header_buf[59:57] == OPCODE_GRANT_DATA) ? 1'b1 :
                                    1'b0 ;


            release_ack         <= (ox2tl_release_ack) ? 1'b1 :
                                   (fifo_done_st)      ? 1'b0 :
                                   release_ack;

            acc_ack             <= (header_buf[59:57] == OPCODE_ACCESS_ACK) ? 1'b1 :
                                   1'b0 ;

            acc_ack_data        <= (header_buf[59:57] == OPCODE_ACCESS_ACK_DATA) ? 1'b1 :
                                   1'b0 ;

            probe               <= (ox2tl_probe)  ? 1'b1 :
                                   (fifo_done_st) ? 1'b0 :
                                   probe;

        //  actual_bcnt         <= bcnt_buf[11:0] ;

            rx2tx_rcv_tlgnt		<=
            		tx2rx_rcv_tlgnt_ack ? 1'b0 :                                                          // negate
            		header_wait_st & (delay_cnt == 4'd2) & (channel == CH_D)
            			& ((d_opcode == OPCODE_GRANT) | (d_opcode == OPCODE_GRANT_DATA)) ? 1'b1 :         // assert
            		rx2tx_rcv_tlgnt;                                                                      // keep

            tl2coh_rx_release_ack_rcvd	        <=
    			header_outp_st				                               ? 1'b0    :    // negate
            	header_wait_st & (delay_cnt == 4'd2) & (channel == CH_D)
            			& (d_opcode == OPCODE_RELEASE_ACK)                 ? 1'b1    :    // assert
    			tl2coh_rx_release_ack_rcvd;                                               // keep


        //  header_buf              <=      (tl2f_rx_header_re_i) ? f2tl_rx_header_i : 64'b0 ;
            addr_buf                <=      (tl2f_rx_addr_re_i) ? f2tl_rx_addr_i : 64'b0 ;
            mask_buf                <=      (tl2f_rx_mask_re_i) ? f2tl_rx_mask_i : 64'b0 ;
        //  data_buf                <=      f2tl_rx_data_i ;
        //  bcnt_buf                <=      (tl2f_rx_bcnt_re_i) ? f2tl_rx_bcnt_i : 16'b0 ;

            b_opcode                <=      (channel == CH_B) ? header_buf[59:57] : 3'b0 ;
            b_param                 <=      (channel == CH_B) ? header_buf[55:52] : 4'b0 ;
            b_size                  <=      (channel == CH_B) ? header_buf[51:48] : 4'b0 ;
            b_corrupt               <=      (channel == CH_B) ? header_buf[38]    : 1'b0 ;
            b_source                <=      (channel == CH_B) ? header_buf[25:0] : 26'b0 ;
            b_address               <=
                (b_opcode == OPCODE_PROBE_BLOCK)  ? f2tl_rx_addr_i :
                64'b0;

            d_opcode                <=      (channel == CH_D) ? header_buf[59:57] : 3'b0 ;
            d_param                 <=      (channel == CH_D) ? header_buf[55:52] : 4'b0 ;
            d_size                  <=      (channel == CH_D) ? header_buf[51:48] : 4'b0 ;
            d_denied                <=      (channel == CH_D) ? header_buf[39]    : 1'b0 ;
            d_corrupt               <=      (channel == CH_D) ? header_buf[38]    : 1'b0 ;
            d_source                <=      (channel == CH_D) ? header_buf[25:0] : 26'b0 ;

//          d_data                  <=      header_buf;
//          d_valid                 <=      header_buf ;
//          d_sink                  <=      header_buf ;          // Use for Permission

            d_sink                  <=
                (d_opcode == OPCODE_GRANT) | (d_opcode == OPCODE_GRANT_DATA) ? f2tl_rx_addr_i [25:0] :
                26'b0;
// ======================= NOC CMD =======================
            msg_type                <=      (b_opcode == OPCODE_PROBE_BLOCK)        ? L2_DIS_FLUSH_REQ :
                                            (d_opcode == OPCODE_ACCESS_ACK_DATA ||
                                             d_opcode == OPCODE_GRANT_DATA      )   ? LOAD_MEM_ACK :    // 20220509 not sure for GRANT_DATA
                                            //(d_opcode == OPCODE_ACCESS_ACK_DATA) ? LOAD_MEM_ACK :
                                            (d_opcode == OPCODE_ACCESS_ACK      ||
                                             d_opcode == OPCODE_GRANT           ||
                                             d_opcode == OPCODE_RELEASE_ACK)        ? STORE_MEM_ACK :   // 20220512 not sure for GRANT & RELEASE_ACK
                                            //(d_opcode == OPCODE_ACCESS_ACK) ? STORE_MEM_ACK :
                                            8'b0 ;

        //  payload_length          <=      {3'b0, bcnt_buf[15:3]} + |(bcnt_buf[2:0]) ;

            //payload_length is only 8 bits in qwd. BCNT is only 12 bits in bytes
            // upper bit truncated. But actual NOC payload_length should never be that high
            payload_length          <=      {actual_bcnt[11:3]} + |(actual_bcnt[2:0]) ;        //20220520 CLe .//20220701 ADDED actual_bcnt

            src_chipid              <=      header_buf[25:20];
            src_xpos                <=      header_buf[19:12];
            src_ypos                <=      header_buf[11:4 ];
            tag                     <=      header_buf[ 3:0 ];

// ======================= DATA FIFO SIGNALS =======================


// ======================= NOC OUTPUT =======================

            output_data <=      // |       14       |    8    |    8    |   4  |        8      |    8    |    8    |  6  |
                (header_outp_st) ? {6'b0, src_chipid, src_xpos, src_ypos, fbits, payload_length, msg_type, 4'b0,tag, 6'b1} :

                (d_size == 5 || d_size == 6) ? (
                    (data_wait_st && wait_cnt == 3) ? data_buf[255:192] :
                    (data_wait_st && wait_cnt == 2) ? data_buf[191:128] :
                    (data_wait_st && wait_cnt == 1) ? data_buf[127:64]  :
                    (data_wait_st && wait_cnt == 0) ? data_buf[63:0]    :
                    output_data
                ) :

                (d_size == 4) ? (
                    (data_wait_st && wait_cnt == 1) ? data_buf[127:64]  ://Narayana
                    (data_wait_st && wait_cnt == 0) ? data_buf[63:0]    ://
                    (data_wait_st && wait_cnt == 3) ? data_buf[255:192] :
                    (data_wait_st && wait_cnt == 2) ? data_buf[191:128] :
                    output_data
                ):

                (d_size == 3) ? (
                    (data_wait_st && wait_cnt == 0) ? data_buf[63:0]    :
                    (data_wait_st && wait_cnt == 3) ? data_buf[255:192] :
                    (data_wait_st && wait_cnt == 2) ? data_buf[191:128] :
                    (data_wait_st && wait_cnt == 1) ? data_buf[127:64]  :
                    output_data
                ) :

                (d_size == 2) ? (
                    (data_wait_st && wait_cnt == 0) ? {32'b0,data_buf[31:0]} :
                    (data_wait_st && wait_cnt == 3) ? data_buf[255:192] :
                    (data_wait_st && wait_cnt == 2) ? data_buf[191:128] :
                    (data_wait_st && wait_cnt == 1) ? data_buf[127:64] :
                    output_data
                ) :

                (d_size == 1) ? (
                    (data_wait_st && wait_cnt == 0) ? {48'b0,data_buf[15:0]} :
                    (data_wait_st && wait_cnt == 3) ? data_buf[255:192] :
                    (data_wait_st && wait_cnt == 2) ? data_buf[191:128] :
                    (data_wait_st && wait_cnt == 1) ? data_buf[127:64] :
                    output_data
                ) :

                (d_size == 0) ? (
                    (data_wait_st && wait_cnt == 0) ? {56'b0,data_buf[7:0]} :
                    (data_wait_st && wait_cnt == 3) ? data_buf[255:192] :
                    (data_wait_st && wait_cnt == 2) ? data_buf[191:128] :
                    (data_wait_st && wait_cnt == 1) ? data_buf[127:64] :
                    output_data
                ) :

                output_data;


            output_data_wren        <=      (header_outp_st | data_wait_st) ? 1'b1 : 1'b0 ; //
            fifo_rden_buf_1         <=      output_fifo_rden;
            fifo_rden_buf_2         <=      fifo_rden_buf_1;
        //  noc_out_valid           <=      fifo_rden_buf_1;
        //  noc_out_data            <=      output_rd_data ;
			noc_out_valid			<=		(noc_out_ready && output_rden_cnt >= 8'd3 && data_reg_cnt < 8'd9)	?	1'b1	:	1'b0;			// using output_rden_cnt >= 3 due to few delays
            noc_out_data            <=      (data_reg_cnt == 8'd0) ? data_reg_01 :
											(data_reg_cnt == 8'd1) ? data_reg_02 :
											(data_reg_cnt == 8'd2) ? data_reg_03 :
											(data_reg_cnt == 8'd3) ? data_reg_04 :
											(data_reg_cnt == 8'd4) ? data_reg_05 :
											(data_reg_cnt == 8'd5) ? data_reg_06 :
											(data_reg_cnt == 8'd6) ? data_reg_07 :
											(data_reg_cnt == 8'd7) ? data_reg_08 :
											(data_reg_cnt == 8'd8) ? data_reg_09 :
											noc_out_data;
        //  noc_out_valid           <=      (output_rden_cnt >= 8'd1 && output_rden_cnt <

            //RESET during header_wait_st just before the header output and increments for every output_data_wren cycle
        //  wren_cnt                <=      (header_wait_st) ? 8'b0 :
        //                                  (output_data_wren) ? wren_cnt + 8'd1 :
        //                                  wren_cnt ;

            wren_cnt                <=      (acc_ack) ?  1'b1 :
                                            (fifo_idle_st) ? payload_length : wren_cnt ;

			busy					<= 		fifo_done_st 	? 1'b0: // negate
											header_rden_st	? 1'b1: // assert
											busy;					// hold

			if (coh2tl_prb_ack_no_data) begin
                noc_out_data        <=		64'b0;
                noc_out_valid       <=		1'b0;
            end
        end // else

    end //always comb


    // HEADER SM
    always@ (posedge clk) begin
        if(!reset_) begin
            tl2f_rx_header_re_i <= 1'b0;
            tl2f_rx_addr_re_i   <= 1'b0;
            tl2f_rx_bcnt_re_i   <= 1'b0 ;
            header_buf          <= 64'b0;
            actual_bcnt         <= 12'b0;
            bcnt_buf            <= 16'b0;
            delay_cnt           <= 4'b0 ;
            cmd_done            <= 1'b0 ; //+/2022-10-27 Shankar: To avoid multiple drivers

        end // if reset

        else begin
            case(tl2n_header_state)
                H_IDLE_ST : begin
                    tl2f_rx_header_re_i <= (!f2tl_rx_header_empty_i && !busy) ? 1'b1 : 1'b0;
                    tl2f_rx_addr_re_i   <= (!f2tl_rx_addr_empty_i && !busy) ? 1'b1 : 1'b0;
                    tl2f_rx_bcnt_re_i   <= (!f2tl_rx_bcnt_empty_i && !busy) ? 1'b1 : 1'b0;
                    bcnt_buf            <= 16'b0;
                    actual_bcnt         <= 12'b0;
                    delay_cnt           <= 4'b0 ;
                end
                H_RDEN_ST : begin
                    tl2f_rx_header_re_i <= 1'b0 ;
                    tl2f_rx_addr_re_i   <= 1'b0 ;
                    tl2f_rx_bcnt_re_i <= 1'b0 ;
                end
                H_DECO_ST : begin
                    header_buf          <= f2tl_rx_header_i;
                    bcnt_buf            <= f2tl_rx_bcnt_i ;
                    tl2f_rx_header_re_i <= 1'b0 ;
                    tl2f_rx_addr_re_i   <= 1'b0 ;
                    tl2f_rx_bcnt_re_i   <= 1'b0 ;
                end

                H_WAIT_ST : begin
                    //Add logic to subtract the padding and get the correct bcnt.
                    actual_bcnt         <= (acc_ack_data && d_size >= 4'd0 && d_size <= 4'd3)       ?  (d_size == 2)  ? (f2tl_rx_bcnt_i[11:0] -  'd28) :  //subtract the padding bytes(3 qwd + extra padding bytes in the qwd with data)
                                                                                                       (d_size == 1)  ? (f2tl_rx_bcnt_i[11:0] -  'd30) :  //subtract the padding bytes(3 qwd + extra padding bytes in the qwd with data)
                                                                                                       (d_size == 0)  ? (f2tl_rx_bcnt_i[11:0] -  'd31) :  //subtract the padding bytes(3 qwd + extra padding bytes in the qwd with data)
                                                                                                        f2tl_rx_bcnt_i[11:0] -  'd24                   :  //subtract 3 qwd of padding //AccAckData need one more padding to get 64 byte since it doesn't have d_sink
                                           (acc_ack_data && d_size == 4)                      ||
                                           (gnt_data     && d_size >= 4'd0 && d_size <= 4'd3)       ?  (d_size == 2)  ? (f2tl_rx_bcnt_i[11:0] -  'd20) :  //subtract the padding bytes(2 qwd + extra padding bytes in the qwd with data)
                                                                                                       (d_size == 1)  ? (f2tl_rx_bcnt_i[11:0] -  'd22) :  //subtract the padding bytes(2 qwd + extra padding bytes in the qwd with data)
                                                                                                       (d_size == 0)  ? (f2tl_rx_bcnt_i[11:0] -  'd23) :  //subtract the padding bytes(2 qwd + extra padding bytes in the qwd with data)
                                                                                                        f2tl_rx_bcnt_i[11:0] - 'd16                    :  //subtract 2 qwd of padding
                                           (acc_ack_data && d_size > 4'd4 && d_size <= 4'd6)  ||
                                           (gnt_data     && d_size >  4'd3 && d_size <= 4'd6)       ? (f2tl_rx_bcnt_i[11:0] - 'd8)     :    //subtract 1 qwd of padding //max size is 6. 2^6 bytes at once.
                                           f2tl_rx_bcnt_i[11:0] ;

                    delay_cnt           <= delay_cnt + 4'b1 ;
                end

                H_OUTP_ST : begin
                    cmd_done            <= 1'b1 ;
                end

                H_DONE_ST : begin
                    tl2f_rx_header_re_i <= 1'b0;
                    tl2f_rx_addr_re_i   <= 1'b0 ;
                    tl2f_rx_bcnt_re_i <= 1'b0 ;
                    cmd_done            <= 1'b0 ;
                end

                default: begin
                    tl2f_rx_header_re_i <= 1'b0 ;
                    tl2f_rx_addr_re_i   <= 1'b0 ;
                    tl2f_rx_bcnt_re_i   <= 1'b0 ;
                    cmd_done            <= 1'b0 ;
                    delay_cnt           <= 4'b0 ;
                end
            endcase
        end // else
    end // always header state machine


    // DATA SM
    always@ (posedge clk) begin
        if(!reset_) begin
            tl2f_rx_data_re_i               <=      1'b0 ;
            tl2f_rx_mask_re_i               <=      1'b0 ;
            data_bcnt                       <=      8'b0 ;
            data_rden_cnt                   <=      8'b0 ;
            actual_mask                     <=      64'b0;
        //  actual_data                     <=      256'b0;
            wait_cnt                        <=      4'b0 ;
            data_delay                      <=      4'b0 ;
            data_buf                        <=      256'b0; //+/2022-10-27 Shankar: To avoid multiple drivers
        end
        else begin
            case(tl2n_data_state)
                D_IDLE_ST   :   begin
                    tl2f_rx_data_re_i       <=      1'b0 ;
                    tl2f_rx_mask_re_i       <=      1'b0 ;
                    actual_mask             <=      64'b0;
                //  actual_data             <=      256'b0;
                    data_bcnt               <=      actual_bcnt;
                    data_rden_cnt           <=      {1'b0, bcnt_buf[11:5]} + |(bcnt_buf[4:0]) ;
                    data_delay              <=      4'b0 ;
                end
                D_RDEN_ST   :   begin
                    tl2f_rx_data_re_i       <=      1'b1 ;
                    tl2f_rx_mask_re_i       <=      (!f2tl_rx_mask_empty_i) ? 1'b1 : 1'b0 ;
                    wait_cnt                <=      4'b0 ;
                    data_rden_cnt           <=      data_rden_cnt - 8'd1 ;
                    data_delay              <=      4'b0 ;
                end

                D_LOAD_ST   : begin
                    data_delay              <=      data_delay + 4'b1 ;
                    tl2f_rx_data_re_i       <=      1'b0 ;
                    tl2f_rx_mask_re_i       <=      1'b0 ;
                    case(actual_bcnt)
                        8'd64: data_buf <= f2tl_rx_data_i;
                        8'd32: data_buf <= f2tl_rx_data_i;
                        8'd16: data_buf <= f2tl_rx_data_i[127:0];
                        8'd08: data_buf <= f2tl_rx_data_i[63:0];
                        8'd04: data_buf <= f2tl_rx_data_i[31:0];
                        8'd02: data_buf <= f2tl_rx_data_i[15:0];
                        8'd01: data_buf <= f2tl_rx_data_i[7:0];
                    endcase

                    case(actual_bcnt)
                        8'd64: actual_mask <= 64'b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd63: actual_mask <= 64'b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd62: actual_mask <= 64'b0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd61: actual_mask <= 64'b0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd60: actual_mask <= 64'b0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd59: actual_mask <= 64'b0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd58: actual_mask <= 64'b0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd57: actual_mask <= 64'b0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd56: actual_mask <= 64'b0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd55: actual_mask <= 64'b0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd54: actual_mask <= 64'b0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd53: actual_mask <= 64'b0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd52: actual_mask <= 64'b0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd51: actual_mask <= 64'b0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd50: actual_mask <= 64'b0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd49: actual_mask <= 64'b0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd48: actual_mask <= 64'b0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd47: actual_mask <= 64'b0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd46: actual_mask <= 64'b0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd45: actual_mask <= 64'b0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd44: actual_mask <= 64'b0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd43: actual_mask <= 64'b0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd42: actual_mask <= 64'b0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd41: actual_mask <= 64'b0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd40: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd39: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd38: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd37: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd36: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd35: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd34: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd33: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd32: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd31: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd30: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd29: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111 ;
                        8'd28: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111 ;

                        8'd27: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111 ;
                        8'd26: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111 ;
                        8'd25: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111 ;
                        8'd24: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111 ;

                        8'd23: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111 ;
                        8'd22: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111 ;
                        8'd21: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111 ;
                        8'd20: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111 ;

                        8'd19: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111 ;
                        8'd18: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111 ;
                        8'd17: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111 ;
                        8'd16: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111 ;

                        8'd15: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111 ;
                        8'd14: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111 ;
                        8'd13: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111 ;
                        8'd12: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111 ;

                        8'd11: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111 ;
                        8'd10: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111 ;
                        8'd09: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111 ;
                        8'd08: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111 ;

                        8'd07: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111 ;
                        8'd06: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111 ;
                        8'd05: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111 ;
                        8'd04: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111 ;

                        8'd03: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111 ;
                        8'd02: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011 ;
                        8'd01: actual_mask <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001 ;
                    endcase
                end

                D_WAIT_ST   :   begin
                    tl2f_rx_data_re_i       <=      1'b0 ;
                    tl2f_rx_mask_re_i       <=      1'b0 ;
                    data_bcnt               <=      (data_bcnt > 8'b0) ? data_bcnt - 8'd8 : data_bcnt ;
                    wait_cnt                <=      wait_cnt + 4'd1 ;
                end

                D_DONE_ST   :   begin
                    data_bcnt               <=      8'b0;
                    tl2f_rx_data_re_i       <=      1'b0 ;
                    tl2f_rx_mask_re_i       <=      1'b0 ;
                end

                default     : begin
                    tl2f_rx_data_re_i       <=      1'b0 ;
                    tl2f_rx_mask_re_i       <=      1'b0 ;
                end
        endcase
        end // else
    end // always data sm


    reg [9*8:0] ascii_tl2n_header_state;
    reg [9*8:0] ascii_tl2n_data_state;
    reg [9*8:0] ascii_tl2n_fifo_state;

    always@ (tl2n_header_state) begin
        case(tl2n_header_state)
            H_IDLE_ST   :       ascii_tl2n_header_state = "H_IDLE_ST";
            H_RDEN_ST   :       ascii_tl2n_header_state = "H_RDEN_ST";
            H_DECO_ST   :       ascii_tl2n_header_state = "H_DECO_ST";
            H_WAIT_ST   :       ascii_tl2n_header_state = "H_WAIT_ST";
            H_OUTP_ST   :       ascii_tl2n_header_state = "H_OUTP_ST";
            H_DONE_ST   :       ascii_tl2n_header_state = "H_DONE_ST";
        endcase
    end // always tl2n_header_state

    always@ (tl2n_data_state) begin
        case(tl2n_data_state)
            D_IDLE_ST   :       ascii_tl2n_data_state = "D_IDLE_ST" ;
            D_RDEN_ST   :       ascii_tl2n_data_state = "D_RDEN_ST" ;
            D_LOAD_ST   :       ascii_tl2n_data_state = "D_LOAD_ST" ;
            D_WAIT_ST   :       ascii_tl2n_data_state = "D_WAIT_ST" ;
            D_DONE_ST   :       ascii_tl2n_data_state = "D_DONE_ST" ;
        endcase
    end // always tl2n_data_state

    always@ (tl2n_fifo_state) begin
        case(tl2n_fifo_state)
            F_IDLE_ST   :       ascii_tl2n_fifo_state = "F_IDLE_ST" ;
            F_RDEN_ST   :       ascii_tl2n_fifo_state = "F_RDEN_ST" ;
            F_DONE_ST   :       ascii_tl2n_fifo_state = "F_DONE_ST" ;
            F_DONE2_ST  :       ascii_tl2n_fifo_state = "F_DONE2_ST" ;

        endcase
    end // always tl2n_data_state
endmodule
