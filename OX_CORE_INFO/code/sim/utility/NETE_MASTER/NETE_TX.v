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

module NETE_TX(
            input                   clk,
            input                   reset_,
            
            // FIFO I/O
            input  [255:0]          tx_data_in,
            input                   tx_mac_empty,
            output reg              tx_mac_rd_en,
            
            // Output signals to ENDPOINT 
            input                   tx_tready,  
            output reg [63:0]       sfp_axis_rx_0_tdata,    
            output reg              sfp_axis_rx_0_tvalid,
            output reg [7:0]        sfp_axis_rx_0_tkeep,            // Mask, 1bit keep -> 1byte data
            output reg [3:0]        sfp_axis_rx_0_tDest,            // ChipID, assign 0 for now
            output reg              sfp_axis_rx_0_tlast             // Send out along with last data byte
    );
    
    parameter   NETE_IDLE   =   8'h01;
    parameter   NETE_RDEN   =   8'h02;
    parameter   NETE_WAIT   =   8'h04;
    parameter   NETE_DECO   =   8'h08;
    parameter   NETE_DONE   =   8'h80;
    
    parameter   OUTP_IDLE   =   4'h1;
    parameter   OUTP_NO_C   =   4'h2;
    parameter   OUTP_OUTP   =   4'h4;
    parameter   OUTP_DONE   =   4'h8;
    
    reg  [7:0]       nete_sm;
    wire             nete_idle;
    wire             nete_rden;
    wire             nete_wait;
    wire             nete_deco;
    wire             nete_done;
    
    reg  [3:0]       outp_sm;
    wire             outp_idle;
    wire             outp_no_c;
    wire             outp_outp;
    wire             outp_done;
    
    reg  [1:0]       wait_cnt;               // wait 2 cycles
    reg  [3:0]       qqword_total;           // total number of qqword in this pkt
    reg  [3:0]       qqword_cnt;             // count qqword
    reg  [3:0]       qqword_cnt_buf;
    reg  [7:0]       qword_total;           // total number of qword in this pkt
    reg  [7:0]       qword_cnt;             // count qword

    reg  [15:0]      bcnt;                   // store bcnt (first 16 bit of first qqword)
    reg  [15:0]      bcnt_left;              // subtract 8bytes from bcnt for ever output
    reg  [255:0]     data_in;                // input buffer for data
    reg  [3:0]       last_bcnt;              // stores bcnt of last qword
    reg  [15:0]      input_bcnt;             // input bcnt left
    
    reg  [63:0]      reg_1;                  // stores 64bit of data output from 256 input
    reg  [63:0]      reg_2;
    reg  [63:0]      reg_3;
    reg  [63:0]      reg_4;
       
    reg              data_in_valid;          // data valid for buffered input
    reg  [1:0]       outp_cnt;               // cnt to 4
    
    wire             output_ready;           // high when 4 registers have data, ready to output
    reg  [63:0]      data_out_buf;           // delay data_out for 1 clk to match with keep
    reg              valid_out_buf;          // delay valid_out for 1 clk to match with keep
    reg              last_out_buf;           // delay last_out for 1 clk to match with keep
    reg  [7:0]       keep_buff;
    
    assign nete_idle = nete_sm[0];
    assign nete_rden = nete_sm[1];
    assign nete_wait = nete_sm[2];
    assign nete_deco = nete_sm[3];
    assign nete_done = nete_sm[7];
    
    assign outp_idle = outp_sm[0];
    assign outp_no_c = outp_sm[1];
    assign outp_outp = outp_sm[2];    
    assign outp_done = outp_sm[3];
    
    assign output_ready = (|data_in) ? 1'b1 : 1'b0 ;
    
    always@ (posedge clk) begin              // NETE_SM FLOW       
        if(!reset_) begin
            nete_sm <=  NETE_IDLE;
            outp_sm <=  OUTP_IDLE ;
        end // if reset_
        else begin
            case(nete_sm)
                NETE_IDLE : nete_sm <= (!tx_mac_empty) ? NETE_RDEN : NETE_IDLE ;
                NETE_RDEN : nete_sm <= NETE_WAIT;
                NETE_WAIT : nete_sm <= (wait_cnt == 2'd1) ? NETE_DECO : NETE_WAIT ;
                NETE_DECO : nete_sm <= (input_bcnt >= bcnt) ? NETE_DONE : NETE_RDEN ;
                NETE_DONE : nete_sm <= (last_out_buf) ? NETE_IDLE : NETE_DONE;
            endcase
            case(outp_sm)
                OUTP_IDLE : outp_sm <= (nete_deco && qqword_cnt == 4'b0) ? OUTP_NO_C : OUTP_IDLE ;
                OUTP_NO_C : outp_sm <= (outp_cnt == 2'd3) ? OUTP_OUTP : OUTP_NO_C ;
                OUTP_OUTP : outp_sm <= (last_out_buf) ? OUTP_DONE : OUTP_OUTP ;
                OUTP_DONE : outp_sm <= OUTP_IDLE ;
            endcase            
        end
    end // always
    
    
    always@ (posedge clk) begin              // SM Logic   
        if(!reset_) begin
            // ======================= NETE_SM LOGIC =======================
            tx_mac_rd_en            <= 1'b0;
            qqword_cnt              <= 4'b0;
//            bcnt_left               <= 15'b0;
            
            wait_cnt                <= 2'b0;
            input_bcnt              <= 16'b0 ;

            // ======================= OUTP_SM LOGIC =======================
            qword_cnt               <= 8'b0 ;
            outp_cnt                <= 2'b0 ;
            data_out_buf            <= 64'b0 ;
        end // if reset
        
        else begin
            // ======================= NETE_SM LOGIC =======================
            case(nete_sm)
                NETE_IDLE   :   begin
                    tx_mac_rd_en            <= 1'b0;
                    qqword_cnt              <= 4'b0;
                    wait_cnt                <= 2'b0;
                    input_bcnt              <= 16'b0 ;
                end
                NETE_RDEN   :   begin
                    tx_mac_rd_en            <= 1'b1;  
                    input_bcnt              <= (qqword_cnt == 4'b0) ? input_bcnt + 16'd24 :
                                               input_bcnt + 16'd32 ;                 
                end
                NETE_WAIT   :   begin
                    tx_mac_rd_en            <= 1'b0;
                    wait_cnt                <= wait_cnt + 2'd1 ;
                    
                end
                NETE_DECO   :   begin
                    wait_cnt                <= 2'd0;
                    qqword_cnt              <= qqword_cnt + 4'd1 ;
//                    bcnt_left               <= (qqword_cnt == 4'd0) ? data_in[63:0] : bcnt_left ;
                    
//                    tx_mac_rd_en            <= (qqword_cnt < qqword_total-1) ? 1'b1 : 1'b0 ;
                    
                end
                NETE_DONE   :   begin
                
                end   
            endcase
            // ======================= OUTP_SM LOGIC =======================
            case(outp_sm)
                OUTP_IDLE   :   begin
                    qword_cnt               <= 8'b0 ;
                    data_out_buf            <= 64'b0 ;
                    outp_cnt                <= 2'b0 ;
                end
                OUTP_NO_C   :   begin
                    qword_cnt               <= qword_cnt + 8'd1 ;
                    outp_cnt                <= outp_cnt + 2'd1 ;
                    data_out_buf            <= (outp_cnt == 2'd1) ? reg_2 :
                                               (outp_cnt == 2'd2) ? reg_3 :
                                               (outp_cnt == 2'd3) ? reg_4 :
                                               data_out_buf ;
                                                                   
                end
                OUTP_OUTP   :   begin
                    qword_cnt               <= qword_cnt + 8'd1 ;
                    outp_cnt                <= outp_cnt + 2'd1 ;
                    data_out_buf            <= (outp_cnt == 2'd0) ? reg_1 :
                                               (outp_cnt == 2'd1) ? reg_2 :
                                               (outp_cnt == 2'd2) ? reg_3 :
                                               reg_4 ;
                                                
                end
                OUTP_DONE   :   begin
                    
                end
            endcase
        end // else        
    end // always    
    
    always@ (posedge clk) begin
        if(!reset_) begin
            data_in                 <= 256'b0 ;
            qqword_total            <= 4'b0;
            last_bcnt               <= 8'b0 ;
            bcnt                    <= 16'b0;
            qqword_cnt_buf          <= 4'b0;
            data_in_valid           <= 1'b0;
            
            bcnt_left               <= 16'b0;
            reg_1                   <= 64'b0;
            reg_2                   <= 64'b0;
            reg_3                   <= 64'b0;
            reg_4                   <= 64'b0;    
            sfp_axis_rx_0_tvalid    <= 1'b0 ;  
            sfp_axis_rx_0_tlast     <= 1'b0 ;   
            sfp_axis_rx_0_tkeep     <= 8'b0 ;  
            sfp_axis_rx_0_tdata     <= 64'b0 ;
            sfp_axis_rx_0_tDest     <= 4'b0;
            
            valid_out_buf           <= 1'b0 ;  
            last_out_buf            <= 1'b0 ; 
            qword_total             <= 8'b0 ;    
            
            keep_buff               <= 8'b0 ;         
        end
        
        else begin
            data_in         <= tx_data_in ;
            
            qword_total     <= (qqword_cnt == 4'b0) ? tx_data_in[15:3] + (|tx_data_in[2:0]) : qword_total ;
                               
            qqword_total    <= (nete_idle) ? 4'b0 :
                               (qqword_cnt == 4'b0) ? tx_data_in[15:5] + (|tx_data_in[4:0]) : qqword_total ;
                               
            last_bcnt       <= (nete_idle) ? 8'b0 :
                               (qqword_cnt == 8'b0) ? (tx_data_in[2:0]) : last_bcnt ;
                               
            bcnt            <= (qqword_cnt == 8'd0) ? tx_data_in[63:0] : bcnt;   
            qqword_cnt_buf  <= qqword_cnt ;      
            
//            data_out2       <= data_out;
//            data_valid2     <= data_valid;
//            sfp_axis_rx_0_tvalid <= data_valid2;
//            sfp_axis_rx_0_tdata  <= data_out2;
            data_in_valid           <= (qqword_cnt > 4'd0 && qqword_cnt_buf < qqword_total) ? 1'b1 : 1'b0 ;
            
            reg_1                   <= (output_ready) ? data_in[63:0]    : 64'b0 ;
            reg_2                   <= (output_ready) ? data_in[127:64]  : 64'b0 ;
            reg_3                   <= (output_ready) ? data_in[191:128] : 64'b0 ;
            reg_4                   <= (output_ready) ? data_in[255:192] : 64'b0 ;    
            
            bcnt_left               <= (outp_no_c && qword_cnt == 8'd0) ? bcnt :
                                       (qword_cnt > 8'd0 && qword_cnt <= qword_total-8'd1 && bcnt_left - 8'd8 >= 8'd0) ? bcnt_left - 8'd8 : 16'b0 ;
            
            valid_out_buf           <= (qword_cnt > 8'd0 && qword_cnt <= qword_total) ? 1'b1 : 1'b0 ;                   
            sfp_axis_rx_0_tvalid    <= valid_out_buf ;
            
            last_out_buf            <= (qword_cnt > 8'b0 && qword_cnt == qword_total) ? 1'b1 : 1'b0 ;
            keep_buff               <= (bcnt_left >= 16'd8) ? 8'b1111_1111 :
                                       (bcnt_left == 16'd7) ? 8'b0111_1111 :  
                                       (bcnt_left >= 16'd6) ? 8'b0011_1111 :   
                                       (bcnt_left >= 16'd5) ? 8'b0001_1111 :
                                       (bcnt_left >= 16'd4) ? 8'b0000_1111 :
                                       (bcnt_left >= 16'd3) ? 8'b0000_0111 :
                                       (bcnt_left >= 16'd2) ? 8'b0000_0011 :
                                       (bcnt_left >= 16'd1) ? 8'b0000_0001 :
                                   8'b0000_0000;  
            sfp_axis_rx_0_tlast     <= last_out_buf ;
            sfp_axis_rx_0_tdata     <= data_out_buf ;
            if(sfp_axis_rx_0_tvalid) $display("DATA_OUT TO ENDPOINT: %h", sfp_axis_rx_0_tdata) ;
            sfp_axis_rx_0_tkeep     <= keep_buff;         
        end // else
    end // always
    
    reg [4*8-1:0] ascii_nete_sm;
    
    always@ (nete_sm) begin
        case(nete_sm)
            NETE_IDLE   :   ascii_nete_sm = "IDLE";
            NETE_RDEN   :   ascii_nete_sm = "RDEN";
            NETE_WAIT   :   ascii_nete_sm = "WAIT";
            NETE_DECO   :   ascii_nete_sm = "DECO";
            NETE_DONE   :   ascii_nete_sm = "DONE";
        endcase
    end    

    reg [4*8-1:0] ascii_outp_sm;
        
    always@(outp_sm) begin
        case(outp_sm)
            OUTP_IDLE   :   ascii_outp_sm = "IDLE";
            OUTP_NO_C   :   ascii_outp_sm = "NO_C";
            OUTP_OUTP   :   ascii_outp_sm = "OUTP";
            OUTP_DONE   :   ascii_outp_sm = "DONE";
        endcase
    end
    
    
    
    
    
    
    
//    parameter       NETE_IDLE = 8'h01;
//    parameter       NETE_RDEN = 8'h02;
//    parameter       NETE_WAIT = 8'h04;
//    parameter       NETE_DECO = 8'h08;
//    parameter       NETE_OUTP = 8'h10;
//    parameter       NETE_LOOP = 8'h20;
//    parameter       NETE_DONE = 8'h80;
    
//    reg [7:0]       nete_sm;
//    wire            nete_idle_st;
//    wire            nete_rden_st;
//    wire            nete_wait_st;
//    wire            nete_deco_st;
//    wire            nete_outp_st;
//    wire            nete_loop_st;
//    wire            nete_done_st;
    
//    reg  [3:0]      out_cnt;                // cnt to 4 (4-64bit output per 1-256bit input
//    reg  [15:0]     bcnt;                   // store bcnt (first 16 bit of first qqword)
//    reg  [15:0]     bcnt_left;              // subtract 8bytes from bcnt for ever output
//    reg  [3:0]      qqword_total;           // total number of qqword in this pkt
//    reg  [3:0]      qqword_cnt;             // count qqword
//    reg  [7:0]      qword_total;            // total number of quad word in this pkt
//    reg  [7:0]      qword_cnt;              // count qword
//    reg  [255:0]    data_in;                // input buffer for data
//    reg  [1:0]      wait_cnt;               // wait 2 cycles
//    reg  [3:0]      last_bcnt;              // stores bcnt of last qword
    
//    wire            not_full_8byte;          // high when last qword is not a full byte
//    wire [63:0]     out_1, out_2,           // assign to 64bit of data input
//                    out_3, out_4;
                                   
//    reg  [63:0]     data_out, data_out2;
//    reg             data_valid, data_valid2;
    
//    assign nete_idle_st = nete_sm[0] ;
//    assign nete_rden_st = nete_sm[1] ;
//    assign nete_wait_st = nete_sm[2] ;
//    assign nete_deco_st = nete_sm[3] ;
//    assign nete_outp_st = nete_sm[4] ;
//    assign nete_loop_st = nete_sm[5] ;
//    assign nete_done_st = nete_sm[7] ;
    
//    assign out_1 = (!reset_) ? 1'b0 : (qqword_cnt == 8'b1) ? data_in[127:64]  : data_in[63:0] ; 
//    assign out_2 = (!reset_) ? 1'b0 : (qqword_cnt == 8'b1) ? data_in[191:128] : data_in[127:64] ; 
//    assign out_3 = (!reset_) ? 1'b0 : (qqword_cnt == 8'b1) ? data_in[255:192] : data_in[191:128] ; 
//    assign out_4 = (!reset_) ? 1'b0 : (qqword_cnt == 8'b1) ? 64'b0            : data_in[255:192] ; 
    
////    assign first_qqword_done = qword_cnt == 8'd0 && out_cnt == 2'd2 ;
////    assign other_qqword_done = qword_cnt > 8'd0 && out_cnt == 2'd3 ;
    
//    assign not_full_8byte = (|last_bcnt) ;
    
//    always@ (posedge clk) begin             // NETE_SM Flow
//        if(!reset_) begin
//            nete_sm <= NETE_IDLE ;
//        end 
//        else begin
//            case(nete_sm)
//                NETE_IDLE   :   begin
//                    nete_sm <=  (!tx_mac_empty) ? NETE_RDEN : NETE_IDLE ;
//                end
//                NETE_RDEN   :   begin
//                    nete_sm <=  NETE_WAIT ;
//                end
//                NETE_WAIT   :   begin
//                    nete_sm <= (wait_cnt == 2'd1) ? NETE_DECO : NETE_WAIT ;
//                end
//                NETE_DECO   :   begin
//                    nete_sm <= (tx_tready) ? NETE_OUTP : NETE_DECO;
//                end
//                NETE_OUTP   :   begin
//                    nete_sm <= (qqword_cnt == 4'd1 && out_cnt == 4'd3 || qqword_cnt > 4'd1 && out_cnt == 4'd4) ? ((qqword_cnt < qqword_total) ? NETE_RDEN : NETE_DONE) :
//                               NETE_OUTP ; 

//                end
////                NETE_LOOP   :   begin
////                    nete_sm <= (qword_cnt == qword_total) ? NETE_DONE : NETE_RDEN ;
////                end
//                NETE_DONE   :   begin
//                    nete_sm <= NETE_IDLE ;
//                end
//                default     :   begin
//                    nete_sm <= NETE_IDLE ;
//                end
//            endcase
//        end
//    end // end 
    
//    always@ (posedge clk) begin
//        if(!reset_) begin
//            tx_mac_rd_en            <= 1'b0;
//            out_cnt                 <= 4'b0;
            
//            qword_cnt               <= 8'b0;
//            qqword_cnt              <= 4'b0;
//            bcnt_left               <= 15'b0;
            
//            data_out                <= 64'b0;
//            data_valid              <= 1'b0;
//            sfp_axis_rx_0_tkeep     <= 8'b0;
//            sfp_axis_rx_0_tDest     <= 4'b0;
//            sfp_axis_rx_0_tlast     <= 1'b0;
//            wait_cnt                <= 2'b0;
//        end // if reset
        
//        else begin
//            case(nete_sm)
//                NETE_IDLE   :   begin
//                    tx_mac_rd_en            <= 1'b0;
//                    out_cnt                 <= 4'b0;
//                    qword_cnt               <= 8'b0;
//                    qqword_cnt              <= 4'b0;
                    
//                    wait_cnt                <= 2'b0;
                    
//                    data_out                <= 64'b0;
//                    data_valid              <= 1'b0;
//                    sfp_axis_rx_0_tkeep     <= 8'b0;
//                    sfp_axis_rx_0_tlast     <= 1'b0;
//                end
//                NETE_RDEN   :   begin
//                    tx_mac_rd_en            <= 1'b1;
//                    sfp_axis_rx_0_tvalid    <= 1'b0;
                    
//                end
//                NETE_WAIT   :   begin
//                    tx_mac_rd_en            <= 1'b0;
//                    out_cnt                 <= 4'b0;
//                    wait_cnt                <= wait_cnt + 2'd1 ;
                    
//                end
//                NETE_DECO   :   begin
//                    qword_cnt               <= qword_cnt + 8'd1 ;
//                    wait_cnt                <= 2'd0;
//                    qqword_cnt              <= qqword_cnt + 4'd1 ;
//                    bcnt_left               <= (qqword_cnt == 4'd0) ? data_in[63:0] : bcnt_left ;
//                end
//                NETE_OUTP   :   begin
//                    out_cnt                 <= out_cnt + 2'd1 ;
//                    qword_cnt               <= qword_cnt + 8'd1 ;
//                    data_out                <= (out_cnt == 4'd0) ? out_1 :
//                                               (out_cnt == 4'd1) ? out_2 :
//                                               (out_cnt == 4'd2) ? out_3 :
//                                               out_4 ;
//                    data_valid              <= (qqword_cnt == 4'd1 && out_cnt < 4'd3 || qqword_cnt > 4'd1 && out_cnt < 4'd4) ? 1'b1 : 1'b0; 
//                    bcnt_left               <= (out_cnt > 4'd0 && bcnt_left >= 15'd8) ? bcnt_left - 15'd8 : 
//                                               (bcnt_left < 15'd8 && !(|data_out)) ? 15'd0 :bcnt_left ;  
                                                                     
//                end
//                NETE_DONE   :   begin
//                    sfp_axis_rx_0_tlast     <= 1'b1;  
//                end
//            endcase
//        end
//    end // always
    
    
//    always@ (posedge clk) begin
//        if(!reset_) begin
//            data_in         <= 256'b0 ;
//            qword_total     <= 8'b0;
//            qqword_total    <= 4'b0;
//            last_bcnt       <= 8'b0 ;
//            bcnt            <= 16'b0;
//        end
        
//        else begin
//            data_in         <= tx_data_in ;
            
//            qword_total     <= (nete_idle_st) ? 8'b0 :
//                               (qword_cnt == 8'b0) ? tx_data_in[15:3] + (|tx_data_in[2:0]) : qword_total ;
            
//            qqword_total    <= (nete_idle_st) ? 4'b0 :
//                               (qqword_cnt == 4'b0) ? tx_data_in[15:5] + (|tx_data_in[4:0]) : qqword_total ;
                               
//            last_bcnt       <= (nete_idle_st) ? 8'b0 :
//                               (qword_cnt == 8'b0) ? (tx_data_in[2:0]) : last_bcnt ;
                               
//            bcnt            <= (qword_cnt == 8'd0) ? data_in[63:0] : bcnt;         
            
//            data_out2       <= data_out;
//            data_valid2     <= data_valid;
//            sfp_axis_rx_0_tvalid <= data_valid2;
//            sfp_axis_rx_0_tdata  <= data_out2;
      
//            sfp_axis_rx_0_tkeep <= (bcnt_left >= 16'd8) ? 8'b1111_1111 :
//                                   (bcnt_left == 16'd7) ? 8'b0111_1111 :  
//                                   (bcnt_left >= 16'd6) ? 8'b0011_1111 :   
//                                   (bcnt_left >= 16'd5) ? 8'b0001_1111 :
//                                   (bcnt_left >= 16'd4) ? 8'b0000_1111 :
//                                   (bcnt_left >= 16'd3) ? 8'b0000_0111 :
//                                   (bcnt_left >= 16'd2) ? 8'b0000_0011 :
//                                   (bcnt_left >= 16'd1) ? 8'b0000_0001 :
//                                   8'b0000_0000;               
//        end // else
//    end // always
    
//    reg [4*8-1:0] ascii_nete_sm;
    
//    always@ (nete_sm) begin
//        case(nete_sm)
//            NETE_IDLE   :   ascii_nete_sm = "IDLE";
//            NETE_RDEN   :   ascii_nete_sm = "RDEN";
//            NETE_WAIT   :   ascii_nete_sm = "WAIT";
//            NETE_DECO   :   ascii_nete_sm = "DECO";
//            NETE_OUTP   :   ascii_nete_sm = "OUTP";
//            NETE_DONE   :   ascii_nete_sm = "DONE";
//        endcase
//    end
endmodule

   