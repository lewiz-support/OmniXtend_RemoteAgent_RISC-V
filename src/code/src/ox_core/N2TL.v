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

module N2TL
    #(  parameter   DATA_WIDTH  =   64)
    (
    input clk,
    input reset_,
    // From NOC MASTER
    input                     noc_valid,
    input [DATA_WIDTH - 1:0]  noc_data,
    
    // TO NOC_MASTER
    output reg                noc_ready,
    
    // Inputs from FIFO
    input                          f2tl_tx_header_full_i,
    input                          f2tl_tx_addr_full_i,
    input                          f2tl_tx_mask_full_i,
    input                          f2tl_tx_data_full_i,
    input                          f2tl_tx_bcnt_full_i,
    
    
    // Outputs to FIFO
    output reg [DATA_WIDTH - 1:0]  tl2f_tx_header_i,
    output reg                     tl2f_tx_header_we_i,
    output reg [DATA_WIDTH - 1:0]  tl2f_tx_addr_i,
    output reg                     tl2f_tx_addr_we_i,
    output reg [DATA_WIDTH - 1:0]  tl2f_tx_mask_i,
    output reg                     tl2f_tx_mask_we_i,
    output reg [255:0]             tl2f_tx_data_i,
    output reg                     tl2f_tx_data_we_i,
    output reg [15:0]              tl2f_tx_bcnt_i,
    output reg                     tl2f_tx_bcnt_we_i,

    // Interface to/from COHERENT MGR for ACQUIRE function
    input 						   coh2tl_tx_acquire_req_ack,       // from Coherent MGR to negate acquire request
	input						   coh2tl_tx_acquire_gen_en,        // from Coherent MGR to generate TL AcquireBlock packet
	input                          coh2tl_gntack_gen_en,            // from Coherent MGR to generate a GrantAck packet
	output reg					   tl2coh_tx_acquire_req,	        // to Coherent MGR
	output reg					   tl2coh_tx_acquire_gen_done,	    // to Coherent MGR
	output reg                     tl2coh_tx_gntack_gen_done,       // to Coherent MGR
	
	//Interface to/from COHERENT MGR for PROBE function   (ADDED ONLY FOR PROBEACK and PROBEACKDATA)           //20220526 
	
	input                          coh2tl_tx_prb_flush_wait,        // from Coherent MGR
	input                          coh2tl_prb_ack_w_data,           // from Coherent MGR
	input                          coh2tl_prb_ack_no_data,          // from Coherent MGR
	output reg                     tl2coh_tx_probe_req_done,        // To Coherent manager
	
	// Interface to/from COHERENT MGR for RELEASE function
	input                          tl2coh_tx_release_req_ack,       // from Coherent MGR to negate release request
	output reg                     tl2coh_tx_release_req,           // to Coherent MGR
		
	input      [3:0]               c_prb_ack_size,                  // from Coherent MGR for ProbeAck TL message
	input      [25:0]              c_prb_ack_source,                // from Coherent MGR for ProbeAck TL message
	input      [63:0]              c_prb_ack_address,               // from Coherent MGR for ProbeAck TL message	
	input      [25:0]              e_sink,                          // from Coherent MGR for GrantAck TL message
	
	// Config signal for byte count 
	input                          lewiz_noc_mode 
	
	
	);
    
    reg                     valid;           //initial flop to store input valid
    reg                     probe_ack_valid;      //for use in PROBEAck no data - self generating
    reg  [DATA_WIDTH-1:0]  	data;            //initial flop to store input data

    wire                    put;
    wire                    get; 
    wire                    acquire;
    wire                    relse; 
    wire                    relse_data;  
    wire                    probe_ack;  
    wire					probe_ack_data ;		//for use during Probe response cycle. If this is 1, 
    												//Logic will translate the NOC cycle to ProbeAck* cycle
    
    reg  [7:0]              qwd_cnter;       //counts the number of input received
    wire                    end_of_pkt;      // HIGH at the end of each pkt, otherwise LOW
    wire                    fifo_full;       // if any of the fifo is full
    wire                    data_begin;      // indicates beginning of payload
    wire [7:0]              pld_length_cal;  // temp reg value for mask calculation
