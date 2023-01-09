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


`timescale 1ns / 1ns


module NETE_MASTER (
        input                   clk,
        input                   rst_,


        //--------------------------------//
        // TX FIFO
        input      [255:0]      ox2m_tx_data,
        input                   ox2m_tx_we,
        output                  m2ox_tx_fifo_full,


        //--------------------------------//
        // Endpoint AXIS TX
        input                   sfp_axis_tx_0_tready,
        output     [63:0]       sfp_axis_rx_0_tdata,
        output                  sfp_axis_rx_0_tvalid,
        output     [7:0]        sfp_axis_rx_0_tkeep,
        output     [3:0]        sfp_axis_rx_0_tDest,
        output                  sfp_axis_rx_0_tlast,


        //--------------------------------//
        // Endpoint AXIS RX

        input      [63:0]       axi_in_data,
        input                   axi_in_valid,
        input                   axi_in_last,
        input      [7:0]        axi_in_keep,
        input      [3:0]        axi_in_dest,
        output                  axi_in_rdy,


        //--------------------------------//
        // RX FIFOs

        //IPCS
        output     [63:0]       ipcs_data_out,
        input                   ipcs_rden,
        output                  ipcs_empty,
        output     [6:0]        ipcs_usedword,

        //Packet Data
        output     [255:0]      pkt_data_out,
        input                   pkt_rden,
        output                  pkt_empty,
        output     [6:0]        pkt_usedword

    );

    // TX FIFO to NETE_TX SIGNALs
    wire [255:0]        nete2f_data;
    wire                nete2f_rden;
    wire                f2nete_empty;

    // NETE_RX to RX FIFO SIGNALS

    wire [63:0]         ipcs_wdata;
    wire                ipcs_we;
    wire                fifo_bcnt_full;
    wire [6:0]          fifo_bcnt_usedword;

    wire [255:0]        pkt_wdata;
    wire                pkt_we;
    wire                fifo_pkt_full;
    wire [6:0]          fifo_pkt_usedword;



// ===================================================================================================
//                                          TX FIFO and NETE
// ===================================================================================================
    tx_pkt_fifo_8192x256 pkt_fifo(
        .reset_                     (rst_),
    
        .wrclk                      (clk),
        .wren                       (ox2m_tx_we),
        .datain                     (ox2m_tx_data),
        .wrfull                     (m2ox_tx_fifo_full),
        .wrusedw                    (),
    
        .rdclk                      (clk),
        .rden                       (nete2f_rden),
        .dataout                    (nete2f_data),
        .rdempty                    (f2nete_empty),
        .rdusedw                    ()
    );
    
    NETE_TX     NETE_TX (
        .clk                        (clk),
        .reset_                     (rst_),
        // FIFO I/O
        .tx_data_in                 (nete2f_data),
        .tx_mac_empty               (f2nete_empty),
        .tx_mac_rd_en               (nete2f_rden),

        // Output signals to ENDPOINT
        .sfp_axis_rx_0_tdata        (sfp_axis_rx_0_tdata),      // o-64
        .tx_tready                  (sfp_axis_tx_0_tready),     // i-1
        .sfp_axis_rx_0_tvalid       (sfp_axis_rx_0_tvalid),     // o-1
        .sfp_axis_rx_0_tkeep        (sfp_axis_rx_0_tkeep),      // o-8
        .sfp_axis_rx_0_tDest        (sfp_axis_rx_0_tDest),      // o-4
        .sfp_axis_rx_0_tlast        (sfp_axis_rx_0_tlast)       // o-1
    );

// ===================================================================================================
//                                          RX FIFO and NETE
// ===================================================================================================

	ipcs_fifo   ipcs_fifo_16x64 (
	    .reset_                     (rst_),

        .wrclk                      (clk),	                    // i-1
        .wren                       (ipcs_we),	                // i-1
        .datain                     (ipcs_wdata),	            // o-64
        .wrfull                     (fifo_bcnt_full),	        // o-1
        .wrusedw                    (fifo_bcnt_usedword),       // o-7

        .rdclk                      (clk),	                    // i-1
        .rden                       (ipcs_rden),	            // i-1
        .dataout                    (ipcs_data_out),            // o-64
        .rdempty                    (ipcs_empty),               // o-1
        .rdusedw                    (ipcs_usedword)             // o-7
	);

	pkt_fifo   pkt_fifo_16x256 (
        .reset_                     (rst_),
    
        .wrclk                      (clk),
        .wren                       (pkt_we),
        .datain                     (pkt_wdata),
        .wrfull                     (fifo_pkt_full),
        .wrusedw                    (fifo_pkt_usedword),
    
        .rdclk                      (clk),
        .rden                       (pkt_rden),
        .dataout                    (pkt_data_out),
        .rdempty                    (pkt_empty),
        .rdusedw                    (pkt_usedword)
	 ) ;

    NETE_RX     NETE_RX (
        .clk                        (clk),
        .reset_                     (rst_),

        // ENDPOINT SIGNALS
        .rx_tready                  (axi_in_rdy),               // o-1

        .sfp_axis_tx_0_tvalid       (axi_in_valid),             // i-1
        .sfp_axis_tx_0_tdata        (axi_in_data),              // i-64
        .sfp_axis_tx_0_tlast        (axi_in_last),              // i-1
        .sfp_axis_tx_0_tkeep        (axi_in_keep),              // i-8
        .sfp_axis_tx_0_tDest        (4'b0),                     // i-4

        // DATA FIFO SIGNALS
        .fifo_pkt_full              (fifo_pkt_full),            // i-1
        .fifo_pkt_usedword          (fifo_pkt_usedword),        // i-4
        .fifo_pkt_data              (pkt_wdata),                // o-256
        .fifo_pkt_wren              (pkt_we),                   // o-1

        // BCNT FIFO SIGNAL
        .fifo_bcnt_full             (fifo_bcnt_full),           // i-1
        .fifo_bcnt_usedword         (fifo_bcnt_usedword),       // i-4
        .fifo_bcnt_data             (ipcs_wdata),               // o-64
        .fifo_bcnt_wren             (ipcs_we)                   // o-1
    );

endmodule