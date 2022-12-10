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
// Date: 2022-07-28
// Project: OmniXtend Core
// Comments: AXIS Master Emulator, Memory Data Source
//           Sends data from connected memory over AXIS bus while 
//           receiver is ready. Memory values dictate 'valid' and 
//           'last' signals. To have output loop through memory,
//           use 'done' to drive 'reset' or use an external trigger.
//
//           May also be used as a NoC Master by not connecting
//           'last' or 'strobe' signals. Note that NoC commands
//           must be separated by at least one beat with 'valid'
//           deasserted.
//
//
//           Each addressable block of memory must contain the data
//           in the lowest bits, followed by DATA_WIDTH/8 bits of
//           strobe, valid bit then last bit.
//
//           e.g. For 64 bit Data, each must contain, in hex 
//                74'hC_SS_DDDDDDDDDDDDDDDD where nibble 'C'
//                is binary 0_0_last_valid
//
//
//           WARNING: REQUIRES sequential read memory (data out
//                    only changes on rising edge)
//
//********************************
// File history:
//   2022-07-28 E.Kaiser: Original
//****************************************************************

//Output example
//      |       |       |       |       |       |       |       |
//        _______ _______ _______ _______ _______ _______________
//-------X__DDD__X__DDD__X__DDD__X__DDD__X__DDD__X__DDD__________
//        _______ _______ _______ _______ _______ _______
//-------X___S___X___S___X___S___X___S___X___S___X___S___X-------
//        _______________________________________________
//_______|                     valid                     |_______
//                                               ________
//______________________________________________|  last  |_______
//

`timescale 1ns / 1ps


module axis_mastersim_mem
    #(
        parameter       DATA_WIDTH      = 64,               //Output Data width
        parameter       ADDR_WIDTH      = 10,               //Address width
        localparam      TOTAL_WIDTH     = DATA_WIDTH+DATA_WIDTH/8+2,
        
        parameter       ADDR_MAX        = 1023              //Maximum value for address
    )(
        input                           clk,                //i-1, Depends on the speed of the device
        input                           reset_,             //i-1

        //Memory In
        input      [TOTAL_WIDTH-1:0]    mem_in_data,        //i-DATA_WIDTH+DATA_WIDTH/8+2, Data from memory
        output reg [ADDR_WIDTH-1:0]     mem_in_addr,        //o-ADDR_WIDTH, Address for data memory
        output                          mem_in_en,          //o-1, Memory enable signal

        //AXIS Bus Out
        output     [DATA_WIDTH-1:0]     axis_out_tdata,     //o-DATA_WIDTH, Outgoing data
        output     [DATA_WIDTH/8-1:0]   axis_out_tstrb,     //o-DATA_WIDTH/8, Indicates what bytes of the data is valid.
        output                          axis_out_tvalid,    //o-1, Signal to show if the data is valid.
        output                          axis_out_tlast,     //o-1, Signal to show the last data beat.
        input                           axis_out_tready,    //i-1, Indicates if the slave is ready.

        //Control IO
        input                           enable,             //i-1, Enable the simulator
        input                           latch,              //i-1, If asserted, enable latches until a 'last' beat output
        output                          running,            //i-1, Asserted while the simulator is currently active
        output                          done,               //o-1, Asserted when simulator has run out of data

        //Debug
        output                          test                //o-1 debug
    );



    //================================================================//
    //  Internal Signals
    
    //Data registers
    reg  [TOTAL_WIDTH-1:0]  axisdata;
    reg  [TOTAL_WIDTH-1:0]  axisdata_bk;

    //Latching enable register
    reg                     run;

    //Run either when latched or enabled
    assign                  running = (enable | run);
    reg                     running_dly;
    
    //Delayed ready signal
    reg axis_out_tready_dly;

    //Always enable the memory  //TODO: Should we do this?
    assign  mem_in_en = 1'b1;

    //Done when max address is reached
    assign  done =  mem_in_addr >= ADDR_MAX;
    
    //Drive outputs directly from axisdata while enabled and not 'done'
    assign axis_out_tdata   =   (           done) ? 0 : axisdata[DATA_WIDTH-1:0];
    assign axis_out_tstrb   =   (!running | done) ? 0 : axisdata[DATA_WIDTH/8+DATA_WIDTH-1:DATA_WIDTH];
    assign axis_out_tvalid  =   (!running | done) ? 0 : axisdata[DATA_WIDTH/8+DATA_WIDTH];
    assign axis_out_tlast   =   (!running | done) ? 0 : axisdata[DATA_WIDTH/8+DATA_WIDTH+1];

    
    //Debug signal
    assign  test =  1'b0;
    
    
    //================================================================//
    //  Register Logic

    //Delayed ready signal
    always @ (posedge clk) begin
        if(!reset_) axis_out_tready_dly <= 1'b0;
        else        axis_out_tready_dly <= axis_out_tready;
    end

    //Advance to next data word if enabled and receiver is ready
    always @ (posedge clk) begin
        if(!reset_) begin
            mem_in_addr <= {ADDR_WIDTH{1'b0}};
        end
        else if (running & !done) begin
            mem_in_addr <=
                (axis_out_tready) ? mem_in_addr + 1 :
                mem_in_addr;
        end
    end
    
    //Only update the output while ready
    //  (and put back the beat that was lost when ready fell)
    always @ (posedge clk) begin
        if(!reset_) begin
            axisdata <= {TOTAL_WIDTH{1'b0}};
            axisdata_bk <= {TOTAL_WIDTH{1'b0}};
        end
        else if (running_dly & !done) begin
            axisdata    <= (axis_out_tready) ? 
                                (!axis_out_tready_dly) ? axisdata_bk : 
                                mem_in_data :
                            axisdata;
                        
            axisdata_bk <= (axis_out_tready_dly & !axis_out_tready) ? mem_in_data :
                            axisdata_bk;
        end
    end
    
    //
    always @ (posedge clk) running_dly <= running;
    
    //Latching enable/run register
    always @ (posedge clk) begin
        if(!reset_) begin
            run <= 1'b0;
        end
        else begin
            run <= latch ? (
                    enable ? 1'b1 :
                    (axis_out_tlast & axis_out_tready) ? 1'b0 :
                    run
                ) : run;
        end
    end

endmodule