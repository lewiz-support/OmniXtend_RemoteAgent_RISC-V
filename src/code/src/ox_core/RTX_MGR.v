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

//TODO: Ensure all signals are properly initialized on reset

module RTX_MGR(
        input               clk,
        input               reset_,

        input               last_data,

        // ================= for TX =================
        input               tx_req,         // indicates tx request, go to TX PATH in SM
        input [21:0]        tx_seq,         // 22 bit sequence number
        input [15:0]        tx_bcnt,        // byte count
        input               bcnt_valid,     // bcnt valid
        
        output reg          tx_gnt,         // grant TX path
        output reg [11:0]   tx_buf_addr,    // addr for TX parth to write data to
        
        output reg          tx_entry_full,  // high when all entry is full      
        output reg          tx_done,        // write to buffer is done
        
        // ================= for RX =================
        input               ack_req,        // request to process 1 ack_num
        input [21:0]        ack_num,        // also used for RTX
        input [3:0]         entries2free,   // ack mgr tells how many entries to free up
        input               oxm_rtx_done,   // control signal for ProbeBlock from M2Ox
        
        output reg          ack_done,       // signal to requester that the processing is done
        
        // ================= for RTX =================
        input               rtx_req,        // request to process a NACK
        
        output reg          rtx_done,       // indicate to requester that RTX request is done
        output reg [3:0]    rtx_cmd_cnt,     // number of cmds RTX_MGR inserted for TX path to retransmit
        output reg          rtx_gnt,        // grant tx path to use rtx queue 

        // ================= for FIFO =================
        input               cmd_q_full,
        
        output reg          cmd_q_wr_en,
        output reg [63:0]   cmd_q_datain
    );
    
    
    parameter IDLE              = 16'h0001;
    // TX Path
    parameter TX_REQ            = 16'h0002;
    parameter TX_GNT            = 16'h0004;
    parameter TX_WTDATA         = 16'h0008;
    parameter TX_DONE           = 16'h0010;
    
    // RX ACK PATH
    parameter RX_ACK_CHK        = 16'h0020;
    parameter RX_ACK_CALC       = 16'h0040;
    parameter RX_ACK_COMP       = 16'h0080;
    parameter RX_FREE           = 16'h0100;
    parameter RX_DONE           = 16'h0200;
    
    // RTX Path
    parameter RTX_START         = 16'h0400;
    parameter RTX_CMD_BLD       = 16'h0800;
    parameter RTX_CMD_WT        = 16'h1000;
    parameter RTX_GNT           = 16'h2000;
    
    parameter DONE              = 16'h8000;
    
    // Size of entry can be changed here
    parameter MAX_ENTRY_INDEX   = 8;
    parameter PTR_WIDTH         = 8;
    parameter ENTRY_NUM         = 8;
    parameter ENTRY_WIDTH       = 51;   // {1-valid, 22-seq_num, 16-bcnt, 12-addr}
    
    parameter ADDR_0            = 12'h000 ;
    parameter ADDR_1            = 12'h040 ;
    parameter ADDR_2            = 12'h080 ;
    parameter ADDR_3            = 12'h0C0 ;
    parameter ADDR_4            = 12'h100 ;
    parameter ADDR_5            = 12'h140 ;
    parameter ADDR_6            = 12'h180 ;
    parameter ADDR_7            = 12'h1C0 ;
    
    // CMD Building SM
    parameter BUILD_IDLE        = 8'h01;
    parameter BUILD_BLD         = 8'h02;
    parameter BUILD_WR          = 8'h04;
    parameter BUILD_WAIT        = 8'h10;
    parameter BUILD_DONE        = 8'h80;
    
    
    reg [21:0]              seq_num;
    reg [15:0]              bcnt;
    reg                     bcnt_valid_buf;
    reg [7:0]               num2free;
    reg [7:0]               num_freed;
    
    reg                     tx_path;
    reg                     ack_path;
    reg                     rtx_path;
    
    reg [PTR_WIDTH-1:0]     head;
    reg [PTR_WIDTH-1:0]     tail;
    
    reg [ENTRY_WIDTH-1:0]   entry_0;
    reg [ENTRY_WIDTH-1:0]   entry_1;
    reg [ENTRY_WIDTH-1:0]   entry_2;
    reg [ENTRY_WIDTH-1:0]   entry_3;
    reg [ENTRY_WIDTH-1:0]   entry_4;
    reg [ENTRY_WIDTH-1:0]   entry_5;
    reg [ENTRY_WIDTH-1:0]   entry_6;
    reg [ENTRY_WIDTH-1:0]   entry_7;
    
    
    reg [15:0]              main_sm;
    wire                    idle_st         = main_sm[0];
    wire                    tx_req_st       = main_sm[1];
    wire                    tx_gnt_st       = main_sm[2];
    wire                    tx_wtdata_st    = main_sm[3];
    wire                    tx_done_st      = main_sm[4];
    wire                    rx_ack_chk_st   = main_sm[5];
    wire                    rx_ack_calc_st  = main_sm[6];
    wire                    rx_ack_comp_st  = main_sm[7];
    wire                    rx_free_st      = main_sm[8];
    wire                    rx_done_st;         
    wire                    rtx_start_st    = main_sm[9];
    wire                    rtx_cmd_bld_st  = main_sm[10];
    wire                    rtx_cmd_wt_st   = main_sm[11];
    wire                    rtx_gnt_st      = main_sm[12];
    wire                    done_st         = main_sm[15];
    
    reg [7:0]               build_sm;
    wire                    build_idle_st   = build_sm[0];
    wire                    build_bld_st    = build_sm[1];
    wire                    build_wr_st     = build_sm[2];
    wire                    build_wait_st   = build_sm[3];
    wire                    build_done_st   = build_sm[7];
    
    
    reg  [7:0]              buf_status;
    wire                    move_tail;
    wire                    wrap_tail;
    wire                    wrap_head;
    reg  [7:0]              head_norm_incr;
