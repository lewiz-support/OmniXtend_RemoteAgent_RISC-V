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

module OX_CORE
    #(  parameter  NOC_DATA_WIDTH   = 64,
        parameter  TL_DATA_WIDTH    = 256,
        parameter  TL_HEADER_WIDTH  = 64,
        parameter  SRC_MAC          = 48'h001232_FFFFF0,
        parameter  DST_MAC          = 48'h000000_000000)
    (
        input                           clk                     ,
        input                           rst_                    ,
        input                           prb_ack_mode            ,   // config signal    (Pulse)
        input                           lewiz_noc_mode          ,

        //TX Path, NOC In
        input                           noc_in_valid            ,
        input      [NOC_DATA_WIDTH-1:0] noc_in_data             ,
        output                          noc_in_ready            ,

        //RX Path, NOC Out
        input                           noc_out_ready           ,
        output                          noc_out_valid           ,
        output     [NOC_DATA_WIDTH-1:0] noc_out_data            ,

        //TX Path, LMAC Out
        input                           m2ox_tx_fifo_full       ,
        input      [12:0]               m2ox_tx_fifo_wrused     ,
        output                          ox2m_tx_we              ,
        output     [255:0]              ox2m_tx_data            ,
      //output     [31:0]               ox2m_tx_be              ,   //(optional) Byte enable

        //RX Path, LMAC In
        input      [63:0]               m2ox_rx_ipcs_data       ,
        input                           m2ox_rx_ipcs_empty      ,
        input      [6:0]                m2ox_rx_ipcs_usedword   ,
        output                          ox2m_rx_ipcs_rden       ,

        input      [255:0]              m2ox_rx_pkt_data        ,
        input                           m2ox_rx_pkt_empty       ,
        input      [6:0]                m2ox_rx_pkt_usedword    ,
        output                          ox2m_rx_pkt_rden        ,
        output                          ox2m_rx_pkt_rd_cycle
    );

    //================================================================//
    //  Sequencing/Retransmission Management Signals
    //    Between TX and RX Paths

    wire                            tx2rx_updateseq_req         ;
    wire        [21:0]              tx2rx_seq_num               ;
    wire                            tx2rx_updateseq_done        ;

    wire                            rx2tx_updateack_req         ;
    wire        [21:0]              rx2tx_new_ack_num           ;
    wire        [3:0]               rx2tx_free_entries          ;
    wire        [3:0]               rx2tx_rtx_entries           ;
    wire                            rx2tx_rtx_req               ;
    wire                            rx2tx_rtxreq_done           ;
    wire                            rx2tx_updateack_done        ;

    wire                            rx2tx_send_req              ;
    wire                            rx2tx_ack_mode              ;
    wire        [21:0]              rx2tx_rxack_num             ;
    wire                            rx2tx_sendreq_done          ;

    wire                            tx_req                      ;
    wire                            tx_done                     ;
    wire                            ackmtotx_busy               ;


    //================================================================//
    //  Cache Coherency Manager Signals

    wire                            tl2coh_tx_acquire_req       ;   // from TL Logic    (Event)
    wire                            tl2coh_tx_acquire_gen_done  ;   // from TL Logic    (Pulse)
    wire                            rx2tx_rcv_tlgnt             ;   // from TL RX Logic (Event)
    wire                            tl2coh_tx_gntack_gen_done   ;   // from TL Logic    (Pulse)
    wire                            coh2tl_tx_acquire_req_ack   ;   // to TL Logic      (Pulse)
    wire                            coh2tl_tx_acquire_gen_en    ;   // to TL Logic      (Event)
    wire                            tx2rx_rcv_tlgnt_ack         ;   // to TL Logic      (Pulse)
    wire                            coh2tl_gntack_gen_en        ;   // to TL Logic      (Event)

    wire                            tl2coh_rx_probe_req         ;   // from TL Logic    (Event)
    wire                            tl2coh_rx_prb_displ_gen_ack ;   // from TL Logic    (Pulse)
    wire                            tl2coh_tx_probe_req_done    ;   // from TL Logic    (pulse)
    wire                            coh2tl_rx_probe_req_ack     ;   // to TL Logic      (Pulse)
    wire                            coh2tl_rx_prb_displ_gen_en  ;   // to TL Logic      (Event)
    wire                            coh2tl_tx_prb_flush_wait    ;   // to TL Logic      (Event)
    wire                            coh2tl_prb_ack_w_data       ;   // to TL Logic      (Event)
    wire                            coh2tl_prb_ack_no_data      ;   // to TL Logic      (Event)

    wire                            tl2coh_tx_release_req       ;   // from TL Logic    (Event)
    wire                            tl2coh_rx_release_ack_rcvd  ;   // from TL Logic    (Pulse)
    wire                            tl2coh_tx_release_req_ack   ;   // to TL Logic      (Pulse)

    wire       [3:0]                b_size                      ;   // to Coherent MGR for ProbeAck TL message
    wire       [25:0]               b_source                    ;   // from TL2N Probe TL message
    wire       [63:0]               b_address                   ;   // from TL2N Probe TL message
    wire       [3:0]                c_prb_ack_size              ;   // to N2TL for ProbeAck TL message
    wire       [25:0]               c_prb_ack_source            ;   // to N2TL for ProbeAck TL message
    wire       [63:0]               c_prb_ack_address           ;   // to N2TL for ProbeAck TL message
    wire       [25:0]               d_sink                      ;   // from TL2N for GrantAck TL message
    wire       [25:0]               e_sink                      ;   // to N2TL for GrantAck TL message


    ////????
    wire                            oxm_rtx_done                ;   // control signal for ProbeBlock to RTX_MGR from M2OX


    //================================================================//
    //  OX Transmit Path

    OX_TX_PATH #(
        .DATA_WIDTH (NOC_DATA_WIDTH ),
        .SRC_MAC    (SRC_MAC        ),
        .DST_MAC    (DST_MAC        ))
    OT1(
        .clk                        (clk),
        .rst_                       (rst_),

        //TX Path, NOC In
        .noc_in_valid               (noc_in_valid),
        .noc_in_data                (noc_in_data),
        .noc_in_ready               (noc_in_ready),

        //TX Path, LMAC Out
        .m2ox_tx_fifo_full          (m2ox_tx_fifo_full),
        .m2ox_tx_fifo_wrused        (m2ox_tx_fifo_wrused),
        .ox2m_tx_we                 (ox2m_tx_we),
        .ox2m_tx_data               (ox2m_tx_data),
    //  .ox2m_tx_be                 (), //(optional) Byte enable


        //Sequencing/Retransmission Management
        .tx2rx_updateseq_req        (tx2rx_updateseq_req),
        .tx2rx_seq_num              (tx2rx_seq_num),
        .tx2rx_updateseq_done       (tx2rx_updateseq_done),

        .rx2tx_updateack_req        (rx2tx_updateack_req),
        .rx2tx_new_ack_num          (rx2tx_new_ack_num),
        .rx2tx_free_entries         (rx2tx_free_entries),
        .rx2tx_rtx_entries          (rx2tx_rtx_entries),
        .rx2tx_rtx_req              (rx2tx_rtx_req),
        .rx2tx_rtxreq_done          (rx2tx_rtxreq_done),
        .rx2tx_updateack_done       (rx2tx_updateack_done),

        .rx2tx_send_req             (rx2tx_send_req),
        .rx2tx_ack_mode             (rx2tx_ack_mode),
        .rx2tx_rxack_num            (rx2tx_rxack_num),
        .rx2tx_sendreq_done         (rx2tx_sendreq_done),

        .tx_send_req                (tx_req),                      // o- to check if tx is requesting to transmit normal packet
        .tx_done                    (tx_done),                     // o- to indicate tx_transmit is done
        .ackmtotx_busy              (ackmtotx_busy),               // o- indicate ack-mgn is busy


        //Interface to/from Coherent Mgr
        .coh2tl_tx_acquire_req_ack  (coh2tl_tx_acquire_req_ack),   // from Coherent MGR to negate acquire request
        .coh2tl_tx_acquire_gen_en   (coh2tl_tx_acquire_gen_en),    // from Coherent MGR to generate TL AcquireBlock packet
        .coh2tl_gntack_gen_en       (coh2tl_gntack_gen_en),        // from Coherent MGR to generate a GrantAck packet

        .tl2coh_tx_acquire_req      (tl2coh_tx_acquire_req),       // to Coherent MGR
        .tl2coh_tx_acquire_gen_done (tl2coh_tx_acquire_gen_done),  // to Coherent MGR
        .tl2coh_tx_gntack_gen_done  (tl2coh_tx_gntack_gen_done),   // to Coherent MGR

        .coh2tl_tx_prb_flush_wait   (coh2tl_tx_prb_flush_wait),    // from Coherent MGR
        .coh2tl_prb_ack_w_data      (coh2tl_prb_ack_w_data),       // from Coherent MGR
        .coh2tl_prb_ack_no_data     (coh2tl_prb_ack_no_data),      // from Coherent MGR
        .tl2coh_tx_probe_req_done   (tl2coh_tx_probe_req_done),    // to Coherent MGR

        .tl2coh_tx_release_req_ack  (tl2coh_tx_release_req_ack),   // from Coherent MGR to negate release request
        .tl2coh_tx_release_req      (tl2coh_tx_release_req),       // to Coherent MGR


        //Interface to/from N2TL
        .c_prb_ack_size             (c_prb_ack_size),              // to N2TL for ProbeAck TL message
        .c_prb_ack_source           (c_prb_ack_source),            // to N2TL for ProbeAck TL message
        .c_prb_ack_address          (c_prb_ack_address),           // to N2TL for ProbeAck TL message
        .e_sink                     (e_sink),                      // to N2TL for GrantAck TL message

        .lewiz_noc_mode             (lewiz_noc_mode),

        .oxm_rtx_done               (oxm_rtx_done)                 // i-1
    );


    //================================================================//
    //  OX Receive Path

    OX_RX_PATH
    #(  .TL_HEADER_WIDTH(TL_HEADER_WIDTH),
        .TL_DATA_WIDTH(TL_DATA_WIDTH),
        .NOC_DATA_WIDTH(NOC_DATA_WIDTH))
    OR1 (
        .clk                        (clk),
        .rst_                       (rst_),

        //RX Path, LMAC In
        .m2ox_rx_ipcs_data          (m2ox_rx_ipcs_data),
        .m2ox_rx_ipcs_empty         (m2ox_rx_ipcs_empty),
        .m2ox_rx_ipcs_usedword      (m2ox_rx_ipcs_usedword),
        .ox2m_rx_ipcs_rden          (ox2m_rx_ipcs_rden),

        .m2ox_rx_pkt_data           (m2ox_rx_pkt_data),
        .m2ox_rx_pkt_empty          (m2ox_rx_pkt_empty),
        .m2ox_rx_pkt_usedword       (m2ox_rx_pkt_usedword),
        .ox2m_rx_pkt_rden           (ox2m_rx_pkt_rden),
        .ox2m_rx_pkt_rd_cycle       (ox2m_rx_pkt_rd_cycle),

        //RX Path, NOC Out
        .noc_out_valid              (noc_out_valid),
        .noc_out_data               (noc_out_data),
        .noc_out_ready              (noc_out_ready),


        //Sequencing/Retransmission Management
        .tx2rx_updateseq_req        (tx2rx_updateseq_req),
        .tx2rx_seq_num              (tx2rx_seq_num),
        .tx2rx_updateseq_done       (tx2rx_updateseq_done),

        .rx2tx_updateack_req        (rx2tx_updateack_req),
        .rx2tx_new_ack_num          (rx2tx_new_ack_num),
        .rx2tx_free_entries         (rx2tx_free_entries),
        .rx2tx_rtx_entries          (rx2tx_rtx_entries),
        .rx2tx_rtx_req              (rx2tx_rtx_req),
        .rx2tx_rtxreq_done          (rx2tx_rtxreq_done),
        .rx2tx_updateack_done       (rx2tx_updateack_done),

        .rx2tx_send_req             (rx2tx_send_req),
        .rx2tx_ack_mode             (rx2tx_ack_mode),
        .rx2tx_rxack_num            (rx2tx_rxack_num),
        .rx2tx_sendreq_done         (rx2tx_sendreq_done),

        .tx_req                     (tx_req),                       //  i- to check if tx is requesting to transmit normal packet
        .tx_done                    (tx_done),                      //  i- to indicate tx_transmit is done
        .ackmtotx_busy              (ackmtotx_busy),                //  o- indicate ack-mgn is busy

        //Interface to Coherent Mgr
        .tx2rx_rcv_tlgnt_ack        (tx2rx_rcv_tlgnt_ack),          // if 1, coherent mgr ACK TL Logic TL GNT indication
        .rx2tx_rcv_tlgnt            (rx2tx_rcv_tlgnt),              // if 1, TL Logic seen a TL GNT for ACQUIRE_REQL

        .coh2tl_rx_probe_req_ack    (coh2tl_rx_probe_req_ack)        ,
        .coh2tl_rx_prb_displ_gen_en (coh2tl_rx_prb_displ_gen_en)     ,
        .coh2tl_prb_ack_w_data      (coh2tl_prb_ack_w_data)          ,
        .coh2tl_prb_ack_no_data     (coh2tl_prb_ack_no_data)         ,
        .tl2coh_rx_probe_req        (tl2coh_rx_probe_req)            ,
        .tl2coh_rx_prb_displ_gen_ack(tl2coh_rx_prb_displ_gen_ack)    ,

        .tl2coh_rx_release_ack_rcvd (tl2coh_rx_release_ack_rcvd),   // to Coherent MGR

        .b_size                     (b_size),                       // to Coherent MGR for ProbeAck TL message
        .b_source                   (b_source),                     // to Coherent MGR for ProbeAck TL message
        .b_address                  (b_address),                    // to Coherent MGR for ProbeAck TL message
        .d_sink                     (d_sink),                       // to coherent mgr for GrantAck TL message

        .oxm_rtx_done               (oxm_rtx_done)                  // o-1
    );


    //================================================================//
    //  Cache Coherency Manager

    COHERENT_MGR COHERENT_MGR1(
        .clk                        (clk)                            ,
        .reset_                     (rst_)                           ,

        //TL Aquire SM
        .tl2coh_tx_acquire_req      (tl2coh_tx_acquire_req)          ,
        .tl2coh_tx_acquire_gen_done (tl2coh_tx_acquire_gen_done)     ,
        .rx2tx_rcv_tlgnt            (rx2tx_rcv_tlgnt)                ,
        .tl2coh_tx_gntack_gen_done  (tl2coh_tx_gntack_gen_done)      ,
        .coh2tl_tx_acquire_req_ack  (coh2tl_tx_acquire_req_ack)      ,
        .coh2tl_tx_acquire_gen_en   (coh2tl_tx_acquire_gen_en)       ,
        .tx2rx_rcv_tlgnt_ack        (tx2rx_rcv_tlgnt_ack)            ,
        .coh2tl_gntack_gen_en       (coh2tl_gntack_gen_en)           ,

        //TL Probe SM
        .tl2coh_rx_probe_req        (tl2coh_rx_probe_req)            ,
        .tl2coh_rx_prb_displ_gen_ack(tl2coh_rx_prb_displ_gen_ack)    ,
        .tl2coh_tx_probe_req_done   (tl2coh_tx_probe_req_done)       ,
        .prb_ack_mode               (prb_ack_mode)                   ,
        .coh2tl_rx_probe_req_ack    (coh2tl_rx_probe_req_ack)        ,
        .coh2tl_rx_prb_displ_gen_en (coh2tl_rx_prb_displ_gen_en)     ,
        .coh2tl_tx_prb_flush_wait   (coh2tl_tx_prb_flush_wait)       ,
        .coh2tl_prb_ack_w_data      (coh2tl_prb_ack_w_data)          ,
        .coh2tl_prb_ack_no_data     (coh2tl_prb_ack_no_data)         ,

        //TL Release SM
        .tl2coh_tx_release_req      (tl2coh_tx_release_req)          ,
        .tl2coh_rx_release_ack_rcvd (tl2coh_rx_release_ack_rcvd)     ,
        .tl2coh_tx_release_req_ack  (tl2coh_tx_release_req_ack)      ,

        //for GrantAck and ProbeAck TL message
        .b_size                     (b_size)                         ,   // from TL2N for ProbeAck TL message
        .b_source                   (b_source)                       ,   // from TL2N for ProbeAck TL message
        .b_address                  (b_address)                      ,   // from TL2N for ProbeAck TL message
        .d_sink                     (d_sink)                         ,   // from TL2N for GrantAck TL message
        .c_prb_ack_size             (c_prb_ack_size)                 ,   // to N2TL for ProbeAck TL message
        .c_prb_ack_source           (c_prb_ack_source)               ,   // to N2TL for ProbeAck TL message
        .c_prb_ack_address          (c_prb_ack_address)              ,   // to N2TL for ProbeAck TL message
        .e_sink                     (e_sink)                             // to N2TL for GrantAck TL message
    );

endmodule
