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
// Comments: Xilinx PHY Reset Detection
//           Asserts rst_done once PHY has finished reset
//
//           NOTE: Only tested with complete PHY reset (issued by 'sys_reset')
//
//********************************
// File history:
//   2022-11-10: Original
//****************************************************************

`timescale 1ns / 1ps


module rstctrl_phy (
        input       clk,
        input       reset_,

        input       rst_rx,
        input       rst_tx,

        input       stat_rx,
        input       stat_tx,

        output reg  rst_done,
        output reg  stat_good
    );

    //Reset inputs delayed by 1 cycle
    reg rst_rx_dly, rst_tx_dly;
    always @ (posedge clk) begin
        rst_rx_dly <= rst_rx;
        rst_tx_dly <= rst_tx;
    end

    //Reset input edge detection
    reg rst_rx_r, rst_rx_f, rst_tx_f;
    always @ (posedge clk) begin
        if(!reset_) begin
            rst_rx_r    <=  1'b0;
            rst_rx_f    <=  1'b0;
            rst_tx_f    <=  1'b0;

            rst_done    <=  1'b0;
            stat_good   <=  1'b0;
        end
        else begin
            rst_rx_r    <= (!rst_rx_dly &  rst_rx) ? 1'b1     : rst_rx_r;
            rst_rx_f    <= ( rst_rx_dly & !rst_rx) ? rst_rx_r : rst_rx_f;
            rst_tx_f    <= ( rst_tx_dly & !rst_tx) ? 1'b1     : rst_tx_f;

            rst_done    <= (rst_rx_r & rst_rx_f & rst_tx_f) ? 1'b1 : rst_done;
            stat_good   <= (rst_rx_r & rst_rx_f & rst_tx_f & stat_rx & stat_tx) ? 1'b1 : stat_good;
        end
    end

endmodule