//  wire [3:0]              num_freed;
    reg  [7:0]              wrap_index;
    wire [7:0]              remain_entry_cnt;
    
    reg [7:0]               cur_head;
    reg [7:0]               nxt_head;
    reg [7:0]               temp_head;              // used for rtx cmd
    reg [1:0]               comp_cnt;
//  reg [3:0]               rtx_cnt;
    reg                     build_req;
    reg                     build_finished;
    
    
    wire                    entry0_en;              // outputs bcnt
    wire                    entry1_en;
    wire                    entry2_en;
    wire                    entry3_en;
    wire                    entry4_en;
    wire                    entry5_en;
    wire                    entry6_en;
    wire                    entry7_en;
    
    wire                    entry0_sel;             // outputs buf_addr early
    wire                    entry1_sel;
    wire                    entry2_sel;
    wire                    entry3_sel;
    wire                    entry4_sel;
    wire                    entry5_sel;
    wire                    entry6_sel;
    wire                    entry7_sel;


    
    wire                    entry0_active;
    wire                    entry1_active;
    wire                    entry2_active;
    wire                    entry3_active;
    wire                    entry4_active;
    wire                    entry5_active;
    wire                    entry6_active;
    wire                    entry7_active;                    
    
    reg                     entry0_rst;
    reg                     entry1_rst;
    reg                     entry2_rst;
    reg                     entry3_rst;
    reg                     entry4_rst;
    reg                     entry5_rst;
    reg                     entry6_rst;
    reg                     entry7_rst;
    
    wire [50:0]             head_entry;
    
    wire                    full;                           // high when status = max_entry-2
    
    assign full             = (buf_status >= 4'd7) ? 1'b1 : 1'b0 ; 

    assign move_tail  = (!reset_) ? 1'b0 : (tx_done_st && buf_status <= 8'd7) ; // <= 3 to leave at least 1 entry empty
    assign wrap_tail  = (!reset_) ? 1'b0 : tail == 8'd7 && !entry_0[50];

