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



module NETE_RX(
        input               clk,
        input               reset_,

        //In from Endpoints
        input   [63:0]          sfp_axis_tx_0_tdata,
        input   [7:0]           sfp_axis_tx_0_tkeep,
        input                   sfp_axis_tx_0_tvalid,
        input                   sfp_axis_tx_0_tlast,
        input   [3:0]           sfp_axis_tx_0_tDest,

        output reg              rx_tready,

        //Out to LMAC RX Stand-in FIFOs
        output reg [255:0]      fifo_pkt_data,
        output reg              fifo_pkt_wren,
        input                   fifo_pkt_full,
        input      [6:0]        fifo_pkt_usedword,

        output reg [63:0]       fifo_bcnt_data,     // either be 62Byte or 70Byte: 6/7 qword = 48/56byte + 14byte of omi header. 70Byte is including CRC
        output reg              fifo_bcnt_wren,
        input                   fifo_bcnt_full,
        input      [6:0]        fifo_bcnt_usedword
    );

    parameter NETE_RX_IDLE = 8'h01;
    parameter NETE_RX_GET  = 8'h02;
    parameter NETE_RX_COMB = 8'h04;
    parameter NETE_RX_LAST = 8'h08;
    parameter NETE_RX_WAIT = 8'h10;
    parameter NETE_RX_DONE = 8'h80;

    parameter ALMOST_FULL_CONST  = 7'd64;      // 128-64, 2k / 32 = 64 left

    reg     [63:0]      data_buf;
    reg                 valid_buf;
    reg                 last_buf;
    reg     [7:0]       keep_buf;
    reg     [3:0]       dest_buf;

    reg     [63:0]      data_buf_1;
    reg     [63:0]      data_buf_2;
    reg     [63:0]      data_buf_3;
    reg     [63:0]      data_buf_4;

    reg                 last_buf_2;
    reg     [64:0]      bcnt_buf_2;

    reg     [7:0]       nete_rx_sm;

    wire                nete_rx_idle;
    wire                nete_rx_get;
    wire                nete_rx_comb;
    wire                nete_rx_last;
    wire                nete_rx_wait;
    wire                nete_rx_done;

    reg     [3:0]       get_cnt;                    // counter to 4 for each
    reg     [3:0]       comb_delay;                 // delay up to 4 to get
    wire                comb_ready;                 // got all 4 64bit data, ready to combine them into 256bit data
    wire                almost_full;                // high when fifo usedword reaches a number
    wire                busy;
    reg                 full_byte ;                 // high for last byte is full 8 byte


    // Testing registers
    reg     [21:0]      seq_number;                 // stores received seq num
    reg     [21:0]      ack_number;                 // stores received ack_num
    reg                 ack_nack;                   // ack or nack
    reg     [ 7:0]      valid_cnt;                  // count valid clock cycle
    reg     [63:0]      header_temp;                // stores TLoE Frame header
    reg     [ 2:0]      chan;
    reg     [ 2:0]      opcode;

    assign nete_rx_idle = nete_rx_sm[0];
    assign nete_rx_get  = nete_rx_sm[1];
    assign nete_rx_comb = nete_rx_sm[2];
    assign nete_rx_last = nete_rx_sm[3];
    assign nete_rx_wait = nete_rx_sm[4];
    assign nete_rx_done = nete_rx_sm[7];

    assign comb_ready   = ((get_cnt == 4'd4) ? 1'b1 : 1'b0) ;
    assign almost_full  = ((fifo_pkt_usedword >= ALMOST_FULL_CONST) ? 1'b1 : 1'b0) ;
//  assign comb_ready   = (!reset_) ? 1'b0 : ((get_cnt == 4'd4) ? 1'b1 : 1'b0) ;
//  assign almost_full  = (!reset_) ? 1'b0 : ((fifo_pkt_usedword >= ALMOST_FULL_CONST) ? 1'b1 : 1'b0) ;
    assign busy         = (nete_rx_get | nete_rx_last | nete_rx_wait) ? 1'b1 : 1'b0 ;

    //NETE_RX_SM Next State Logic (Flow)
    always@(posedge clk) begin
        if(!reset_) begin
            nete_rx_sm  <= NETE_RX_IDLE;
        end // if reset

        else begin
            case(nete_rx_sm)
                NETE_RX_IDLE    :   nete_rx_sm  <=  (sfp_axis_tx_0_tvalid) ? NETE_RX_GET : NETE_RX_IDLE ;
                NETE_RX_GET     :   nete_rx_sm  <=  (last_buf) ? NETE_RX_LAST : NETE_RX_GET ;
            //  NETE_RX_COMB    :   nete_rx_sm  <=  NETE_RX_WREN ;
                NETE_RX_LAST    :   nete_rx_sm  <=  NETE_RX_WAIT ;
                NETE_RX_WAIT    :   nete_rx_sm  <=  NETE_RX_DONE;
                NETE_RX_DONE    :   nete_rx_sm  <=  NETE_RX_IDLE ;
                default         :   nete_rx_sm  <=  NETE_RX_IDLE ;
            endcase
        end // else
    end // always

    //NETE_RX_SM Output Logic
    always@ (posedge clk) begin
        if(!reset_) begin
        //  get_cnt                 <= 4'b0 ;
            comb_delay              <= 4'b0 ;

        end // if reset_
        else begin
            case(nete_rx_sm)
                NETE_RX_IDLE: begin
                //  get_cnt         <=  4'b0 ;
                    comb_delay      <=  4'b0 ;
                end // idle

                NETE_RX_GET: begin
                //  get_cnt         <=  (get_cnt < 4'd4 && valid_buf) ? get_cnt + 4'd1 : 4'b0 ;
                end // get

                NETE_RX_COMB: begin
                //  get_cnt         <= 4'b0 ;
                end // comb

                NETE_RX_LAST: begin
                end // wren

                NETE_RX_WAIT: begin
                end // wait

                NETE_RX_DONE: begin
                end // done

            endcase
        end // else
    end // always


    // Combinational Logic
    always@(posedge clk) begin
        if(!reset_) begin
            data_buf    <= 64'b0;
            valid_buf   <= 1'b0;
            last_buf    <= 1'b0;
            keep_buf    <= 8'b0;
            dest_buf    <= 4'b0;

            rx_tready   <= 1'b0;

            data_buf_1  <= 64'b0;
            data_buf_2  <= 64'b0;
            data_buf_3  <= 64'b0;
            data_buf_4  <= 64'b0;

            get_cnt     <= 4'b0 ;

            fifo_pkt_wren   <= 1'b0;
            fifo_pkt_data   <= 256'b0;

            fifo_bcnt_wren  <= 1'b0;
            fifo_bcnt_data  <= 64'b0 ;
            bcnt_buf_2      <= 64'b0 ;
            last_buf_2      <= 1'b0 ;

            // test reg
            seq_number      <= 22'hf ;
            ack_number      <= 22'hf ;
            ack_nack        <= 1'b0 ;
            valid_cnt       <= 8'b0 ;
            header_temp     <= 64'b0 ;
            opcode          <= 3'b0 ;
            chan            <= 3'b0;
        end // if reset

        else begin
            data_buf    <= sfp_axis_tx_0_tdata;
            if(sfp_axis_tx_0_tvalid) begin
                if(sfp_axis_tx_0_tlast)  $display("=============> DATA_IN_FROM ENDPOINT LAST: %h <=============", sfp_axis_tx_0_tdata) ;
                else                     $display("=============> DATA_IN_FROM ENDPOINT: %h <=============", sfp_axis_tx_0_tdata) ;
            end
            valid_buf   <= sfp_axis_tx_0_tvalid;
            last_buf    <= sfp_axis_tx_0_tlast;
            keep_buf    <= sfp_axis_tx_0_tkeep;
            dest_buf    <= sfp_axis_tx_0_tDest;

            last_buf_2  <= last_buf;

            data_buf_1  <= data_buf;
            data_buf_2  <= data_buf_1;
            data_buf_3  <= data_buf_2;
            data_buf_4  <= data_buf_3;

        //  data_buf_1  <= (nete_rx_get) ? data_buf   : data_buf_1 ;
        //  data_buf_2  <= (nete_rx_get) ? data_buf_1 : data_buf_2 ;
        //  data_buf_3  <= (nete_rx_get) ? data_buf_2 : data_buf_3 ;
        //  data_buf_4  <= (nete_rx_get) ? data_buf_3 : data_buf_4 ;

        //  get_cnt     <= (|data_buf_1) ? (get_cnt < 4'd4 ) ? get_cnt + 4'd1 : 4'b1 : 4'b0 ;
           full_byte    <= (last_buf_2 && get_cnt == 4'd4) ? 1'b1 : 1'b0;

           get_cnt      <= (nete_rx_last) ? (valid_buf) ? 4'd1 : 4'b0 :
                           (!valid_buf) ? get_cnt :
                           (get_cnt < 4'd4 ) ? get_cnt + 4'd1 : 4'b1 ; //|| !last_buf_2


        //  get_cnt      <= valid_buf &  nete_rx_last ? (get_cnt + 4'd1) :
        //                  valid_buf & !nete_rx_last ? ((get_cnt < 4'd4) ? get_cnt + 4'd1 : 4'd1) :
        //                  4'd0 ;


            fifo_pkt_wren   <=  (comb_ready | last_buf_2) ? 1'b1 : 1'b0 ;
        //  fifo_pkt_data   <=  (comb_ready | last_buf_2) ? {data_buf_1, data_buf_2, data_buf_3, data_buf_4} : fifo_pkt_data ;
            fifo_pkt_data   <=  (comb_ready || (last_buf_2 && get_cnt == 4'd4)) ? {data_buf_1, data_buf_2, data_buf_3, data_buf_4} :
                                (last_buf_2 && get_cnt == 4'd1) ? {192'b0, data_buf_1}:
                                (last_buf_2 && get_cnt == 4'd2) ? {128'b0, data_buf_1, data_buf_2}:
                                (last_buf_2 && get_cnt == 4'd3) ? {64'b0, data_buf_1, data_buf_2, data_buf_3}:
                                fifo_pkt_data ;

            rx_tready       <=  (!almost_full) ? 1'b1 : 1'b0 ;  // & nete_rx_idle
            rx_tready       <=  1'b1 ;  // & nete_rx_idle
           
            if(nete_rx_last) begin
                bcnt_buf_2 <= (keep_buf) ? 64'd8 : 64'b0;
            end
            else begin
                case(keep_buf)
                    8'b1111_1111    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd8 ;
                    8'b0111_1111    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd7 ;
                    8'b0011_1111    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd6 ;
                    8'b0001_1111    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd5 ;
                    8'b0000_1111    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd4 ;
                    8'b0000_0111    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd3 ;
                    8'b0000_0011    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd2 ;
                    8'b0000_0001    :   bcnt_buf_2 <= bcnt_buf_2 + 64'd1 ;
                    8'b0000_0000    :   bcnt_buf_2 <= 64'b0 ;
                endcase
            end

            fifo_bcnt_data  <= (nete_rx_idle) ? 64'b0 :
                               (nete_rx_last) ? bcnt_buf_2 :
                               (nete_rx_wait) ? 64'b0 : fifo_bcnt_data ;
                               
            fifo_bcnt_wren  <= (nete_rx_last) ? 1'b1 : 1'b0 ;

            //testing reg
        // header_temp      <= (valid_cnt == 8'd1) ? {sfp_axis_tx_0_tdata[7:0], sfp_axis_tx_0_tdata[15:8]} :
        //                     (valid_cnt == 8'd2) ? {header_temp[15:0], sfp_axis_tx_0_tdata[7:0], sfp_axis_tx_0_tdata[15:8], sfp_axis_tx_0_tdata[23:16], sfp_axis_tx_0_tdata[31:24], sfp_axis_tx_0_tdata[39:32], sfp_axis_tx_0_tdata[47:40]} :
        //                     header_temp ;
        // header_temp      <= (fifo_pkt_wren & nete_rx_get) ? {fifo_pkt_data[175:112]} : header_temp;
           header_temp      <= (fifo_pkt_wren & nete_rx_get) ? {fifo_pkt_data[119:112],
                                                                fifo_pkt_data[127:120],
                                                                fifo_pkt_data[135:128],
                                                                fifo_pkt_data[143:136],
                                                                fifo_pkt_data[151:144],
                                                                fifo_pkt_data[159:152],
                                                                fifo_pkt_data[167:160],
                                                                fifo_pkt_data[175:168]} : header_temp;
            seq_number      <= header_temp[53:32] ;
            ack_number      <= header_temp[31:10] ;
            ack_nack        <= header_temp[9] ;
            opcode          <= fifo_pkt_data[179:177];
            chan            <= fifo_pkt_data[182:180] ;
        //  valid_cnt       <= (sfp_axis_tx_0_tvalid && !nete_rx_done) ? valid_cnt + 8'd1 : 8'b0 ;
        end // else
    end // always

    reg [4*8-1:0]    ascii_nete_rx_sm;
    always@(nete_rx_sm) begin
        case(nete_rx_sm)
            NETE_RX_IDLE    :   ascii_nete_rx_sm = "IDLE" ;
            NETE_RX_GET     :   ascii_nete_rx_sm = "GET " ;
            NETE_RX_COMB    :   ascii_nete_rx_sm = "COMB" ;
            NETE_RX_LAST    :   ascii_nete_rx_sm = "LAST" ;
            NETE_RX_WAIT    :   ascii_nete_rx_sm = "WAIT" ;
            NETE_RX_DONE    :   ascii_nete_rx_sm = "DONE" ;
        endcase
    end // always
endmodule