//    reg  [7:0]              pld_length_cal;  // temp reg value for mask calculation
//    reg  [15:0]             tl2f_tx_bcnt_i;     // show the number of enabled bits
//    reg  [7:0]              total_byte_cnt;  // Total number of byte in msg
    wire [7:0]              total_byte_cnt;  // Total number of byte in msg
    
    reg                     addr_mode;       // set to either piton mode for 64byte
    

     
    reg  [7:0]              data_load_cnter; // count the number of 64bit data stored in data_temp
   
    reg  [7:0]              tlc_header_state;
    wire                    header_idle_st;
    wire                    header_deco_st;
    wire                    header_wait_st;
    wire                    header_done_st;
    
    reg  [3:0]              tlc_data_state;
    wire                    data_idle_st;
    wire                    data_load_st;
    wire                    data_done_st;
   
    
    //============== DECODED SIGNALS (NOC)==============    
    // FLIT 1
    reg  [13:0]	dst_chipid;
    reg  [7:0]  dst_xpos;
    reg  [7:0]  dst_ypos;
    reg  [3:0]  dst_fbits;
    reg  [7:0]  payload_length;
    reg  [7:0]  msg_type;
    reg  [7:0]  tag;
    // FLIT 2
    reg  [47:0] dst_addr;
    reg  [2:0]  noc_data_size;
    reg  [2:0]  last_byte_cnt;//for LeWiz Purposes only, not for NOC caches
    // FLIT 3
    reg  [13:0] src_chipid;
    reg  [7:0]  src_xpos;
    reg  [7:0]  src_ypos;
    reg  [3:0]  src_fbits;
    
    reg  [6:0]  tl_addr_align;
 
    //============== TileLink SIGNALS ==============
    //============== Channel A =====================
    reg  [25:0]  a_source;          // {TAG, DST_CHIPID}
    reg  [3:0]   a_size;            // PAYLOAD_LENGTH
    reg  [2:0]   a_opcode;          // MSG_TYPE
    //reg          a_valid;
    reg          a_ready; 
    reg  [3:0]   a_param;           // zero for now
    //reg  [255:0] a_data;            //{DATA_4, DATA_3, DATA_2, DATA_1}
    reg          a_corrupt;
    reg  [63:0]  a_mask;            // Based on PAYLOAD_LENGTH
    reg  [63:0]  a_addr;            //{DST_XPOS, DST_YPOST, DST_ADDR}
    reg  [7:0]   a_domain;          // all zero
    
    // ??? need to take channel into account
    //============== Channel C =====================
    reg  [25:0]  c_source;          // {TAG, DST_CHIPID}
    reg  [3:0]   c_size;            // PAYLOAD_LENGTH
    reg  [2:0]   c_opcode;          // MSG_TYPE
    //reg          c_valid;
    reg          c_ready; 
    reg  [3:0]   c_param;           // zero for now
    //reg  [255:0] c_data;            //{DATA_4, DATA_3, DATA_2, DATA_1}
    reg          c_corrupt;
    //reg  [63:0]  c_mask;            // Based on PAYLOAD_LENGTH
    reg  [63:0]  c_addr;            //{DST_XPOS, DST_YPOST, DST_ADDR}
    reg  [7:0]   c_domain;          // all zero
    
    localparam PITON_MODE             = 1'b1;   // use for addr alignment. PITON mode always align to 64Byte
    localparam NOT_PITON_MODE         = 1'b0;   // allow odd number of alignment
    
    localparam HEADER_IDLE_ST         = 8'h01;
    localparam HEADER_DECO_ST         = 8'h02;
    localparam HEADER_WAIT_ST         = 8'h04;
    localparam HEADER_DONE_ST         = 8'h80;
   
    localparam DATA_IDLE_ST           = 4'h1;
    localparam DATA_LOAD_ST           = 4'h2;
    localparam DATA_DONE_ST           = 4'h8;
    
    // CHANNELS
    localparam CH_A                   = 3'd1;
    localparam CH_B                   = 3'd2;
    localparam CH_C                   = 3'd3;
    localparam CH_D                   = 3'd4;
    localparam CH_E                   = 3'd5;
    
    // NOC MSG_TYPE
    localparam STORE_REQ              = 8'd2;	//cacheable
    localparam WB_REQ				  = 8'd12;
    localparam LOAD_MEM               = 8'd19;	//cacheable
    localparam STORE_MEM              = 8'd20;	//cacheable
    localparam LOAD_MEM_ACK           = 8'd24;
    localparam STORE_MEM_ACK          = 8'd25;
    localparam LOAD_REQ               = 8'd31;	//cacheable (assume, 20220422)
    localparam L2_LINE_FLUSH_REQ      = 8'd34;
    localparam L2_DIS_FLUSH_REQ       = 8'd35;  //(20220526)
    localparam NC_LOAD_REQ            = 8'd14;	//non-cacheable, Load_Req  - treat as = GET
    localparam NC_STORE_REQ           = 8'd15;	//non-cacheable, Store_Req - treat as = PUT
    
    // TileLink OPCODE
    localparam OPCODE_GET             = 3'd4;
    localparam OPCODE_PUT_FULL_DATA   = 3'd0;
    localparam OPCODE_PUT_PARTIAL_DATA= 3'd1;
    localparam OPCODE_ACCESS_ACK      = 3'd0;
    localparam OPCODE_ACCESS_ACK_DATA = 3'd1;
    localparam OPCODE_ACQUIRE_BLOCK   = 3'd6;	// for COHERENCY   20220422, on wave shows as C
    localparam OPCODE_RELEASE         = 3'd6;	// for COHERENCY
    localparam OPCODE_RELEASE_DATA    = 3'd7;	// for COHERENCY
    localparam OPCODE_PROBE_ACK       = 3'd4;   // for COHERENCY 20220526
    localparam OPCODE_PROBE_ACK_DATA  = 3'd5;   // for COHERENCY 20220526
    
    assign header_idle_st 	= tlc_header_state[0];
    assign header_deco_st 	= tlc_header_state[1];
    assign header_wait_st 	= tlc_header_state[2];
    assign header_done_st 	= tlc_header_state[7];
    
    assign data_idle_st   	= tlc_data_state[0];
    assign data_load_st   	= tlc_data_state[1];
    assign data_done_st   	= tlc_data_state[3];
    
    assign data_begin 	  	= (qwd_cnter >= 8'd3) ? 1'b1 : 1'b0;
    //??? May need to include ACQUIRE, RELEASE ?
//	assign end_of_pkt 	  	= (put && qwd_cnter > 8'd0 && qwd_cnter == payload_length + 8'd2) ? 1'b1 : 
    assign end_of_pkt 	  	= //(put && qwd_cnter > 8'd0 && qwd_cnter == payload_length + 8'd2) ? 1'b1 :
    
    								//Probe Ack data conditions
    						     probe_ack_data? 
    								((qwd_cnter > 8'd0 && (qwd_cnter == (payload_length + 8'd2) ) ) ? 1'b1 : 1'b0) :
    					
    								//1'b0
    							 //:		//end of probe ack data cycle
    						
    						//Probe ack conditions //20220602
    						      //probe_ack_cycle? 
    								//((qwd_cnter > 8'd0 && (qwd_cnter == 8'd3 ) ) ? 1'b1 : 1'b0) :
    						//end of probe ack cycle
    						
    						//20220606 //for PROBE
    						
    						   probe_ack?((qwd_cnter > 8'd0 && (qwd_cnter == 8'd3))? 1'b1: 1'b0):
    							//from previous
                              ((put | relse_data) && qwd_cnter > 8'd0 && qwd_cnter == payload_length + 8'd2) ? 1'b1 : 
                              (get && qwd_cnter > 8'd0 && qwd_cnter == 8'd3)                  ? 1'b1 :
                        	  //(coh2tl_tx_acquire_gen_en && qwd_cnter > 8'd0 && qwd_cnter == 8'd2) ? 1'b1 :
                        	  (coh2tl_tx_acquire_req_ack && qwd_cnter == 8'd3)                ? 1'b1 :
                        	  //(tl2coh_tx_release_req_ack)                                     ? 1'b1 :
                        	  //(tl2coh_tx_release_req_ack)                                     ? 1'b1 :
                        	  (relse && qwd_cnter > 8'd0 && qwd_cnter == 8'd3)                ? 1'b1 :
                        	  
                        	  (tl2coh_tx_gntack_gen_done)                                     ? 1'b1 :
                        	   1'b0; // When payload_length does not include any header flits (+2)
                        	   
                        	   
    assign fifo_full  	  	= (f2tl_tx_header_full_i | f2tl_tx_addr_full_i | f2tl_tx_mask_full_i | f2tl_tx_data_full_i) ? 1'b1 : 1'b0;
//	assign put          	= (msg_type == STORE_MEM || msg_type == STORE_REQ) ? 1'b1 : 1'b0;
    assign put        	  	= (msg_type == NC_STORE_REQ) ? 1'b1 : 1'b0;               // NC_STORE_REQ = 15
    	//this is combinational logic
//  assign get          	= (msg_type == LOAD_MEM || msg_type == LOAD_REQ) ? 1'b1 : 1'b0; 
    assign get        	  	= (msg_type == NC_LOAD_REQ) ? 1'b1 : 1'b0; 	//20220422
    assign acquire          = (msg_type == LOAD_MEM || msg_type == LOAD_REQ)        ? 1'b1  : 1'b0   ;
    assign relse            = (msg_type == WB_REQ) & !(coh2tl_tx_prb_flush_wait)    ? 1'b1  : 1'b0   ;
    assign relse_data       = (msg_type == L2_LINE_FLUSH_REQ)                       ? 1'b1  : 1'b0   ;
    assign total_byte_cnt  	= (tl2f_tx_bcnt_i > 16'd0  && tl2f_tx_bcnt_i <= 16'd2 ) ? tl2f_tx_bcnt_i :
                              (tl2f_tx_bcnt_i > 16'd2  && tl2f_tx_bcnt_i <= 16'd4 ) ? 8'd4  :
                              (tl2f_tx_bcnt_i > 16'd4  && tl2f_tx_bcnt_i <= 16'd8 ) ? 8'd8  :
                              (tl2f_tx_bcnt_i > 16'd8  && tl2f_tx_bcnt_i <= 16'd16) ? 8'd16 :
                              (tl2f_tx_bcnt_i > 16'd16 && tl2f_tx_bcnt_i <= 16'd32) ? 8'd32 :
                              (tl2f_tx_bcnt_i > 16'd32 && tl2f_tx_bcnt_i <= 16'd64) ? 8'd64 :
                               8'd0 ;
    assign probe_ack       = (coh2tl_prb_ack_no_data && coh2tl_tx_prb_flush_wait)     ? 1'b1  : 1'b0   ;
    assign probe_ack_data  = ((msg_type == WB_REQ) & coh2tl_tx_prb_flush_wait 
                                                         & coh2tl_prb_ack_w_data)     ? 1'b1  : 1'b0   ;
    assign pld_length_cal  	= ((header_deco_st | header_wait_st) & |payload_length) ? payload_length << 3 
                                                                                            : 8'b0;                // converts payload length to bcnt
    
    //assign probe_ack_data_cycle = (msg_type == L2_DIS_FLUSH_REQ) & coh2tl_tx_prb_flush_wait ? 1'b1 : 1'b0; //20220602  for probe ack data 
    // pld_length_cal in Byte count; payload_length in Qword
    assign pld_length_cal  	= ((header_deco_st | header_wait_st) & |payload_length) ? payload_length << 3 : 8'b0;                // converts payload length to bcnt
    
 
 
    always@ (posedge clk) begin                         // Header State Machine
        if(!reset_) begin
            tlc_header_state <= HEADER_IDLE_ST;
        end // if reset
        
        else begin
            if(header_idle_st)
                //tlc_header_state <= noc_valid ? HEADER_DECO_ST : HEADER_IDLE_ST;
                //tlc_header_state <= noc_valid            ? HEADER_DECO_ST : 
                //tlc_header_state <= noc_valid & coh2tl_prb_ack_w_data   ? HEADER_DECO_ST :
                tlc_header_state <= valid                   ? HEADER_DECO_ST :
                                    coh2tl_gntack_gen_en ? HEADER_WAIT_ST :
                                    HEADER_IDLE_ST;
            if(header_deco_st)
                tlc_header_state <= (qwd_cnter == 8'd2) ? HEADER_WAIT_ST :
                                                          HEADER_DECO_ST;  // qwd_cnter == 2: Last of cmd flit
//                tlc_header_state <= (qwd_cnter == 8'd2) ? ((put) ? HEADER_WAIT_ST :
//                                                           (get) ? HEADER_DONE_ST :
//                                                           HEADER_DECO_ST) : HEADER_DECO_ST;  // qwd_cnter == 2: Last of cmd flit
            if(header_wait_st)
            		//??? may need to include ACQUIRE and RELEASE?
                //tlc_header_state <= (end_of_pkt | get) ? HEADER_DONE_ST : HEADER_WAIT_ST;
                tlc_header_state <= (end_of_pkt | get | coh2tl_tx_acquire_gen_en | coh2tl_gntack_gen_en) ? HEADER_DONE_ST : HEADER_WAIT_ST;
//                tlc_header_state <= (end_of_pkt) ? HEADER_DONE_ST : HEADER_WAIT_ST;
            if(header_done_st)
                tlc_header_state <= HEADER_IDLE_ST;
        end // else
    end // always
    

    always@ (posedge clk) begin                         // Data State Machine
        if(!reset_) begin
            tlc_data_state <= DATA_IDLE_ST;
        end // if !reset_
        
        else begin
            if(data_idle_st) 
            		//20220602 (added condition for probe ack data)  
                tlc_data_state <= ((put | relse_data | probe_ack_data) & qwd_cnter == 8'd2 & !end_of_pkt) ? DATA_LOAD_ST : 
                                  //(put & qwd_cnter == 8'd2 & end_of_pkt)  ? DATA_DONE_ST :    // For when there's only 1 qwd or less of payload
                                  ((put | relse_data | probe_ack_data) & qwd_cnter == 8'd2 & (end_of_pkt))  ? DATA_DONE_ST :   
                                  DATA_IDLE_ST;
            if(data_load_st)
                tlc_data_state <= (end_of_pkt) ? DATA_DONE_ST : DATA_LOAD_ST;
            if(data_done_st)    
                tlc_data_state <= DATA_IDLE_ST;
        end // else
    end // always Data State Machine

    
    always@(posedge clk) begin
        if(!reset_) begin
            noc_data_size   <= 3'b0;
            addr_mode       <= 1'b0 ;
            valid           <= 1'b0 ;
            data            <= 64'b0 ;
            qwd_cnter       <= 8'b0 ;
//            pld_length_cal  <= 8'b0 ;
            tl2f_tx_bcnt_i  <= 16'b0 ;
//            total_byte_cnt  <= 8'b0 ;
            tl_addr_align   <= 6'b0;
            data_load_cnter <= 8'b0 ;
            
            dst_chipid      <= 14'b0 ;
            dst_xpos        <= 8'b0 ;
            dst_ypos        <= 8'b0 ;
            dst_fbits       <= 4'b0 ;
            payload_length  <= 8'b0 ;
            msg_type        <= 8'b0 ;
            tag             <= 8'b0 ;
            dst_addr        <= 48'b0 ;
            last_byte_cnt   <= 3'b0 ;
            src_chipid      <= 14'b0 ;
            src_xpos        <= 8'b0 ;
            src_ypos        <= 8'b0 ;
            src_fbits       <= 4'b0 ;
            
            // Channel A
            a_source        <= 26'b0 ;
            a_size          <= 4'b0 ;
            a_opcode        <= 3'b0 ;
            //a_valid         <= 1'b0; // Using FIFO wr_en instead
            a_ready         <= 1'b0 ;
            a_param         <= 4'b0 ;
            //a_data          <= 256'b0; // Using FIFO data bus instead
            a_corrupt       <= 1'b0 ;
            a_mask          <= 64'b0 ;
            a_addr          <= 64'b0 ;
            a_domain        <= 8'b0 ;            
            
            // Channel C
            c_source        <= 26'b0 ;
            c_size          <= 4'b0 ;
            c_opcode        <= 3'b0 ;
            //c_valid         <= 1'b0; // Using FIFO wr_en instead
            c_ready         <= 1'b0 ;
            c_param         <= 4'b0 ;
            //c_data          <= 256'b0; // Using FIFO data bus instead
            c_corrupt       <= 1'b0 ;
            //c_mask          <= 64'b0 ;
            c_addr          <= 64'b0 ;
            c_domain        <= 8'b0 ;   

            // OUTPUT REGISTERS
            noc_ready           <= 1'b0;
            
            tl2f_tx_header_we_i <= 1'b0 ;
            tl2f_tx_addr_we_i   <= 1'b0 ;
            tl2f_tx_mask_we_i   <= 1'b0 ;
            tl2f_tx_data_we_i   <= 1'b0 ;
            tl2f_tx_bcnt_we_i   <= 1'b0 ;
            
            tl2f_tx_header_i    <= 64'b0 ;
            tl2f_tx_addr_i      <= 64'b0 ;
            tl2f_tx_mask_i      <= 64'b0 ;
            tl2f_tx_data_i      <= 256'b0 ;
            tl2f_tx_bcnt_i      <= 16'b0 ;
        end // if reset_
        
        else begin
            addr_mode       <= PITON_MODE ;                   // PITON_MODE: align to 64 Byte
            noc_ready       <= (header_idle_st) ? 1'b1: 1'b0; // | header_done_st
//            noc_ready <= ((header_idle_st | header_done_st) & !fifo_full) ? 1'b1: 1'b0;           // Use when connecting to FIFO
            //valid           <= noc_valid; 
            valid           <= coh2tl_prb_ack_no_data ? probe_ack_valid :   //for testing probeack NO data
                               noc_valid ;                                  //for probeAck with data or normal cases from NOC master
                    
            data            <= noc_data;
            qwd_cnter       <= (!end_of_pkt) ? (valid) ? qwd_cnter + 1 : qwd_cnter : 8'b0; //reset at done_st
            
            data_load_cnter <= (data_load_st) ? ((data_load_cnter <= 8'd2 && !end_of_pkt) ? data_load_cnter + 8'd1 : 8'b0) : 8'b0;
            
            // ===================== ASSIGN NOC CMD =====================
            dst_chipid      <= (qwd_cnter == 8'd0) ? data[63:50] : dst_chipid ;
            dst_xpos        <= (qwd_cnter == 8'd0) ? data[49:42] : dst_xpos ;
            dst_ypos        <= (qwd_cnter == 8'd0) ? data[41:34] : dst_ypos ;
            dst_fbits       <= (qwd_cnter == 8'd0) ? data[33:30] : dst_fbits ;
            payload_length  <= (qwd_cnter == 8'd0) ? data[29:22] : payload_length ;
        //-/msg_type        <= (qwd_cnter == 8'd0) ? data[21:14] : msg_type ; 
            msg_type        <= (qwd_cnter == 8'd0) ? ((data[21:14] == LOAD_MEM) ? NC_LOAD_REQ : data[21:14]) : msg_type ; //+/	//2022-10-10: temporarily convert acquire to get
            tag             <= (qwd_cnter == 8'd0) ? data[13:6]  : tag ;
            
            dst_addr        <= (qwd_cnter == 8'd1) ? data[63:16] : dst_addr ;
            noc_data_size   <= (qwd_cnter == 8'd1) ? data[10:8] : noc_data_size ;
            last_byte_cnt   <= (qwd_cnter == 8'd1) ? data[2:0]   : last_byte_cnt ;  //only in LeWiz mode
            
            src_chipid      <= (qwd_cnter == 8'd2) ? data[63:50] : src_chipid ;
            src_xpos        <= (qwd_cnter == 8'd2) ? data[49:42] : src_xpos ;
            src_ypos        <= (qwd_cnter == 8'd2) ? data[41:34] : src_ypos ;
            src_fbits       <= (qwd_cnter == 8'd2) ? data[33:30] : src_fbits ;
            
            // ===================== ASSIGN TLC CMD =====================
            
            // Statement for selecting the channel A or C
            
            // Channel A
            if (put | get | acquire)
            begin
            // a_source        <= {src_chipid[5:0],src_xpos,src_ypos,tag[3:0]};
            a_source        <= (qwd_cnter == 8'd3) ? {src_chipid[5:0],src_xpos,src_ypos,tag[3:0]} : a_source;    // 20220511  ** chipid uses the MSB as id to identify the CPU 10/04/22
//            a_size          <= payload_length[3:0];
              
//            size 1 - 4 doesn't work with pl_length_cal

//            case(pld_length_cal)                // a_size: 2^n of byte size (total_byte_cnt)
//                8'd1 :  begin
//                             a_size <= 4'd0;
//                             tl_addr_align <= 6'b11_1111;
//                        end    
//                8'd2 :  begin
//                             a_size <= 4'd1;
//                             tl_addr_align <= 6'b11_1110;
//                        end     
//                8'd4 :  begin
//                             a_size <= 4'd2;
//                             tl_addr_align <= 6'b11_1100;
//                        end     
//                8'd8 :  begin
//                             a_size <= 4'd3;
//                             tl_addr_align <= 6'b11_1000;
//                        end     
//                8'd16:  begin
//                             a_size <= 4'd4;
//                             tl_addr_align <= 6'b11_0000;
//                        end     
//                8'd32:  begin
//                             a_size <= 4'd5;
//                             tl_addr_align <= 6'b10_0000;
//                        end     
//                8'd64:  begin
//                             a_size <= 4'd6;
//                             tl_addr_align <= 6'b00_0000;
//                        end
//                default:begin
//                             a_size <= 4'd0;
//                             tl_addr_align <= 6'b00_0000;
//                        end     
//            endcase
         
//            a_size          <= noc_data_size;                                                                        // using the noc data size instead of the payload length 20221004
            a_size          <= (addr_mode == PITON_MODE)                        ?   4'd6:
                                (tl2f_tx_bcnt_i == 0                             ?   a_size   :
                                tl2f_tx_bcnt_i == 1                              ?   4'd0:
                                tl2f_tx_bcnt_i == 2                              ?   4'd1:
                                (tl2f_tx_bcnt_i) > 2  && (tl2f_tx_bcnt_i <= 4)   ?   4'd2:
                                (tl2f_tx_bcnt_i) > 4  && (tl2f_tx_bcnt_i <= 8)   ?   4'd3:
                                (tl2f_tx_bcnt_i) > 8  && (tl2f_tx_bcnt_i <= 16)  ?   4'd4:
                                (tl2f_tx_bcnt_i) > 16 && (tl2f_tx_bcnt_i <= 32)  ?   4'd5:
                                (tl2f_tx_bcnt_i) > 32 && (tl2f_tx_bcnt_i <= 64)  ?   4'd6:                         // don't need as it max out at 6: 9/29 by Kit
                                4'd6);
                               
            tl_addr_align   <= (addr_mode == PITON_MODE)                           ?   7'b100_0000:
                              // addr mode == not piton mode then we do this:
                               (header_deco_st) ?
                               (!tl2f_tx_bcnt_we_i) ? tl_addr_align :
                               ((tl2f_tx_bcnt_i == 1)                              ?   7'b111_1111:                     // addr is aligned to size, using 6 bit alignment for 6 bit size
                                (tl2f_tx_bcnt_i == 2)                              ?   7'b111_1110:                     //
                                (tl2f_tx_bcnt_i > 2)  && (tl2f_tx_bcnt_i <= 4)     ?   7'b111_1100:
                                (tl2f_tx_bcnt_i > 4)  && (tl2f_tx_bcnt_i <= 8)     ?   7'b111_1000:
                                (tl2f_tx_bcnt_i > 8)  && (tl2f_tx_bcnt_i <= 16)    ?   7'b111_0000:
                                (tl2f_tx_bcnt_i > 16) && (tl2f_tx_bcnt_i <= 32)    ?   7'b110_0000:
                                (tl2f_tx_bcnt_i) > 32 && (tl2f_tx_bcnt_i <= 64)    ?   7'b100_0000:
                                7'b111_1111)   :     tl_addr_align;

            a_addr          <= (qwd_cnter == 8'd2) ? {{dst_xpos,dst_ypos,dst_addr[47:7]}, dst_addr[6:0] & tl_addr_align} : a_addr;
            a_opcode        <= 
            				(qwd_cnter >= 8'd1) ? // =2
            						//for COHERENCY   20220421
            						//may need to adjust later with the correct state. QWD_CNTER may not be the right time
            					//coh2tl_tx_acquire_gen_en ? (OPCODE_ACQUIRE_BLOCK ) :
            					tl2coh_tx_acquire_req                                   ? OPCODE_ACQUIRE_BLOCK      :
            						//normal PUT and GET
                               //(msg_type == STORE_REQ  || msg_type == STORE_MEM && tl2f_tx_bcnt_i == 16'd64) ? OPCODE_PUT_FULL_DATA : 
                               //(msg_type == NC_STORE_REQ && tl2f_tx_bcnt_i == 16'd64)   ? OPCODE_PUT_FULL_DATA      : 
                               //((msg_type == STORE_REQ  || msg_type == STORE_MEM) && tl2f_tx_bcnt_i < 16'd64) ? OPCODE_PUT_PARTIAL_DATA :
                               //((msg_type == NC_STORE_REQ) && tl2f_tx_bcnt_i < 16'd64)  ? OPCODE_PUT_PARTIAL_DATA   :
                               (msg_type == NC_STORE_REQ && payload_length == 8'd8)   ? OPCODE_PUT_FULL_DATA        :
                               (msg_type == NC_STORE_REQ && payload_length < 8'd8)  ? OPCODE_PUT_PARTIAL_DATA       :
                               //(msg_type == LOAD_MEM   || msg_type == LOAD_REQ)  ? OPCODE_GET :
                               (msg_type == NC_LOAD_REQ)                                ? OPCODE_GET                :		//20220422 CLE
                               (msg_type == STORE_MEM_ACK)                              ? OPCODE_ACCESS_ACK         :
                               (msg_type == LOAD_MEM_ACK)                               ? OPCODE_ACCESS_ACK_DATA    :
                               3'b0 : 3'b0;
            
            // Acquire use param Grow NtoB (0)                  
            a_param         <= (msg_type == STORE_REQ       ||  msg_type == STORE_MEM ||
                                msg_type == LOAD_MEM        ||  msg_type == LOAD_REQ  ||
                                msg_type == STORE_MEM_ACK   ||  msg_type == LOAD_MEM_ACK) ? 4'b0 : 
                                4'b0 ;
            a_domain        <=  8'b0;       // Domain always zero  
            a_ready         <=  (fifo_full) ? 1'b0 : 1'b1;
            //a_ready         <=  (fifo_full  | header_done_st)   ? 1'b0  : 
            //                    (put | get  | acquire       )   ? 1'b1  :
            //                     a_ready;
            
            end
            
            // Channel C
            //for COHERENCY   20220502
            else if (relse | relse_data | probe_ack | probe_ack_data ) //ADDED FOR PROBEACK 20220601
            begin
            // c_source        <= {src_chipid[5:0],src_xpos,src_ypos,tag[3:0]};
            c_source        <= (qwd_cnter == 8'd3) ? {src_chipid[5:0],src_xpos,src_ypos,tag[3:0]} : c_source;    // 20220511 
//            a_size          <= payload_length[3:0];
//            case(pld_length_cal)                // a_size: 2^n of byte size (total_byte_cnt)
//                8'd1 :  begin
//                             c_size <= 4'd0;
//                             tl_addr_align <= 6'b11_1111;
//                        end    
//                8'd2 :  begin
//                             c_size <= 4'd1;
//                             tl_addr_align <= 6'b11_1110;
//                        end     
//                8'd4 :  begin
//                             c_size <= 4'd2;
//                             tl_addr_align <= 6'b11_1100;
//                        end     
//                8'd8 :  begin
//                             c_size <= 4'd3;
//                             tl_addr_align <= 6'b11_1000;
//                        end     
//                8'd16:  begin
//                             c_size <= 4'd4;
//                             tl_addr_align <= 6'b11_0000;
//                        end     
//                8'd32:  begin
//                             c_size <= 4'd5;
//                             tl_addr_align <= 6'b10_0000;
//                        end     
//                8'd64:  begin
//                             c_size <= 4'd6;
//                             tl_addr_align <= 6'b00_0000;
//                        end
//                default:begin
//                             c_size <= 4'd0;
//                             tl_addr_align <= 6'b00_0000;
//                        end     
//            endcase

            c_size          <= tl2f_tx_bcnt_i == 1                              ?   4'd0:
                               tl2f_tx_bcnt_i == 2                              ?   4'd1:
                               (tl2f_tx_bcnt_i) > 2  && (tl2f_tx_bcnt_i <= 4)   ?   4'd2:
                               (tl2f_tx_bcnt_i) > 4  && (tl2f_tx_bcnt_i <= 8)   ?   4'd3:
                               (tl2f_tx_bcnt_i) > 8  && (tl2f_tx_bcnt_i <= 16)  ?   4'd4:
                               (tl2f_tx_bcnt_i) > 16 && (tl2f_tx_bcnt_i <= 32)  ?   4'd5:
                               (tl2f_tx_bcnt_i) > 32 && (tl2f_tx_bcnt_i <= 64)  ?   4'd6:
                               c_size;
                               
            tl_addr_align   <= tl2f_tx_bcnt_i == 1                              ?   6'b11_1111:
                               tl2f_tx_bcnt_i == 2                              ?   6'b11_1110:
                               (tl2f_tx_bcnt_i) > 2  && (tl2f_tx_bcnt_i <= 4)   ?   6'b11_1100:
                               (tl2f_tx_bcnt_i) > 4  && (tl2f_tx_bcnt_i <= 8)   ?   6'b11_1000:
                               (tl2f_tx_bcnt_i) > 8  && (tl2f_tx_bcnt_i <= 16)  ?   6'b11_0000:
                               (tl2f_tx_bcnt_i) > 16 && (tl2f_tx_bcnt_i <= 32)  ?   6'b10_0000:
                               (tl2f_tx_bcnt_i) > 32 && (tl2f_tx_bcnt_i <= 64)  ?   6'b00_0000:

            c_addr          <= (qwd_cnter == 8'd2) ? {{dst_xpos,dst_ypos,dst_addr[47:6]}, dst_addr[5:0] & tl_addr_align} : c_addr;
            c_opcode        <= qwd_cnter >= 8'd1 ? 
                               (probe_ack_data && tl2f_tx_bcnt_i == 16'd64 && coh2tl_prb_ack_w_data)     ?  (OPCODE_PROBE_ACK_DATA)             :
                             //( probe_ack_cycle)                                                        ?  (OPCODE_PROBE_ACK)                  :
                               (probe_ack && coh2tl_prb_ack_no_data)                                     ?  (OPCODE_PROBE_ACK)                  :
            				    (relse      && tl2coh_tx_release_req)       ? (OPCODE_RELEASE)      :
            				    (relse_data && tl2f_tx_bcnt_i == 16'd64)    ? (OPCODE_RELEASE_DATA) :
            				   c_opcode :
            				   c_opcode ;
            				   
          				   
            				   
  
            // Acquire use param Grow NtoB (0)                  
            c_param         <= (msg_type == WB_REQ | msg_type == L2_LINE_FLUSH_REQ)    ? 4'b0  : 
                                4'b0 ;
            c_domain        <=  8'b0;       // Domain always zero    
            c_ready         <=  (fifo_full) ? 1'b0 : 1'b1;
            //c_ready         <= (fifo_full | header_done_st)     ? 1'b0  : 
            //                   (relse     | relse_data    )     ? 1'b1  :
            //                   c_ready;
            
            end
            
            // ===================== ASSIGN Ouptut =====================
            //tl2f_tx_header_we_i <= (end_of_pkt) ? 1'b1 : 1'b0 ;
            //tl2f_tx_header_we_i <= (end_of_pkt | coh2tl_gntack_gen_en) ? 1'b1 : 1'b0 ;
//            tl2f_tx_header_we_i <= (end_of_pkt) ? 1'b1 : 1'b0 ;		//20220503 CLE
            tl2f_tx_header_we_i <=  (((put & a_size <= 4'd3) | get | acquire) & header_done_st) ?   1'b1 :            //Added Condition for Put Partial Data (Size < = 8 Bytes)
                                    (end_of_pkt && !((put & a_size <= 4'd3) | get | acquire))     ?   1'b1 : 1'b0 ;     //20220503 CLE
            //tl2f_tx_header_i    <= (end_of_pkt) ? {1'b0, CH_A, a_opcode, 1'b0, a_param,
            //                                      a_size, a_domain,1'b0, a_corrupt, 12'b0, a_source}: 
            tl2f_tx_header_i    <= 
                    // for GrantAck (need to consider for the case of coming other NOC command and GrantAck simutaniously
                    (coh2tl_gntack_gen_en)      ? {1'b0, CH_E, 34'b0, e_sink}:
            			// for ACQUIRE cycle (need to be earlier)
            		(coh2tl_tx_acquire_req_ack) ? {1'b0, CH_A, a_opcode, 1'b0, a_param,
                                        a_size, a_domain,1'b0, a_corrupt, 12'b0, src_chipid[5:0],src_xpos,src_ypos,tag[3:0] }: 
                    // for normal cycles
            		//(end_of_pkt) ? {1'b0, CH_A, a_opcode, 1'b0, a_param,
                    //                    a_size, a_domain,1'b0, a_corrupt, 12'b0, a_source}:
                    // Channel A 
//                    (end_of_pkt & (put | get | acquire))    ? {1'b0, CH_A, a_opcode, 1'b0, a_param,
//                                        a_size, a_domain,1'b0, a_corrupt, 12'b0, a_source}:
                    (end_of_pkt & put & a_size > 4'd3)    ? {1'b0, CH_A, a_opcode, 1'b0, a_param,
                                        a_size, a_domain,1'b0, a_corrupt, 12'b0, a_source}:
                    (header_done_st & ((put & a_size <= 4'd3) | get | acquire))    ? {1'b0, CH_A, a_opcode, 1'b0, a_param,
                                        a_size, a_domain,1'b0, a_corrupt, 12'b0, a_source}:
                     // Channel C
                    (end_of_pkt & (probe_ack_data | probe_ack)) ? {1'b0, CH_C, c_opcode, 1'b0, c_param,
                                        c_prb_ack_size, c_domain,1'b0, c_corrupt, 12'b0,c_prb_ack_source}:
                    (end_of_pkt & (relse | relse_data))     ? {1'b0, CH_C, c_opcode, 1'b0, c_param,
                                        c_size, c_domain,1'b0, c_corrupt, 12'b0, src_chipid[5:0],src_xpos,src_ypos,tag[3:0]}:                 
                     tl2f_tx_header_i ;
            
            //tl2f_tx_addr_we_i   <= (end_of_pkt) ? 1'b1 : 1'b0 ;
            tl2f_tx_addr_we_i   <= (end_of_pkt & !coh2tl_gntack_gen_en) ? 1'b1 : 1'b0 ;     // 20220505 
            //tl2f_tx_addr_i      <= (end_of_pkt) ? a_addr : tl2f_tx_addr_i ;
            
            
            //added b_flush_wait for PROBEACK checking 20220526 
//            tl2f_tx_addr_i      <= (end_of_pkt & (put | get | acquire)) ? a_addr :
//                                   (end_of_pkt & (probe_ack | probe_ack_data))      ? c_prb_ack_address: //20220606
//                                   (end_of_pkt & (relse | relse_data))  ? c_addr : 
//                                    tl2f_tx_addr_i ;

            tl2f_tx_addr_i      <= (end_of_pkt & (put | get | acquire)) ? {{dst_xpos,dst_ypos,dst_addr[47:7]}, dst_addr[6:0] & tl_addr_align} :
                                   (end_of_pkt & (probe_ack | probe_ack_data))      ? c_prb_ack_address: //20220606
                                   (end_of_pkt & (relse | relse_data))  ? {{dst_xpos,dst_ypos,dst_addr[47:7]}, dst_addr[6:0] & tl_addr_align} : 
                                    tl2f_tx_addr_i ;
            
            //tl2f_tx_bcnt_we_i   <= (end_of_pkt) ? 1'b1 : 1'b0 ;
            //tl2f_tx_bcnt_we_i   <= (end_of_pkt & !coh2tl_gntack_gen_en) ? 1'b1 : 1'b0 ;     // 20220505 
            tl2f_tx_bcnt_we_i   <= (qwd_cnter == 1 & !coh2tl_gntack_gen_en) ? 1'b1 : 1'b0 ;     // 20220505 
            //tl2f_tx_bcnt_i      <= (|pld_length_cal) ? pld_length_cal - 8'd7 + last_byte_cnt : 8'b0 ;
            	// --- min packet is 
            	 //((qwd_cnter > 8'd0 && (qwd_cnter == (payload_length + 8'd2) ) ) ? 1'b1 : 1'b0) :

            // --- previous code
            //tl2f_tx_bcnt_i      <= 
            	// coh2tl_gntack_gen_en ? 16'd32 :	//20220503 CLE, temp, need to know the correct count 
            	//		(Not needed, OX2M recalculate with padding)
            		//normal cases
            //	(|pld_length_cal) ? (pld_length_cal - 8'd7 + last_byte_cnt) : 8'b0  ;
            //
            // --- cache transfers are always Nx8 bytes
//            tl2f_tx_bcnt_i      <=          //byte count of the packet without header
//            	// NORMAL - non-LeWiz mode
//            	//   subtract 7 (max number of odd bytes, then add whatever real number of bytes remaining is
//            	!lewiz_noc_mode ? (((|pld_length_cal) && (qwd_cnter == 8'd1)) ? (pld_length_cal - 8'd7 + data[2:0]) : 8'h0 ) :    // last byte count is directly taking from the data buffer when qwd_cnter == 1
//            		//normal cases            	 
//            	( |pld_length_cal ? pld_length_cal : 8'h0 );
            // New byte cnt for the noc data size field 20221005
            tl2f_tx_bcnt_i      <=  !(lewiz_noc_mode)   ?   ((noc_data_size == 3'b000)  ?   16'd0   : 
                                                             (noc_data_size == 3'b001)  ?   16'd1   :
                                                             (noc_data_size == 3'b010)  ?   16'd2   :
                                                             (noc_data_size == 3'b011)  ?   16'd4   :
                                                             (noc_data_size == 3'b100)  ?   16'd8   :
                                                             (noc_data_size == 3'b101)  ?   16'd16  :
                                                             (noc_data_size == 3'b110)  ?   16'd32  :
                                                             16'd64  )  :
                                                             tl2f_tx_bcnt_i ;
            	//PUT always have data
            	//ACQUIRE process does not have data, RELEASE has data
//            tl2f_tx_mask_we_i   <= (end_of_pkt & put) ? 1'b1 : 1'b0 ;
                tl2f_tx_mask_we_i   <= (qwd_cnter == 8'd2 && put) ? 1'b1 : 1'b0 ;
            case(tl2f_tx_bcnt_i) 
                8'd64: tl2f_tx_mask_i <= 64'b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd63: tl2f_tx_mask_i <= 64'b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd62: tl2f_tx_mask_i <= 64'b0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd61: tl2f_tx_mask_i <= 64'b0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd60: tl2f_tx_mask_i <= 64'b0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd59: tl2f_tx_mask_i <= 64'b0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd58: tl2f_tx_mask_i <= 64'b0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd57: tl2f_tx_mask_i <= 64'b0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd56: tl2f_tx_mask_i <= 64'b0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd55: tl2f_tx_mask_i <= 64'b0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd54: tl2f_tx_mask_i <= 64'b0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd53: tl2f_tx_mask_i <= 64'b0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd52: tl2f_tx_mask_i <= 64'b0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd51: tl2f_tx_mask_i <= 64'b0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd50: tl2f_tx_mask_i <= 64'b0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd49: tl2f_tx_mask_i <= 64'b0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd48: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd47: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd46: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd45: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd44: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd43: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd42: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd41: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd40: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd39: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd38: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd37: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd36: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd35: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd34: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd33: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd32: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd31: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111 ;
                8'd30: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111 ;
                8'd29: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111 ;
                8'd28: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111 ;
                
                8'd27: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111 ;
                8'd26: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111 ;
                8'd25: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111 ;
                8'd24: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111 ;
                
                8'd23: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111 ;
                8'd22: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111 ;
                8'd21: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111 ;
                8'd20: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111 ;
                
                8'd19: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111 ;
                8'd18: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111 ;
                8'd17: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111 ;
                8'd16: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111 ;
                
                8'd15: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111 ;
                8'd14: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111 ;
                8'd13: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111 ;
                8'd12: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111 ;
                
                8'd11: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111 ;
                8'd10: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111 ;
                8'd09: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111 ;
                8'd08: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111 ;
                
                8'd07: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111 ;
                8'd06: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111 ;
                8'd05: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111 ;
                8'd04: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111 ;
                
                8'd03: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111 ;
                8'd02: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011 ;
                8'd01: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001 ;
                
                
                default: tl2f_tx_mask_i <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000 ;
            endcase

            case(data_load_cnter)
                8'd0:    tl2f_tx_data_i <= {192'b0, data};
                8'd1:    tl2f_tx_data_i <= {128'b0, data, tl2f_tx_data_i[63:0]};
                8'd2:    tl2f_tx_data_i <= {64'b0, data, tl2f_tx_data_i[127:0]};
                8'd3:    tl2f_tx_data_i <= {data, tl2f_tx_data_i[191:0]};
                default: tl2f_tx_data_i <= 256'b0;
            endcase
            
            //tl2f_tx_data_we_i <= ((data_load_cnter == 8'd3 || end_of_pkt) && put) ? 1'b1: 1'b0 ;  
            tl2f_tx_data_we_i <= ((data_load_cnter == 8'd3 || end_of_pkt) && (put | relse_data | probe_ack_data)) ? 1'b1: 1'b0 ; //FOR_PROBE_ACK_DATA
        end
    end 
    
//-------------------- COHERENT PROCESSING: ACQUIRE FUNCTION
	
    always@(posedge clk) 
    begin
        if(!reset_) 
        	begin
            tl2coh_tx_acquire_req     			<= 	       1'b0    ;
            tl2coh_tx_acquire_gen_done			<=	       1'b0    ;
            tl2coh_tx_gntack_gen_done           <=         1'b0    ;
            end
        else
        	begin
        	tl2coh_tx_acquire_req				<=
        		coh2tl_tx_acquire_req_ack 				?   1'b0   :   // negate
    			header_deco_st & 
    		    acquire                       	        ?   1'b1   :   // assert
    			tl2coh_tx_acquire_req; 						           // keep	
    		
    		tl2coh_tx_acquire_gen_done			<=
    			coh2tl_tx_acquire_gen_en &  		
    			     header_done_st & acquire	        ?   1'b1   :
    			1'b0;
    		tl2coh_tx_gntack_gen_done	        <=
    			header_done_st				            ?   1'b0   :	// negate
            	header_wait_st & 
            	   coh2tl_gntack_gen_en 			    ? 	1'b1   :	// assert
    			tl2coh_tx_gntack_gen_done;								// keep	
    		
        	end
	end

//-------------------- COHERENT PROCESSING: RELEASE FUNCTION
	
	always@(posedge clk) 
    begin
        if(!reset_) 
        	begin
            tl2coh_tx_release_req     			<= 	       1'b0    ;
            end
        else
        	begin
        	tl2coh_tx_release_req				<=
        		tl2coh_tx_release_req_ack 				?   1'b0   :   // negate
    			header_deco_st & 
    		    (relse | relse_data)                   ?   1'b1   :   // assert
    			tl2coh_tx_release_req; 						           // keep	
        	end
	end
    
// ---------------------- COHERENT PROCESSING: PROBE FUNCTION //Only for Checking probe ack //20220526
// asserts after the PROBEack info had been written into TL FIFO

    always@(posedge clk)
    begin
        if(!reset_) begin
                tl2coh_tx_probe_req_done    <=    1'b0;
                probe_ack_valid             <=    1'b0;
            end
        else begin
                //tl2coh_tx_probe_req_done              <=      (coh2tl_tx_prb_flush_wait) ? 1'b1: 1'b0 ; 
                //if (probe_ack)
                //if (!probe_ack_data)
//                    begin
//                    tl2coh_tx_probe_req_done    <= 
//                        tl2coh_tx_probe_req_done ?  1'b0 :
//                        //header_wait_st			   ? 1'b0 :   // negate
//            	        qwd_cnter == 8'd2        ? 1'b1 :   // assert
//                        tl2coh_tx_probe_req_done;                 // keep
                    
//                    probe_ack_valid   <=  
//                        probe_ack & end_of_pkt  ? 0 :        
//                        probe_ack               ? 1 :
//                        probe_ack_valid;
//                    end
//                else if (probe_ack_data)
//                    begin
//                    tl2coh_tx_probe_req_done    <=   
//                        tl2coh_tx_probe_req_done ?  1'b0 :                
//                		(header_done_st 
//                		      & tl2f_tx_bcnt_we_i )    ? 1'b1: //20220606
//                        tl2coh_tx_probe_req_done ;             
//                    end
//				    tl2coh_tx_probe_req_done    <=      
//                		(header_done_st & (probe_ack | probe_ack_data) 
//                		  & tl2f_tx_bcnt_we_i )                                   ? 1'b1: //20220606
//                            1'b0 ; 


                tl2coh_tx_probe_req_done    <=   
                        tl2coh_tx_probe_req_done        ? 1'b0 :     
                        probe_ack ? (qwd_cnter == 8'd2  ? 1'b1 : tl2coh_tx_probe_req_done) :   //probe ack NO data
                		probe_ack_data  ? (header_done_st     ? 1'b1 : tl2coh_tx_probe_req_done) :   //probe_ack w. data
                        tl2coh_tx_probe_req_done ;     
                                
                probe_ack_valid     <=  
                        probe_ack & end_of_pkt  ? 0 :        
                        probe_ack               ? 1 :
                        probe_ack_valid;
            end
    end          
//---------------------------------------
    reg [15*8:0] ascii_tlc_header_state;
    
    always@(tlc_header_state) begin
        case(tlc_header_state)
            HEADER_IDLE_ST : ascii_tlc_header_state = "HEADER_IDLE_ST";
            HEADER_DECO_ST : ascii_tlc_header_state = "HEADER_DECO_ST";
            HEADER_WAIT_ST : ascii_tlc_header_state = "HEADER_WAIT_ST";
            HEADER_DONE_ST : ascii_tlc_header_state = "HEADER_DONE_ST";
        endcase
    end
    
    reg [12*8:0] ascii_tlc_data_state;
    
    always@(tlc_data_state) begin
        case(tlc_data_state)
            DATA_IDLE_ST : ascii_tlc_data_state = "DATA_IDLE_ST";
            DATA_LOAD_ST : ascii_tlc_data_state = "DATA_LOAD_ST";
            DATA_DONE_ST : ascii_tlc_data_state = "DATA_DONE_ST";
        endcase
    end
    
endmodule
