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

module RST_CTRL
    #(
        parameter SRC_MAC           = 48'h001232_FFFFF0,
        parameter DST_MAC           = 48'h000000_000000
    )
    (
        input                               clk                         ,
        input                               rst_                        ,

        //input from the Power Up Module
        input                               pwr2rst_rst_ctrl_start      ,   //start signal for RESET_CTRL module.

        //signals to/from OX2M
        input                               ox2rst_rst_ctrl_grant       ,
        output reg [255:0]                  rst2ox_send_pkt_data        ,
        output reg                          rst2ox_pkt_credit_we        ,   //Valid Signal for the packet credit information
        output reg                          rst2ox_rst_ctrl_req         ,
        output reg							rst2ox_pkt_done             ,
        output reg [1:0]                    rst2ox_qqwd_cnter               //Counter for number of qqwds
    );

    reg [7:0] rst_ctrl_state;

    //Parameterization of States for FSM
    localparam  PWR_ON      =   8'h01;
    localparam  IDLE        =   8'h02;
    localparam  REQ         =   8'h04;
    localparam  GRANT       =   8'h08;
    localparam  SEND_PKT    =   8'h10;
    localparam  DONE        =   8'h20;


    //parameterizing the qqwds for ChB and ChD
//  parameter  chB_qqwd0   =   256'h0000_4900_0000_0000_0000_aaaa_18ff_ff32_1200_B67E_C1BE_2400_0000_0000_0000_0046;    //-/
    parameter  chB_qqwd0   =   {32'h4900, 32'h0000, 32'haaaa,swap6(SRC_MAC),swap6(DST_MAC),64'h0046};                             //+/
    parameter  chB_qqwd1   =   256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
    parameter  chB_qqwd2   =   256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000_0000_0000_0000_0000_0000;

//  parameter  chD_qqwd0   =   256'h0000_8900_0000_0100_0000_aaaa_18ff_ff32_1200_B67E_C1BE_2400_0000_0000_0000_0046;    //-/
    parameter  chD_qqwd0   =   {32'h8900, 32'h0100, 32'haaaa,swap6(SRC_MAC),swap6(DST_MAC),64'h0046};                             //+/
    parameter  chD_qqwd1   =   256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
    parameter  chD_qqwd2   =   256'h0000_0000_0000_0000_0000_0000_0000_0000_0000_0100_0000_0000_0000_0000_0000_0000;

    //Initial Credit is 4KB    //Current focus is on the credit field.
    parameter init_credit  =   256'h0000_4900_0000_0000_0000_aaaa_f0ff_ff32_1200_0000_0000_0000_0000_0000_0000_0046;

    wire pwr_on_st                      =   rst_ctrl_state[0];
    wire idle_st                        =   rst_ctrl_state[1];
    wire req_st                         =   rst_ctrl_state[2];
    wire gnt_st                         =   rst_ctrl_state[3];
    wire send_pkt_st                    =   rst_ctrl_state[4];
    wire done_st                        =   rst_ctrl_state[5];

    //reg for Output Pkts
