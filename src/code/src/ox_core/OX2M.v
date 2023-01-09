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


module OX2M
    #(  parameter TX_HEADER_PTR     =12,
        parameter TX_ADDR_PTR       =12,
        parameter TX_MASK_PTR       =12,
        parameter TX_DATA_PTR       =13,
        parameter TX_BCNT_PTR       =12,
        parameter RTX_CMD_PTR       =3,
        parameter RTX_DATA_PTR      =9,
        parameter SRC_MAC           = 48'h001232_FFFFF0,
        parameter DST_MAC           = 48'h000000_000000)
    (
        input                           clk                         ,
        input                           rst_                        ,

        //----------------------------------------------------------------//
        //  From TL Message FIFOs

        // TX Header FIFO
        input       [63:0]              f2ox_tx_header_i            ,
        input                           f2ox_tx_header_empty_i      ,
        input       [TX_HEADER_PTR-1:0] f2ox_tx_header_rdusedw_i    ,
        output                          ox2f_tx_header_re_i         ,

        // TX Address FIFO
        input       [63:0]              f2ox_tx_addr_i              ,
        input                           f2ox_tx_addr_empty_i        ,
        input       [TX_ADDR_PTR-1:0]   f2ox_tx_addr_rdusedw_i      ,
        output                          ox2f_tx_addr_re_i           ,

        // TX Mask FIFO
        input       [63:0]              f2ox_tx_mask_i              ,
        input                           f2ox_tx_mask_empty_i        ,
        input       [TX_MASK_PTR-1:0]   f2ox_tx_mask_rdusedw_i      ,
        output                          ox2f_tx_mask_re_i           ,

        // TX DATA FIFO
        input       [255:0]             f2ox_tx_data_i              ,
        input                           f2ox_tx_data_empty_i        ,
        input       [TX_DATA_PTR-1:0]   f2ox_tx_data_rdusedw_i      ,
        output                          ox2f_tx_data_re_i           ,

        // TX BCNT FIFO
        input       [15:0]              f2ox_tx_bcnt_i              ,
        input                           f2ox_tx_bcnt_empty_i        ,
        input       [TX_BCNT_PTR-1:0]   f2ox_tx_bcnt_rdusedw_i      ,
        output                          ox2f_tx_bcnt_re_i           ,

        //----------------------------------------------------------------//
        //  Retransmission Management

        //RTX MGR
        input                           rtx_mgn_tx_grant            ,   //for normal packet transmit - gnt of a RTX entry
        input                           rtx_mgn_rtx_grant           ,   //for retransmission of a packet during RTX cycle
        input       [11:0]              tx_buf_wr_addr              ,   // addr for data buff fifo
        input                           tx_rtx_entry_full           ,   // high when all entry is full
        output reg                      tx_send_req                 ,   // request for tx, prioritize ack and rtx first
        output      [21:0]              tx_send_seq                 ,   // tx sequence number, comes with tx req
        output reg                      tx_local_bcnt_valid         ,   // bcnt valid for rtx_mgr
        output reg  [15:0]              tx_local_bcnt               ,   // bcnt for rtx_mgr
        output                          tx_done                     ,   // transmission is completed

        //RTX CMD FIFO
        input       [63:0]              f2ox_rtx_cmd_i              ,   // fifo to ox cmd data
        input                           f2ox_rtx_cmd_empty_i        ,   // high if cmd fifo is empty
        input       [RTX_CMD_PTR-1:0]   f2ox_rtx_cmd_rdusedw_i      ,   // rtx cmd fifo usedword
        output                          ox2f_rtx_cmd_re_i           ,   // read enable for rtx cmd fifo

        //RTX DATA buffer
        output      [255:0]             ox2b_rtx_wrdata_i           ,
        output reg  [RTX_DATA_PTR-1:0]  ox2b_rtx_wrdata_wdaddr      ,   /// 16kB RAM = 256bit * 8 * 8
        output                          ox2b_rtx_wrdata_we_i        ,

        input       [255:0]             b2ox_rtx_rddata_i           ,
        output reg  [RTX_DATA_PTR-1:0]  ox2b_rtx_rddata_rdaddr      ,   /// 16kB RAM = 256bit * 8 * 8
        output reg                      ox2b_rtx_rddata_re_i        ,

        //----------------------------------------------------------------//
        //  Sequencing & Acknowledgment Management

        //Update Sequence Request to Seq_Mgr
        output  reg                     tx2rx_updateseq_req,    //Asserted to request Seq_Mgr update sequence number
        output  reg [21:0]              tx2rx_seq_num,          //The new sequence number (of what we transmitted)
        input                           tx2rx_updateseq_done,   //Asserted when Seq_Mgr sequence update is complete

        //Send ACK Request from Seq_Mgr
        input                           rx2tx_send_req,         //Request from seq_mgr to send ACK frame
        input                           rx2tx_ack_mode,         //Type of ACK to send update (1 = ACK, 0 = NACK)
        input       [21:0]              rx2tx_rxack_num,        //update local node ack num to send out to remote node (local ack)
        output                          rx2tx_sendreq_done,     //ack_update_done

        //----------------------------------------------------------------//

        //TX Path to LMAC
        output      [255:0]             ox2m_tx_data                ,
        output                          ox2m_tx_we                  ,
        input                           m2ox_tx_fifo_full           ,
        input       [12:0]              m2ox_tx_fifo_wrused         ,
    //  output      [31:0]              ox2m_tx_be                  ,   //(optional) Byte enable

        //----------------------------------------------------------------//

        //Reset Control
        input       [255:0]             rst2ox_send_pkt_data        ,   //Frame data from reset control (for OX channel and credit)
        input                           rst2ox_pkt_credit_we        ,   //Valid Signal for the packet credit information
        input                           rst2ox_rst_ctrl_req         ,   //Asserted by reset controller to request control over TX
        input                           rst2ox_pkt_done             ,
        input       [1:0]               rst2ox_qqwd_cnter           ,   //Counter for number of qqwds
        output reg                      ox2rst_rst_ctrl_grant
    );




    //================================================================//
    //  Convenience Parameters

    //  TL MSG Channel
    localparam  TL_CHAN_A       =   3'b001,
                TL_CHAN_B       =   3'b010,
                TL_CHAN_C       =   3'b011,
                TL_CHAN_D       =   3'b100,
                TL_CHAN_E       =   3'b101;



    //  Channel A Opcode
    localparam  A_PUT_FULL      =   3'd0,
                A_PUT_PARTIAL   =   3'd1,
                A_ARITHMETIC    =   3'd2,
                A_LOGICAL       =   3'd3,
                A_GET           =   3'd4,
                A_INTENT        =   3'd5,
                A_ACQUIRE_BLOCK =   3'd6,
                A_ACQUIRE_PERN  =   3'd7;


    //  Channel E Opcode
    localparam  C_ACC_ACK_      =   3'd0,
                C_ACC_ACK_DATA  =   3'd1,
                C_HINT_ACK      =   3'd2,
                C_PROBE_ACK     =   3'd4,
                C_PROBE_ACK_DATA=   3'd5,
                C_RELEASE       =   3'd6,
                C_RELEASE_DATA  =   3'd7;

    //  Channel E Opcode
