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

// NOC <--> TL Logic --> OXmgr TX
//               ^
//               |     <-- ^
//      TL COHERENT_MGR    |
//                       OXmgr RX


module COHERENT_MGR (
	input 	    		clk		                    ,
	input 	    		reset_				        ,

	// TL Aquire SM
	input 	    		tl2coh_tx_acquire_req		,	// from TL Logic 	(Event)
	input 	    		tl2coh_tx_acquire_gen_done	,	// from TL Logic 	(Pulse)
	input 	    		rx2tx_rcv_tlgnt			    ,	// from TL RX Logic	(Event)
	input 	    		tl2coh_tx_gntack_gen_done	,	// from TL Logic 	(Pulse)
	output 	    		coh2tl_tx_acquire_req_ack	,	// to TL Logic		(Pulse)
	output 	    		coh2tl_tx_acquire_gen_en	,	// to TL Logic		(Event)
	output 	    		tx2rx_rcv_tlgnt_ack		    ,	// to TL Logic		(Pulse)
	output 	    		coh2tl_gntack_gen_en		,  	// to TL Logic		(Event)

	// TL Probe SM
	input 				tl2coh_rx_probe_req			,	// from TL Logic 	(Event)
	input 				tl2coh_rx_prb_displ_gen_ack	,	// from TL Logic 	(Pulse)
	input 				tl2coh_tx_probe_req_done    ,	// from TL Logic 	(Pulse)
	input               prb_ack_mode                ,   // Config Signal    (Pulse)
	output 				coh2tl_rx_probe_req_ack		,	// to TL Logic		(Pulse)
	output 				coh2tl_rx_prb_displ_gen_en	,	// to TL Logic		(Event)
	output              coh2tl_tx_prb_flush_wait    ,   // to TL Logic      (Event)
	output              coh2tl_prb_ack_w_data       ,   // to TL Logic      (Event)
	output              coh2tl_prb_ack_no_data      ,   // to TL Logic      (Event)

	// TL Release SM
	input 				tl2coh_tx_release_req	    ,	// from TL Logic 	(Event)
	input 				tl2coh_rx_release_ack_rcvd  ,	// from TL Logic 	(Pulse)
	output 				tl2coh_tx_release_req_ack	,   // to TL Logic		(Pulse)

	// for GrantAck and ProbeAck TL message
	input      [3:0]    b_size                      ,   // from TL2N for ProbeAck TL message
	input      [25:0]   b_source                    ,   // from TL2N for ProbeAck TL message
	input      [63:0]   b_address                   ,   // from TL2N for ProbeAck TL message
	input      [25:0]   d_sink                      ,   // Input from TL2N for GrantAck TL message
	output     [3:0]    c_prb_ack_size              ,   // to N2TL for ProbeAck TL message
	output     [25:0]   c_prb_ack_source            ,   // to N2TL for ProbeAck TL message
	output     [63:0]   c_prb_ack_address           ,   // to N2TL for ProbeAck TL message
	output     [25:0]   e_sink                          // Output to N2TL for GrantAck TL message
	);


	// TL Acquire SM
	N2TL_AQSM 	AQ_SM1 (
        .clk					     (clk)					        ,
        .reset_		                 (reset_)				        ,
        .acquire_req	             (tl2coh_tx_acquire_req)		,
        .acquire_gen_done            (tl2coh_tx_acquire_gen_done)	,
        .rx2tx_rcv_tlgnt	         (rx2tx_rcv_tlgnt)		        ,
        .gntack_gen_done             (tl2coh_tx_gntack_gen_done)    ,
        .d_sink                      (d_sink)                       ,
        .acquire_req_ack             (coh2tl_tx_acquire_req_ack)    ,
        .acquire_gen_en              (coh2tl_tx_acquire_gen_en)		,
        .tx2rx_rcv_tlgnt_ack	     (tx2rx_rcv_tlgnt_ack)	        ,
        .gntack_gen_en			     (coh2tl_gntack_gen_en)         ,
        .e_sink                      (e_sink)
	);

    // TL Probe SM
	N2TL_PRBSM	PRB_SM1(
		.clk					     (clk)					        ,
		.reset_					     (reset_)				        ,
		.probe_req				     (tl2coh_rx_probe_req)		    ,
		.prb_displ_gen_ack	 	     (tl2coh_rx_prb_displ_gen_ack)	,
		.probe_req_done			     (tl2coh_tx_probe_req_done)		,
		.prb_ack_mode                (prb_ack_mode)                 ,
		.b_size                      (b_size)                       ,
		.b_source                    (b_source)                     ,
		.b_address                   (b_address)                    ,
		.probe_req_ack			     (coh2tl_rx_probe_req_ack)		,
		.prb_displ_gen_en		     (coh2tl_rx_prb_displ_gen_en)   ,
		.prb_flush_wait              (coh2tl_tx_prb_flush_wait)     ,
		.prb_ack_w_data              (coh2tl_prb_ack_w_data)        ,
		.prb_ack_no_data             (coh2tl_prb_ack_no_data)       ,
		.c_prb_ack_size              (c_prb_ack_size)               ,
		.c_prb_ack_source            (c_prb_ack_source)             ,
		.c_prb_ack_address           (c_prb_ack_address)
	);

	// TL Release SM
	N2TL_RLSSM	RLS_SM1(
        .clk					     (clk)					        ,
        .reset_					     (reset_)				        ,
        .release_req			     (tl2coh_tx_release_req)		,
        .release_ack_rcvd		     (tl2coh_rx_release_ack_rcvd)	,
        .release_req_ack		     (tl2coh_tx_release_req_ack)
	);

endmodule