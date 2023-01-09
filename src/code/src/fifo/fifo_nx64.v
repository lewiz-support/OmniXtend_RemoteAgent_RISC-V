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
// Date: 2022-11-08
// Project: N/A
// Comments: FIFO Wrapper, variable depth, 64-bit wide
//
//********************************
// File history:
//   2022-11-08: Original
//****************************************************************

`timescale 1ns / 1ps


//NOTE: Width parameter is unused when wrapping an IP Block FIFO.  When wrapping
//      `asynch_fifo`, all parameters may be used for adjustments during testing.

//If running a synthesis, automatically use the IP block FIFO
//  Vivado automatically defines SYNTHESIS when running a synthesis
`ifdef SYNTHESIS
    `define USEIPFIFO
`endif

module fifo_nx64
    #(
        parameter   WIDTH   = 64,
        parameter   DEPTH   = 1024,
        parameter   PTR     = 10    //NOTE: 2**PTR = DEPTH
    ) (
        input  wire                 reset_,

        //Write Port
        input  wire                 wrclk,      //i-1,     Write port clock
        input  wire                 wren,       //i-1,     Write enable
        input  wire [WIDTH-1 : 0]   wrdata,     //i-WIDTH, Data to write
        output wire                 wrfull,     //o-1,     Full signal (no space for writes)
        output wire                 wrempty,    //o-1,     Empty signal (0 = some data is present)
        output wire [PTR  : 0]      wrusedw,    //o-PTR,   Number of slots currently in use for writing

        //Read Port
        input  wire                 rdclk,      //i-1,     Read port clock
        input  wire                 rden,       //i-1,     Read enable
        output wire [WIDTH-1 : 0]   rddata,    //i-WIDTH, Read data out
        output wire                 rdfull,     //o-1,     Full signal (data available for read == depth)
        output wire                 rdempty,    //o-1,     Empty signal (no data for reading)
        output wire [PTR  : 0]      rdusedw,    //o-PTR,   Number of slots currently in use for reading

        //Debug Output
        output wire                 dbg
    );


//The Maximum depth this wrapper will support.
//Any greater depths will be reduced to this value.
localparam MAXDEPTH = 8192;



//Xilinx FIFO IP
`ifdef USEIPFIFO
    `ifdef FIFO_MAXDEPTH
    localparam MAX = `FIFO_MAXDEPTH;
    `else
    localparam MAX = MAXDEPTH;
    `endif

    generate case((DEPTH > MAX) ? MAX : DEPTH)

        16: begin
            localparam IPPTR = (PTR < 3) ? PTR+1 : 4;
            fifo_16x64_xil fifo_16x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        32: begin
            localparam IPPTR = (PTR < 4) ? PTR+1 : 5;
            fifo_32x64_xil fifo_32x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        64: begin
            localparam IPPTR = (PTR < 5) ? PTR+1 : 6;
            fifo_64x64_xil fifo_64x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        128: begin
            localparam IPPTR = (PTR < 6) ? PTR+1 : 7;
            fifo_128x64_xil fifo_128x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        256: begin
            localparam IPPTR = (PTR < 7) ? PTR+1 : 8;
            fifo_256x64_xil fifo_256x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        512: begin
            localparam IPPTR = (PTR < 8) ? PTR+1 : 9;
            fifo_512x64_xil fifo_512x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        1024: begin
            localparam IPPTR = (PTR < 9) ? PTR+1 : 10;
            fifo_1024x64_xil fifo_1024x64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        2048: begin
            localparam IPPTR = (PTR < 10) ? PTR+1 : 11;
            fifo_2kx64_xil fifo_2kx64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        4096: begin
            localparam IPPTR = (PTR < 11) ? PTR+1 : 12;
            fifo_4kx64_xil fifo_4kx64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        8192: begin
            localparam IPPTR = (PTR < 12) ? PTR+1 : 13;
            fifo_8kx64_xil fifo_8kx64_xil (
                .rst        (!reset_),

                //Write Port
                .wr_clk         (wrclk),                // Writing Clock
                .wr_en          (wren),                 // Write Enable
                .din            (wrdata),               // Write Data In
                .full           (wrfull),               // Write Full Flag (to avoid overflow)
                .wr_data_count  (wrusedw[IPPTR-1:0]),   // number of slots currently in use for writing

                //Read Port
                .rd_clk         (rdclk),                // Reading Clock
                .rd_en          (rden),                 // Read Enable
                .dout           (rddata),              // Read Data Out
                .empty          (rdempty),              // Read Empty Flag (to avoid underflow)
                .rd_data_count  (rdusedw[IPPTR-1:0]),   // number of slots currently in use for reading

                //Reset safety signals
                .wr_rst_busy    (),
                .rd_rst_busy    ()
            );

            if (PTR >= IPPTR) begin
                assign wrusedw[PTR:IPPTR]= 'b0;
                assign rdusedw[PTR:IPPTR]= 'b0;
            end
        end

        default: begin
            illegal_parameter_condition_error unsupported_depth();
        end
    endcase endgenerate


    assign wrempty=0;
    assign rdfull=0;
    assign dbg=0;


//Pure RTL FIFO
`else
    asynch_fifo # (
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .PTR(PTR)
    ) asynch_fifo (
        .reset_     (reset_),

        //=== Signals for WRITE
        .wrclk      (wrclk),      // Clk for writing data
        .wren       (wren),       // request to write
        .datain     (wrdata),     // Data coming in
        .wrfull     (wrfull),     // indicates FIFO is full or not (To avoid overriding)
        .wrempty    (wrempty),    // 0- some data is present (at least 1 data is present)
        .wrusedw    (wrusedw),    // number of slots currently in use for writing

        //=== Signals for READ
        .rdclk      (rdclk),      // Clk for reading data
        .rden       (rden),       // Request to read from FIFO
        .dataout    (rddata),     // Data coming out
        .rdfull     (rdfull),     // 1-FIFO IS FULL (data available for read == DEPTH)
        .rdempty    (rdempty),    // indicates fifo is empty or not (to avoid underflow)
        .rdusedw    (rdusedw),    // number of slots currently in use for reading

        //=== Signals for TEST
        .dbg        (dbg)
    );
`endif

endmodule


/* Instantiation Template (for depth "dddd" and pointer width "pp")

fifo_nx64 #(.DEPTH(dddd), .PTR(pp)) fifo_ddddx64 (     //NOTE: 2**PTR = DEPTH
    .reset_     (),

    .wrclk      (),     //i-1,   Write port clock
    .wren       (),     //i-1,   Write enable
    .wrdata     (),     //i-64,  Write data in
    .wrfull     (),     //o-1,   Write Full Flag (no space for writes)
    .wrempty    (),     //o-1,   Write Empty Flag (0 = some data is present)
    .wrusedw    (),     //o-PTR, Number of slots currently in use for writing

    .rdclk      (),     //i-1,   Read port clock
    .rden       (),     //i-1,   Read enable
    .rddata     (),     //i-64,  Read data out
    .rdfull     (),     //o-1,   Read Full Flag (data available for read == depth)
    .rdempty    (),     //o-1,   Read Empty Flag (no data for reading)
    .rdusedw    (),     //o-PTR, Number of slots currently in use for reading

    .dbg        ()
);

*/