//     localparam                       E_GRANT_ACK;


    //================================================================//
    //  State Machine Encoding and State Signals

    reg  [15:0] tx_state;
    localparam  TX_IDLE         =  16'h0001,
                TX_RD_FIFO      =  16'h0002,
                TX_DECODE_1     =  16'h0004,
                TX_DECODE_2     =  16'h0008,
                TX_HEADER       =  16'h0010,
                TX_PLD_1        =  16'h0020,
                TX_PLD_2        =  16'h0040,
                TX_FMASK        =  16'h0080,
                TX_RTX_CMD      =  16'h0100,
                TX_RTX_RD       =  16'h0200,
                TX_RTX_DATA     =  16'h0400,
                TX_ACKONLY      =  16'h0800,
                TX_DONE         =  16'h1000;

    wire        tx_idle_st      =   tx_state[0];
    wire        tx_rd_fifo_st   =   tx_state[1];
    wire        tx_decode_1_st  =   tx_state[2];    // gather info for opcode and channel
    wire        tx_decode_2_st  =   tx_state[3];    // gather info for address and data mask, calculate lewiz reserved
    wire        tx_header_st    =   tx_state[4];    // cal ethernet header and TLoE frame header
    wire        tx_pld_1_st     =   tx_state[5];    // gather data and calculate frame mask
    wire        tx_pld_2_st     =   tx_state[6];    // gather data and calculate frame mask
    wire        tx_fmask_st     =   tx_state[7];    // cal TLoE frame mask
    wire        tx_rtx_cmd_st   =   tx_state[8];
    wire        tx_rtx_rd_st    =   tx_state[9];
    wire        tx_rtx_data_st  =   tx_state[10];
    wire        tx_ackonly_st   =   tx_state[11];
    wire        tx_done_st      =   tx_state[12];


    //================================================================//
    //  Other Internal Signals

    // ------- internal variables 20220420
    reg     tx_ackonly_st_dly1 ;
    reg     ackonly_cycle ;

    //------------------
    reg                 tx_fifo_data_re;

    reg  [63:0]         tx_ox2m_out_header_64_buf;
    reg  [255:0]        tx_ox2m_out_data;
    reg  [255:0]        tx_ox2m_out_data_buf;
    reg  [255:0]        tx_ox2m_data_buf_i;
    reg                 tx_ox2m_out_valid;
    reg  [15:0]         data_bcnt;
    reg  [7:0]          ack_only_cnt;

    //LeWiz Reserved
    reg  [15:0]         lewiz_bcnt;

    //Ethernet Header
    reg  [47:0]         dst_mac;
    reg  [47:0]         src_mac;
    reg  [15:0]         eth_type;

    //TLoE Frame Header
    reg  [2:0]          tloe_header_chan;
    reg  [4:0]          tloe_header_credit;
    reg                 tloe_header_ack;
    reg  [21:0]         tloe_header_seq_num_ack;
    reg  [21:0]         tloe_header_seq_num;
    reg  [2:0]          tloe_header_vc;


    //----------------------------------------------------------------//
    // Channel A TL Msg Header Data

    reg  [25:0]         a_source;           // {TAG, DST_CHIPID}
    reg  [3:0]          a_size;             // PAYLOAD_LENGTH
    reg  [2:0]          a_opcode;           // MSG_TYPE
    reg                 a_chan_en;          // Channel
    reg  [3:0]          a_param;            // zero for now
    reg  [255:0]        a_data;             //{DATA_4, DATA_3, DATA_2, DATA_1}
    reg                 a_corrupt;
    reg  [63:0]         a_mask;             // Based on PAYLOAD_LENGTH
    reg  [63:0]         a_addr;             //{DST_XPOS, DST_YPOST, DST_ADDR}
    reg  [7:0]          a_domain;           // all zero
    reg  [3:0]          a_size_left;


    //----------------------------------------------------------------//
    // Channel C TL Msg Header Data

    reg  [25:0]         c_source;           // {TAG, DST_CHIPID}
    reg  [3:0]          c_size;             // PAYLOAD_LENGTH
    reg  [2:0]          c_opcode;           // MSG_TYPE
    reg                 c_chan_en;          // Channel
    reg  [3:0]          c_param;            // zero for now
    reg  [255:0]        c_data;             //{DATA_4, DATA_3, DATA_2, DATA_1}
    reg                 c_corrupt;
    reg  [63:0]         c_addr;             //{DST_XPOS, DST_YPOST, DST_ADDR}
    reg  [7:0]          c_domain;           // all zero
    reg  [3:0]          c_size_left;


    //----------------------------------------------------------------//
    // Channel E TL Msg Header Data

    reg                 e_chan_en;
    reg  [25:0]         e_sink;             //Slave sink identifier

    //----------------------------------------------------------------//

    // TLoE Frame Mask
    reg  [63:0]         tloe_frame_mask;


    // RTX_CMD_FIFO
    reg  [15:0]         rtx_cmd_bcnt_buf;


    //================================================================//
    //  Output Signal Assignments

    assign              ox2f_tx_header_re_i =  (tx_rd_fifo_st & !f2ox_tx_header_empty_i) ? 1'b1 : 1'b0;
    assign              ox2f_tx_bcnt_re_i   =  (tx_rd_fifo_st & !f2ox_tx_bcnt_empty_i  ) ? 1'b1 : 1'b0;

    assign              ox2f_tx_addr_re_i   =  (!tx_decode_1_st) ? 1'b0 :
                                               (f2ox_tx_header_i[62:60] == TL_CHAN_A  || f2ox_tx_header_i[62:60] == TL_CHAN_C) ? 1'b1 :
                                                1'b0;

    assign              ox2f_tx_mask_re_i   =  (!tx_decode_1_st                         ) ? 1'b0 :
                                               (f2ox_tx_header_i[62:60] != TL_CHAN_A    ) ? 1'b0 :
                                               (f2ox_tx_header_i[59:57] == A_PUT_PARTIAL) ? 1'b1 :
                                                1'b0;

//  assign              ox2f_tx_data_re_i   =   tx_decode_2_st  ? (a_opcode    <= 3) && (!f2ox_tx_data_empty_i) :
//                                              tx_header_st    ? (a_opcode    <= 3) && (!f2ox_tx_data_empty_i) && (a_size_left >= 5)  :
//                                              1'b0;
//20220511

    assign              ox2f_tx_data_re_i   =  (tx_decode_2_st) ? ((a_opcode    <= 3) && (!f2ox_tx_data_empty_i)) ||
                                                                  ((f2ox_tx_header_i[62:60] == TL_CHAN_C)         &&
                                                                  ((f2ox_tx_header_i[59:57] == C_RELEASE_DATA)    ||
                                                                   (f2ox_tx_header_i[59:57] == C_PROBE_ACK_DATA)) &&
                                                                  (!f2ox_tx_data_empty_i)) :
                                               (tx_header_st  ) ? ((a_opcode    <= 3) && (!f2ox_tx_data_empty_i)  && (a_size_left >= 5)) ||
                                                                  ((f2ox_tx_header_i[62:60] == TL_CHAN_C)         &&
                                                                  ((f2ox_tx_header_i[59:57] == C_RELEASE_DATA)    ||
                                                                   (f2ox_tx_header_i[59:57] == C_PROBE_ACK_DATA)) &&
                                                                  (!f2ox_tx_data_empty_i) && (c_size_left >= 5)) :
                                                1'b0;

    assign              ox2f_rtx_cmd_re_i   =   (tx_rtx_cmd_st && !f2ox_rtx_cmd_empty_i) ?   1'b1    :1'b0;
    assign              ox2m_tx_data        =   tx_rtx_data_st  ?   b2ox_rtx_rddata_i : tx_ox2m_out_data;
    assign              ox2m_tx_we          =   tx_ox2m_out_valid;
    assign              ox2b_rtx_wrdata_i   =   tx_ox2m_out_data;

//  assign              ox2b_rtx_wrdata_we_i=   |tx_state[11:8] ?   1'b0   :   tx_ox2m_out_valid;
    assign              ox2b_rtx_wrdata_we_i=   tx_ox2m_out_valid;

    assign              tx_done             =   tx_done_st;

//  assign              rx2tx_sendreq_done  =   tx_done_st; // state & RX Cycle in progress (not TX path only)
//  assign              rx2tx_sendreq_done  =   tx_done_st & tx_ackonly_st_dly1;    // state & RX Cycle in progress (not TX path only)  CLE 20220420
    assign              rx2tx_sendreq_done  =   rx2tx_send_req ? ( tx_ackonly_st ? 1'b1 : 1'b0 ) :  //ack only mode (20220420 CLE)
                                                !ackonly_cycle & tx_done_st ;   //normal TX | rtx cycles

