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



module M2OX
    #(
        parameter RX_HEADER_PTR     =13,
        parameter RX_ADDR_PTR       =13,
        parameter RX_MASK_PTR       =13,
        parameter RX_DATA_PTR       =14,
        parameter RX_BCNT_PTR       =13)
    (
        input                           clk                         ,
        input                           rst_                        ,

        //In from LMAC RX FIFOs (IPCS & Packet)
        input       [63:0]              m2ox_rx_ipcs_data           ,
        input                           m2ox_rx_ipcs_empty          ,
        input       [6:0]               m2ox_rx_ipcs_usedword       ,
        output                          ox2m_rx_ipcs_rden           ,

        input       [255:0]             m2ox_rx_pkt_data            ,
        input                           m2ox_rx_pkt_empty           ,
        input       [6:0]               m2ox_rx_pkt_usedword        ,
        output                          ox2m_rx_pkt_rden            ,
        output                          ox2m_rx_pkt_rd_cycle        ,

        //--------------------------------//

        //RX Header FIFO Out
        output      [63:0]              ox2f_rx_header_i            ,
        output                          ox2f_rx_header_we_i         ,
        input                           f2ox_rx_header_full_i       ,
        input       [RX_HEADER_PTR-1:0] f2ox_rx_header_wrusedw_i    ,

        //RX Address FIFO Out
        output      [63:0]              ox2f_rx_addr_i              ,
        output                          ox2f_rx_addr_we_i           ,
        input                           f2ox_rx_addr_full_i         ,
        input       [RX_ADDR_PTR-1:0]   f2ox_rx_addr_wrusedw_i      ,

        //RX Mask FIFO Out
        output      [63:0]              ox2f_rx_mask_i              ,
        output                          ox2f_rx_mask_we_i           ,
        input                           f2ox_rx_mask_full_i         ,
        input       [RX_MASK_PTR-1:0]   f2ox_rx_mask_wrusedw_i      ,

        // RX Data FIFO Out
        output      [255:0]             ox2f_rx_data_i              ,
        output                          ox2f_rx_data_we_i           ,
        input                           f2ox_rx_data_full_i         ,
        input       [RX_DATA_PTR-1:0]   f2ox_rx_data_wrusedw_i      ,

        // RX Bcnt FIFO Out
        output      [15:0]              ox2f_rx_bcnt_i              ,
        output                          ox2f_rx_bcnt_we_i           ,
        input                           f2ox_rx_bcnt_full_i         ,
        input       [RX_BCNT_PTR-1:0]   f2ox_rx_bcnt_wrusedw_i      ,

        //--------------------------------//

        //Sequence Checking  Requests to Seq_Mgr
        output     [21:0]               oxm2ackm_new_ack_num,   // Remote ack num from RXed packet
        output     [21:0]               oxm2ackm_new_seq_num,   // Remote seq num from RXed packet
        output reg                      oxm2ackm_chk_req,       // Asserted to request a sequence check
        output                          oxm2ackm_ack,           // Remote ack mode from RXed packet (ack = 1, nack = 0)
        output                          rx_done,                // Asserted when we have finished RXing current packet
        input                           oxm2ackm_accept,        // Accept the current received packet or not (1 = accept 0 = reject)
        input                           oxm2ackm_done,          // Asserted by seq_mgr when sequence check is done
        input                           oxm2ackm_busy,          

        //--------------------------------//

        output reg                      oxm_rtx_done,           // control signal for ProbeBlock to RTX_MGR

        //--------------------------------//

        //Coherency Signals to TL2N (to diff acquire and release)
        output reg                      ox2tl_aquire_gnt,       // Tells TL this is an acquire gnt response
        output reg                      ox2tl_release_ack,      // Tells TL this is a release ack response
        output reg                      ox2tl_acc_ack,          // Tells TL this is a Get acc response with no data
        output reg                      ox2tl_acc_ack_data,     // Tells TL this is a Put acc response with data
        output reg                      ox2tl_probe
    );


    //================================================================//
    //  Convenience Parameters

    //TL MSG Channel
    localparam          TL_CHAN_A       =   3'b001,
                        TL_CHAN_B       =   3'b010,
                        TL_CHAN_C       =   3'b011,
                        TL_CHAN_D       =   3'b100,
                        TL_CHAN_E       =   3'b101;


    //Channel B Opcode
    localparam          B_PUT_FULL      =   3'd0,
                        B_PUT_PARTIAL   =   3'd1,
                        B_ARITHMETIC    =   3'd2,
                        B_LOGICAL       =   3'd3,
                        B_GET           =   3'd4,
                        B_INTENT        =   3'd5,
                        B_PROBE_BLOCK   =   3'd6,
                        B_PROBE_PERM    =   3'd7;

    //Channel D Opcode
    localparam          D_ACC_ACK       =   3'd0,
                        D_ACC_ACK_DATA  =   3'd1,
                        D_HINT_ACK      =   3'd2,
                        D_GRANT         =   3'd4,
                        D_GRANT_DATA    =   3'd5,
                        D_RELEASE_ACK   =   3'd6;


    //================================================================//
    //  State Machine Encoding and State Signals

    reg [15:0]      rx_state;
    localparam      RX_IDLE         =   16'h01,
                    RX_IPCS         =   16'h02,
                    RX_PKT_RD_1     =   16'h04,
                    RX_DECODE_1     =   16'h08,
                    RX_PKT_RD_2     =   16'h10,
                    RX_DECODE_2     =   16'h20,
                    RX_DONE         =   16'h40,
                    RX_DONE_1       =   16'h80,
                    RX_DONE_2       =   16'h100;

    wire            rx_idle_st      =   rx_state[0];
    wire            rx_ipcs_st      =   rx_state[1];
    wire            rx_pkt_rd_1_st  =   rx_state[2];    // gather info for opcode and channel
    wire            rx_decode_1_st  =   rx_state[3];    // gather info for address and data mask, calculate lewiz reserved
    wire            rx_pkt_rd_2_st  =   rx_state[4];    // gather info for address and data mask, calculate lewiz reserved
    wire            rx_decode_2_st  =   rx_state[5];
    wire            rx_done_st      =   rx_state[6];
    wire            rx_done_1_st    =   rx_state[7];
    wire            rx_done_2_st    =   rx_state[8];

