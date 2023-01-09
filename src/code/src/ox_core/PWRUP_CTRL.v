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

//This module is Used to generate the control signal to power up the reset control module. 
//The reset is active low in our system. 


module PWRUP_CTRL(

    input                               clk                         ,
    input                               rst_                        ,
    output reg                          pwr2rst_rst_ctrl_start              //start signal for RESET_CTRL module
    );
    
    //registers
    reg rst_dly;
    
//	-----> Delay the Reset Using a Flip Flop<-----   
    always @(posedge clk)  begin
                rst_dly                 <= rst_;
                pwr2rst_rst_ctrl_start  <= !rst_dly & rst_ ;                //Generate the control signal to start RESET_CTRL module
    end
    
       
endmodule
