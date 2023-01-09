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
//           TL AQ_SM      |
//                       OXmgr RX


module N2TL_AQSM (
	input 	    clk				                     ,
	input 	    reset_				                 ,
	input 	    acquire_req			                 ,	// from TL Logic 	(Event)
	input 	    acquire_gen_done	                 ,	// from TL Logic 	(Pulse)
	input 	    rx2tx_rcv_tlgnt		                 ,	// from TL RX Logic	(Event)
	input 	    gntack_gen_done	                     ,	// from TL Logic 	(Pulse)
	input      [25:0]  d_sink                        ,
	output reg  acquire_req_ack		                 ,	// to TL Logic		(Pulse)
	output reg  acquire_gen_en		                 ,	// to TL Logic		(Event)
	output reg  tx2rx_rcv_tlgnt_ack                  ,	// to TL Logic		(Pulse)
	output reg         gntack_gen_en			     ,  // to TL Logic		(Event)
	output reg [25:0]  e_sink
	);

	// FSM - State Machine states
	localparam 	AQ_IDLE 		     = 5'h01         ;
	localparam	AQ_ACQUIRE_GEN 	     = 5'h02         ;
	localparam	AQ_GNT_WAIT 	     = 5'h04         ;
	localparam	AQ_GNTACK_GEN 	     = 5'h08         ;
	localparam	AQ_DONE 		     = 5'h10         ;

	reg [4:0]	aq_state                             ;

	wire		aq_idle_st	         = aq_state[0]   ;
	wire		aq_acquire_gen_st    = aq_state[1]   ;
	wire		aq_gnt_wait_st	     = aq_state[2]   ;
	wire		aq_gntack_gen_st     = aq_state[3]   ;
	wire		aq_done_st	         = aq_state[4]   ;

	// SM assignment
	always @ (posedge clk) begin
		if (!reset_) begin
			aq_state <= AQ_IDLE;
		end

		else begin
			if (aq_idle_st) begin
				aq_state <=
					acquire_req       ? AQ_ACQUIRE_GEN  :
										AQ_IDLE         ;
			end
			if (aq_acquire_gen_st) begin
				aq_state <=
					acquire_gen_done  ? AQ_GNT_WAIT     :
									    AQ_ACQUIRE_GEN  ;
			end
			if (aq_gnt_wait_st) begin
				aq_state <=
					rx2tx_rcv_tlgnt   ? AQ_GNTACK_GEN   :
									    AQ_GNT_WAIT     ;
			end
			if (aq_gntack_gen_st) begin
				aq_state <=
					gntack_gen_done   ? AQ_DONE         :
									    AQ_GNTACK_GEN	;
			end
			if (aq_done_st) begin
				aq_state <= AQ_IDLE                     ;
			end
		end
	end


	always @(posedge clk) begin
		if (!reset_) begin
			acquire_req_ack 	<= 1'b0;
			acquire_gen_en 		<= 1'b0;
			tx2rx_rcv_tlgnt_ack <= 1'b0;
			gntack_gen_en 		<= 1'b0;
			e_sink              <= 26'b0;
		end
		else begin
			acquire_req_ack 	<=
					aq_idle_st & acquire_req           ? 1'b1 :
											             1'b0 ;
			acquire_gen_en      <=
					acquire_gen_done                   ? 1'b0 :	   //negate
					aq_idle_st & acquire_req           ? 1'b1 :	   //assert
					                            acquire_gen_en;	   //keep
			tx2rx_rcv_tlgnt_ack <=
					aq_gnt_wait_st & rx2tx_rcv_tlgnt   ? 1'b1 :
													     1'b0 ;
			gntack_gen_en 		<=
					gntack_gen_done                    ? 1'b0 :    //negate
					//aq_gntack_gen_st                 ? 1'b1 :    //assert (1 clk cycle delay)
					aq_gnt_wait_st & rx2tx_rcv_tlgnt   ? 1'b1 :	   //assert
					                             gntack_gen_en;    //keep

		    e_sink              <= d_sink                     ;
		end
	end

    //synopsys translate_off
    reg [16*8-1:0] ascii_aq_state;

    always@(aq_state)
    begin
        case(aq_state)
        AQ_IDLE			: 	ascii_aq_state = "AQ_IDLE"        ;
        AQ_ACQUIRE_GEN	:	ascii_aq_state = "AQ_ACQUIRE_GEN" ;
        AQ_GNT_WAIT		:	ascii_aq_state = "AQ_GNT_WAIT"    ;
        AQ_GNTACK_GEN	:	ascii_aq_state = "AQ_GNTACK_GEN"  ;
        AQ_DONE			:	ascii_aq_state = "AQ_DONE"        ;
        default         :   ascii_aq_state = "Unknown"        ;
        endcase
    end
    //synopsys translate_on

endmodule