//      reg [255:0]   pkt_credit_ch_B     ;
//      reg [255:0]   pkt_credit_ch_D     ;

    //counter to count number of pkts
    reg [3:0]     pkt_cnt ;

    // Number of channels required pkt to init the CREDIT
    parameter	MAX_PKT_OUT	    = 4'd1 ;    //if count starts at 0. Allow 2 pkts out max
    parameter MAX_QQWD_OUT      = 2'd2 ;    //Max qqwd to send is 3. (Might change in further Implementation)

    //FSM
    always@(posedge clk) begin
        if(!rst_) begin
            rst_ctrl_state                  <=  PWR_ON;
        end
        else begin
            if (pwr_on_st) begin
            	//pwr2rst_rst_ctrl_start is a pulse so we only transition from PWR_ON to IDLE exactly once
                rst_ctrl_state      <= pwr2rst_rst_ctrl_start ? IDLE : PWR_ON ;
            end

            if(idle_st) begin
            	//if 2 pkts out required for B & D channels,
                rst_ctrl_state      <= (pkt_cnt <= MAX_PKT_OUT) ? REQ : IDLE;
            end

            if(req_st) begin
                rst_ctrl_state      <= ox2rst_rst_ctrl_grant ?
                                           GRANT : REQ;
            end

            if(gnt_st) begin
                rst_ctrl_state      <= SEND_PKT;
            end

            //loop to send out enough qqwds for an OX pkt
            if(send_pkt_st) begin
                rst_ctrl_state      <= (rst2ox_qqwd_cnter == MAX_QQWD_OUT) ?
                                            DONE : SEND_PKT;
            end

            //done 1 pkt so increment pkt_cnt
            if(done_st) begin
                rst_ctrl_state      <= (pkt_cnt >= MAX_PKT_OUT) ?
                                            IDLE : REQ ;
            end
        end
    end

    reg             send_ch_B;

    wire [255:0]    send_qqwd0  = (send_ch_B) ? chB_qqwd0 : chD_qqwd0 ;
	wire [255:0]    send_qqwd1  = (send_ch_B) ? chB_qqwd1 : chD_qqwd1 ;
	wire [255:0]    send_qqwd2  = (send_ch_B) ? chB_qqwd2 : chD_qqwd2 ;

    //Logic for each state
    always@(posedge clk) begin
        if(!rst_) begin
            rst2ox_send_pkt_data                   <=      init_credit;		//4KB
            rst2ox_pkt_credit_we                   <=      1'b0;
            rst2ox_rst_ctrl_req                    <=      1'b0;
            rst2ox_pkt_done					       <=	   1'b0;
            rst2ox_qqwd_cnter                      <=      2'b0;
            pkt_cnt                                <=      4'b0;
            send_ch_B                              <=      1'b0;
        end
        else begin
            rst2ox_rst_ctrl_req    <=
                gnt_st          ?   1'b0 :
                req_st          ?   1'b1 :
                rst2ox_rst_ctrl_req;

            rst2ox_pkt_done        <=
                rst2ox_pkt_done?   1'b0 :
                done_st        ?   1'b1 :
                rst2ox_pkt_done;

            rst2ox_pkt_credit_we   <=
         	   done_st         ?   1'b0 :
         	   send_pkt_st     ?   1'b1 :
         	   rst2ox_pkt_credit_we;

            rst2ox_qqwd_cnter      <=
                rst2ox_qqwd_cnter == MAX_QQWD_OUT         ?   2'b0                  :
                send_pkt_st                               ?   rst2ox_qqwd_cnter + 1 :
                rst2ox_qqwd_cnter;

            rst2ox_send_pkt_data   <=
         	   (send_pkt_st && rst2ox_qqwd_cnter == 2'd0)  ?   send_qqwd0 :
         	   (send_pkt_st && rst2ox_qqwd_cnter == 2'd1)  ?   send_qqwd1 :
         	   (send_pkt_st && rst2ox_qqwd_cnter == 2'd2)  ?   send_qqwd2 :
         	   rst2ox_send_pkt_data ;

            pkt_cnt         <=
                done_st        ?   pkt_cnt + 1 :
                pkt_cnt;

            send_ch_B       <=
                pkt_cnt == 0    ?   1'b1 :
                1'b0;
        end
    end

    //ASCII State Names (FOR SIMULATION ONLY)
    reg [8*8:0] ascii_rst_ctrl_state;
    always@(rst_ctrl_state) begin
        case(rst_ctrl_state)
            PWR_ON		: ascii_rst_ctrl_state = "PWR_ON"	;
            IDLE 		: ascii_rst_ctrl_state = "IDLE"   	;
            REQ		    : ascii_rst_ctrl_state = "REQ"		;
            GRANT		: ascii_rst_ctrl_state = "GRANT"  	;
            SEND_PKT  	: ascii_rst_ctrl_state = "SEND_PKT"	;
            DONE   	    : ascii_rst_ctrl_state = "DONE"     ;
        endcase
    end


    //Swap endianness of a 6 byte value
    function [47:0] swap6(input [47:0] value);
        swap6 = {value[7:0],value[15:8],value[23:16],value[31:24],value[39:32],value[47:40]};
    endfunction
endmodule
