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

module OX_RX_PATH
    #(  parameter TL_HEADER_WIDTH   =   64,
        parameter TL_DATA_WIDTH     =   256,
        parameter NOC_DATA_WIDTH    =   64,
        parameter RX_HEADER_PTR     =   13,
        parameter RX_ADDR_PTR       =   13,
        parameter RX_MASK_PTR       =   13,
        parameter RX_DATA_PTR       =   14,
        parameter RX_BCNT_PTR       =   13   )
    (
        input                           clk                         ,
        input                           rst_                        ,

        //RX Path NOC Out
        input                           noc_out_ready               ,
        output                          noc_out_valid               ,
        output     [NOC_DATA_WIDTH-1:0] noc_out_data                ,

        //RX Path LMAC In
        input      [63:0]               m2ox_rx_ipcs_data           ,
        input                           m2ox_rx_ipcs_empty          ,
        input      [6:0]                m2ox_rx_ipcs_usedword       ,
        output                          ox2m_rx_ipcs_rden           ,

        input      [255:0]              m2ox_rx_pkt_data            ,
        input                           m2ox_rx_pkt_empty           ,
        input      [6:0]                m2ox_rx_pkt_usedword        ,
        output                          ox2m_rx_pkt_rden            ,
        output                          ox2m_rx_pkt_rd_cycle        ,

        //seq_mgr Interface
        input                           tx2rx_updateseq_req         ,
        input      [21:0]               tx2rx_seq_num               ,
        output                          tx2rx_updateseq_done        ,

        output                          rx2tx_updateack_req         ,
        output     [21:0]               rx2tx_new_ack_num           ,
        output     [3:0]                rx2tx_free_entries          ,
        output     [3:0]                rx2tx_rtx_entries           ,
        output                          rx2tx_rtx_req               ,
        input                           rx2tx_rtxreq_done           ,
        input                           rx2tx_updateack_done        ,

        output                          rx2tx_send_req              ,
        output                          rx2tx_ack_mode              ,
        output     [21:0]               rx2tx_rxack_num             ,
        input                           rx2tx_sendreq_done          ,

        input                           tx_req                      ,
        input                           tx_done                     ,
        output                          ackmtotx_busy               ,

        //Interface to/from Coherent Mgr
        input                           tx2rx_rcv_tlgnt_ack         ,   // if 1, coherent mgr ACK TL Logic TL GNT indication
        output                          rx2tx_rcv_tlgnt             ,   // if 1, TL Logic seen a TL GNT for ACQUIRE_REQ

        input                           coh2tl_rx_probe_req_ack     ,
        input                           coh2tl_rx_prb_displ_gen_en  ,
        input                           coh2tl_prb_ack_w_data       ,
        input                           coh2tl_prb_ack_no_data      ,
        output                          tl2coh_rx_probe_req         ,
        output                          tl2coh_rx_prb_displ_gen_ack ,

        output                          tl2coh_rx_release_ack_rcvd  ,

        output     [3:0]                b_size                      ,   // to Coherent MGR for ProbeAck TL message
        output     [25:0]               b_source                    ,   // to Coherent MGR for ProbeAck TL message
        output     [63:0]               b_address                   ,   // to Coherent MGR for ProbeAck TL message
        output     [25:0]               d_sink                      ,   // to Coherent MGR for GrantAck TL message

        output                          oxm_rtx_done                    // control signal for ProbeBlock to RTX_MGR
    );


