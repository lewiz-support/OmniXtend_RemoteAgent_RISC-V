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

`define DATA_WIDTH 72

module memory_rom
    #(
        parameter                   FILE    = "mem/mem_default.txt"
    )
    (
        input  [47:0]               addr_inc,
        output [`DATA_WIDTH-1:0]    pkt_gen_out
    );


    reg [`DATA_WIDTH - 1:0] memory_wr_data [0:65535]; //temp memory of 2^16 for data


    assign pkt_gen_out  = memory_wr_data[addr_inc];

    pathutil path();

	initial begin
        $readmemh(path.buildpath_relative(`__FILE__,FILE,""), memory_wr_data);
	end

endmodule