// ============================ HEAD LOGIC ============================     
    assign wrap_head  = (!reset_) ? 1'b0 : head + num2free > MAX_ENTRY_INDEX - 1 ;
    assign remain_entry_cnt = (!reset_) ? 4'b0 : (rx_ack_calc_st && num2free > num_freed) ? num2free - num_freed : 4'b0;
    
    assign entry0_en = (!reset_) ? 1'b0 : (tail == 8'd0 && tx_path && bcnt_valid_buf) ;
    assign entry1_en = (!reset_) ? 1'b0 : (tail == 8'd1 && tx_path && bcnt_valid_buf) ;
    assign entry2_en = (!reset_) ? 1'b0 : (tail == 8'd2 && tx_path && bcnt_valid_buf) ;
    assign entry3_en = (!reset_) ? 1'b0 : (tail == 8'd3 && tx_path && bcnt_valid_buf) ;
    assign entry4_en = (!reset_) ? 1'b0 : (tail == 8'd4 && tx_path && bcnt_valid_buf) ;
    assign entry5_en = (!reset_) ? 1'b0 : (tail == 8'd5 && tx_path && bcnt_valid_buf) ;
    assign entry6_en = (!reset_) ? 1'b0 : (tail == 8'd6 && tx_path && bcnt_valid_buf) ;
    assign entry7_en = (!reset_) ? 1'b0 : (tail == 8'd7 && tx_path && bcnt_valid_buf) ;    
    
    assign entry0_sel = (!reset_) ? 1'b0 : (tail == 8'd0 && tx_path) ;
    assign entry1_sel = (!reset_) ? 1'b0 : (tail == 8'd1 && tx_path) ;
    assign entry2_sel = (!reset_) ? 1'b0 : (tail == 8'd2 && tx_path) ;
    assign entry3_sel = (!reset_) ? 1'b0 : (tail == 8'd3 && tx_path) ;
    assign entry4_sel = (!reset_) ? 1'b0 : (tail == 8'd4 && tx_path) ;
    assign entry5_sel = (!reset_) ? 1'b0 : (tail == 8'd5 && tx_path) ;
    assign entry6_sel = (!reset_) ? 1'b0 : (tail == 8'd6 && tx_path) ;
    assign entry7_sel = (!reset_) ? 1'b0 : (tail == 8'd7 && tx_path) ;
    
    assign entry0_active = (!reset_) ? 1'b0 : entry_0[50] ;
    assign entry1_active = (!reset_) ? 1'b0 : entry_1[50] ;
    assign entry2_active = (!reset_) ? 1'b0 : entry_2[50] ;
    assign entry3_active = (!reset_) ? 1'b0 : entry_3[50] ;
    assign entry4_active = (!reset_) ? 1'b0 : entry_4[50] ;
    assign entry5_active = (!reset_) ? 1'b0 : entry_5[50] ;
    assign entry6_active = (!reset_) ? 1'b0 : entry_6[50] ;
    assign entry7_active = (!reset_) ? 1'b0 : entry_7[50] ;
    
    assign head_entry    = (!reset_) ? 51'b0 : (temp_head == 8'd0) ? entry_0[27:0] :
                                               (temp_head == 8'd1) ? entry_1[27:0] :
                                               (temp_head == 8'd2) ? entry_2[27:0] :
                                               (temp_head == 8'd3) ? entry_3[27:0] :
                                               (temp_head == 8'd4) ? entry_4[27:0] :
                                               (temp_head == 8'd5) ? entry_5[27:0] :
                                               (temp_head == 8'd6) ? entry_6[27:0] :
                                               (temp_head == 8'd7) ? entry_7[27:0] :
                                            //	head_entry;			//-/
                                            	51'h3A5A5A5A5A5;	//+/
    
    
    
//    rtx_cmd_q_fifo_8x64 cmd_q_fifo(
//                                    .reset_(reset_),
//                                    .wrclk(clk),
//                                    .wren(cmd_q_wr_en),
//                                    .datain(cmd_q_datain),
//                                    .wrfull(cmd_q_full),
//                                    .wrusedw(),
                                    
//                                    .rdclk(clk),
//                                    .rden(cmd_q_rd_en),
//                                    .dataout(cmd_q_dataout),
//                                    .rdempty(cmd_q_empty),
//                                    .rdusedw()    
//                                  );


    // MAIN_SM flow
    always@(posedge clk) begin              
        if(!reset_) begin
            main_sm <= IDLE ;
        end // if reset
        
        else begin
            case(main_sm)
                IDLE : begin
                    main_sm <= 
                               (ack_req) ? RX_ACK_CHK :
                               (rtx_req) ? RTX_START :
                               (tx_path) ? TX_REQ : 
                               IDLE ;
                end
// ==================================== TX ====================================                
                TX_REQ : begin
                    main_sm <= (!full) ? TX_GNT : TX_DONE ;
                end
                TX_GNT : begin
                    main_sm <= TX_WTDATA;
                end
                TX_WTDATA : begin
                    main_sm <= (last_data) ? TX_DONE : TX_WTDATA ;
                end
                TX_DONE : begin
                    main_sm <= DONE ;
                end
 // ==================================== ACK ===================================   
                RX_ACK_CHK : begin      // go here @ ack_req
                    main_sm <= RX_ACK_CALC ;
                end
                
                RX_ACK_CALC : begin     //cal # of entries to free
                    main_sm <= RX_ACK_COMP;
                end
                
                RX_ACK_COMP : begin
                    main_sm <= (comp_cnt == 3'd1) ? RX_FREE : RX_ACK_COMP;
                end
                RX_FREE : begin         // free entries and ++ head, go to DONE
                    main_sm <= RX_DONE ;
                               
                end
                RX_DONE : begin
                    main_sm <= (rtx_path) ? RTX_CMD_BLD : DONE ;
                end
 // =================================== NACK ===================================  
                RTX_START : begin
                    main_sm <= (|num2free) ?  RX_ACK_CHK : RTX_CMD_BLD ;
                end

                RTX_CMD_BLD : begin
                    main_sm <= RTX_CMD_WT;
                end
                
                RTX_CMD_WT : begin
                    //main_sm <= (build_finished) ? RTX_GNT : RTX_CMD_WT; // cmd sm will send out done signal for trigger
                    main_sm <= build_finished ? RTX_GNT : 
                               oxm_rtx_done   ? DONE    :
                               RTX_CMD_WT; // cmd sm will send out done signal for trigger
                end
                
                RTX_GNT : begin
                    main_sm <= DONE ; 
                end                                
                DONE : begin
                    main_sm <= IDLE ;
                end   
                
                default : main_sm <= IDLE ;
            endcase     
        end // else
        
    end //always sm
    
    
    // build_sm flow
    always@ (posedge clk) begin                     
        if(!reset_) begin
            build_sm    <= BUILD_IDLE ;
        end
        else begin
            case(build_sm)
                BUILD_IDLE  : begin
                    build_sm <= (build_req & |rtx_cmd_cnt) ? BUILD_BLD : BUILD_IDLE ;
                end
                
                BUILD_BLD   : begin
                    build_sm <= BUILD_WR ; 
                end
                
                BUILD_WR    : begin
                    build_sm <= BUILD_WAIT ;
                end
                
                BUILD_WAIT  : begin
                    build_sm <= (rtx_cmd_cnt) ? BUILD_BLD : BUILD_DONE;
                end
                
                BUILD_DONE  : begin
                    build_sm <= BUILD_IDLE ;
                end
                
                default : begin
                    
                end
            endcase
        end // else
    end // always build_sm flow
    
    
    // build_sm logic
    always@ (posedge clk) begin                     
        if(!reset_) begin
            rtx_cmd_cnt         <=  4'b0;
            rtx_done            <=  1'b0;
            temp_head           <=  8'b0;
            cmd_q_datain        <=  64'b0;
            cmd_q_wr_en         <=  1'b0;
        end // if reset
        
        else begin
            case(build_sm)
                BUILD_IDLE  : begin
                    rtx_cmd_cnt <= buf_status ;
                    rtx_done    <= 1'b0 ;
                    build_finished  <= 1'b0;
                    temp_head       <= head ;
                end
                
                BUILD_BLD   : begin
                    
                    cmd_q_datain    <= head_entry ;
                    cmd_q_wr_en     <= 1'b0 ; 
                end
                
                BUILD_WR    : begin
                    rtx_cmd_cnt     <= (|rtx_cmd_cnt) ? rtx_cmd_cnt - 1 : rtx_cmd_cnt ;
                    cmd_q_wr_en     <= 1'b1 ; 
                    
                end
                
                BUILD_WAIT  : begin
                    cmd_q_wr_en     <= 1'b0 ;
                    temp_head       <= (temp_head == 8'd7 && entry_0[50]) ? 8'd0 : temp_head + 8'd1 ;
                    
                end
                
                BUILD_DONE  : begin
                    cmd_q_wr_en     <= 1'b0 ;
                    rtx_done        <= 1'b1 ;
                    build_finished  <= 1'b1 ;
                    rtx_cmd_cnt     <= 8'b0;
                end
            endcase
        end // else
    end // always build_sm logic
    
    always@ (posedge clk) begin                     // comb logic
        if(!reset_) begin
            tx_gnt      <=  1'b0;	//+/2022-10-26: Initialize registers during reset
            ack_done    <=  1'b0;	//+/
        
            entry_0     <= 51'b0;
            entry_1     <= 51'b0;
            entry_2     <= 51'b0;
            entry_3     <= 51'b0;
            entry_4     <= 51'b0;
            entry_5     <= 51'b0;
            entry_6     <= 51'b0;
            entry_7     <= 51'b0;
            
            seq_num     <= 22'b0;
            bcnt        <= 16'b0;
            num2free    <= 8'b0;
            num_freed   <= 8'b0;
            head        <= 8'b0;
            tail        <= 8'b0;
            tx_buf_addr <= ADDR_0;

            wrap_index      <= 8'b0;
            head_norm_incr  <= 8'b0;
            comp_cnt        <= 3'b0;
            cur_head        <= 8'b0;
            nxt_head        <= 8'b0;
            
            
        //  entry0_rst  <= 1'b0;    // To avoid multiple drivers shankar 20221027
        //  entry1_rst  <= 1'b0;
        //  entry2_rst  <= 1'b0;
        //  entry3_rst  <= 1'b0;
        //  entry4_rst  <= 1'b0;
        //  entry5_rst  <= 1'b0;
        //  entry6_rst  <= 1'b0;
        //  entry7_rst  <= 1'b0;
            
            tx_entry_full <= 1'b0;
        end // if reset
        
        else begin
            seq_num     <= (idle_st) ? tx_seq :
                           seq_num ;                                 // seq_num buffer
            bcnt        <= (bcnt_valid) ? tx_bcnt + 16'd8 :
                           bcnt ;     
            bcnt_valid_buf <= bcnt_valid;                                           // bcnt buffer
            num2free    <= (idle_st & (ack_req | rtx_req)) ? entries2free :
                           (rx_ack_calc_st) ? 4'b0 :
                           num2free;                                // num2free buffer
                        
//            ack_path    <= (ack_req) ? 1'b1 :
//                           (rx_free_st) ? 1'b0 :   
//                           ack_path ;  
            
//            rtx_path    <= (rtx_req) ? 1'b1 : 
//                           (rtx_gnt_st) ? 1'b0 :
//                           rtx_path ;                          
                           
            tx_gnt      <= (tx_gnt_st) ? 1'b1 : 1'b0 ;  
                     
            tail        <= (move_tail & !wrap_tail & !full) ? tail + 8'd1 : //advancing
                           (move_tail &  wrap_tail & !full) ? 8'd0 :        //wrapping around
                           tail ;                                           //staying (when full)

            // ======================   ACK LOGICS ======================
//            num_freed   <= (MAX_ENTRY_INDEX - head) ;               // MAX_ENTRY_INDEX = 4 || 4 - 0 = 4
            num_freed   <= (rx_ack_chk_st) ? (MAX_ENTRY_INDEX - head) : num_freed;               // MAX_ENTRY_INDEX = 4 || 4 - 0 = 4
            
            wrap_index  <= (remain_entry_cnt > 0) ? remain_entry_cnt - 1 : wrap_index;
//            head        <= (wrap_head ? wrap_index : head_norm_incr);
            head        <= head_norm_incr ;
                           
            head_norm_incr <= (rx_ack_chk_st &  wrap_head) ? 8'd0 + remain_entry_cnt :
                              (rx_ack_chk_st & !wrap_head) ? head + num2free : 
                              head_norm_incr;
                           
            comp_cnt    <= (rx_ack_comp_st) ? comp_cnt + 3'd1 : 3'b0;
            
            cur_head    <= (rx_ack_chk_st) ? head : cur_head ;
            nxt_head    <= (rx_ack_comp_st) ? head : nxt_head ;
            
            ack_done    <= rx_free_st ? 1'b1 : 1'b0 ;
            
            // ======================   NACK LOGICS ======================
            
            //============================================================
            
            
            tx_buf_addr <= (entry0_sel) ? ADDR_0 :
                           (entry1_sel) ? ADDR_1 :
                           (entry2_sel) ? ADDR_2 :
                           (entry3_sel) ? ADDR_3 :
                           (entry4_sel) ? ADDR_4 :
                           (entry5_sel) ? ADDR_5 :
                           (entry6_sel) ? ADDR_6 :
                           (entry7_sel) ? ADDR_7 :
                           12'b0 ;     
                           
//            buf_status <= ((tx_path | ack_path) & done_st) | (rtx_path & rtx_cmd_bld_st) ? entry_0[46] + entry_1[46] + entry_2[46] + entry_3[46] :
//            buf_status <= (done_st) ? entry_0[46] + entry_1[46] + entry_2[46] + entry_3[46] :
//            buf_status  <=  (done_st) ? entry_0[46] :
//                            buf_status;
        
            entry_0     <= (entry0_en) ? {1'b1,seq_num,bcnt,ADDR_0 } : 
                           (entry0_rst& rx_free_st) ? 51'b0 :
                           entry_0 ;
                           
            entry_1     <= (entry1_en) ? {1'b1,seq_num,bcnt,ADDR_1} : 
                           (entry1_rst & rx_free_st) ? 51'b0 :
                           entry_1;
                           
            entry_2     <= (entry2_en) ? {1'b1,seq_num,bcnt,ADDR_2} : 
                           (entry2_rst & rx_free_st) ? 51'b0 :
                           entry_2;
                           
            entry_3     <= (entry3_en) ? {1'b1,seq_num,bcnt,ADDR_3} : 
                           (entry3_rst & rx_free_st) ? 51'b0 :
                           entry_3;
                           
            entry_4     <= (entry4_en) ? {1'b1,seq_num,bcnt,ADDR_4} : 
                           (entry4_rst & rx_free_st) ? 51'b0 :
                           entry_4;               
                           
            entry_5     <= (entry5_en) ? {1'b1,seq_num,bcnt,ADDR_5} : 
                           (entry5_rst & rx_free_st) ? 51'b0 :
                           entry_5;               
                           
            entry_6     <= (entry6_en) ? {1'b1,seq_num,bcnt,ADDR_6} : 
                           (entry6_rst & rx_free_st) ? 51'b0 :
                           entry_6;
                           
            entry_7     <= (entry7_en) ? {1'b1,seq_num,bcnt,ADDR_7} : 
                           (entry7_rst & rx_free_st) ? 51'b0 :
                           entry_7;
                                                         
            tx_entry_full <= full;               
        end // else
    end // always comb      
    
    always @(posedge clk) begin                     // main_sm logic
        if(!reset_) begin
            rtx_gnt         <= 1'b0;
            build_req       <= 1'b0;
            buf_status      <= 8'b0;
            tx_path         <= 1'b0;
            ack_path        <= 1'b0;
            rtx_path        <= 1'b0;
            tx_done         <= 1'b0;
        end // if reset
        
        else begin
            case(main_sm) 
                IDLE    :   begin
                    tx_path     <= (tx_req) ? 1'b1 : tx_path ;
                    ack_path    <= (ack_req) ? 1'b1 : ack_path ;
                    rtx_path    <= (rtx_req) ? 1'b1 : rtx_path ;
                end
                TX_DONE :   begin
                    buf_status  <=  entry_0[50] + entry_1[50] + entry_2[50] + entry_3[50] +
                                    entry_4[50] + entry_5[50] + entry_6[50] + entry_7[50]   ;
                    tx_path     <=  1'b0;
                    tx_done     <=  1'b1;
                end
                
                RX_DONE :   begin
                    buf_status  <=  entry_0[50] + entry_1[50] + entry_2[50] + entry_3[50] +
                                    entry_4[50] + entry_5[50] + entry_6[50] + entry_7[50]   ;
                    ack_path    <= 1'b0;
                end
                RTX_START : begin
                end //RTX_START
                
                RTX_CMD_BLD : begin
                    build_req   <= 1'b1;
                    
                end // RTX_CMD_BLD
                
                RTX_CMD_WT : begin 
                    build_req   <=  1'b0;
                    rtx_path    <= oxm_rtx_done ? 1'b0  :  rtx_path; 
                end // RTX_CMD_WT
                
                RTX_GNT : begin
                    rtx_path    <= 1'b0 ;
                    rtx_gnt     <= 1'b1;
                end // RTX_GNT
                
                DONE : begin
                    rtx_gnt     <= 1'b0;
                    tx_done     <= 1'b0;
                    buf_status  <=  entry_0[50] + entry_1[50] + entry_2[50] + entry_3[50] +
                                    entry_4[50] + entry_5[50] + entry_6[50] + entry_7[50]   ;
                end // done
                
                default: begin
                   
                end // default
            endcase
        end
    end // always
    
    
    always@ (posedge clk) begin
        if(!reset_) begin
            entry0_rst  <= 1'b0;    // To avoid multiple drivers shankar 20221027
            entry1_rst  <= 1'b0;
            entry2_rst  <= 1'b0;
            entry3_rst  <= 1'b0;
            entry4_rst  <= 1'b0;
            entry5_rst  <= 1'b0;
            entry6_rst  <= 1'b0;
            entry7_rst  <= 1'b0;
        end    
        else if(rx_ack_comp_st && comp_cnt > 0) begin 
            case(cur_head)
                4'd0 : begin
                    entry0_rst  <= 1'b1 ;
                    entry1_rst  <= (nxt_head >= 8'd2) ? 1'b1 : 1'b0 ;
                    entry2_rst  <= (nxt_head >= 8'd3) ? 1'b1 : 1'b0 ;
                    entry3_rst  <= (nxt_head >= 8'd4) ? 1'b1 : 1'b0 ;
                    entry4_rst  <= (nxt_head >= 8'd5) ? 1'b1 : 1'b0 ;
                    entry5_rst  <= (nxt_head >= 8'd6) ? 1'b1 : 1'b0 ;
                    entry6_rst  <= (nxt_head >= 8'd7) ? 1'b1 : 1'b0 ;
//                    entry7_rst  <= (nxt_head == 4'd7) ? 1'b1 : 1'b0 ;     // always 1 empty
                end
            
                4'd1 : begin
//                    entry0_rst  <=                                        // always 1 empty
                    entry1_rst  <= 1'b1 ;
                    entry2_rst  <= (nxt_head >= 8'd3 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry3_rst  <= (nxt_head >= 8'd4 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry4_rst  <= (nxt_head >= 8'd5 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry5_rst  <= (nxt_head >= 8'd6 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry6_rst  <= (nxt_head == 8'd7 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry7_rst  <= (nxt_head == 8'd0) ? 1'b1 : 1'b0 ;

                end // 4'd1
            
                4'd2 : begin
                    entry0_rst  <= (nxt_head == 8'd1) ? 1'b1 : 1'b0 ;  
//                    entry1_rst
                    entry2_rst  <= 1'b1 ;
                    entry3_rst  <= (nxt_head >= 8'd4 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry4_rst  <= (nxt_head >= 8'd5 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry5_rst  <= (nxt_head >= 8'd6 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;
                    entry6_rst  <= (nxt_head == 8'd7 || nxt_head <= 8'd1) ? 1'b1 : 1'b0 ;
                    entry7_rst  <= (nxt_head == 8'd1 || nxt_head == 8'd0) ? 1'b1 : 1'b0 ;         
                end // 4'd2
            
                4'd3 : begin
                    entry0_rst  <= (nxt_head == 8'd1 || nxt_head == 8'd2) ? 1'b1 : 1'b0 ;
                    entry1_rst  <= (nxt_head == 8'd2) ? 1'b1 : 1'b0 ;  
//                    entry2_rst
                    entry3_rst  <= 1'b1 ;      
                    entry4_rst  <= (nxt_head >= 8'd5 || nxt_head <= 8'd2) ? 1'b1 : 1'b0 ;   
                    entry5_rst  <= (nxt_head >= 8'd6 || nxt_head <= 8'd2) ? 1'b1 : 1'b0 ;  
                    entry6_rst  <= (nxt_head == 8'd7 || nxt_head <= 8'd2) ? 1'b1 : 1'b0 ;  
                    entry7_rst  <= (nxt_head <= cur_head) ? 1'b1 : 1'b0 ;   
                end // 4'd3
                
                4'd4 : begin
                    entry0_rst  <= (nxt_head > 8'd0 && nxt_head < 8'd3) ? 1'b1 : 1'b0 ;
                    entry1_rst  <= (nxt_head == 8'd2 || nxt_head == 8'd3) ? 1'b1 : 1'b0 ;
                    entry2_rst  <= (nxt_head == 8'd3) ? 1'b1 : 1'b0 ;
//                    entry3_rst
                    entry4_rst  <= 1'b1 ;
                    entry5_rst  <= (nxt_head >= 8'd6 || nxt_head <= 8'd3) ? 1'b1 : 1'b0 ;
                    entry6_rst  <= (nxt_head ==8'd7 || nxt_head <= 8'd3) ? 1'b1 : 1'b0 ;
                    entry7_rst  <= (nxt_head <= cur_head) ? 1'b1 : 1'b0 ;
                end // 4'd4
                
                4'd5 : begin
                    entry0_rst  <= (nxt_head >= 8'd1 && nxt_head <= 8'd4) ? 1'b1 : 1'b0 ;
                    entry1_rst  <= (nxt_head >= 8'd2 && nxt_head <= 8'd4) ? 1'b1 : 1'b0 ;
                    entry2_rst  <= (nxt_head >= 8'd3 && nxt_head <= 8'd4) ? 1'b1 : 1'b0 ;
                    entry3_rst  <= (nxt_head == 8'd4) ? 1'b1 : 1'b0 ;
//                    entry4_rst
                    entry5_rst  <= 1'b1 ;
                    entry6_rst  <= (nxt_head == 8'd7 || nxt_head <= 8'd4) ? 1'b1 : 1'b0 ;
                    entry7_rst  <= (nxt_head <= cur_head) ? 1'b1 : 1'b0 ;
                end // 4'd5
                
                4'd6 : begin
                    entry0_rst  <= (nxt_head >= 8'd1 && nxt_head <= 8'd5) ? 1'b1 : 1'b0;
                    entry1_rst  <= (nxt_head >= 8'd2 && nxt_head <= 8'd5) ? 1'b1 : 1'b0;
                    entry2_rst  <= (nxt_head >= 8'd3 && nxt_head <= 8'd5) ? 1'b1 : 1'b0;
                    entry3_rst  <= (nxt_head >= 8'd4 && nxt_head <= 8'd5) ? 1'b1 : 1'b0;
                    entry4_rst  <= (nxt_head == 8'd5) ? 1'b1 : 1'b0 ;
//                    entry5_rst
                    entry6_rst  <= 1'b1 ;
                    entry7_rst  <= (nxt_head < cur_head) ? 1'b1 : 1'b0 ;
                end // 4'd6
                
                4'd7 : begin
                    entry0_rst  <= (nxt_head >= 8'd1 && nxt_head < cur_head) ? 1'b1 : 1'b0 ;
                    entry1_rst  <= (nxt_head >= 8'd2 && nxt_head < cur_head) ? 1'b1 : 1'b0 ;
                    entry2_rst  <= (nxt_head >= 8'd3 && nxt_head < cur_head) ? 1'b1 : 1'b0 ;
                    entry3_rst  <= (nxt_head >= 8'd4 && nxt_head < cur_head) ? 1'b1 : 1'b0 ;
                    entry4_rst  <= (nxt_head >= 8'd5 && nxt_head < cur_head) ? 1'b1 : 1'b0 ;
                    entry5_rst  <= (nxt_head == 8'd6) ? 1'b1 : 1'b0 ;
//                    entry6_rst
                    entry7_rst  <= 1'b1 ;
                end // 4'd7
            endcase
        end // if  
        else begin
            entry0_rst <= 1'b0;
            entry1_rst <= 1'b0;
            entry2_rst <= 1'b0;
            entry3_rst <= 1'b0;
            entry4_rst <= 1'b0;
            entry5_rst <= 1'b0;
            entry6_rst <= 1'b0;
            entry7_rst <= 1'b0;
        end // else  
    end // always
    
    reg [12*8:0] ascii_main_sm;
    always@(main_sm) begin
        case(main_sm)
            IDLE        : ascii_main_sm = "IDLE" ;
            TX_REQ      : ascii_main_sm = "TX_REQ" ;
            TX_GNT      : ascii_main_sm = "TX_GNT" ;
            TX_WTDATA   : ascii_main_sm = "TX_WTDATA" ;
            TX_DONE     : ascii_main_sm = "TX_DONE" ;
            RX_ACK_CHK  : ascii_main_sm = "RX_ACK_CHK" ;
            RX_ACK_CALC : ascii_main_sm = "RX_ACK_CALC" ;
            RX_ACK_COMP : ascii_main_sm = "RX_ACK_COMP" ;
            RX_FREE     : ascii_main_sm = "RX_FREE" ;
            RX_DONE     : ascii_main_sm = "RX_DONE";
            RTX_START   : ascii_main_sm = "RTX_START" ;
            RTX_CMD_BLD : ascii_main_sm = "RTX_CMD_BLD" ;
            RTX_CMD_WT  : ascii_main_sm = "RTX_CMD_WT" ;
            RTX_GNT     : ascii_main_sm = "RTX_GNT" ;
            DONE        : ascii_main_sm = "DONE" ;
            
//            default : ascii_main_sm = "IDLE" ;
        endcase
    end
    
    reg [10*8:0] ascii_build_sm;
    always@(build_sm) begin
        case(build_sm)
            BUILD_IDLE  : ascii_build_sm = "BUILD_IDLE" ;
            BUILD_BLD   : ascii_build_sm = "BUILD_BLD" ;
            BUILD_WR    : ascii_build_sm = "BUILD_WR" ;
            BUILD_WAIT  : ascii_build_sm = "BUILD_WAIT" ;
            BUILD_DONE  : ascii_build_sm = "BUILD_DONE" ;
        endcase
    end
    
endmodule