//  assign              tx_send_seq         =   tx2rx_seq_num;
    assign              tx_send_seq         =   tloe_header_seq_num;


    //================================================================//
    //  TX State Machine

    //Next State Logic
    always @(posedge clk) begin
        if (!rst_) begin
            tx_state    <=  TX_IDLE;
        end
        else begin
            if (tx_idle_st) begin
                tx_state    <=
                            //-/rx2tx_send_req & rtx_mgn_tx_grant   ? TX_ACKONLY     :      //CLE 20220420, sending ACK packet
                                rx2tx_send_req                      ? TX_ACKONLY     :      //+/	//2022-10-11: Send ACK only packet without waiting for RTX Mgr grant
                                rtx_mgn_rtx_grant                   ? TX_RTX_CMD     :      //retransmit packet
                                rtx_mgn_tx_grant                    ? TX_RD_FIFO     :      //normal transmit from TL logic
                                !rst2ox_rst_ctrl_req    &&
                                ox2rst_rst_ctrl_grant               ? TX_HEADER      :      //reset control packet
                            //  rx2tx_send_req && !tx_send_req      ? TX_ACKONLY     :
                                TX_IDLE;
            end

            //----------------------------------------------------------------//
            //  Standard TX States

            if (tx_rd_fifo_st) begin
                tx_state    <=  TX_DECODE_1;
            end

            if (tx_decode_1_st) begin
                tx_state    <=  TX_DECODE_2;
            end

            if (tx_decode_2_st) begin
                tx_state    <=  TX_HEADER;
            end

            if (tx_header_st) begin
                tx_state    <=  TX_PLD_1;
            end

            if (tx_pld_1_st) begin
                tx_state    <=  (a_chan_en && (a_opcode == A_PUT_FULL     | a_opcode == A_PUT_PARTIAL)) |
                                (c_chan_en && (c_opcode == C_RELEASE_DATA | c_opcode == C_PROBE_ACK_DATA)) ?
                                    (data_bcnt > 16'd32 ? TX_PLD_2 : TX_FMASK) :
                                    TX_FMASK;
            end

            if (tx_pld_2_st) begin
                tx_state    <=  TX_FMASK;
            end

            if (tx_fmask_st) begin
                tx_state    <=  TX_DONE;
            end

            if (tx_rtx_cmd_st) begin
                tx_state    <=  TX_RTX_RD;
            end

            if (tx_rtx_rd_st) begin
                tx_state    <=  TX_RTX_DATA;
            end

            if (tx_rtx_data_st) begin
                tx_state    <= (rtx_cmd_bcnt_buf != 16'd0) ? TX_RTX_DATA :
                               (!f2ox_rtx_cmd_empty_i    ) ? TX_RTX_CMD  :
                                TX_DONE;
            end

            if (tx_ackonly_st) begin
                tx_state    <= (ack_only_cnt == 8'b11    ) ? TX_DONE : TX_ACKONLY ;
            end

            if (tx_done_st) begin
                tx_state    <=  TX_IDLE;
            end
        end // else
    end // always

    //Primary TX Logic
    always @(posedge clk) begin
        if  (!rst_) begin
            tx_fifo_data_re      <= 1'b0;

            //to LMAC
            tx_ox2m_out_data     <= 256'b0;
            tx_ox2m_out_valid    <= 1'b0;

            //LeWiz Reserved
            lewiz_bcnt           <= 16'b0;

            //Ethernet Header
            dst_mac              <= DST_MAC;
            src_mac              <= SRC_MAC;
            eth_type             <= 16'hAAAA;     //Temporary ETH Type  //TODO: change ETH type once determined

            //TLoE Frame Mask
            tloe_frame_mask                 <=  64'b0;

            //
            tx_ox2m_out_header_64_buf       <=  64'b0;
            tx_ox2m_data_buf_i              <=  256'b0;
            tx_ox2m_out_data_buf            <=  256'b0;
            data_bcnt                       <=  16'b0;
            tx_send_req                     <=  1'b0;
            tx2rx_updateseq_req             <=  1'b0;
            tx2rx_seq_num                   <=  22'b0;
            ox2b_rtx_wrdata_wdaddr          <=  256'b0;
            ox2b_rtx_rddata_rdaddr          <=  256'b0;
            ox2b_rtx_rddata_re_i            <=  1'b0;
            rtx_cmd_bcnt_buf                <=  16'b0;
            tx_local_bcnt                   <=  16'b0;
            ack_only_cnt                    <=  8'b0;
            tx_local_bcnt_valid             <=  1'b0;

            //internal vars
            tx_ackonly_st_dly1              <=  1'b0;       //20220420
            ackonly_cycle                   <=  1'b0 ;
        end
        else begin

            tx_ackonly_st_dly1      <=  tx_ackonly_st;      //20220420

            //Raise ACK only flag if handling an ACK request, lower on TX completion
            ackonly_cycle           <=
                (tx_done_st                                    ) ? 1'b0 :   //negate
            //-/(tx_idle_st & rx2tx_send_req & rtx_mgn_tx_grant) ? 1'b1 :   //CLE 20220420, assert
                (tx_idle_st & rx2tx_send_req                   ) ? 1'b1 :   //+/	//2022-10-11: Send ACK only packet without waiting for RTX Mgr grant
                ackonly_cycle;                                              //keep

           case (tx_state)
                //Idle State: Reset registers and assert TX request to RTX Mgr
                TX_IDLE: begin
                    tx_fifo_data_re     <= 1'b0;

                    //to LMAC
                    tx_ox2m_out_data    <= 256'b0;
                    tx_ox2m_out_valid   <= 1'b0;

                    //LeWiz Reserved
                    lewiz_bcnt          <= 16'b0;
                    tx_local_bcnt       <= 16'b0;
                    tx_local_bcnt_valid <= 1'b0;

                    //Ethernet Header
                //  dst_mac             <= 'b0;
                //  src_mac             <=  SRC_MAC;
                //  eth_type            <= 'b0;

                    data_bcnt                   <= 16'b0;
                    tx_ox2m_out_header_64_buf   <= 64'b0;
                    tx_ox2m_data_buf_i          <= 256'b0;
                    tx_ox2m_out_data_buf        <= 256'b0;

                    tx_send_req                 <=         //CLE 20220420
                        //ACK only cycle (if RTX not full and MAC not full, and currently not being granted by RTX mgr)
                    //  rx2tx_send_req ? (!tx_rtx_entry_full && !m2ox_tx_fifo_full) && !(rtx_mgn_rtx_grant | rtx_mgn_tx_grant) :
                    //-/rx2tx_send_req ? (!tx_rtx_entry_full && !m2ox_tx_fifo_full) && !(rtx_mgn_tx_grant) :    //2022-10-11: Send ACK only packet without waiting for RTX Mgr grant
                        //normal transmit of a packet to LMAC or retransmit of packets
                        (!tx_rtx_entry_full && !f2ox_tx_header_empty_i && !m2ox_tx_fifo_full) && !(rtx_mgn_rtx_grant ^ rtx_mgn_tx_grant);   //TODO: should this use xor?

                    tx2rx_updateseq_req         <= 1'b0;
                    ox2b_rtx_wrdata_wdaddr      <= rtx_mgn_tx_grant    ?   tx_buf_wr_addr  :   ox2b_rtx_wrdata_wdaddr;
                    ack_only_cnt                <= 8'b0;
                end

                //----------------------------------------------------------------//
                //  Standard TX States

                TX_RD_FIFO: begin
                    tx_send_req <=  1'b0;
                end

                TX_DECODE_1: begin
                    lewiz_bcnt                  <=  16'd30;             //msg bcnt + ethernet header(14B) + TLoE header (8B) + TLoE Frame mask (8B)
                    data_bcnt                   <=  f2ox_tx_bcnt_i;     //store away the BCNT from FIFO (for 0 pld, = 'h20 or 32)
                    tx_ox2m_out_header_64_buf   <=  f2ox_tx_header_i;   //store away the TL header for transmit later
                    tx2rx_updateseq_req         <=  1'b1;               //update seq req
                    tx2rx_seq_num               <= tloe_header_seq_num; //current local seq number, added 20220516
                end

                TX_DECODE_2: begin
                //  lewiz_bcnt          <=  e_chan_en   ?   lewiz_bcnt + (1 << a_size) + 16'd8                    : // TL msg Header (8B for channel e)

                    lewiz_bcnt          <=
                    //  e_chan_en   ?   lewiz_bcnt + 16'd40                   :     // TL msg Header (8B for channel e)
                        (e_chan_en  | (c_chan_en & (c_opcode == C_RELEASE | c_opcode == C_PROBE_ACK)))  ?
                                        lewiz_bcnt + 16'd40                   :     // TL msg Header (8B for channel e)

                        // for release_data and probe_data case
                        (c_chan_en & (c_opcode == C_RELEASE_DATA | c_opcode == C_PROBE_ACK_DATA))       ?
                                        lewiz_bcnt + (1 << c_size) + 16'd16   :     // (TL msg Header + addr)16B

                    //  a_opcode == A_PUT_PARTIAL   ?   lewiz_bcnt + (1 << a_size) + 16'd24   : // (TL msg Header + addr)16B + data mask(8B)

                        (a_opcode == (A_PUT_PARTIAL) && (a_size == 3)) ? lewiz_bcnt + (1 << a_size) + 16'd32   :         // (TL msg Header + addr)16B + data mask(8B)+  8B Padding
                        (a_opcode == (A_PUT_PARTIAL) && (a_size == 2)) ? lewiz_bcnt + (1 << a_size) + 16'd32 + 'd4  :    // (TL msg Header + addr)16B + data mask(8B)+ 12B Padding
                        (a_opcode == (A_PUT_PARTIAL) && (a_size == 1)) ? lewiz_bcnt + (1 << a_size) + 16'd32 + 'd6  :    // (TL msg Header + addr)16B + data mask(8B)+ 14B Padding
                        (a_opcode == (A_PUT_PARTIAL) && (a_size == 0)) ? lewiz_bcnt + (1 << a_size) + 16'd32 + 'd7  :    // (TL msg Header + addr)16B + data mask(8B)+ 15B Padding
                        (a_opcode == (A_PUT_PARTIAL) && (a_size >  3)) ? lewiz_bcnt + (1 << a_size) + 16'd24   :

                        (a_opcode <= 3                               ) ? lewiz_bcnt + (1 << a_size) + 16'd16   : // (TL msg Header + addr)16B

                        //for ACQUIRE and other cases
                        lewiz_bcnt + 16'd40; // TL msg Header(8B) + addr(8B) + ethernet header(14B) + TLoE header (8B) + TLoE Frame mask (8B) + Padding (14B) = 60B

                //  if (a_chan_en)
                    if (a_chan_en | e_chan_en
                            //send RELEASE pkt
                            | (c_chan_en & (c_opcode == C_RELEASE    | c_opcode == C_RELEASE_DATA  |
                                            c_opcode == C_PROBE_ACK  | c_opcode == C_PROBE_ACK_DATA)))      // 20220503 - add E channel support
                    begin
                        //emulating an ARP cache for sending packet out from TL
                        case (a_addr[49:48])
                            2'b00:  dst_mac <=  DST_MAC;      //Shankar FPGA IMPLEMENTATION        // KIT_20220401, Default case for testing with Endpoint
                        //  2'b00:  dst_mac <=  SRC_MAC + 48'd1;
                            2'b01:  dst_mac <=  SRC_MAC + 48'd2;
                            2'b10:  dst_mac <=  SRC_MAC + 48'd3;
                            2'b11:  dst_mac <=  SRC_MAC + 48'd4;
                        endcase
                    end
                    else if (c_chan_en) begin
                        //emulating an ARP cache
                        case (c_addr[49:48])    //for ACK responses to remote data on C channel
                            2'b00:  dst_mac <=  SRC_MAC + 48'd1;
                            2'b01:  dst_mac <=  SRC_MAC + 48'd2;
                            2'b10:  dst_mac <=  SRC_MAC + 48'd3;
                            2'b11:  dst_mac <=  SRC_MAC + 48'd4;
                        endcase
                    end
                //  eth_type                <=  'hAAAA;
                    tx2rx_seq_num <= tloe_header_seq_num;  // current local seq number
                    tx2rx_updateseq_req    <=  1'b0;
                end

                //Header State: Assemble Header data and store in Pre-TX FIFO
                TX_HEADER: begin
                    tloe_frame_mask        <=   64'b1;  //always 1 if only 1 TL message in the TLoE Frame
                        //snd hdr out to the LMAC
                //  tx_ox2m_out_data        <=  {
                //                                  tx_ox2m_out_header_64_buf[55:48],  tx_ox2m_out_header_64_buf[63:56],                        // TL Msg Header [63:48]
                //                                  tloe_header_chan, tloe_header_credit,
                //                                  tloe_header_seq_num_ack[5:0],tloe_header_ack, 1'b0, // TLoE Frame Header
                //                                  tloe_header_seq_num_ack[13:6],
                //                                  tloe_header_seq_num_ack[21:14],
                //                                  tloe_header_seq_num[7:0],   // TLoE Frame Header
                //                                  tloe_header_seq_num[15:8],
                //                                  2'b0, tloe_header_seq_num[21:16],
                //                                  tloe_header_vc, 5'b0,           // TLoE Frame Header
                //                                  eth_type[7:0], eth_type[15:8],                                                              // Ethernet Type
                //                                  src_mac[7:0], src_mac[15:8], src_mac[23:16], src_mac[31:24], src_mac[39:32], src_mac[47:40],// Ethernet SRC MAC
                //                                  dst_mac[7:0], dst_mac[15:8], dst_mac[23:16], dst_mac[31:24], dst_mac[39:32], dst_mac[47:40],// Ethernet DST MAC
                //                                  48'b0,lewiz_bcnt                                                                            // Lewiz Reserived
                //                              };
                    //If sending RST Frames, use that data. Otherwise, assemble from internal header data
                    tx_ox2m_out_data        <=  rst2ox_pkt_credit_we && (rst2ox_qqwd_cnter == 2'd1)    ?   rst2ox_send_pkt_data : {
                                                    tx_ox2m_out_header_64_buf[55:48],  tx_ox2m_out_header_64_buf[63:56],                        // TL Msg Header [63:48]
                                                    tloe_header_chan, tloe_header_credit,
                                                    tloe_header_seq_num_ack[5:0],tloe_header_ack, 1'b0, // TLoE Frame Header
                                                    tloe_header_seq_num_ack[13:6],
                                                    tloe_header_seq_num_ack[21:14],
                                                    tloe_header_seq_num[7:0],   // TLoE Frame Header
                                                    tloe_header_seq_num[15:8],
                                                    2'b0, tloe_header_seq_num[21:16],
                                                    tloe_header_vc, 5'b0,           // TLoE Frame Header
                                                    eth_type[7:0], eth_type[15:8],                                                              // Ethernet Type
                                                    src_mac[7:0], src_mac[15:8], src_mac[23:16], src_mac[31:24], src_mac[39:32], src_mac[47:40],// Ethernet SRC MAC
                                                    dst_mac[7:0], dst_mac[15:8], dst_mac[23:16], dst_mac[31:24], dst_mac[39:32], dst_mac[47:40],// Ethernet DST MAC
                                                    48'b0, lewiz_bcnt                                                                           // Lewiz Reserved
                                                };

                    tx_ox2m_out_valid       <=  ox2rst_rst_ctrl_grant   ?   (rst2ox_qqwd_cnter == 2'b1  ?   1'b1 : 1'b0)   :
                                                1'b1;

                    ox2b_rtx_wrdata_wdaddr  <=  ox2b_rtx_wrdata_wdaddr + tx_ox2m_out_valid;
                    tx_local_bcnt           <=  lewiz_bcnt;
                    tx_local_bcnt_valid     <=  1'b1;
                end

                //Payload 1 State: Assemble TLoE payload and store in Pre-TX FIFO
                TX_PLD_1: begin
                    tx_local_bcnt_valid     <=  1'b0;

                    //A CH stuffs
                    if (a_chan_en) begin
                        if (a_opcode <= 3) begin        //has pld
                            if (a_opcode == A_PUT_PARTIAL) begin
                                if (a_size >= 4) begin
                                    tx_ox2m_out_data    <= {a_data[79:0],          // 10-B data Note: Data from software send out to network is expected to be already big endian.
                                                            a_mask[7:0],   a_mask[15:8],    a_mask[23:16],    a_mask[31:24],    a_mask[39:32],    a_mask[47:40],    a_mask[55:48],    a_mask[63:56], // 8-B mask
                                                            a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                                            tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                                            tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                    data_bcnt           <=  data_bcnt - 16'd10;
                                end
                                else begin
                                //  case (a_size)
                                //    4'b0:   tx_ox2m_out_data  <=    { tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48],tloe_frame_mask[63:56],40'b0,a_data[7:0],          // 4-B TLoE mask, 5-B Padding 1-B data
                                //                                        a_mask[7:0],   a_mask[15:8],    a_mask[23:16],    a_mask[31:24],    a_mask[39:32],    a_mask[47:40],    a_mask[55:48],    a_mask[63:56], // 8-B mask
                                //                                        a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                //                                        tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                //                                        tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                //    4'h1:   tx_ox2m_out_data  <=    { tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48],tloe_frame_mask[63:56],32'b0,a_data[15:0],         // 4-B TLoE mask, 4-B Padding 2-B data
                                //                                        a_mask[7:0],   a_mask[15:8],    a_mask[23:16],    a_mask[31:24],    a_mask[39:32],    a_mask[47:40],    a_mask[55:48],    a_mask[63:56], // 8-B mask
                                //                                        a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                //                                        tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                //                                        tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                //    4'h2:   tx_ox2m_out_data  <=    { tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48],tloe_frame_mask[63:56],16'b0,a_data[31:0],         // 4-B TLoE mask, 2-B Padding 4-B data
                                //                                        a_mask[7:0],   a_mask[15:8],    a_mask[23:16],    a_mask[31:24],    a_mask[39:32],    a_mask[47:40],    a_mask[55:48],    a_mask[63:56], // 8-B mask
                                //                                        a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                //                                        tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                //                                        tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                //    4'h3:   tx_ox2m_out_data  <=    { tloe_frame_mask[55:48],tloe_frame_mask[63:56],a_data[63:0],          // 2-B TLoE mask,8-B data
                                //                                        a_mask[7:0],   a_mask[15:8],    a_mask[23:16],    a_mask[31:24],    a_mask[39:32],    a_mask[47:40],    a_mask[55:48],    a_mask[63:56], // 8-B mask
                                //                                        a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                //                                        tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                //                                        tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                //    default:tx_ox2m_out_data  <=    { a_data[79:0],          // 10-B data
                                //                                        a_mask[7:0],   a_mask[15:8],    a_mask[23:16],    a_mask[31:24],    a_mask[39:32],    a_mask[47:40],    a_mask[55:48],    a_mask[63:56], // 8-B mask
                                //                                        a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                //                                        tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                //                                        tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                //  endcase

                                    case (a_size)
                                        //Size 0 (1 Byte)
                                        4'b0:   tx_ox2m_out_data <= {
                                                    72'b0, a_data[7:0],          // 9-B Padding 1-B data
                                                    a_mask[ 7:0 ], a_mask[15:8 ], a_mask[23:16], a_mask[31:24], a_mask[39:32], a_mask[47:40], a_mask[55:48], a_mask[63:56], // 8-B mask
                                                    a_addr[ 7:0 ], a_addr[15:8 ], a_addr[23:16], a_addr[31:24], a_addr[39:32], a_addr[47:40], a_addr[55:48], a_addr[63:56], // 8-B addr
                                                    tx_ox2m_out_header_64_buf[ 7:0 ],   tx_ox2m_out_header_64_buf[15:8 ],  tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                                    tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                                                };

                                        //Size 1 (2 Bytes)
                                        4'h1:   tx_ox2m_out_data <= {
                                                    64'b0,a_data[15:0],                                                                                   // 8-B Padding 2-B data
                                                    a_mask[ 7:0 ], a_mask[15:8 ], a_mask[23:16], a_mask[31:24], a_mask[39:32], a_mask[47:40], a_mask[55:48], a_mask[63:56], // 8-B mask
                                                    a_addr[ 7:0 ], a_addr[15:8 ], a_addr[23:16], a_addr[31:24], a_addr[39:32], a_addr[47:40], a_addr[55:48], a_addr[63:56], // 8-B addr
                                                    tx_ox2m_out_header_64_buf[ 7:0 ],   tx_ox2m_out_header_64_buf[15:8 ],  tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                                    tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                                                };

                                        //Size 2 (4 Bytes)
                                        4'h2:   tx_ox2m_out_data <= {
                                                    48'b0,a_data[31:0],                                                                                                     // 6-B Padding 4-B data
                                                    a_mask[ 7:0 ], a_mask[15:8 ], a_mask[23:16], a_mask[31:24], a_mask[39:32], a_mask[47:40], a_mask[55:48], a_mask[63:56], // 8-B mask
                                                    a_addr[ 7:0 ], a_addr[15:8 ], a_addr[23:16], a_addr[31:24], a_addr[39:32], a_addr[47:40], a_addr[55:48], a_addr[63:56], // 8-B addr
                                                    tx_ox2m_out_header_64_buf[ 7:0 ],   tx_ox2m_out_header_64_buf[15:8 ],  tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                                    tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                                                };

                                        //Size 3 (8 Bytes)
                                        4'h3:   tx_ox2m_out_data <= {
                                                    16'b0,a_data[63:0],                                                                                                     // 2-B Padding,8-B data
                                                    a_mask[ 7:0 ], a_mask[15:8 ], a_mask[23:16], a_mask[31:24], a_mask[39:32], a_mask[47:40], a_mask[55:48], a_mask[63:56], // 8-B mask
                                                    a_addr[ 7:0 ], a_addr[15:8 ], a_addr[23:16], a_addr[31:24], a_addr[39:32], a_addr[47:40], a_addr[55:48], a_addr[63:56], // 8-B addr
                                                    tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                                    tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                                                };

                                        //Size 4+ (16+ Bytes)
                                        default:tx_ox2m_out_data <= {
                                                    a_data[79:0],          // 10-B data
                                                    a_mask[ 7:0 ], a_mask[15:8 ], a_mask[23:16], a_mask[31:24], a_mask[39:32], a_mask[47:40], a_mask[55:48], a_mask[63:56], // 8-B mask
                                                    a_addr[ 7:0 ], a_addr[15:8 ], a_addr[23:16], a_addr[31:24], a_addr[39:32], a_addr[47:40], a_addr[55:48], a_addr[63:56], // 8-B addr
                                                    tx_ox2m_out_header_64_buf[ 7:0 ],   tx_ox2m_out_header_64_buf[15:8 ],  tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                                    tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                                                };
                                    endcase

                                    data_bcnt           <=      16'd0;
                                end
                            end
                            else begin
                                tx_ox2m_out_data    <=    { a_data[143:0],          // 18-B data
                                                            a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                                            tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                                            tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                                data_bcnt           <=  data_bcnt   > 16'd18  ?   data_bcnt - 16'd18    : 16'd0;
                            end
                            tx_ox2m_data_buf_i      <=  a_data;
                            tx_ox2m_out_valid       <=  1'b1;
                        end
                        else begin      //for opcode > 3, has no pld
                        //  tx_ox2m_out_data    <=    { tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48],tloe_frame_mask[63:56],112'b0,          // 14-B Padding, 4B Frame Mask
                            tx_ox2m_out_data    <=    { 144'b0,          // 18-B Padding
                                                        a_addr[7:0],   a_addr[15:8],    a_addr[23:16],    a_addr[31:24],    a_addr[39:32],    a_addr[47:40],    a_addr[55:48],    a_addr[63:56], // 8-B addr
                                                        tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                                                        tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]}; // TL Msg Header
                            data_bcnt           <=    16'd0;
                        end
                    end     //A CH

                    // 20220506
                    if (c_chan_en) begin
                        if (c_opcode == C_RELEASE_DATA | c_opcode == C_PROBE_ACK_DATA) begin
                            tx_ox2m_out_data    <= {
                                c_data[143:0],                                                                                                          // 18-B data
                                c_addr[ 7:0 ], c_addr[15:8 ], c_addr[23:16], c_addr[31:24], c_addr[39:32], c_addr[47:40], c_addr[55:48], c_addr[63:56], // 8-B addr
                                tx_ox2m_out_header_64_buf[ 7:0 ],   tx_ox2m_out_header_64_buf[15:8 ],  tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                            };

                            data_bcnt           <=  (data_bcnt > 16'd18) ?  data_bcnt - 16'd18  :  16'd0;
                            tx_ox2m_data_buf_i  <=  c_data;
                            tx_ox2m_out_valid   <=  1'b1;
                        end

                        else begin
                            tx_ox2m_out_data <= {
                                144'b0,                                                                                                                 // 18-B Padding
                                c_addr[ 7:0 ], c_addr[15:8 ], c_addr[23:16], c_addr[31:24], c_addr[39:32], c_addr[47:40], c_addr[55:48], c_addr[63:56], // 8-B addr
                                tx_ox2m_out_header_64_buf[ 7:0 ],   tx_ox2m_out_header_64_buf[15:8 ],  tx_ox2m_out_header_64_buf[23:16],                // TL Msg Header
                                tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40]                 // TL Msg Header
                            };

                            data_bcnt        <=    16'd0;
                        end
                    end //CH C

                    //-------------- CH E
                    if (e_chan_en) begin    //CH E
                        tx_ox2m_out_data <= {
                            144'b0,          // 18-B Padding for pkt with 0 pld
                            //padding in place of addr
                            8'h00,   8'h00,    8'h00,    8'h00,    8'h00,    8'h00,    8'h00,    8'h00, // 8-B addr
                            //hdr-64-buf contains the TL msg header
                            tx_ox2m_out_header_64_buf[7:0],     tx_ox2m_out_header_64_buf[15:8],   tx_ox2m_out_header_64_buf[23:16],  // TL Msg Header
                            tx_ox2m_out_header_64_buf[31:24],   tx_ox2m_out_header_64_buf[39:32],  tx_ox2m_out_header_64_buf[47:40] // TL Msg Header
                        };

                        data_bcnt       <= 16'd0;

                    end //CH E

                    //Reset Control Packet
                    if (rst2ox_pkt_credit_we && (rst2ox_qqwd_cnter == 2'd2)) begin
                        tx_ox2m_out_data <=  rst2ox_send_pkt_data;
                        data_bcnt        <=  16'd0;
                    end

                    //---- wr addr of RTX buf (for all TX packets)
                    ox2b_rtx_wrdata_wdaddr  <=  ox2b_rtx_wrdata_wdaddr + tx_ox2m_out_valid;
                end     //PLD_1

                //Payload 2 State: Assemble any remaining TLoE payload and store in Pre-TX FIFO
                TX_PLD_2: begin
                    if (a_chan_en && a_opcode <= 3) begin
                        tx_ox2m_out_data    <= (a_opcode == A_PUT_PARTIAL)  ?   {a_data[79:0], tx_ox2m_data_buf_i[255:80]}  :   {a_data[143:0], tx_ox2m_data_buf_i[255:144]};
                        data_bcnt           <=  data_bcnt - 16'd32;
                        tx_ox2m_out_valid   <=  1'b1;
                    end

                    if (c_chan_en && (c_opcode == C_RELEASE_DATA | c_opcode == C_PROBE_ACK_DATA)) begin
                        tx_ox2m_out_data    <= {c_data[143:0], tx_ox2m_data_buf_i[255:144]};
                        data_bcnt           <=  data_bcnt - 16'd32;
                        tx_ox2m_out_valid   <=  1'b1;
                    end

                    ox2b_rtx_wrdata_wdaddr  <=  ox2b_rtx_wrdata_wdaddr + tx_ox2m_out_valid;
                end

                //Frame Mask State: Assemble TLoE Frame mask and store in Pre-TX FIFO
                TX_FMASK: begin
                    //Channel A Mask
                    if (a_chan_en) begin
                        if (a_opcode <= 3) begin
//                      tx_ox2m_out_data    <=  (a_opcode != A_PUT_PARTIAL) ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
//                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[255:144]} :
//                                                    a_size <= 2                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24]}                  :
//                                                    a_size == 3                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
//                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40]}                                                                 :
//                                                    a_size == 4                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
//                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[127:80]}  :   //up to 16B, 6B in here
//                                                    a_size == 5                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
//                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[255:80]}  :   //up to 32B, 22B in here
//                                                    {   tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
//                                                        tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[255:80]};

                            tx_ox2m_out_data    <=  (a_opcode != A_PUT_PARTIAL) ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[255:144]} :   // 8-B TLoE mask, 14-B data
                                                    a_size == 0                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], 48'b0}           :   // 8-B TLoE mask, 6-B Padding
                                                    a_size == 1                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], 48'b0}           :   // 8-B TLoE mask, 6-B Padding
                                                    a_size == 2                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], 48'b0}           :   // 8-B TLoE mask, 6-B Padding
                                                    a_size == 3                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], 48'b0}           :   // 8-B TLoE mask, 6-B Padding
                                                    a_size == 4                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[127:80]}  :   // 8-B TLoE massk, 6-B data
                                                    a_size == 5                 ?   {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                                                     tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[255:80]}  :   // 8-B TLoE mask, 22-B data
                                                    {   tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                        tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], a_data[255:80]};

                            tx_ox2m_out_valid   <=  1'b1;
                        end
                        else begin
                            tx_ox2m_out_data    <=  {   144'b0,
                                                        tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                        tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56],
                                                        48'b0};
                            tx_ox2m_out_valid   <=  1'b1;
                        end
                    end     //CH A

                    //Channel C Mask
                    //20220511
                    if (c_chan_en) begin
                        if (c_opcode == C_RELEASE_DATA | c_opcode == C_PROBE_ACK_DATA)  begin
                            tx_ox2m_out_data    <= {tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                    tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56], c_data[255:144]} ;
                            tx_ox2m_out_valid   <=  1'b1;
                        end
                        else begin
                            tx_ox2m_out_data    <=  {   144'b0,
                                                        tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],
                                                        tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48], tloe_frame_mask[63:56],
                                                        48'b0};
                            tx_ox2m_out_valid   <=  1'b1;
                        end
                    end     // CH C

                    //Channel E Mask
                    // 20220506
                    if (e_chan_en) begin   //CH E
                        tx_ox2m_out_data        <=  //output FMASK
                            {   144'b0,             // 18-B
                                tloe_frame_mask[7:0],  tloe_frame_mask[15:8], tloe_frame_mask[23:16], tloe_frame_mask[31:24],   // 4-B
                                tloe_frame_mask[39:32],tloe_frame_mask[47:40],tloe_frame_mask[55:48],tloe_frame_mask[63:56],    // 4-B
                                48'b0};             // 6-B
                            tx_ox2m_out_valid   <=  1'b1;
                        end     // CH E

                    //Reset Control Packet
                    if (rst2ox_pkt_credit_we && (rst2ox_qqwd_cnter == 2'd0)) begin
                       tx_ox2m_out_data     <=  rst2ox_send_pkt_data;
                       tx_ox2m_out_valid    <=  1'b1;
                    end

                    //------- WR addr rtx buf
                    ox2b_rtx_wrdata_wdaddr  <=  ox2b_rtx_wrdata_wdaddr + tx_ox2m_out_valid;
                end     //FMASK


                //----------------------------------------------------------------//
                //  Retransmission TX States

                TX_RTX_CMD: begin
                end

                TX_RTX_RD: begin
                    tx_send_req                 <=  1'b0;
                //  rtx_cmd_bcnt_buf            <=  (f2ox_rtx_cmd_i[27:12] > 'd32) ?   f2ox_rtx_cmd_i - 'd32  : 'd0;
                    rtx_cmd_bcnt_buf            <=  f2ox_rtx_cmd_i[27:12];
                    ox2b_rtx_rddata_rdaddr      <=  f2ox_rtx_cmd_i[11:0 ];
                    ox2b_rtx_rddata_re_i        <=  1'b1;
                end

                TX_RTX_DATA: begin
                    if (rtx_cmd_bcnt_buf >=   16'd32) begin
                       rtx_cmd_bcnt_buf            <=  rtx_cmd_bcnt_buf - 'd32;
                       ox2b_rtx_rddata_re_i        <=  1'b1;
                       ox2b_rtx_rddata_rdaddr      <=  ox2b_rtx_rddata_rdaddr + 1'b1;
                    end
                    else begin
                       rtx_cmd_bcnt_buf            <=  16'd0;
                       ox2b_rtx_rddata_re_i        <=  1'b0;
                       ox2b_rtx_rddata_rdaddr      <=  ox2b_rtx_rddata_rdaddr;
                    end

                    tx_ox2m_out_valid<=  ox2b_rtx_rddata_re_i;
                end

                //----------------------------------------------------------------//

                //ACK Only Packet State: Assemble and ACK only frame and store in Pre-TX FIFO
                TX_ACKONLY: begin
                    tx_send_req             <=  1'b0;       //CLE 20220420, negate the request

                //  tx_ox2m_out_data        <= {
                //                              tx_ox2m_out_header_64_buf[55:48],  tx_ox2m_out_header_64_buf[63:56],                        // TL Msg Header [63:48]
                //                              tloe_header_chan, tloe_header_credit, tloe_header_seq_num_ack[5:0],tloe_header_ack, 1'b0,   // TLoE Frame Header
                //                              tloe_header_seq_num_ack[13:6], tloe_header_seq_num_ack[21:14], tloe_header_seq_num[7:0],    // TLoE Frame Header
                //                              tloe_header_seq_num[15:8], 2'b0, tloe_header_seq_num[21:16], tloe_header_vc, 5'b0,          // TLoE Frame Header
                //                              eth_type[7:0], eth_type[15:8],                                                              // Ethernet Type
                //                              src_mac[7:0], src_mac[15:8], src_mac[23:16], src_mac[31:24], src_mac[39:32], src_mac[47:40],// Ethernet SRC MAC
                //                              dst_mac[7:0], dst_mac[15:8], dst_mac[23:16], dst_mac[31:24], dst_mac[39:32], dst_mac[47:40],// Ethernet DST MAC
                //                              48'b0,16'd70                                                                                // Lewiz Reserved
                //                           };

                    tx_ox2m_out_data        <= !ack_only_cnt ? {
                                                tx_ox2m_out_header_64_buf[55:48],  tx_ox2m_out_header_64_buf[63:56],                        // TL Msg Header [63:48]
                                                tloe_header_chan, tloe_header_credit, tloe_header_seq_num_ack[5:0],tloe_header_ack, 1'b0,   // TLoE Frame Header
                                                tloe_header_seq_num_ack[13:6], tloe_header_seq_num_ack[21:14], tloe_header_seq_num[7:0],    // TLoE Frame Header
                                                tloe_header_seq_num[15:8], 2'b0, tloe_header_seq_num[21:16], tloe_header_vc, 5'b0,          // TLoE Frame Header
                                                eth_type[7:0], eth_type[15:8],                                                              // Ethernet Type
                                                src_mac[7:0], src_mac[15:8], src_mac[23:16], src_mac[31:24], src_mac[39:32], src_mac[47:40],// Ethernet SRC MAC
                                                dst_mac[7:0], dst_mac[15:8], dst_mac[23:16], dst_mac[31:24], dst_mac[39:32], dst_mac[47:40],// Ethernet DST MAC
                                                48'b0,16'd70                                                                                // Lewiz Reserved
                                               } : 256'b0;

                    tx2rx_updateseq_req     <= (ack_only_cnt == 8'b0)  ? 1'b1 : 1'b0;
                    tx2rx_seq_num           <=  tloe_header_seq_num;  // current local seq number
                    tx_ox2m_out_valid       <= (ack_only_cnt == 8'b11) ? 1'b0 : 1'b1;
                //  tx_ox2m_out_valid       <= (ack_only_cnt == 8'b11) ? 1'b0 : 1'b1;
                    ack_only_cnt            <=  ack_only_cnt + 1'b1;
                    tx_local_bcnt           <=  16'd70;
                    tx_local_bcnt_valid     <= (ack_only_cnt==8'd2)    ? 1'b1 : 1'b0 ;
                    ox2b_rtx_wrdata_wdaddr  <=  ox2b_rtx_wrdata_wdaddr + tx_ox2m_out_valid;
                end // TX_ACKONLY

                //----------------------------------------------------------------//

                //Done State: Complete and clean up
                TX_DONE: begin
                    tx_ox2m_out_valid   <=  1'b0;
                    //tx2rx_seq_num     <=  tloe_header_seq_num ;
                end // TX_DONE

               default: begin end //tx_state    <=  TX_IDLE;
           endcase
        end // else
    end // always


    //TloE Header Encoding
    always @(posedge clk) begin
        if (!rst_) begin
            tloe_header_chan                <=  3'b0;
            tloe_header_credit              <=  5'h08;              // KIT_20220401 was 1F, 1F was too large of a credit for endpoint to handle (maybe)
        //  tloe_header_credit              <=  5'b0;
            tloe_header_ack                 <=  1'b0;
            tloe_header_seq_num_ack         <=  22'b0;
            tloe_header_seq_num             <=  22'b0;
            tloe_header_vc                  <=  3'b0;

            //Reset Control
            ox2rst_rst_ctrl_grant           <=  1'b0;

        end
        else begin
            //for case of RX2TX send req to generate ACK, NACK packets etc via Channel C            //X/
            // for CH E only Master send to slave so its CH and CRED can be 0 (or don't care)       //X/
            //Channel number in TLoE header only needs to be set when advertising its credit count  //</
            tloe_header_chan                <= (rx2tx_send_req && !tx_send_req) ? 3'b011 : 3'b0 ;   //for most CH A and all of CH E

            tloe_header_seq_num             <= (ox2rst_rst_ctrl_grant && tx_header_st) ? tloe_header_seq_num + 22'd1 :
                                                tloe_header_seq_num + tx2rx_updateseq_done;

        //  tloe_header_ack                 <=  rx2tx_send_req ? rx2tx_ack_mode : tloe_header_ack;

            // ProabeAck, ProbeAckData and GrantAck features are assigned ack bit as 1  //X/
        //-/tloe_header_ack                 <=  ((f2ox_tx_header_i[62:60] == TL_CHAN_C) &&
        //-/                                    (f2ox_tx_header_i[59:57] == C_PROBE_ACK || f2ox_tx_header_i[59:57] == C_PROBE_ACK_DATA)) ||
        //-/                                    (f2ox_tx_header_i[62:60] == TL_CHAN_E)                          ?   1'b1 :
        //-/                                    rx2tx_send_req                                                  ?   rx2tx_ack_mode :
        //-/                                //  tloe_header_ack;
        //-/                                    1'b0;

            //ACK bit is set unless RTX is needed (determined by ACK mode from seq_mgr)
            //2022-10-13: Only NACK when needed
            tloe_header_ack                 <= (tx_idle_st)     ? 1'b1 :
                                               (rx2tx_send_req) ? rx2tx_ack_mode :
                                                tloe_header_ack;

            //TODO: update ACK number any time an RX packet is accepted (requires changes in seq_mgr)
            tloe_header_seq_num_ack         <=  rx2tx_send_req  ?   rx2tx_rxack_num :   tloe_header_seq_num_ack;

            // Reset Control
            ox2rst_rst_ctrl_grant           <=  rst2ox_pkt_done          ?  1'b0 :  // negate
                                                rst2ox_rst_ctrl_req      ?  1'b1 :  // assert
                                                ox2rst_rst_ctrl_grant;              // keep
        end
    end

    // Channel A, C & E
    always @(posedge clk) begin
        if (!rst_) begin
            a_source    <=  26'b0;
            a_size      <=  4'b0;
            a_opcode    <=  3'b0;
            a_param     <=  4'b0;
            a_data      <=  256'b0;
            a_corrupt   <=  1'b0;
            a_mask      <=  64'b0;
            a_addr      <=  64'b0;
            a_domain    <=  8'b0;
            a_chan_en   <=  1'b0;   //4'b0;
            a_size_left <=  4'b0;

            // 20220506
            c_chan_en   <=  1'b0;
            c_source    <=  26'b0;
            c_size      <=  4'b0;
            c_opcode    <=  3'b0;
            c_param     <=  4'b0;
            c_data      <=  256'b0;
            c_corrupt   <=  1'b0;
            c_addr      <=  64'b0;
            c_domain    <=  8'b0;
            c_size_left <=  4'b0;

            // 20220503 CLE
            e_chan_en   <=  1'b0;
            e_sink      <=  26'b0;
        end
        else begin
            case (tx_state)
                    TX_IDLE: begin
                         a_source    <= 26'b0;
                         a_size      <= 4'b0;
                         a_opcode    <= 3'b0;
                         a_param     <= 4'b0;
                         a_data      <= 256'b0;
                         a_corrupt   <= 1'b0;
                         a_mask      <= 64'b0;
                         a_addr      <= 64'b0;
                         a_domain    <= 8'b0;
                         a_chan_en   <= 1'b0;
                         a_size_left <=  4'b0;

                         // 20220506
                         c_chan_en   <= 1'b0;
                         c_source    <= 26'b0;
                         c_size      <= 4'b0;
                         c_opcode    <= 3'b0;
                         c_param     <= 4'b0;
                         c_data      <= 256'b0;
                         c_corrupt   <= 1'b0;
                         c_addr      <= 64'b0;
                         c_domain    <= 8'b0;
                         c_size_left <=  4'b0;

                        // -- only need for control signals
                        e_chan_en   <=  1'b0;
                        e_sink      <=  26'b0;
                    end

                    TX_RD_FIFO: begin
                    end

                    TX_DECODE_1: begin
                        if (f2ox_tx_header_i[62:60] == TL_CHAN_A) begin
                           a_source     <=  f2ox_tx_header_i[25:0];
                           a_corrupt    <=  f2ox_tx_header_i[38];
                           a_domain     <=  f2ox_tx_header_i[47:40];
                           a_size       <=  f2ox_tx_header_i[51:48];
                           a_size_left  <=  f2ox_tx_header_i[51:48];
                           a_param      <=  f2ox_tx_header_i[55:52];
                           a_opcode     <=  f2ox_tx_header_i[59:57];
                           a_chan_en    <=  1'b1;
                        end

                        // 20220506
                        else if (f2ox_tx_header_i[62:60] == TL_CHAN_C) begin
                           c_source     <=  f2ox_tx_header_i[25:0];
                           c_corrupt    <=  f2ox_tx_header_i[38];
                           c_domain     <=  f2ox_tx_header_i[47:40];
                           c_size       <=  f2ox_tx_header_i[51:48];
                           c_size_left  <=  f2ox_tx_header_i[51:48];
                           c_param      <=  f2ox_tx_header_i[55:52];
                           c_opcode     <=  f2ox_tx_header_i[59:57];
                           c_chan_en    <=  1'b1;
                        end

                        //CLE, 20220503 - add CHAN_E
                        else if (f2ox_tx_header_i[62:60] == TL_CHAN_E) begin
                           e_sink       <=  f2ox_tx_header_i[25:0];
                           e_chan_en    <=  1'b1 ;
                        end
                    end

                    TX_DECODE_2: begin
                        if (a_chan_en) begin
                            a_addr          <=  f2ox_tx_addr_i;
                            a_mask          <=  f2ox_tx_mask_i;
                            a_size_left     <=  a_size_left >= 5   ?   a_size_left -1   : a_size_left;
                        end

                        // 20220506
                        else if (c_chan_en) begin
                            c_addr          <=  f2ox_tx_addr_i;
                            c_size_left     <=  c_size_left >= 5   ?   c_size_left -1   : c_size_left;
                        end
                    end

                    TX_HEADER: begin
                        if (a_chan_en) begin
                        //  if (|a_mask[31:0])
                        //  begin
                        //  end

                            //getting data pld and determine remaining qqwd
                            a_data          <=  f2ox_tx_data_i;
                            a_size_left     <=  a_size_left >= 5   ?   a_size_left -1   : a_size_left;
                        end

                        // 20220506
                        else if (c_chan_en) begin
                        //  if (|a_mask[31:0])
                        //  begin
                        //  end

                            //getting data pld and determine remaining qqwd
                            c_data          <=  f2ox_tx_data_i;
                            c_size_left     <=  c_size_left >= 5   ?   c_size_left -1   : c_size_left;
                        end
                    end

                    TX_PLD_1: begin
                                      if (a_chan_en) begin
                                          a_data          <=  a_size >= 5   ?   f2ox_tx_data_i  :   a_data;
                                      end

                                      // 20220506
                                      else if (c_chan_en) begin
                                          c_data          <=  c_size >= 5   ?   f2ox_tx_data_i  :   c_data;
                                      end
                                    end
                   TX_PLD_2: begin
                                    end
                   TX_FMASK: begin
                                    end
                   TX_RTX_CMD: begin
                                    end
                   TX_RTX_RD: begin
                                    end
                   TX_RTX_DATA: begin
                                    end
                   TX_ACKONLY: begin
                                    end
                   TX_DONE: begin
                                    end
                   default: begin end//tx_state    <=  TX_IDLE;
            endcase
        end //else
    end //always


    // Channel C    --- 20220506, do CH C in same block as others
    // always @(posedge clk)
    // begin
    //  if (!rst_)
    //  begin
    //      c_source    <=  26'b0;
    //      c_size      <=  4'b0;
    //      c_opcode    <=  3'b0;
    //      c_param     <=  4'b0;
    //      c_data      <=  256'b0;
    //      c_corrupt   <=  1'b0;
    //      c_addr      <=  64'b0;
    //      c_domain    <=  8'b0;
    //      c_size_left <=  4'b0;
    //      c_chan_en   <=  1'b0;
    //  end else begin
    //  end
    //end //Always


    // Channel E    --- 20220503, do CH E in same block as others. CH E only has 1 qwd of header info
    //always @(posedge clk)
    //begin
    //  if (!rst_)
    //  begin
    //      e_chan_en   <=  1'b0;
    //      e_sink      <=  26'b0;
    //  end else begin
    //  end
    //end //always


    //-------- ??? Need to add SYNOPSYS ON/OFF for FPGA

    reg [12*8:0] ascii_tx_state;

    always@(tx_state) begin
        case(tx_state)
             TX_IDLE    : ascii_tx_state = "TX_IDLE"      ;
             TX_RD_FIFO : ascii_tx_state = "TX_RD_FIFO"   ;
             TX_DECODE_1: ascii_tx_state = "TX_DECODE_1"  ;
             TX_DECODE_2: ascii_tx_state = "TX_DECODE_2"  ;
             TX_HEADER  : ascii_tx_state = "TX_HEADER"    ;
             TX_PLD_1   : ascii_tx_state = "TX_PLD_1"     ;
             TX_PLD_2   : ascii_tx_state = "TX_PLD_2"     ;
             TX_FMASK   : ascii_tx_state = "TX_FMASK"     ;
             TX_RTX_CMD : ascii_tx_state = "TX_RTX_CMD"   ;
             TX_RTX_RD : ascii_tx_state =  "TX_RTX_RD"   ;
             TX_RTX_DATA: ascii_tx_state = "TX_RTX_DATA"  ;
             TX_ACKONLY : ascii_tx_state = "TX_ACKONLY"  ;
             TX_DONE    : ascii_tx_state = "TX_DONE"      ;
        endcase
    end
endmodule
