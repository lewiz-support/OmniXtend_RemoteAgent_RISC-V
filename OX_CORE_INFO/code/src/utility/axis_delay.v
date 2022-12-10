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
// Date: 2022-10-12
// Project: N/A
// Comments: AXIS Delay Unit
//           Gates an AXIS slave's 'ready' signal to insert a 
//           configurable delay between packets. Can be triggered
//           by 'ready' falling, or 'valid'/'last' falling.
//
//********************************
// File history:
//   2022-10-12: Original
//****************************************************************

`timescale 1ns / 1ps


module axis_delay
    #(
        parameter       DELAY_WIDTH     = 9                 //Delay counter width
    )(
        input                           clk,                //i-1
        input                           reset_,             //i-1

        //AXIS Bus In
        input                           axis_m_tvalid,      //i-1, Valid signal from master
        input                           axis_m_tlast,       //i-1, Last signal from master
        output                          axis_m_tready,      //o-1, Ready signal to master

        //AXIS Bus Out
        output                          axis_s_tvalid,      //o-1, Valid signal to slave
        input                           axis_s_tready,      //i-1, Ready signal from slave

        //Control IO
        input                           enable,             //i-1, Enable the delay unit
        input                           mode,               //i-1, If asserted, delay triggers on valid/last, otherwise ready
        input [DELAY_WIDTH-1:0]         delay,              //i-DELAY_WIDTH, Delay time in cycles
        output                          active,             //o-1, Asserted while the delay is currently active

        //Debug
        output                          test                //o-1 debug
    );



    //================================================================//
    //  Internal Signals
    
    reg [DELAY_WIDTH-1:0]   counter;
    reg                     trigger;
    assign                  axis_m_tready = axis_s_tready && (counter == 0);
    assign                  axis_s_tvalid = axis_m_tvalid && (counter == 0);
    assign                  active = (counter > 0);
    
    
    //Debug signal
    assign  test =  1'b0;
    
    
    //================================================================//
    //  Register Logic

    always @ (posedge clk) begin
        if(!reset_) begin 
            counter <=   'b0;
        end
        else if (enable) begin           
            counter <= (trigger) ? delay :
                       (counter > 0) ? counter - 1 :
                        counter;
        end
    end
    
    reg axis_m_tvalid_dly;
    reg axis_m_tlast_dly;
    reg axis_s_tready_dly;
    
    always @ (posedge clk) begin
        axis_m_tvalid_dly   <= axis_m_tvalid;
        axis_m_tlast_dly    <= axis_m_tlast ;
        axis_s_tready_dly   <= axis_s_tready;
    end
    
    always @ (negedge clk) begin
        trigger <= (!reset_) ? 1'b0 :
                   (trigger) ? 1'b0 :
                   (enable)  ? (
                        (mode) ? (axis_m_tvalid_dly & !axis_m_tvalid) | (axis_m_tlast_dly & !axis_m_tlast) : 
                        (axis_s_tready_dly & !axis_s_tready)
                      ): 
                    1'b0;
    end
  
    
    

endmodule