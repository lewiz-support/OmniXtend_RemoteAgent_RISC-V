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
// Date: 2022-11-10
// Project: N/A
// Comments: Simple Delay Line
//           Output is asserted a fixed delay after input
//           Output is deasserted immediately after input
//
//********************************
// File history:
//   2022-11-10: Original
//****************************************************************

`timescale 1ns / 1ps


module delayline
    #(
        parameter   DELAY_WIDTH     = 9         //Delay counter width
    )(
        input                       clk,        //i-1
    //  input                       reset_,     //i-1

        input                       in,
        output reg                  out,
        input [DELAY_WIDTH-1:0]     delay       //i-DELAY_WIDTH, Delay time in cycles
    );

    reg [DELAY_WIDTH-1:0]   counter;

    always @ (posedge clk) begin
        if(!in) begin
            counter <=  delay;
            out     <=  1'b0;
        end
        else begin
            counter <= (|counter) ? counter - 1 : counter;
            out     <= (|counter) ? out : 1'b1;
        end
    end

endmodule