`timescale 1ns / 1ps
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
// Comments: Primary OmniXtend Core Testbench
//
//********************************
// File history:
//   N/A
//****************************************************************

//Define SIM_NOCROM to use the NoC ROM and delay in the testbench
//`define SIM_NOCROM

module core_tb();

    parameter   PRINT_SKIPNOP   = 1;    //Don't print out NOP TLoE Frames (those containing no TL message)
    parameter   NOC_FILE        = "mem/mem_CPU.txt"; //File containing NoC commands to issue
    
    //NOTE: NoC command files are located in 'code/sim/utility/NOC_MASTER'

    reg         autonoc_en      = 1;    //1 = Automatically send NoC commands from the above file
    reg [15:0]  autonoc_size    = 5;    //Size of each command in flits (includes any padding)
    reg [15:0]  autonoc_cnt     = 43;   //Number of commands contained in the file
    parameter   autonoc_dly     = 400;  //Number of cycles to wait between NoC commands
    
    //NOTE: Auto-NoC requires all commands in the file to be uniform in size. If not, use a TCL script to
    //      control the NoC Master. See the 'script' directory next to this testbench file. Auto-NoC must
    //      be disabled when running tests via script.

    reg clk;
    reg reset_;


    //================================================================//
    //  NOC_MASER

    //Control Signals from Testbench
    reg                         gen_en;
    reg         [47:0]          pkt_gen_addr;
    reg         [15:0]          pkt_gen_cnt;

    //NOC to OX_CORE
    wire                        noc_in_ready;
    wire        [63:0]          noc_in_data;
    wire                        noc_in_valid;

    //NOC from OX_CORE
    wire                        noc_out_ready;
    wire        [63:0]          noc_out_data;
    wire                        noc_out_valid;

    NOC_MASTER #(.MEM_FILE(NOC_FILE)) NOC_MASER(
        .clk                        (clk),                              //i-1
        .reset_                     (reset_),                           //i-1
        .gen_en                     (gen_en),                           //i-1 simulator generated signal
        .pkt_gen_addr               (pkt_gen_addr),                     //i-48 input starting address
        .pkt_gen_cnt                (pkt_gen_cnt),                      //i-16 input pkt length total

        .noc_in_rdy                 (noc_in_ready),
`ifndef SIM_NOCROM
        .noc_in_data                (noc_in_data),                      //o-64 request msg data/cmd
        .noc_in_valid               (noc_in_valid),                     //o-1  request msg valid
`endif
        .noc_out_rdy                (noc_out_ready),
        .noc_out_data               (noc_out_data),
        .noc_out_valid              (noc_out_valid)
    );

