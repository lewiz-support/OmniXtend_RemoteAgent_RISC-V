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

module rtx_buf
    #(	    parameter RTX_DATA_PTR = 9)
    (
    input                           clk,
    input                           rst_,
    
    input       [255:0]             ox2b_rtx_wrdata_i,             
    input       [RTX_DATA_PTR-1:0]  ox2b_rtx_wrdata_wdaddr,         /// 16kB RAM = 256bit * 64slot * 8entries
    input                           ox2b_rtx_wrdata_we_i,          
   
    output  reg [255:0]             b2ox_rtx_rddata_i,             
    input       [RTX_DATA_PTR-1:0]  ox2b_rtx_rddata_rdaddr,         /// 16kB RAM = 256bit * 64slot * 8entries
    input                           ox2b_rtx_rddata_re_i          
    );
    
    reg [255:0] rtx_mem [(2**RTX_DATA_PTR)-1:0];
    
    always @ (posedge clk)
    begin
        if (!rst_)
        begin
            b2ox_rtx_rddata_i   <=  'b0;    
        end else begin
            if (ox2b_rtx_wrdata_we_i)
            begin
                rtx_mem[ox2b_rtx_wrdata_wdaddr] <=  ox2b_rtx_wrdata_i;  
            end else if(ox2b_rtx_rddata_re_i)
            begin
                b2ox_rtx_rddata_i   <=  rtx_mem[ox2b_rtx_rddata_rdaddr];  
            end
        end // else
    end      
endmodule