//  wire            rx_idle_st      =   rx_state[0];
//  wire            rx_rd_fifo      =   rx_state[1];
//  wire            rx_ipcs_st      =   rx_state[2];
//  wire            rx_pkt_rd_st    =   rx_state[3];    // gather info for opcode and channel
//  wire            rx_decode_1_st  =   rx_state[4];    // gather info for address and data mask, calculate lewiz reserved
//  wire            rx_decode_2_st  =   rx_state[5];
//  wire            rx_done_st      =   rx_state[6];


    //================================================================//
    //  Other Internal Signals


    reg  [15:0]     bcnt4mask ;                          // sub 8 byte for each data out, use for mask

    //LMAC Byte Count Field (LeWiz Reserved)
    reg  [15:0]     lewiz_bcnt;

    //Pkt Data Buffer
    reg  [255:0]    rx_pkt_data_buf;

    //TLoE Frame Header
    wire [63:0]     tloe_frame_header;
    reg  [2:0]      tloe_header_chan;
    reg  [4:0]      tloe_header_credit;
    reg             tloe_header_ack;
    reg  [21:0]     tloe_header_seq_num_ack;
    reg  [21:0]     tloe_header_seq_num;
    reg  [2:0]      tloe_header_vc;

    assign          tloe_frame_header   =   rx_decode_1_st ?   {
                                                rx_pkt_data_buf[119:112],
                                                rx_pkt_data_buf[127:120],
                                                rx_pkt_data_buf[135:128],
                                                rx_pkt_data_buf[143:136],
                                                rx_pkt_data_buf[151:144],
                                                rx_pkt_data_buf[159:152],
                                                rx_pkt_data_buf[167:160],
                                                rx_pkt_data_buf[175:168]
                                            } :   'd0;

    //Data and Write Enable to OX FIFOs
    reg  [255:0]    ox2f_rx_data_out;
    reg             ox2f_rx_data_valid;
    reg  [63:0]     ox2f_rx_header_out;
    reg             ox2f_rx_header_valid;
    reg  [63:0]     ox2f_rx_addr_out;
    reg             ox2f_rx_addr_valid;
    reg  [63:0]     ox2f_rx_mask_out;
    reg             ox2f_rx_mask_valid;
    reg  [15:0]     ox2f_rx_bcnt_out;
    reg             ox2f_rx_bcnt_valid;

    //  oxm2ackm
    reg             oxm2ackm_accepted;  // 1 = accept pkt, 0 = reject pkt;


    //----------------------------------------------------------------//
    // Channel B TL Msg Header Data

    reg  [63:0]     b_tl_msg_header;
    reg  [63:0]     b_tl_msg_addr;
    reg             b_chan_en;
    reg             b_data_en;
    reg  [255:0]    b_data_buf;
//  reg  [25:0]     b_source;           // {TAG, DST_CHIPID}
//  reg  [3:0]      b_size;             // PAYLOAD_LENGTH
//  reg  [2:0]      b_opcode;           // MSG_TYPE
//  reg             b_chan;             // Channel
//  reg  [3:0]      b_param;            // zero for now
//  reg  [255:0]    b_data;             //{DATA_4, DATA_3, DATA_2, DATA_1}
//  reg             b_corrupt;
//  reg  [63:0]     b_mask;             // Based on PAYLOAD_LENGTH
//  reg  [63:0]     b_addr;             //{DST_XPOS, DST_YPOST, DST_ADDR}
//  reg  [7:0]      b_domain;           // all zero
//  reg  [3:0]      b_size_left;


    //----------------------------------------------------------------//
    // Channel D TL Msg Header Data
    reg  [63:0]     d_tl_msg_header;
    reg  [63:0]     d_tl_msg_sink;
    reg             d_chan_en;
    reg             d_data_en;          // if Channel D comes with data, assigned during RX_DECODE_1 and neg at RX_DONE
    reg             d_sink_en;
    reg  [255:0]    d_data_buf;
