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

module NOC_MASTER
    #(  parameter       DATA_WIDTH  = 64,
        parameter [3:0] NOC_WR_IDLE = 4'h1,
        parameter [3:0] NOC_WR_DATA = 4'h2,
        parameter [3:0] NOC_WR_DONE = 4'h8,
        parameter       MEM_FILE    = "mem/mem_default.txt" )
    (
        input                           clk,
        input                           reset_,
        input                           gen_en,             //script provided enable     
        input  [47:0]                   pkt_gen_addr,       //script provided starting addr
        input  [15:0]                   pkt_gen_cnt,        //script provided payload length
        //==========================NOC1 SIGNALS (Request msg)==========================
        input                           noc_in_rdy,         //i-1 ready signal from TLC 
        output reg                      noc_in_valid,         //o-1 valid signal goes to TLC
        output reg [DATA_WIDTH - 1: 0]  noc_in_data,        //o-64 data signal goes to TLC
        
        //==========================NOC2 SIGNALS (Response msg)==========================
        input                           noc_out_valid,        //i-1 valid signal from TLC (response msg)
        input  [DATA_WIDTH - 1: 0]      noc_out_data,       //i-64 response data/msg from TLC
        output reg                      noc_out_rdy         //o-1 ready signal to TLC
    );
    
    //=============================================================================
    //                          Request (Write) Signals 
    //=============================================================================
    reg [3:0] noc_wr_state;
    wire noc_wr_idle_st;
    wire noc_wr_data_st;
    wire noc_wr_done_st;
    
    
    assign noc_wr_idle_st = noc_wr_state[0];
    assign noc_wr_data_st = noc_wr_state[1];
    assign noc_wr_done_st = noc_wr_state[3];
    

    wire [71:0] pkt_gen_out;
    wire        pkt_gen_valid;
    
    reg [15:0] pkt_cnt_dec;
    reg        data_first_wr;
    reg [47:0] addr_inc;
    
    memory_rom #(.FILE(MEM_FILE)) memory_rom (
        .addr_inc       (addr_inc),     //i-48 incrementing address
        .pkt_gen_out    (pkt_gen_out)   //o-72  {8'b valid, 64'b data}
    ); //memory_wr_module
    
    // output block
    always@(posedge clk) begin
        if(!reset_) begin
            noc_in_valid = 1'b0;
            noc_in_data  = 64'b0;
            noc_out_rdy  = 1'b1;
        end // if
        
        else begin
            noc_in_valid = pkt_gen_out[64];
            noc_in_data = pkt_gen_out[63:0];
        end // else
        
    end //always comb
    //=============================================================================
    //                              Write FSM Logic
    //=============================================================================
    always @(posedge clk) begin
        if(!reset_) begin
            noc_wr_state <= NOC_WR_IDLE;
        end // if !reset_
        
        else begin
            if(noc_wr_idle_st) 
//                noc_wr_state <= (gen_en && noc_in_rdy) ? NOC_WR_DATA : NOC_WR_IDLE;
                noc_wr_state <= (gen_en) ? NOC_WR_DATA : NOC_WR_IDLE;
            if(noc_wr_data_st)
                noc_wr_state <= (|pkt_cnt_dec) ? NOC_WR_DATA : NOC_WR_DONE;
            if(noc_wr_done_st)
                noc_wr_state <= NOC_WR_IDLE;
        end // else      
              
    end //always
    
    always @(posedge clk) begin
        if(!reset_) begin
            data_first_wr <= 1'b0;
            pkt_cnt_dec <= 16'b0;
            addr_inc <= 48'b0;
        end // if !reset_
        
        else begin
            if(noc_wr_idle_st) begin
                data_first_wr <= (gen_en) ? 1'b1 : 1'b0;
                pkt_cnt_dec <= (|pkt_gen_cnt) ? pkt_gen_cnt - 1 : pkt_cnt_dec;         // -1 for cnt_dec to reach zero
                addr_inc <= pkt_gen_addr;
            end // noc_wr_idle_st
            
            else if(noc_wr_data_st) begin
                data_first_wr <= 1'b0;
                pkt_cnt_dec <= (|pkt_cnt_dec) ? pkt_cnt_dec - 1 : pkt_cnt_dec;
                addr_inc <= (pkt_cnt_dec >= 1) ? addr_inc + 1 : addr_inc;
            end //noc_wr_data_st
            
            else if(noc_wr_done_st) begin
                pkt_cnt_dec <= 16'b0;
            end //noc_wr_done_st
        end // else
    end // always
    
    
    
    
    
    
    
    
    
    reg  [12*8-1:0] ascii_noc_wr_state;
    always@(noc_wr_state) begin
        case(noc_wr_state)
            NOC_WR_IDLE: ascii_noc_wr_state = "NOC_WR_IDLE";
            NOC_WR_DATA: ascii_noc_wr_state = "NOC_WR_DATA";
            NOC_WR_DONE: ascii_noc_wr_state = "NOC_WR_DONE";
        endcase
    end
endmodule