//  RX Path to/from FIFO
    // NOC side
        // RX Header FIFO
    wire        [63:0]              f2tl_rx_header_i            ;
    wire                            f2tl_rx_header_empty_i      ;
    wire                            tl2f_rx_header_re_i         ;
    wire        [RX_HEADER_PTR-1:0] f2tl_rx_header_rdusedw_i    ;
        // RX Addr FIFO
    wire        [63:0]              f2tl_rx_addr_i              ;
    wire                            f2tl_rx_addr_empty_i        ;
    wire                            tl2f_rx_addr_re_i           ;
    wire        [RX_ADDR_PTR-1:0]   f2tl_rx_addr_rdusedw_i      ;
        // RX Mask FIFO
    wire        [63:0]              f2tl_rx_mask_i              ;
    wire                            f2tl_rx_mask_empty_i        ;
    wire                            tl2f_rx_mask_re_i           ;
    wire        [RX_MASK_PTR-1:0]   f2tl_rx_mask_rdusedw_i      ;
        // RX Data FIFO
    wire        [255:0]             f2tl_rx_data_i              ;
    wire                            f2tl_rx_data_empty_i        ;
    wire                            tl2f_rx_data_re_i           ;
    wire        [RX_DATA_PTR-1:0]   f2tl_rx_data_rdusedw_i      ;
        // RX BCNT FIFO
    wire        [15:0]              f2tl_rx_bcnt_i              ;
    wire                            f2tl_rx_bcnt_empty_i        ;
    wire                            tl2f_rx_bcnt_re_i           ;
    wire        [RX_BCNT_PTR-1:0]   f2tl_rx_bcnt_rdusedw_i      ;
    // LMAC side
        // RX Header FIFO
    wire        [63:0]              ox2f_rx_header_i            ;
    wire                            ox2f_rx_header_we_i         ;
    wire                            f2ox_rx_header_full_i       ;
    wire        [RX_HEADER_PTR-1:0] f2ox_rx_header_wrusedw_i    ;
        // RX Addr FIFO
    wire        [63:0]              ox2f_rx_addr_i              ;
    wire                            ox2f_rx_addr_we_i           ;
    wire                            f2ox_rx_addr_full_i         ;
    wire        [RX_ADDR_PTR-1:0]   f2ox_rx_addr_wrusedw_i      ;
        // RX Mask FIFO
    wire        [63:0]              ox2f_rx_mask_i              ;
    wire                            ox2f_rx_mask_we_i           ;
    wire                            f2ox_rx_mask_full_i         ;
    wire        [RX_MASK_PTR-1:0]   f2ox_rx_mask_wrusedw_i      ;
        // RX Data FIFO
    wire        [255:0]             ox2f_rx_data_i              ;
    wire                            ox2f_rx_data_we_i           ;
    wire                            f2ox_rx_data_full_i         ;
    wire        [RX_DATA_PTR-1:0]   f2ox_rx_data_wrusedw_i      ;
        // RX BCNT FIFO
    wire        [15:0]              ox2f_rx_bcnt_i              ;
    wire                            ox2f_rx_bcnt_we_i           ;
    wire                            f2ox_rx_bcnt_full_i         ;
    wire        [RX_BCNT_PTR-1:0]   f2ox_rx_bcnt_wrusedw_i      ;


    wire        [21:0]              oxm2ackm_new_ack_num        ;
    wire        [21:0]              oxm2ackm_new_seq_num        ;
    wire                            oxm2ackm_chk_req            ;
    wire                            oxm2ackm_ack                ;
    wire                            oxm2ackm_accept             ;
    wire                            oxm2ackm_done               ;
    wire                            oxm2ackm_busy               ;
    wire                            rx_done                     ;

    wire                            ox2tl_aquire_gnt            ;
    wire                            ox2tl_release_ack           ;
    wire                            ox2tl_acc_ack               ;
    wire                            ox2tl_acc_ack_data          ;
    wire                            ox2tl_probe                 ;

    //TileLink to NOC Module
    TL2N #(
    	.TL_HEADER_WIDTH(TL_HEADER_WIDTH),
        .TL_DATA_WIDTH(TL_DATA_WIDTH),
        .NOC_DATA_WIDTH(NOC_DATA_WIDTH))
    TL2N (
        .clk                       (clk),
        .reset_                    (rst_),

        //To NOC_MASTER
        .noc_out_ready                  (noc_out_ready),    //i-1
        .noc_out_valid                  (noc_out_valid),    //o-1
        .noc_out_data                   (noc_out_data),     //o-NOC_DATA_WIDTH



        // INPUT from FIFO
        .f2tl_rx_header_i               (f2tl_rx_header_i),
        .f2tl_rx_header_empty_i         (f2tl_rx_header_empty_i),
        .f2tl_rx_addr_i                 (f2tl_rx_addr_i),
        .f2tl_rx_addr_empty_i           (f2tl_rx_addr_empty_i),
        .f2tl_rx_mask_i                 (f2tl_rx_mask_i),
        .f2tl_rx_mask_empty_i           (f2tl_rx_mask_empty_i),
        .f2tl_rx_data_i                 (f2tl_rx_data_i),
        .f2tl_rx_data_empty_i           (f2tl_rx_data_empty_i),
        .f2tl_rx_bcnt_i                 (f2tl_rx_bcnt_i),
        .f2tl_rx_bcnt_empty_i           (f2tl_rx_bcnt_empty_i),

        // OUTPUT to FIFO
        .tl2f_rx_header_re_i            (tl2f_rx_header_re_i),
        .tl2f_rx_addr_re_i              (tl2f_rx_addr_re_i),
        .tl2f_rx_mask_re_i              (tl2f_rx_mask_re_i),
        .tl2f_rx_data_re_i              (tl2f_rx_data_re_i),
        .tl2f_rx_bcnt_re_i              (tl2f_rx_bcnt_re_i),


        //Interface to Coherent Mgr
        .tx2rx_rcv_tlgnt_ack            (tx2rx_rcv_tlgnt_ack),
        .rx2tx_rcv_tlgnt                (rx2tx_rcv_tlgnt),

        .coh2tl_rx_probe_req_ack        (coh2tl_rx_probe_req_ack)        ,
        .coh2tl_rx_prb_displ_gen_en     (coh2tl_rx_prb_displ_gen_en)     ,
        .coh2tl_prb_ack_w_data          (coh2tl_prb_ack_w_data),
        .coh2tl_prb_ack_no_data         (coh2tl_prb_ack_no_data),
        .tl2coh_rx_probe_req            (tl2coh_rx_probe_req),
        .tl2coh_rx_prb_displ_gen_ack    (tl2coh_rx_prb_displ_gen_ack),

        .tl2coh_rx_release_ack_rcvd     (tl2coh_rx_release_ack_rcvd),

        .b_size                         (b_size),
        .b_source                       (b_source),
        .b_address                      (b_address),
        .d_sink                         (d_sink),

        //Seq Mgn (from M2OX)
        .ox2tl_aquire_gnt               (ox2tl_aquire_gnt),                     // i-1
        .ox2tl_release_ack              (ox2tl_release_ack),                    // i-1
        .ox2tl_probe                    (ox2tl_probe),                          // i-1
        .ox2tl_acc_ack_data             (ox2tl_acc_ack_data),                   // i-1
        .ox2tl_acc_ack                  (ox2tl_acc_ack)                         // i-1
    );


    //Header FIFO
    fifo_nx64 #(.DEPTH(8192), .PTR(RX_HEADER_PTR)) rx_header_fifo_8kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (ox2f_rx_header_we_i),      //i-1,   Write enable
        .wrdata     (ox2f_rx_header_i),         //i-64,  Write data in
        .wrfull     (f2ox_rx_header_full_i),    //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2ox_rx_header_wrusedw_i), //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (tl2f_rx_header_re_i),      //i-1,   Read enable
        .rddata     (f2tl_rx_header_i),         //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (DATA AVAILABLE FOR READ is == DEPTH)
        .rdempty    (f2tl_rx_header_empty_i),   //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2tl_rx_header_rdusedw_i), //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Address FIFO
    fifo_nx64 #(.DEPTH(8192), .PTR(RX_ADDR_PTR)) rx_addr_fifo_8kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (ox2f_rx_addr_we_i),        //i-1,   Write enable
        .wrdata     (ox2f_rx_addr_i),           //i-64,  Write data in
        .wrfull     (f2ox_rx_addr_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2ox_rx_addr_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (tl2f_rx_addr_re_i),        //i-1,   Read enable
        .rddata     (f2tl_rx_addr_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (DATA AVAILABLE FOR READ is == DEPTH)
        .rdempty    (f2tl_rx_addr_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2tl_rx_addr_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Mask FIFO
    fifo_nx64 #(.DEPTH(8192), .PTR(RX_MASK_PTR)) rx_mask_fifo_8kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (ox2f_rx_mask_we_i),        //i-1,   Write enable
        .wrdata     (ox2f_rx_mask_i),           //i-64,  Write data in
        .wrfull     (f2ox_rx_mask_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2ox_rx_mask_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (tl2f_rx_mask_re_i),        //i-1,   Read enable
        .rddata     (f2tl_rx_mask_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (data available for read == depth)
        .rdempty    (f2tl_rx_mask_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2tl_rx_mask_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Data FIFO
    fifo_nx256 #(.DEPTH(16384), .PTR(RX_DATA_PTR)) rx_data_fifo_16kx256 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (ox2f_rx_data_we_i),        //i-1,   Write enable
        .wrdata     (ox2f_rx_data_i),           //i-256, Write data in
        .wrfull     (f2ox_rx_data_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2ox_rx_data_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (tl2f_rx_data_re_i),        //i-1,   Read enable
        .rddata     (f2tl_rx_data_i),           //i-256, Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (DATA AVAILABLE FOR READ is == DEPTH)
        .rdempty    (f2tl_rx_data_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2tl_rx_data_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );

    //Byte Count FIFO
    fifo_nx64 #(.DEPTH(8192), .PTR(RX_BCNT_PTR)) rx_bcnt_fifo_8kx64 (
        .reset_     (rst_),

        .wrclk      (clk),                      //i-1,   Write port clock
        .wren       (ox2f_rx_bcnt_we_i),        //i-1,   Write enable
        .wrdata     (ox2f_rx_bcnt_i),           //i-64,  Write data in
        .wrfull     (f2ox_rx_bcnt_full_i),      //o-1,   Write Full Flag (no space for writes)
        .wrempty    (),                         //o-1,   Write Empty Flag (0 = some data is present)
        .wrusedw    (f2ox_rx_bcnt_wrusedw_i),   //o-PTR, Number of slots currently in use for writing

        .rdclk      (clk),                      //i-1,   Read port clock
        .rden       (tl2f_rx_bcnt_re_i),        //i-1,   Read enable
        .rddata     (f2tl_rx_bcnt_i),           //i-64,  Read data out
        .rdfull     (),                         //o-1,   Read Full Flag (DATA AVAILABLE FOR READ is == DEPTH)
        .rdempty    (f2tl_rx_bcnt_empty_i),     //o-1,   Read Empty Flag (no data for reading)
        .rdusedw    (f2tl_rx_bcnt_rdusedw_i),   //o-PTR, Number of slots currently in use for reading

        .dbg        ()
    );


    //MAC to TileLink Module
    M2OX #(
        .RX_HEADER_PTR  (RX_HEADER_PTR  ),
        .RX_ADDR_PTR    (RX_ADDR_PTR    ),
        .RX_MASK_PTR    (RX_MASK_PTR    ),
        .RX_DATA_PTR    (RX_DATA_PTR    ),
        .RX_BCNT_PTR    (RX_BCNT_PTR    ))
    m2ox_u1   (
        .clk                            (clk                     ),
        .rst_                           (rst_                    ),

        // RX Header FIFO
        .f2ox_rx_header_full_i          (f2ox_rx_header_full_i),
        .f2ox_rx_header_wrusedw_i       (f2ox_rx_header_wrusedw_i),
        .ox2f_rx_header_we_i            (ox2f_rx_header_we_i),
        .ox2f_rx_header_i               (ox2f_rx_header_i),

        // RX Address FIFO
        .f2ox_rx_addr_full_i            (f2ox_rx_addr_full_i),
        .f2ox_rx_addr_wrusedw_i         (f2ox_rx_addr_wrusedw_i),
        .ox2f_rx_addr_we_i              (ox2f_rx_addr_we_i),
        .ox2f_rx_addr_i                 (ox2f_rx_addr_i),

        // RX Mask FIFO
        .f2ox_rx_mask_full_i            (f2ox_rx_mask_full_i),
        .f2ox_rx_mask_wrusedw_i         (f2ox_rx_mask_wrusedw_i),
        .ox2f_rx_mask_we_i              (ox2f_rx_mask_we_i),
        .ox2f_rx_mask_i                 (ox2f_rx_mask_i),

        // RX Bcnt FIFO
        .f2ox_rx_bcnt_full_i            (f2ox_rx_bcnt_full_i),
        .f2ox_rx_bcnt_wrusedw_i         (f2ox_rx_bcnt_wrusedw_i),
        .ox2f_rx_bcnt_we_i              (ox2f_rx_bcnt_we_i),
        .ox2f_rx_bcnt_i                 (ox2f_rx_bcnt_i),

        // RX data FIFO
        .f2ox_rx_data_full_i            (f2ox_rx_data_full_i),
        .f2ox_rx_data_wrusedw_i         (f2ox_rx_data_wrusedw_i),
        .ox2f_rx_data_we_i              (ox2f_rx_data_we_i),
        .ox2f_rx_data_i                 (ox2f_rx_data_i),


        //RX Path LMAC In
        .m2ox_rx_ipcs_data              (m2ox_rx_ipcs_data      ),
        .m2ox_rx_ipcs_empty             (m2ox_rx_ipcs_empty     ),
        .ox2m_rx_ipcs_rden              (ox2m_rx_ipcs_rden      ),
        .m2ox_rx_ipcs_usedword          (m2ox_rx_ipcs_usedword  ),

        .m2ox_rx_pkt_data               (m2ox_rx_pkt_data        ),
        .m2ox_rx_pkt_empty              (m2ox_rx_pkt_empty       ),
        .ox2m_rx_pkt_rden               (ox2m_rx_pkt_rden        ),
        .m2ox_rx_pkt_usedword           (m2ox_rx_pkt_usedword    ),
        .ox2m_rx_pkt_rd_cycle           (ox2m_rx_pkt_rd_cycle    ),

        //Seq Mgn (to seq_mgr)
        .oxm2ackm_new_ack_num           (oxm2ackm_new_ack_num),
        .oxm2ackm_new_seq_num           (oxm2ackm_new_seq_num),
        .oxm2ackm_chk_req               (oxm2ackm_chk_req),         //o-1,
        .oxm2ackm_ack                   (oxm2ackm_ack),
        .oxm2ackm_accept                (oxm2ackm_accept),
        .oxm2ackm_done                  (oxm2ackm_done),            //i-1
        .oxm2ackm_busy                  (oxm2ackm_busy || ackmtotx_busy),   //i-1
        .rx_done                        (rx_done),
        .oxm_rtx_done                   (oxm_rtx_done),      // o-1

        //Seq Mgn (to TL2N)
        .ox2tl_aquire_gnt               (ox2tl_aquire_gnt),         // o-1
        .ox2tl_release_ack              (ox2tl_release_ack),         // o-1
        .ox2tl_probe                    (ox2tl_probe),              // o-1
        .ox2tl_acc_ack_data             (ox2tl_acc_ack_data),       // o-1
        .ox2tl_acc_ack                  (ox2tl_acc_ack)             // o-1
    );

    seq_mgr SM  (
        .clk                    (clk),
        .rst_                   (rst_),

        .tx_req                 (tx_req),                   //  i- to check if tx is requesting to transmit normal packet
        .tx_done                (tx_done),                  //  i- to indicate tx_transmit is done
        .ackmtotx_busy          (ackmtotx_busy),            //  o- indicate ack-mgn is busy

        .tx2rx_updateseq_req    (tx2rx_updateseq_req),      //    update seq req
        .tx2rx_seq_num          (tx2rx_seq_num),            //    seq num from tx (local seq)
        .tx2rx_updateseq_done   (tx2rx_updateseq_done),     //    update seq req done back to tx

        .rx2tx_updateack_req    (rx2tx_updateack_req),      //    update tx ack req (update remote ack)
//      .rx2tx_new_ack_num      (rx2tx_new_ack_num),        //    new ack num from rx  (remote ack for rtx)
        .rx2tx_free_entries     (rx2tx_free_entries),       //    number of entries to free int he RTX linked list
//      .rx2tx_rtx_entries      (rx2tx_rtx_entries),        //    the number of entries needing retransmit
        .rx2tx_rtx_req          (rx2tx_rtx_req),            //    RTX req
        .rx2tx_rtxreq_done      (rx2tx_rtxreq_done),        //    RTX req done
//      .rx2tx_rtxreq_done      (1'b1),                     //    RTX req done
        .rx2tx_updateack_done   (rx2tx_updateack_done),
//      .rx2tx_updateack_done   (1'b1),

        .rx2tx_send_req         (rx2tx_send_req),           //  send req
        .rx2tx_ack_mode         (rx2tx_ack_mode),           //  ack mode, ack = 1, nack = 0
        .rx2tx_rxack_num        (rx2tx_rxack_num),          //  ack num to send out to remote node (local ack)
        .rx2tx_sendreq_done     (rx2tx_sendreq_done),

        .bcnt_rden              (ox2m_rx_ipcs_rden),        // i-1 bcnt read enable to indicate that's a pkt
        .oxm2ackm_new_ack_num   (oxm2ackm_new_ack_num),     //  remote ack num
        .oxm2ackm_new_seq_num   (oxm2ackm_new_seq_num),     //  remote seq num
        .oxm2ackm_chk_req       (oxm2ackm_chk_req),         // i- , req to check
        .oxm2ackm_ack           (oxm2ackm_ack),             //  remote ack mode, ack = 1, nack = 0
        .oxm2ackm_accept        (oxm2ackm_accept),          //  accepting the current received data or not. 1 = accept 0 = reject
        .oxm2ackm_done          (oxm2ackm_done),            // o-1,
        .oxm2ackm_busy          (oxm2ackm_busy),            // o-1
        .rx_done                (rx_done)
    );
endmodule