//  reg  [25:0]     d_source;           // {TAG, DST_CHIPID}
//  reg  [3:0]      d_size;             // PAYLOAD_LENGTH
//  reg  [2:0]      d_opcode;           // MSG_TYPE
//  reg             d_chan;             // Channel
//  reg  [3:0]      d_param;            // zero for now
//  reg  [255:0]    d_data;             //{DATA_4, DATA_3, DATA_2, DATA_1}
//  reg             d_corrupt;
//  reg  [25:0]     d_sink;             //Slave sink identifier
//  reg             d_denied;           //Slave unable to service the request
//  reg  [7:0]      d_domain;           // all zero

    wire [3:0]      d_size  =   d_tl_msg_header[51:48];    //d_size

    //================================================================//
    //  Output Signal Assignments


    //LMAC IPCS FIFO Read Enable: assert in Idle state if not empty and seq_mgr not busy
    assign          ox2m_rx_ipcs_rden   =   (rx_idle_st && !m2ox_rx_ipcs_empty && !oxm2ackm_busy) ? 1'b1 : 1'b0;

    //LMAC Packet FIFO Read Enable: assert in IPCS state if not empty, or if bytes left to write and seq_mgr check is done
    assign          ox2m_rx_pkt_rden    =   (rx_ipcs_st && !m2ox_rx_pkt_empty)       ? 1'b1 :
                                            ((lewiz_bcnt != 16'd0) && oxm2ackm_done) ? 1'b1 :
                                            1'b0;

    assign          ox2m_rx_pkt_rd_cycle=   1'b0;


    //RX Header FIFO
    assign          ox2f_rx_header_we_i =   ox2f_rx_header_valid;
    assign          ox2f_rx_header_i    =   ox2f_rx_header_out  ;

    //RX Address FIFO
    assign          ox2f_rx_addr_we_i   =   ox2f_rx_addr_valid  ;
    assign          ox2f_rx_addr_i      =   ox2f_rx_addr_out    ;

    //RX Mask FIFO
    assign          ox2f_rx_mask_we_i   =   ox2f_rx_mask_valid  ;
    assign          ox2f_rx_mask_i      =   ox2f_rx_mask_out    ;

    //RX Data FIFO
    assign          ox2f_rx_data_we_i   =   ox2f_rx_data_valid  ;
    assign          ox2f_rx_data_i      =   ox2f_rx_data_out    ;

    //RX Bcnt FIFO
    assign          ox2f_rx_bcnt_we_i   =   ox2f_rx_bcnt_valid  ;
    assign          ox2f_rx_bcnt_i      =   ox2f_rx_bcnt_out    ;


    assign          oxm2ackm_ack        =   tloe_header_ack;
    assign          oxm2ackm_new_ack_num=   tloe_header_seq_num_ack;
    assign          oxm2ackm_new_seq_num=   tloe_header_seq_num;


    assign          rx_done = rx_done_st;   //Assert done while in Done State



    //================================================================//
    //  RX State Machine

    //Next State Logic
    always @(posedge clk) begin
        if (!rst_) begin
            rx_state    <=  RX_IDLE;
        end else begin
            if (rx_idle_st) begin
                rx_state    <=  !oxm2ackm_busy && (!m2ox_rx_ipcs_empty && !m2ox_rx_pkt_empty && !(f2ox_rx_header_full_i || f2ox_rx_addr_full_i || f2ox_rx_mask_full_i || f2ox_rx_data_full_i || f2ox_rx_bcnt_full_i))
                                 ?     RX_IPCS     :   RX_IDLE;
            end

            if (rx_ipcs_st) begin
                rx_state    <=  !m2ox_rx_pkt_empty     ?     RX_PKT_RD_1     :   RX_IDLE;
            end

            if (rx_pkt_rd_1_st) begin
                rx_state    <=  RX_DECODE_1;
            end

            //Decode 1 State: Stay here until Sequence manager has finished checking Seq #s
            if (rx_decode_1_st) begin
                rx_state    <=  oxm2ackm_done   ?   RX_PKT_RD_2   :   RX_DECODE_1;
            end

            if (rx_pkt_rd_2_st) begin
                rx_state    <=  RX_DECODE_2;
            end

            if (rx_decode_2_st) begin
                rx_state    <=  (lewiz_bcnt <= 16'd32) ? RX_DONE : RX_DECODE_2;
            end

            if (rx_done_st) begin
                rx_state    <=  RX_DONE_1;
            end

            if (rx_done_1_st) begin
                rx_state    <=  RX_DONE_2 ;
            end

            if(rx_done_2_st) begin
                rx_state    <=  RX_IDLE ;
            end

        end // else
    end // always

    //Data Control Logic (reading, decoding and writing)
    always @(posedge clk) begin
        if  (!rst_) begin
            lewiz_bcnt                  <=  16'b0;
            tloe_header_chan            <=  'b0;
            tloe_header_credit          <=  'b0;
            tloe_header_ack             <=  'b0;
            tloe_header_seq_num_ack     <=  'b0;
            tloe_header_seq_num         <=  'b0;
            tloe_header_vc              <=  'b0;
            ox2f_rx_data_out            <=  'b0;
            ox2f_rx_data_valid          <=  'b0;
            ox2f_rx_header_out          <=  'b0;
            ox2f_rx_header_valid        <=  'b0;
            ox2f_rx_addr_out            <=  'b0;
            ox2f_rx_addr_valid          <=  'b0;
            ox2f_rx_mask_out            <=  'b0;
            ox2f_rx_mask_valid          <=  'b0;
            ox2f_rx_bcnt_out            <=  'b0;
            ox2f_rx_bcnt_valid          <=  'b0;
            rx_pkt_data_buf             <=  'b0;
            oxm2ackm_chk_req            <=  'b0;
            oxm2ackm_accepted           <=  'b0;
            oxm_rtx_done                <=  'b0;
            bcnt4mask                   <=  16'b0;
        end
        else begin
            case (rx_state)

                //Idle State: Reset Internal Registers
                RX_IDLE: begin
                    lewiz_bcnt                  <=  16'b0;
                    tloe_header_chan            <=    'b0;
                    tloe_header_credit          <=    'b0;
                    tloe_header_ack             <=    'b0;
                    tloe_header_seq_num_ack     <=    'b0;
                    tloe_header_seq_num         <=    'b0;
                    tloe_header_vc              <=    'b0;
                    ox2f_rx_data_out            <=    'b0;
                    ox2f_rx_data_valid          <=    'b0;
                    ox2f_rx_header_out          <=    'b0;
                    ox2f_rx_header_valid        <=    'b0;
                    ox2f_rx_addr_out            <=    'b0;
                    ox2f_rx_addr_valid          <=    'b0;
                    ox2f_rx_mask_out            <=    'b0;
                    ox2f_rx_mask_valid          <=    'b0;
                    ox2f_rx_bcnt_valid          <=    'b0;
                    ox2f_rx_bcnt_out            <=    'b0;
                    rx_pkt_data_buf             <=    'b0;
                    oxm2ackm_chk_req            <=    'b0;
                    oxm2ackm_accepted           <=    'b0;
                    oxm_rtx_done                <=    'b0;
                    bcnt4mask                   <=  16'b0;
                end

                //IPCS State: Store packet byte count
                RX_IPCS: begin
                  //lewiz_bcnt                  <=  m2ox_rx_ipcs_data[63:48];
                  //ox2f_rx_bcnt_out            <=  m2ox_rx_ipcs_data[63:48];
                    lewiz_bcnt                  <=  m2ox_rx_ipcs_data[15:0];
                    ox2f_rx_bcnt_out            <=  m2ox_rx_ipcs_data[15:0];
                end

                //Packet Read 1 State: Store first data QQWord and assert sequence check request to seq_mgr
                RX_PKT_RD_1: begin
                    rx_pkt_data_buf             <=  m2ox_rx_pkt_data;           // Buffer first QQWord
                  //lewiz_bcnt                  <=  lewiz_bcnt - 16'd32;
                    lewiz_bcnt                  <=  (lewiz_bcnt <=16'd32)        ? 0 : (lewiz_bcnt - 16'd32);
                    ox2f_rx_bcnt_out            <=  (ox2f_rx_bcnt_out <= 'd38)   ? 0: (ox2f_rx_bcnt_out - 'd38);    // 14B Ethernet Header, 8B TloE Header, 8B TL Msg Header, 8B TLoE Frame Mask
                    oxm2ackm_chk_req            <=  1'b1;
                end

                //Decode 1 State: Decode TLoE frame header and wait for Sequence Manager to check Seq #
                RX_DECODE_1: begin
                    oxm2ackm_chk_req            <=  !oxm2ackm_done;
                    tloe_header_chan            <=  rx_pkt_data_buf[182:180];
                  //tloe_header_chan            <=  tloe_frame_header[7:5];
                    tloe_header_credit          <=  tloe_frame_header[4:0];
                    tloe_header_ack             <=  tloe_frame_header[9];
                    tloe_header_seq_num_ack     <=  tloe_frame_header[31:10];
                    tloe_header_seq_num         <=  tloe_frame_header[53:32];
                    tloe_header_vc              <=  tloe_frame_header[63:61];

                    rx_pkt_data_buf             <=  m2ox_rx_pkt_data;

                    //Decrement bytes left to process count when leaving state
                    lewiz_bcnt                  <=  oxm2ackm_done ?
                                                    ////(rx_pkt_data_buf[179:177] ==    D_GRANT) || (rx_pkt_data_buf[179:177] ==    D_GRANT_DATA)   ?
                                                    ////(lewiz_bcnt < 16'd40)   ?   16'd0   :   lewiz_bcnt - 16'd40 :
                                                        (lewiz_bcnt < 16'd32)   ?   16'd0   :   lewiz_bcnt - 16'd32 :
                                                    lewiz_bcnt;

                    //Decrement output byte count when leaving state if message is D_GRANT or D_GRANT_DATA
                    ox2f_rx_bcnt_out            <=  oxm2ackm_done ?
                                                    ((rx_pkt_data_buf[179:177] ==    D_GRANT         ||    rx_pkt_data_buf[179:177] ==    D_GRANT_DATA) ?
                                                    ox2f_rx_bcnt_out - 'd8  :   ox2f_rx_bcnt_out  ) :
                                                    ox2f_rx_bcnt_out;


                  //bcnt4mask                   <= ox2f_rx_bcnt_out;

                  //case(ox2f_rx_bcnt_out)
                  //    8'd64: ox2f_rx_mask_out <= 64'b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd63: ox2f_rx_mask_out <= 64'b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd62: ox2f_rx_mask_out <= 64'b0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd61: ox2f_rx_mask_out <= 64'b0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd60: ox2f_rx_mask_out <= 64'b0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd59: ox2f_rx_mask_out <= 64'b0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd58: ox2f_rx_mask_out <= 64'b0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd57: ox2f_rx_mask_out <= 64'b0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd56: ox2f_rx_mask_out <= 64'b0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd55: ox2f_rx_mask_out <= 64'b0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd54: ox2f_rx_mask_out <= 64'b0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd53: ox2f_rx_mask_out <= 64'b0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd52: ox2f_rx_mask_out <= 64'b0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd51: ox2f_rx_mask_out <= 64'b0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd50: ox2f_rx_mask_out <= 64'b0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd49: ox2f_rx_mask_out <= 64'b0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd48: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd47: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd46: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd45: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd44: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd43: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd42: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd41: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd40: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd39: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd38: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd37: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd36: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd35: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd34: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd33: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd32: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd31: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd30: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd29: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd28: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd27: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111 ;
                  //    8'd26: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111 ;
                  //    8'd25: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111 ;
                  //    8'd24: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd23: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111 ;
                  //    8'd22: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111 ;
                  //    8'd21: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111 ;
                  //    8'd20: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111 ;
                  //
                  //    8'd19: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111 ;
                  //    8'd18: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111 ;
                  //    8'd17: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111 ;
                  //    8'd16: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111 ;
                  //
                  //    8'd15: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111 ;
                  //    8'd14: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111 ;
                  //    8'd13: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111 ;
                  //    8'd12: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111 ;
                  //
                  //    8'd11: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111 ;
                  //    8'd10: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111 ;
                  //    8'd09: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111 ;
                  //    8'd08: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111 ;
                  //
                  //    8'd07: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111 ;
                  //    8'd06: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111 ;
                  //    8'd05: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111 ;
                  //    8'd04: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111 ;
                  //
                  //    8'd03: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111 ;
                  //    8'd02: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011 ;
                  //    8'd01: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001 ;
                  //endcase
                end

                //Packet Read 2 State: Store second QQWord and calculate data mask
                RX_PKT_RD_2: begin
                        rx_pkt_data_buf             <=  m2ox_rx_pkt_data;                                                   // Buffer second QQWord
                        lewiz_bcnt                  <=  lewiz_bcnt  < 16'd32    ?   'd0 :   lewiz_bcnt - 16'd32;

                        case(ox2f_rx_bcnt_out)
                            8'd64: ox2f_rx_mask_out <= 64'b1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd63: ox2f_rx_mask_out <= 64'b0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd62: ox2f_rx_mask_out <= 64'b0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd61: ox2f_rx_mask_out <= 64'b0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd60: ox2f_rx_mask_out <= 64'b0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd59: ox2f_rx_mask_out <= 64'b0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd58: ox2f_rx_mask_out <= 64'b0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd57: ox2f_rx_mask_out <= 64'b0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd56: ox2f_rx_mask_out <= 64'b0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd55: ox2f_rx_mask_out <= 64'b0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd54: ox2f_rx_mask_out <= 64'b0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd53: ox2f_rx_mask_out <= 64'b0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd52: ox2f_rx_mask_out <= 64'b0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd51: ox2f_rx_mask_out <= 64'b0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd50: ox2f_rx_mask_out <= 64'b0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd49: ox2f_rx_mask_out <= 64'b0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd48: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd47: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd46: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd45: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd44: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd43: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd42: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd41: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd40: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd39: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd38: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd37: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd36: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd35: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd34: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd33: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd32: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd31: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd30: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd29: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111_1111 ;
                            8'd28: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111_1111 ;

                            8'd27: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111_1111 ;
                            8'd26: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111_1111 ;
                            8'd25: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111_1111 ;
                            8'd24: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111_1111 ;

                            8'd23: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111_1111 ;
                            8'd22: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111_1111 ;
                            8'd21: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111_1111 ;
                            8'd20: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111_1111 ;

                            8'd19: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111_1111 ;
                            8'd18: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111_1111 ;
                            8'd17: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111_1111 ;
                            8'd16: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111_1111 ;

                            8'd15: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111_1111 ;
                            8'd14: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111_1111 ;
                            8'd13: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111_1111 ;
                            8'd12: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111_1111 ;

                            8'd11: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111_1111 ;
                            8'd10: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111_1111 ;
                            8'd09: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111_1111 ;
                            8'd08: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111_1111 ;

                            8'd07: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111_1111 ;
                            8'd06: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011_1111 ;
                            8'd05: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001_1111 ;
                            8'd04: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_1111 ;

                            8'd03: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0111 ;
                            8'd02: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0011 ;
                            8'd01: ox2f_rx_mask_out <= 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0001 ;
                        endcase

                end

                //Decode 2 State: Keep reading in data (while data is left) and output it to appropriate FIFOs
                //                Uses message type and parameters to determine what data to output and how
                RX_DECODE_2: begin
                    rx_pkt_data_buf             <=  m2ox_rx_pkt_data;  // Store third plus QQWord
                    lewiz_bcnt                  <=  (lewiz_bcnt < 16'd32)   ?   16'd0   :   lewiz_bcnt - 16'd32;

                    //If message is on channel B, extract data
                    if (b_chan_en) begin
                        if (b_data_en) begin
                            ox2f_rx_data_out        <=  {rx_pkt_data_buf[239:0],b_data_buf[255:240]};
                            ox2f_rx_data_valid      <=  lewiz_bcnt  == 'd0   ?   1'b0    :   oxm2ackm_accept;
                        end
                        oxm_rtx_done                <=  b_tl_msg_header[59:57] == B_PROBE_BLOCK   ?   1'b1    : 1'b0;
                        oxm2ackm_accepted           <=  oxm2ackm_accept;
                        ox2f_rx_header_out          <=  'b0;
                        ox2f_rx_header_valid        <=  'b0;
                        ox2f_rx_addr_out            <=  'b0;
                        ox2f_rx_addr_valid          <=  'b0;
                    end

                    //If message is on channel D, extract data based on size
                    if (d_chan_en) begin
                        if (d_data_en) begin
                            case (d_tl_msg_header[51:48])    //d_size
                                4'h0: begin
                                    ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 1B data
                                end

                                4'h1: begin
                                    ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 2B data
                                end

                                4'h2: begin
                                    ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 4B data
                                end

                                4'h3: begin
                                    ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 8B data
                                end

                                4'h4: begin
                                    ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 16B data
                                end

                                4'h5: begin
                                    ox2f_rx_data_out <= d_sink_en ? {m2ox_rx_pkt_data[47:0],rx_pkt_data_buf[255:48]} : {rx_pkt_data_buf[239:0],d_data_buf[255:240]};    // up to 32B data
                                end

                                default: begin
                                    ox2f_rx_data_out <= d_sink_en ? {m2ox_rx_pkt_data[47:0],rx_pkt_data_buf[255:48]} : {rx_pkt_data_buf[239:0],d_data_buf[255:240]};    // up to 64B data
                                end
                            endcase

                        //  ox2f_rx_data_valid  <=    lewiz_bcnt    == 16'd0   ?   1'b0    :   oxm2ackm_accept;
                            ox2f_rx_data_valid  <=    oxm2ackm_accept;
                            bcnt4mask           <=    (bcnt4mask >= 16'd32) ? bcnt4mask - 16'd32 : 16'b0;

                        end // if(d_data_en)

                        oxm2ackm_accepted           <=  oxm2ackm_accept;
                        ox2f_rx_header_out          <=  'b0;
                        ox2f_rx_header_valid        <=  'b0;
                        ox2f_rx_addr_out            <=  'b0;
                        ox2f_rx_addr_valid          <=  'b0;

                    end //if (d_chan_en)
                end // RX_DECODE_2

                //Done State: Assert external done signal and handle some Channel D data if applicable
                //            NOTE: Operation is not truly done in this state
                RX_DONE: begin
                    if (d_data_en) begin
                        case (d_tl_msg_header[51:48])    //d_size
                            4'h0: begin
                                ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 1B data
                            end

                            4'h1: begin
                                ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 2B data
                            end

                            4'h2: begin
                                ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 4B data
                            end

                            4'h3: begin
                                ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 8B data
                            end

                            4'h4: begin
                                ox2f_rx_data_out <= d_sink_en ? rx_pkt_data_buf[223:48] : {rx_pkt_data_buf[223:0],d_data_buf[255:240]};    // up to 16B data
                            end

                            4'h5: begin
                                ox2f_rx_data_out <= d_sink_en ? {m2ox_rx_pkt_data[47:0],rx_pkt_data_buf[255:48]} : {rx_pkt_data_buf[239:0],d_data_buf[255:240]};    // up to 32B data
                            end

                            default: begin
                                ox2f_rx_data_out <= d_sink_en ? {m2ox_rx_pkt_data[47:0],rx_pkt_data_buf[255:48]} : {rx_pkt_data_buf[239:0],d_data_buf[255:240]};    // up to 64B data
                            end
                        endcase

                          //ox2f_rx_data_valid  <=    lewiz_bcnt    == 16'd0   ?   1'b0    :   oxm2ackm_accept;
                          //ox2f_rx_data_valid  <=  oxm2ackm_accepted;  //if <= 32 bytes should only valid for 1 clk  20220902
                            ox2f_rx_data_valid  <= (d_size <= 4'd5) ? 1'b0 : oxm2ackm_accepted;

                            bcnt4mask           <=    (bcnt4mask >= 16'd32) ? bcnt4mask - 16'd32 : 16'b0;
                    end // if(d_data_en)
                end

                //Done 1 State: Output header and byte count along with any final data to FIFOs
                //              NOTE: Operation actually done at the end of this state
                RX_DONE_1: begin

                    if (b_chan_en) begin
                        if (b_data_en) begin
                            ox2f_rx_data_out    <=  (b_tl_msg_header[51:48] < 6) ? ox2f_rx_data_out :
                                                        {rx_pkt_data_buf[239:0],b_data_buf[255:240]};   // up to 64B data

                          //ox2f_rx_data_valid  <=  (d_tl_msg_header[51:48] < 6)  ? ox2f_rx_data_valid : oxm2ackm_accepted;
                            ox2f_rx_data_valid  <=  oxm2ackm_accepted;
                            ox2f_rx_bcnt_out    <=  {4'b1,ox2f_rx_bcnt_out[11:0]}; //The upper 4 bits are used to indicate to TL2N, the presence of payload in the packet (If 1, there is payload)
                        end
                        else begin
                            //ox2f_rx_bcnt_out  <=  'd0;
                        end

                        ox2f_rx_header_out      <=    b_tl_msg_header;
                        ox2f_rx_header_valid    <=    oxm2ackm_accepted;
                        ox2f_rx_addr_out        <=    b_tl_msg_addr;
                        ox2f_rx_addr_valid      <=    oxm2ackm_accepted;
                        ox2f_rx_bcnt_valid      <=    oxm2ackm_accepted;

                    end

                    if (d_chan_en) begin
                        if (d_data_en) begin
                            ox2f_rx_data_out    <=  (d_tl_msg_header[51:48] < 6)  ? ox2f_rx_data_out :
                                                    (d_sink_en                 )  ? {m2ox_rx_pkt_data[47:0], rx_pkt_data_buf[255:48]} :
                                                    {rx_pkt_data_buf[239:0],d_data_buf[255:240]};   // up to 64B data

                          //ox2f_rx_data_valid  <=  (d_tl_msg_header[51:48] < 6)  ? ox2f_rx_data_valid    :   oxm2ackm_accepted;
                          //ox2f_rx_data_valid  <=  oxm2ackm_accepted;
                            ox2f_rx_data_valid  <=  1'b0 ;
                            ox2f_rx_bcnt_out    <= {4'b1,ox2f_rx_bcnt_out[11:0]}; //The upper 4 bits are used to indicate to TL2N, the presence of payload in the packet (If 1, there is payload)
                        end
                        else begin
                          //ox2f_rx_bcnt_out  <=  'd0;
                        end

                        ox2f_rx_header_out          <=    d_tl_msg_header;
                        ox2f_rx_header_valid        <=    oxm2ackm_accepted;
                        ox2f_rx_addr_out            <=    d_tl_msg_sink;
                        ox2f_rx_addr_valid          <=    oxm2ackm_accepted && d_sink_en;
                        ox2f_rx_bcnt_valid          <=    oxm2ackm_accepted;
                        ox2f_rx_mask_valid          <=    ((ox2tl_aquire_gnt | ox2tl_acc_ack_data) & oxm2ackm_accepted) ? 1'b1 : 1'b0 ;
                    end
                end

                //Done 2 State: Reset some internal registers (it gets done again next state in Idle)
                //              TODO: External done signal should be asserted here instead of "normal" done ?
                //                    If not, we dont need this state at all
                RX_DONE_2: begin
                   tloe_header_chan         <=   'b0;
                   tloe_header_credit       <=   'b0;
                   tloe_header_ack          <=   'b0;
                   tloe_header_seq_num_ack  <=   'b0;
                   tloe_header_seq_num      <=   'b0;
                   tloe_header_vc           <=   'b0;

                   ox2f_rx_bcnt_out         <=   'd0;
                   ox2f_rx_bcnt_valid       <=  1'b0;
                   ox2f_rx_header_valid     <=  1'b0;
                   ox2f_rx_addr_valid       <=  1'b0;
                   ox2f_rx_mask_valid       <=  1'b0;
                end

               //default: rx_state    <=  RX_IDLE;
           endcase
        end // else
    end // always


//    // Channel B
//    always @(posedge clk)
//    begin
//      if (!rst_)
//      begin
//          b_source    <=  0;
//          b_size      <=  0;
//          b_opcode    <=  0;
//          b_param     <=  0;
//          b_data      <=  0;
//          b_corrupt   <=  0;
//          b_mask      <=  0;
//          b_addr      <=  0;
//          b_domain    <=  0;
//          b_chan      <=  0;
//          b_size_left <=  0;
//      end else begin
//      end
//    end //always


    //Channel B & D Detection and Header/Parameter Decoding
    always @(posedge clk) begin
        if (!rst_) begin
            b_tl_msg_header <=  'b0;
            b_tl_msg_addr   <=  'b0;
            b_chan_en       <=  'b0;
            b_data_en       <=  'b0;
            b_data_buf      <=  'b0;

            d_tl_msg_header <=  'b0;
            d_tl_msg_sink   <=  'b0;
            d_chan_en       <=  'b0;
            d_data_en       <=  'b0;
            d_sink_en       <=  'b0;
            d_data_buf      <=  'b0;
        end
        else begin
            case (rx_state)
                RX_IDLE: begin
                    b_tl_msg_header <=  'b0;
                    b_tl_msg_addr   <=  'b0;
                    b_chan_en       <=  'b0;
                    b_data_en       <=  'b0;
                    b_data_buf      <=  'b0;

                    d_tl_msg_header <=  'b0;
                    d_tl_msg_sink   <=  'b0;
                    d_chan_en       <=  'b0;
                    d_data_en       <=  'b0;
                    d_data_buf      <=  'b0;
                end

                RX_IPCS: begin
                end

                RX_PKT_RD_1: begin
                end


                RX_DECODE_1: begin
                    if (rx_pkt_data_buf[182:180] == TL_CHAN_B) begin    // check if channel B
                        b_tl_msg_header    <=    {
                                                rx_pkt_data_buf[183:176],
                                                rx_pkt_data_buf[191:184],
                                                rx_pkt_data_buf[199:192],
                                                rx_pkt_data_buf[207:200],
                                                rx_pkt_data_buf[215:208],
                                                rx_pkt_data_buf[223:216],
                                                rx_pkt_data_buf[231:224],
                                                rx_pkt_data_buf[239:232]
                                            };
                        b_chan_en        <=    1'b1;
                       // b_data_en        <=    rx_pkt_data_buf[179:177] ==  ;     // Need to be enabled for including data
                        b_data_buf       <=    rx_pkt_data_buf;
                    end

                    if (rx_pkt_data_buf[182:180] == TL_CHAN_D)    // check if channel D
                    begin
                        d_tl_msg_header    <=    {
                                                rx_pkt_data_buf[183:176],
                                                rx_pkt_data_buf[191:184],
                                                rx_pkt_data_buf[199:192],
                                                rx_pkt_data_buf[207:200],
                                                rx_pkt_data_buf[215:208],
                                                rx_pkt_data_buf[223:216],
                                                rx_pkt_data_buf[231:224],
                                                rx_pkt_data_buf[239:232]
                                            };
                        d_chan_en        <=    1'b1;
                        d_sink_en        <=    rx_pkt_data_buf[179:177] ==  D_GRANT         ||  rx_pkt_data_buf[179:177] == D_GRANT_DATA;
                        d_data_en        <=    rx_pkt_data_buf[179:177] ==  D_ACC_ACK_DATA  ||  rx_pkt_data_buf[179:177] == D_GRANT_DATA;
                        d_data_buf       <=    rx_pkt_data_buf;
                    end
                end

                RX_PKT_RD_2: begin
                    if (b_chan_en) begin
                        b_data_buf      <=    rx_pkt_data_buf;
                    end

                    if (d_chan_en) begin
                        d_data_buf      <=    rx_pkt_data_buf;
                    end
                end

                RX_DECODE_2: begin
                    if (b_chan_en) begin
                        b_tl_msg_addr   <= {b_data_buf[247:240]   , b_data_buf[255:248],
                                            rx_pkt_data_buf[7:0]  , rx_pkt_data_buf[15:8],
                                            rx_pkt_data_buf[23:16], rx_pkt_data_buf[31:24],
                                            rx_pkt_data_buf[39:32], rx_pkt_data_buf[47:40]};
                        b_data_buf      <=  rx_pkt_data_buf;

                    end

                    if (d_chan_en) begin
                        if (d_sink_en) begin
                            d_tl_msg_sink   <=    {16'b0, rx_pkt_data_buf[7:0],    rx_pkt_data_buf[15:8],
                                                        rx_pkt_data_buf[23:16],    rx_pkt_data_buf[31:24],
                                                        rx_pkt_data_buf[39:32],    rx_pkt_data_buf[47:40]};
                        end
                        d_data_buf      <=  rx_pkt_data_buf;
                    end
                end

                RX_DONE: begin
                    d_data_buf          <=  rx_pkt_data_buf;        //20220525 (same as data_buf2)
                end

                RX_DONE_1: begin
                    d_sink_en <= 1'b0 ;
                end

          endcase
        end
    end //always


//===================== Generate TL FIFO WE 20220525
always @(posedge clk)
    if (!rst_) begin
        ox2tl_aquire_gnt    <= 1'b0 ;
        ox2tl_release_ack   <= 1'b0 ;
        ox2tl_acc_ack       <= 1'b0 ;
        ox2tl_acc_ack_data  <= 1'b0 ;
        ox2tl_probe         <= 1'b0 ;
    end
    else begin
        ox2tl_aquire_gnt    <=  (rx_decode_1_st && rx_pkt_data_buf[182:180] == TL_CHAN_D &&
                                (rx_pkt_data_buf[179:177] == D_GRANT || rx_pkt_data_buf[179:177] == D_GRANT_DATA)) ? 1'b1 :
                                (rx_done_2_st) ? 1'b0 :
                                ox2tl_aquire_gnt ;

        ox2tl_release_ack   <=  (rx_decode_1_st && rx_pkt_data_buf[182:180] == TL_CHAN_D &&
                                (rx_pkt_data_buf[179:177] == D_RELEASE_ACK)) ? 1'b1 :
                                (rx_done_2_st) ? 1'b0 :
                                ox2tl_release_ack ;

        ox2tl_probe         <=  (rx_decode_1_st && rx_pkt_data_buf[182:180] == TL_CHAN_B &&
                                (rx_pkt_data_buf[179:177] == B_PROBE_BLOCK)) ? 1'b1 :
                                (rx_done_2_st) ? 1'b0 :
                                ox2tl_probe ;

        ox2tl_acc_ack       <=  (rx_decode_1_st && rx_pkt_data_buf[182:180] == TL_CHAN_D &&
                                (rx_pkt_data_buf[179:177] == D_ACC_ACK))  ? 1'b1 :
                                (rx_done_2_st) ? 1'b0 :
                                ox2tl_acc_ack ;

        ox2tl_acc_ack_data  <=  (rx_decode_1_st && rx_pkt_data_buf[179:177] == D_ACC_ACK_DATA) ? 1'b1 :
                                (rx_done_2_st) ? 1'b0 :
                                ox2tl_acc_ack_data ;
    end


    //=========== for simulation
    //  FSM

    reg [12*8:0] ascii_rx_state;

    always@(rx_state) begin
        case(rx_state)
             RX_IDLE    : ascii_rx_state = "RX_IDLE"    ;
             RX_IPCS    : ascii_rx_state = "RX_IPCS"    ;
             RX_PKT_RD_1: ascii_rx_state = "RX_PKT_RD_1";
             RX_DECODE_1: ascii_rx_state = "RX_DECODE_1";
             RX_PKT_RD_2: ascii_rx_state = "RX_PKT_RD_2";
             RX_DECODE_2: ascii_rx_state = "RX_DECODE_2";
             RX_DONE    : ascii_rx_state = "RX_DONE"    ;
             RX_DONE_1  : ascii_rx_state = "RX_DONE_1"  ;
             RX_DONE_2  : ascii_rx_state = "RX_DONE_2"  ;
        endcase
    end // always rx_state



endmodule