`ifdef SIM_NOCROM
    //================================================================//
    //  Block ROM and Master Emulator
    
    localparam  DATA_WIDTH      = 64;               //Output Data width
    localparam  ADDR_WIDTH      = 10;               //Address width
    localparam  ADDR_MAX        = 175;              //Maximum value for address (Emulator stops sending at this point)
    localparam  TOTAL_WIDTH     = DATA_WIDTH+DATA_WIDTH/8+2;
    
    
    //Master Control I/O
    reg                         enable=1;
    wire                        running;
    wire                        done;
    
    //AXIS signals unused by NoC
    wire [DATA_WIDTH/8-1:0]     rsrvd_strb;     //Indicates what bytes of the data is valid
    wire                        rsrvd_last;     //Signal to show the last data word
    
    //Memory to Master Signals
    wire [TOTAL_WIDTH-1:0]      mem_data;
    wire [ADDR_WIDTH-1:0]       mem_addr;
    wire                        mem_en;
    
    wire                        noc_tmp_ready;
    wire                        noc_tmp_valid;
    
    //Block ROM Containing NoC Commands
    brom_noc nocrom(
        .rsta       (mem_reset),
        .clka       (clk),
        .ena        (mem_en),
        .addra      (mem_addr),
        .douta      (mem_data),
        .rsta_busy  ()
    );
    
    //AXIS/NoC Master Emulator
    axis_mastersim_mem #(
        .DATA_WIDTH     (DATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .ADDR_MAX       (ADDR_MAX)
    ) noc_mastersim (
        .clk                    (clk),          //i-1
        .reset_                 (reset_),       //i-1
    
        .mem_in_data            (mem_data),     //i-DATA_WIDTH+DATA_WIDTH/8+2, Data from memory
        .mem_in_addr            (mem_addr),     //o-ADDR_WIDTH, Address for data memory
        .mem_in_en              (mem_en),       //o-1, Memory enable signal
    
        .axis_out_tdata         (noc_in_data),  //o-IN_DATA_WIDTH, Outgoing data
        .axis_out_tstrb         (rsrvd_strb),   //o-IN_DATA_WIDTH/8, Indicates what bytes of the data is valid.
        .axis_out_tvalid        (noc_tmp_valid),//o-1, Signal to show if the data is valid.
        .axis_out_tlast         (rsrvd_last),   //o-1, Signal to show the last data word.
        .axis_out_tready        (noc_tmp_ready),//i-1, Indicates if the slave is ready.
    
        .enable                 (enable),
        .latch                  (1),
        .running                (running),
        .done                   (done),
    
        .test                   ()          //o-1 debug
    );
    always @ (posedge done) begin
        #1000
        file_close = 1;
        #10
        $finish;
    end
    
    axis_delay #(
        .DELAY_WIDTH    (9)     //Delay counter width
    ) delay (
        .clk                (clk),          //i-1
        .reset_             (reset_),       //i-1

        //AXIS Bus In
        .axis_m_tvalid      (noc_tmp_valid),//i-1, Valid signal from master
        .axis_m_tlast       (0),            //i-1, Last signal from master
        .axis_m_tready      (noc_tmp_ready),//o-1, Ready signal to master

        //AXIS Bus Out
        .axis_s_tready      (noc_in_ready), //i-1, Ready signal from slave
        .axis_s_tvalid      (noc_in_valid), //o-1, Valid signal to slave

        //Control IO
        .enable             (1),            //i-1, Enable the simulator
        .mode               (0),            //i-1, If asserted, delay triggers on valid/last, otherwise ready
        .delay              (200),          //i-DELAY_WIDTH, Delay time in cycles
        .active             (),             //o-1, Asserted while the dealy is currently active

        //Debug
        .test               ()              //o-1 debug
    );
`endif

    //================================================================//
    //  OX_CORE

    //OX_CORE Configuration
    reg                         prb_ack_mode;
    reg                         lewiz_noc_mode;

    //TX to NETE_MASTER
    wire                        ox2m_tx_we;
    wire        [255:0]         ox2m_tx_data;
    wire                        m2ox_tx_fifo_full;

    //RX from NETE_MASTER
    wire        [63:0]          m2ox_rx_ipcs_data;
    wire                        m2ox_rx_ipcs_empty;
    wire        [6:0]           m2ox_rx_ipcs_usedword;
    wire                        ox2m_rx_ipcs_rden;

    wire        [255:0]         m2ox_rx_pkt_data;
    wire                        m2ox_rx_pkt_empty;
    wire        [6:0]           m2ox_rx_pkt_usedword;
    wire                        ox2m_rx_pkt_rden;


    OX_CORE         OX_CORE_U1  (
        .clk                        (clk),
        .rst_                       (reset_),

        //--- config signals
        //  prback_mode: 0 = ProbeAck with Data; 1 = ProbeAck with no data (for testing only)
        .prb_ack_mode               (prb_ack_mode),                 //i-1

        //  lewiz_noc_mode: 0 = standard NOC protocol mode (max datasize = 64 bytes)
        //                  1 = LeWiz NOC mode, extended data size to 2KBytes
        .lewiz_noc_mode             (lewiz_noc_mode),

        //TX Path from NOC
        .noc_in_valid               (noc_in_valid),                     // i-1
        .noc_in_data                (noc_in_data),                      // i-64
        .noc_in_ready               (noc_in_ready),                     // o-1

        //RX Path to NOC
        .noc_out_ready              (noc_out_ready),                    // i-1
        .noc_out_valid              (noc_out_valid),                    // o-1
        .noc_out_data               (noc_out_data),                     // i-64

        //TX Path to LMAC
        .m2ox_tx_fifo_full          (m2ox_tx_fifo_full),                // o-1
        .m2ox_tx_fifo_wrused        (),
        .ox2m_tx_we                 (ox2m_tx_we),                       // o-1
        .ox2m_tx_data               (ox2m_tx_data),                     // o-256
      //.ox2m_tx_be                 (),                                 //(optional) Byte enable

        //RX Path from LMAC
        .m2ox_rx_ipcs_data          (m2ox_rx_ipcs_data),                // i-64
        .m2ox_rx_ipcs_empty         (m2ox_rx_ipcs_empty),               // i-1
        .ox2m_rx_ipcs_rden          (ox2m_rx_ipcs_rden),                // o-1
        .m2ox_rx_ipcs_usedword      (m2ox_rx_ipcs_usedword),            // i-7


        .m2ox_rx_pkt_data           (m2ox_rx_pkt_data),                 // i-256
        .m2ox_rx_pkt_empty          (m2ox_rx_pkt_empty),                // i-1
        .m2ox_rx_pkt_usedword       (m2ox_rx_pkt_usedword),             // i-7
        .ox2m_rx_pkt_rden           (ox2m_rx_pkt_rden),                 // o-1
        .ox2m_rx_pkt_rd_cycle       ()
    );


    //================================================================//
    //  NETE_MASTER

    // Signals to Endpoint
    wire                        sfp_axis_tx_0_tready;
    wire        [63:0]          sfp_axis_rx_0_tdata;
    wire                        sfp_axis_rx_0_tvalid;
    wire        [7:0]           sfp_axis_rx_0_tkeep;
    wire        [3:0]           sfp_axis_rx_0_tDest;
    wire                        sfp_axis_rx_0_tlast;

    // Signals from Endpoint
    wire        [63:0]          axi_in_data;
    wire        [7:0]           axi_in_keep;
    wire                        axi_in_valid;
    wire                        axi_in_last;
    wire                        axi_in_rdy;
    wire        [3:0]           axi_in_dest;

    NETE_MASTER     NETE_MASTER (
        .clk                    (clk),
        .rst_                   (reset_),

        //TX FIFO I/O  (from OX_CORE) from Lewiz to endpoint
        .ox2m_tx_we             (ox2m_tx_we),                           // i-1
        .ox2m_tx_data           (ox2m_tx_data),                         // i-256
        .m2ox_tx_fifo_full      (m2ox_tx_fifo_full),                    // o -1

        //NETE_TX I/O  (to Endpoint) from endpoint to Lewiz
        .sfp_axis_tx_0_tready   (sfp_axis_tx_0_tready),                 // o-1
        .sfp_axis_rx_0_tdata    (sfp_axis_rx_0_tdata),                  // o-64
        .sfp_axis_rx_0_tvalid   (sfp_axis_rx_0_tvalid),                 // o-1
        .sfp_axis_rx_0_tkeep    (sfp_axis_rx_0_tkeep),                  // o-8
        .sfp_axis_rx_0_tDest    (sfp_axis_rx_0_tDest),                  // o-4
        .sfp_axis_rx_0_tlast    (sfp_axis_rx_0_tlast),                  // o-1

        //NETE_RX I/O (from Endpoint)
        .axi_in_data            (axi_in_data),                          // i-64
        .axi_in_valid           (axi_in_valid),                         // i-1
        .axi_in_last            (axi_in_last),                          // i-1
        .axi_in_keep            (axi_in_keep),                          // i-1
        .axi_in_rdy             (axi_in_rdy),                           // o-1
        .axi_in_dest            (axi_in_dest),                          // o-4


        //RX FIFO I/O (to OX_CORE)
        .pkt_rden               (ox2m_rx_pkt_rden),                     // i-1
        .pkt_data_out           (m2ox_rx_pkt_data),                     // o-256
        .pkt_empty              (m2ox_rx_pkt_empty),                    // o-1
        .pkt_usedword           (m2ox_rx_pkt_usedword),                 // o-7

        .ipcs_rden              (ox2m_rx_ipcs_rden),                    // i-1
        .ipcs_data_out          (m2ox_rx_ipcs_data),                    // o-64
        .ipcs_empty             (m2ox_rx_ipcs_empty),                   // o-1
        .ipcs_usedword          (m2ox_rx_ipcs_usedword)                 // o-7
    );


    //================================================================//
    //  Endpoint

    OmnixtendEndpoint  endpoint (
        .sconfig_axi_aclk        (clk),                                  // i-1 config clk
        .sconfig_axi_aresetn     (reset_),                               // i-1 config reset
        .sconfig_axi_arready     (),                                     // o-1
        .sconfig_axi_arvalid     (1'b0),                                 // i-1
        .sconfig_axi_araddr      (16'b0),                                // i-16
        .sconfig_axi_arprot      (3'b0),                                 // i-3
        .sconfig_axi_rvalid      (),                                     // o-1
        .sconfig_axi_rready      (1'b0),                                 // i-1
        .sconfig_axi_rdata       (),                                     // o-64
        .sconfig_axi_rresp       (),                                     // o-2
        .sconfig_axi_awready     (),                                     // o-1
        .sconfig_axi_awvalid     (1'b0),                                 // i-1
        .sconfig_axi_awaddr      (16'b0),                                // i-16
        .sconfig_axi_awprot      (3'b0),                                 // i-3
        .sconfig_axi_wready      (),                                     // o-1
        .sconfig_axi_wvalid      (1'b0),                                 // i-1
        .sconfig_axi_wdata       (64'b0),                                // i-64
        .sconfig_axi_wstrb       (8'b0),                                 // i-8
        .sconfig_axi_bvalid      (),                                     // o-1
        .sconfig_axi_bready      (1'b0),                                 // i-1
        .sconfig_axi_bresp       (),                                     // o-2

        .interrupt               (),                                     // o-1

        .sfp_axis_tx_aclk_0      (clk),                                  // i-1 tx clk
        .sfp_axis_tx_aresetn_0   (reset_),                               // i-1 tx reset
        .sfp_axis_tx_0_tvalid    (axi_in_valid),                         // o-1  from endpoint to Lewiz
        .sfp_axis_tx_0_tready    (axi_in_rdy),                           // i-1  from Lewiz to endpoint
        .sfp_axis_tx_0_tdata     (axi_in_data),                          // o-64 from endpoint to Lewiz
        .sfp_axis_tx_0_tlast     (axi_in_last),                          // o-1  from endpoint to Lewiz
        .sfp_axis_tx_0_tkeep     (axi_in_keep),                          // o-8  from endpoint to Lewiz
        .sfp_axis_tx_0_tDest     (axi_in_dest),                          // o-4  from endpoint to Lewiz

        .sfp_axis_rx_aclk_0      (clk),                                  // i-1 rx clk
        .sfp_axis_rx_aresetn_0   (reset_),                               // i-1 rx reset
        .sfp_axis_rx_0_tready    (sfp_axis_tx_0_tready),                 // o-1  from endpoint to Lewiz
        .sfp_axis_rx_0_tvalid    (sfp_axis_rx_0_tvalid),                 // i-1  from Lewiz to endpoint
        .sfp_axis_rx_0_tdata     (sfp_axis_rx_0_tdata),                  // i-64 from Lewiz to endpoint
        .sfp_axis_rx_0_tkeep     (sfp_axis_rx_0_tkeep),                  // i-8  from Lewiz to endpoint
        .sfp_axis_rx_0_tDest     (sfp_axis_rx_0_tDest),                  // i-4  from Lewiz to endpoint
        .sfp_axis_rx_0_tlast     (sfp_axis_rx_0_tlast)                   // i-1  from Lewiz to endpoint
    );

    //================================================================//
    //  Initialization & Clocks

    initial begin
        clk <= 1'b0;
        reset_ <= 1'b0;
        gen_en <= 1'b0;
        pkt_gen_addr <= 48'b0;
        pkt_gen_cnt <= 16'b0;

        prb_ack_mode        <=  1'b0;
        lewiz_noc_mode      <=  1'b0;

        #200 reset_ <= 1'b1;
    end

    always #1 clk <= ~clk;


    //================================================================//
    //  File handling

    integer f;
    reg file_close;

    //Open File at simulation start and close when `file_close` is asserted
    initial begin
        file_close <= 1'b0;
        f = $fopen({`__FILE__,".MSG.txt"},"w");
    end
    always @(posedge file_close) $fclose(f);



    //================================================================//
    //  Debug Printing

    //Request/response counters
    //(assumes all requests and responses go in order)

    //----------------------------------------------------------------//
    //  Collect & Print NOC Request data

    //Flit counter and data values.
    //NOTE: NOC Fields OPTIONS1, OPTIONS3 & OPTIONS4 are only for coherence requests/responses
    integer       id_nocreq = 0;
    integer      flt_nocreq = 0;
    reg [13:0 ] data_nocreq_chipid;         //flit1 63:50 - CHIPID
    reg [ 7:0 ] data_nocreq_xpos;           //      49:42 - XPOS
    reg [ 7:0 ] data_nocreq_ypos;           //      41:34 - YPOS
    reg [ 3:0 ] data_nocreq_fbits;          //      33:30 - FBITS
    reg [ 7:0 ] data_nocreq_payload;        //      29:22 - PAYLOAD LENGTH  (# of QWords)
    reg [ 7:0 ] data_nocreq_type;           //      21:14 - MESSAGE TYPE
    reg [ 7:0 ] data_nocreq_tag;            //      13:06 - MSHR/TAG
    reg [ 5:0 ] data_nocreq_opt1;           //      05:00 - OPTIONS1
    reg [47:0 ] data_nocreq_addr;           //flit2 63:16 - ADDRESS         (byte addressing, truncated to QWords (0-7 = QW0, 8-15 = QW1, etc)
    reg [12:0 ] data_nocreq_opt2;           //      15:03 - OPTIONS2
    reg [ 2:0 ] data_nocreq_lastbytes;      //      02:00 - LAST BYTE COUNT (the last QWord contains byte 0 through this #)
    reg [13:0 ] data_nocreq_srcchipid;      //flit3 63:50 - SRC CHIPID
    reg [ 7:0 ] data_nocreq_srcxpos;        //      49:42 - SRC XPOS
    reg [ 7:0 ] data_nocreq_srcypos;        //      41:34 - SRC YPOS
    reg [ 3:0 ] data_nocreq_srcfbits;       //      33:30 - SRC FBITS
    reg [29:0 ] data_nocreq_opt3;           //      29:00 - OPTIONS3
    //TODO: storage for PUT data

    //Collect data when NOC valid is asserted
    always @(posedge clk) begin
        @(negedge clk)
        if (reset_ & noc_in_valid) begin
            //$fdisplay(f,"~~Building NOC Request %0d (flit %0d): %h @ %0d",id_nocreq,flt_nocreq,noc_in_data,$time);
            case (flt_nocreq)
                0: begin
                    data_nocreq_chipid      <= noc_in_data[63:50];
                    data_nocreq_xpos        <= noc_in_data[49:42];
                    data_nocreq_ypos        <= noc_in_data[41:34];
                    data_nocreq_fbits       <= noc_in_data[33:30];
                    data_nocreq_payload     <= noc_in_data[29:22];
                    data_nocreq_type        <= noc_in_data[21:14];
                    data_nocreq_tag         <= noc_in_data[13:06];
                    data_nocreq_opt1        <= noc_in_data[05:00];
                end
                1: begin
                    data_nocreq_addr        <= noc_in_data[63:16];
                    data_nocreq_opt2        <= noc_in_data[15:03];
                    data_nocreq_lastbytes   <= noc_in_data[02:00];
                end
                2: begin
                    data_nocreq_srcchipid   <= noc_in_data[63:50];
                    data_nocreq_srcxpos     <= noc_in_data[49:42];
                    data_nocreq_srcypos     <= noc_in_data[41:34];
                    data_nocreq_srcfbits    <= noc_in_data[33:30];
                    data_nocreq_opt3        <= noc_in_data[29:00];
                end
                //TODO: collect PUT data
            endcase
            flt_nocreq <= flt_nocreq + 1;
        end

    end

    //Print values when NOC valid is deasserted
    always @(negedge noc_in_valid) begin
        if (reset_) begin
            $fdisplay(f,"--------------------------------");
            $fdisplay(f,"NOC Request %0d @ time %4d ns",id_nocreq,$time);
            $fdisplay(f,"  CHIPID      : %h",data_nocreq_chipid);
            $fdisplay(f,"  XPOS        : %h",data_nocreq_xpos);
            $fdisplay(f,"  YPOS        : %h",data_nocreq_ypos);
            $fdisplay(f,"  FBITS       : %h",data_nocreq_fbits);
            $fdisplay(f,"  Payload Len : %h",data_nocreq_payload);
            $fdisplay(f,"  Msg Type    : %h",data_nocreq_type);
            $fdisplay(f,"  TAG         : %h",data_nocreq_tag);
            $fdisplay(f,"  Options1    : %h",data_nocreq_opt1);
            $fdisplay(f,"  Address     : %h",data_nocreq_addr);
            $fdisplay(f,"  Options2    : %h",data_nocreq_opt2);
            $fdisplay(f,"  Last Bytes  : %h",data_nocreq_lastbytes);
            $fdisplay(f,"  SRC CHIPID  : %h",data_nocreq_srcchipid);
            $fdisplay(f,"  SRC XPOS    : %h",data_nocreq_srcxpos);
            $fdisplay(f,"  SRC YPOS    : %h",data_nocreq_srcypos);
            $fdisplay(f,"  SRC FBITS   : %h",data_nocreq_srcfbits);
            $fdisplay(f,"  Options3    : %h",data_nocreq_opt3);

            //TODO: print PUT data
            $fdisplay(f," ");
            id_nocreq   <= id_nocreq + 1;
        end

        flt_nocreq  <= 0;
    end

    //----------------------------------------------------------------//
    //  Collect & Print NOC Response data

    //Flit counter and data values
    //NOTE: NOC response = 1 flit of header, 0+ flits of data
    //NOTE: NOC Fields OPTIONS1, OPTIONS3 & OPTIONS4 are only for coherence requests/responses
    integer      id_nocrsp = 0;
    integer     flt_nocrsp = 0;
    reg [13:0] data_nocrsp_chipid;          // 63:50 - CHIPID
    reg [ 7:0] data_nocrsp_xpos;            // 49:42 - XPOS
    reg [ 7:0] data_nocrsp_ypos;            // 41:34 - YPOS
    reg [ 3:0] data_nocrsp_fbits;           // 33:30 - FBITS
    reg [ 7:0] data_nocrsp_payload;         // 29:22 - PAYLOAD LENGTH
    reg [ 7:0] data_nocrsp_type;            // 21:14 - MESSAGE TYPE
    reg [ 7:0] data_nocrsp_tag;             // 13:06 - MSHR/TAG
    reg [ 5:0] data_nocrsp_opt4;            // 05:00 - OPTIONS4
    reg [63:0] data_nocrsp_data [1023:0];   // Storage for response payload
    integer    data_nocrsp_cnt;             //

    //Collect data when NOC valid is asserted
    always @(posedge clk) begin
        @(negedge clk)
        if (reset_ & noc_out_valid) begin
            //$fdisplay(f,"~~Building NOC Response %0d (flit %0d): %h",id_nocrsp,flt_nocrsp,noc_out_data);
            if (flt_nocrsp == 0) begin
                data_nocrsp_chipid      <= noc_out_data[63:50];
                data_nocrsp_xpos        <= noc_out_data[49:42];
                data_nocrsp_ypos        <= noc_out_data[41:34];
                data_nocrsp_fbits       <= noc_out_data[33:30];
                data_nocrsp_payload     <= noc_out_data[29:22];
                data_nocrsp_type        <= noc_out_data[21:14];
                data_nocrsp_tag         <= noc_out_data[13:06];
                data_nocrsp_opt4        <= noc_out_data[05:00];
            end
            else begin
                data_nocrsp_data[flt_nocrsp-1]<= noc_out_data;
            end

            flt_nocrsp <= flt_nocrsp + 1;
        end
    end

    //Print values when NOC valid is deasserted
    always @(negedge noc_out_valid) begin
        if (reset_) begin
            $fdisplay(f,"--------------------------------");
            $fdisplay(f,"NOC Response %0d @ time %4d ns",id_nocrsp,$time);
            $fdisplay(f,"  CHIPID      : %h",data_nocrsp_chipid);
            $fdisplay(f,"  XPOS        : %h",data_nocrsp_xpos);
            $fdisplay(f,"  YPOS        : %h",data_nocrsp_ypos);
            $fdisplay(f,"  FBITS       : %h",data_nocrsp_fbits);
            $fdisplay(f,"  Payload Len : %h",data_nocrsp_payload);
            $fdisplay(f,"  Msg Type    : %h",data_nocrsp_type);
            $fdisplay(f,"  TAG         : %h",data_nocrsp_tag);
            $fdisplay(f,"  Options1    : %h",data_nocrsp_opt4);

            if (flt_nocrsp > 1) begin
                $fdisplay(f,"  Data");
                for (data_nocrsp_cnt=0; data_nocrsp_cnt < flt_nocrsp-1; data_nocrsp_cnt = data_nocrsp_cnt + 1) begin
                    $fdisplay(f,"    %h",data_nocrsp_data[data_nocrsp_cnt]);
                end
            end

            $fdisplay(f," ");
            id_nocrsp  <= id_nocrsp + 1;
        end
        flt_nocrsp  <= 0;
    end


    //----------------------------------------------------------------//
    //  Collect & Print TileLink Request data

    //Flit counter and data values
    integer      id_tlreq  = 0;
    integer     flt_tlreq = 0;
    reg [47:0] data_tlreq_dmac;             // F1 47:0              - Destination MAC
    reg [47:0] data_tlreq_smac;             // F1 63:48, F2 31:0    - Source MAC
    reg [15:0] data_tlreq_ether;            // F2 47:32             - Ether Type
    reg [63:0] data_tlreq_tloe;             // F2 63:48, F3 47:0    - TLoE Header
    reg [63:0] data_tlreq_tl0;              // F3 63:48, F4 47:0    - TL message QW0
  //reg [63:0] data_tlreq_tl1;              // F4 63:48, F5 47:0    - TL message QW1
    reg [63:0] data_tlreq_data [1023:0];    // Storage for remaining message data
    integer    data_tlreq_cnt;              //

    //Collect data when TLoE valid is asserted
    always @(posedge clk) begin
        @(negedge clk)
        if (reset_ & sfp_axis_rx_0_tvalid) begin
            //$fdisplay(f,"~~Building TL Request %0d (flit %0d): %h",id_tlreq,flt_tlreq,sfp_axis_rx_0_tdata);
            case (flt_tlreq)
                0: begin
                    data_tlreq_dmac         <= sfp_axis_rx_0_tdata[47:0 ];
                    data_tlreq_smac [15:0 ] <= sfp_axis_rx_0_tdata[63:48];
                end
                1: begin
                    data_tlreq_smac [47:16] <= sfp_axis_rx_0_tdata[31:0];
                    data_tlreq_ether        <= sfp_axis_rx_0_tdata[47:32];
                    data_tlreq_tloe [63:48] <= swap2(sfp_axis_rx_0_tdata[63:48]);
                end
                2: begin
                    data_tlreq_tloe [47:0 ] <= swap6(sfp_axis_rx_0_tdata[47:0 ]);
                    data_tlreq_tl0  [63:48] <= swap2(sfp_axis_rx_0_tdata[63:48]);
                end
                3: begin
                    data_tlreq_tl0  [47:0 ] <= swap6(sfp_axis_rx_0_tdata[47:0 ]);
                    data_tlreq_data[0][63:48]<= swap2(sfp_axis_rx_0_tdata[63:48]);
                end
                default: begin
                    data_tlreq_data[flt_tlreq-4][47:0 ] <= swap6(sfp_axis_rx_0_tdata[47:0 ]);
                    data_tlreq_data[flt_tlreq-3][63:48] <= swap2(sfp_axis_rx_0_tdata[63:48]);
                end
            endcase

            flt_tlreq <= flt_tlreq + 1;
        end
    end

    //Print values when TLoE valid is deasserted
    always @(negedge sfp_axis_rx_0_tlast) begin    //negedge sfp_axis_rx_0_tvalid
        if (reset_ && !(data_tlreq_tl0[59:57] == 3'b0 & PRINT_SKIPNOP)) begin
            if (data_tlreq_tl0[59:57] == 3'b0) $fdisplay(f,"NOP Frame");
            $fdisplay(f,"--------------------------------");
            $fdisplay(f,"TileLink Request %0d @ time %4d ns",id_tlreq,$time);
            $fdisplay(f,"  Dst MAC     : %h",data_tlreq_dmac);
            $fdisplay(f,"  Src MAC     : %h",data_tlreq_smac);
            $fdisplay(f,"  Ether Type  : %h",data_tlreq_ether);
            $fdisplay(f,"  TLoE Head   : %h",data_tlreq_tloe);
            $fdisplay(f,"   -Credit    : %h",data_tlreq_tloe[4:0]);
            $fdisplay(f,"   -Channel   : %h",data_tlreq_tloe[7:5]);
            $fdisplay(f,"   -Rsrvd     : %h",data_tlreq_tloe[8]);
            $fdisplay(f,"   -Ack       : %h",data_tlreq_tloe[9]);
            $fdisplay(f,"   -Seq# Ack  : %h",data_tlreq_tloe[31:10]);
            $fdisplay(f,"   -Seq#      : %h",data_tlreq_tloe[53:32]);
            $fdisplay(f,"   -Rsrvd     : %h",data_tlreq_tloe[60:54]);
            $fdisplay(f,"   -V.Channel : %h",data_tlreq_tloe[63:61]);

            $fdisplay(f,"  TL0         : %h",data_tlreq_tl0);
            $fdisplay(f,"   -Source    : %h",data_tlreq_tl0[25:0]);
            $fdisplay(f,"   -Rsrvd     : %h",data_tlreq_tl0[37:26]);
            $fdisplay(f,"   -Error     : %h",data_tlreq_tl0[39:38]);
            $fdisplay(f,"   -Domain    : %h",data_tlreq_tl0[47:40]);
            $fdisplay(f,"   -Size      : %h",data_tlreq_tl0[51:48]);
            $fdisplay(f,"   -Param     : %h",data_tlreq_tl0[55:52]);
            $fdisplay(f,"   -R         : %h",data_tlreq_tl0[56]);
            $fdisplay(f,"   -Opcode    : %h",data_tlreq_tl0[59:57]);
            $fdisplay(f,"   -Channel   : %h",data_tlreq_tl0[62:60]);
            $fdisplay(f,"   -R         : %h",data_tlreq_tl0[63]);

            if (flt_tlreq > 4) begin
                $fdisplay(f,"  TL1+, TLoE Mask");
                for (data_tlreq_cnt=0; data_tlreq_cnt < flt_tlreq-4; data_tlreq_cnt = data_tlreq_cnt + 1) begin
                    $fdisplay(f,"    %h",data_tlreq_data[data_tlreq_cnt]);
                end
            end

            $fdisplay(f," ");
            id_tlreq   <= id_tlreq  + 1;
        end
        flt_tlreq   <= 0;
    end


    //----------------------------------------------------------------//
    //  Collect & Print TileLink response data

    //Flit counter and data values
    integer      id_tlrsp  = 0;
    integer     flt_tlrsp = 0;
    reg [47:0] data_tlrsp_dmac;             // F1 47:0              - Destination MAC
    reg [47:0] data_tlrsp_smac;             // F1 63:48, F2 31:0    - Source MAC
    reg [15:0] data_tlrsp_ether;            // F2 47:32             - Ether Type
    reg [63:0] data_tlrsp_tloe;             // F2 63:48, F3 47:0    - TLoE Header
    reg [63:0] data_tlrsp_tl0;              // F3 63:48, F4 47:0    - TL message QW0
    reg [63:0] data_tlrsp_data [1023:0];    // Storage for remaining message data
    integer    data_tlrsp_cnt;              //

    //Collect data when TLoE valid is asserted
    always @(posedge clk) begin
        @(negedge clk)
        if (reset_ & axi_in_valid) begin
            $fdisplay(f,"~~Building TL Response %0d (flit %0d): %h",id_tlrsp,flt_tlrsp,axi_in_data);
            case (flt_tlrsp)
                0: begin
                    data_tlrsp_dmac         <= axi_in_data[47:0 ];
                    data_tlrsp_smac [15:0 ] <= axi_in_data[63:48];
                end
                1: begin
                    data_tlrsp_smac [47:16] <= axi_in_data[31:0];
                    data_tlrsp_ether        <= axi_in_data[47:32];
                    data_tlrsp_tloe [63:48] <= swap2(axi_in_data[63:48]);
                end
                2: begin
                    data_tlrsp_tloe [47:0 ] <= swap6(axi_in_data[47:0 ]);
                    data_tlrsp_tl0  [63:48] <= swap2(axi_in_data[63:48]);
                end
                3: begin
                    data_tlrsp_tl0  [47:0 ] <= swap6(axi_in_data[47:0 ]);
                    data_tlrsp_data[0][63:48]<= swap2(axi_in_data[63:48]);
                end
                default: begin
                    data_tlrsp_data[flt_tlrsp-4][47:0 ] <= swap6(axi_in_data[47:0 ]);
                    data_tlrsp_data[flt_tlrsp-3][63:48] <= swap2(axi_in_data[63:48]);
                end
            endcase

            flt_tlrsp <= flt_tlrsp + 1;
        end
    end

    //Print values when TLoE valid is deasserted
    always @(negedge axi_in_last) begin
        //AXIS signals from the endpoint misbehave, so make sure there is actual data before printing
        //  ('last' gets instantaneously asserted and deasserted any time 'valid' is asserted)
        if (flt_tlrsp) begin
            if (reset_ && !(data_tlrsp_tl0[59:57] == 3'b0 & PRINT_SKIPNOP)) begin
                if (data_tlrsp_tl0[59:57] == 3'b0) $fdisplay(f,"NOP Frame");
                $fdisplay(f,"--------------------------------");
                $fdisplay(f,"TileLink Response %0d @ time %4d ns",id_tlrsp,$time);
                $fdisplay(f,"  Dst MAC     : %h",data_tlrsp_dmac);
                $fdisplay(f,"  Src MAC     : %h",data_tlrsp_smac);
                $fdisplay(f,"  Ether Type  : %h",data_tlrsp_ether);
                $fdisplay(f,"  TLoE Head   : %h",data_tlrsp_tloe);
                $fdisplay(f,"   -Credit    : %h",data_tlrsp_tloe[4:0]);
                $fdisplay(f,"   -Channel   : %h",data_tlrsp_tloe[7:5]);
                $fdisplay(f,"   -Rsrvd     : %h",data_tlrsp_tloe[8]);
                $fdisplay(f,"   -Ack       : %h",data_tlrsp_tloe[9]);
                $fdisplay(f,"   -Seq# Ack  : %h",data_tlrsp_tloe[31:10]);
                $fdisplay(f,"   -Seq#      : %h",data_tlrsp_tloe[53:32]);
                $fdisplay(f,"   -Rsrvd     : %h",data_tlrsp_tloe[60:54]);
                $fdisplay(f,"   -V.Channel : %h",data_tlrsp_tloe[63:61]);
            
                $fdisplay(f,"  TL0         : %h",data_tlrsp_tl0);
                $fdisplay(f,"   -Source    : %h",data_tlrsp_tl0[25:0]);
                $fdisplay(f,"   -Rsrvd     : %h",data_tlrsp_tl0[37:26]);
                $fdisplay(f,"   -Error     : %h",data_tlrsp_tl0[39:38]);
                $fdisplay(f,"   -Domain    : %h",data_tlrsp_tl0[47:40]);
                $fdisplay(f,"   -Size      : %h",data_tlrsp_tl0[51:48]);
                $fdisplay(f,"   -Param     : %h",data_tlrsp_tl0[55:52]);
                $fdisplay(f,"   -R         : %h",data_tlrsp_tl0[56]);
                $fdisplay(f,"   -Opcode    : %h",data_tlrsp_tl0[59:57]);
                $fdisplay(f,"   -Channel   : %h",data_tlrsp_tl0[62:60]);
                $fdisplay(f,"   -R         : %h",data_tlrsp_tl0[63]);
            
                if (flt_tlrsp > 4) begin
                    $fdisplay(f,"  TL1+, TLoE Mask");
                    for (data_tlrsp_cnt=0; data_tlrsp_cnt < flt_tlrsp-4; data_tlrsp_cnt = data_tlrsp_cnt + 1) begin
                        $fdisplay(f,"    %h",data_tlrsp_data[data_tlrsp_cnt]);
                    end
                end
            
                $fdisplay(f," ");
                id_tlrsp   <= id_tlrsp  + 1;
            end
            flt_tlrsp   <= 0;
        end
    end


    //================================================================//
    //  Auto-NoC

    integer i;

    //Automatically Issue NoC commands using NOC_MASTER
    //  Requires all contained commands to be uniform in size
    initial begin
        if (autonoc_en) begin
            //Wait for reset deassertion
            @ (posedge reset_);
            #100;

            //Issue the specified number of commands
            for (i=0; i<autonoc_cnt; i=i+1) begin
                gen_en          <= 1;
                pkt_gen_addr    <= i*autonoc_size;
                pkt_gen_cnt     <= autonoc_size;
                #10;
                gen_en          <= 0;
                pkt_gen_addr    <= 0;
                pkt_gen_cnt     <= 0;
                #400;
            end

            //Wait for all responses to come in, then close output file and finish
            #1000
            file_close = 1;
            #10
            $finish;
        end
    end


    //================================================================//
    //  Handy Functions

    //Swap endianness of a 2 byte value
    function [15:0] swap2(input [15:0] value);
        swap2 = {value[7:0],value[15:8]};
    endfunction

    //Swap endianness of a 4 byte value
    function [31:0] swap4(input [31:0] value);
        swap4 = {value[7:0],value[15:8],value[23:16],value[31:24]};
    endfunction

    //Swap endianness of a 6 byte value
    function [47:0] swap6(input [47:0] value);
        swap6 = {value[7:0],value[15:8],value[23:16],value[31:24],value[39:32],value[47:40]};
    endfunction

endmodule
