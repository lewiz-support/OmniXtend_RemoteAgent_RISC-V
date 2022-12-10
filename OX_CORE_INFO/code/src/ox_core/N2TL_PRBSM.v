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
//           TL PRB_SM     |
//                       OXmgr RX	


module N2TL_PRBSM (
	input 		       clk						   ,	
	input 		       reset_					   ,
	input 		       probe_req				   ,	// from TL Logic (Event)
	input 		       prb_displ_gen_ack		   ,	// from TL Logic (Pulse)
	input              probe_req_done		       ,	// from TL Logic (Pulse)
    input              prb_ack_mode                ,    // config signal (Pulse)
    input      [3:0]   b_size                      ,    // from TL2N for ProbeAck TL message
    input      [25:0]  b_source                    ,    // from TL2N for ProbeAck TL message
	input      [63:0]  b_address                   ,    // from TL2N for ProbeAck TL message
	output reg         probe_req_ack			   ,	// to TL Logic (Pulse)
	output reg         prb_displ_gen_en		       ,    // to TL Logic (Event)
	output reg         prb_flush_wait              ,    // to TL Logic (Event)
	output reg         prb_ack_w_data              ,    // to TL Logic (Event)
	output reg         prb_ack_no_data             ,    // to TL Logic (Event)
	output reg [3:0]   c_prb_ack_size              ,    // to N2TL for ProbeAck TL message
	output reg [25:0]  c_prb_ack_source            ,    // to N2TL for ProbeAck TL message
	output reg [63:0]  c_prb_ack_address                // to N2TL for ProbeAck TL message
	);
	
	// FSM - State Machine states
	localparam 	PRB_IDLE 			= 4'h1		  	;
	localparam	PRB_CACHE_RD		= 4'h2		  	;
	localparam	PRB_DATA_WT 		= 4'h4		  	;
	localparam	PRB_DONE	 		= 4'h8		  	;
	
	reg [3:0]	prb_state							;
	
	wire		prb_idle_st			= prb_state[0]	;
	wire		prb_cache_rd_st		= prb_state[1]	;
	wire		prb_data_wt_st		= prb_state[2]	;
	wire		prb_done_st			= prb_state[3]	;
	
	// SM assignment
	always @ (posedge clk)
	begin
		if (!reset_)
			begin
			prb_state 			<= 					PRB_IDLE	;
			end
		
		else
			begin
			if (prb_idle_st)
				begin
					prb_state 	<= 
						probe_req		 		? 	PRB_CACHE_RD:
						PRB_IDLE;
				end
			if (prb_cache_rd_st)
				begin
					prb_state 	<= 
						prb_displ_gen_ack 		? 	PRB_DATA_WT	:
						PRB_CACHE_RD;
				end
			if (prb_data_wt_st)
				begin
					prb_state 	<= 
						probe_req_done 			?	PRB_DONE	:
						PRB_DATA_WT;
				end
			if (prb_done_st)
				begin
					prb_state 	<= 			  		PRB_IDLE    ;
				end
			end
	end
	
	
	always @(posedge clk)
	begin
		if (!reset_)
			begin
				probe_req_ack 		<=  1'b0	;
				prb_displ_gen_en 	<= 	1'b0	;
				prb_flush_wait      <=  1'b0    ;
				prb_ack_w_data      <=  1'b0    ;
				prb_ack_no_data     <=  1'b0    ;
				c_prb_ack_size      <=  4'b0    ;
				c_prb_ack_source    <=  26'b0   ;
				c_prb_ack_address   <=  64'b0   ;                      
			end
		else
			begin
			probe_req_ack 			<= 
					prb_idle_st & probe_req  	? 	1'b1 		:	
					1'b0;							   								   
										   								   
			prb_displ_gen_en      	<= 
					prb_displ_gen_ack        	? 	1'b0 		:	   	//negate
					prb_idle_st & probe_req    	? 	1'b1 		:	   	//assert
					prb_displ_gen_en;	   					   	   		//keep								
				   					   	   
		    prb_flush_wait           <=
		            probe_req_done                        ?   1'b0    :   // negate
		            prb_cache_rd_st & prb_displ_gen_ack   ?   1'b1    :   // assert
		            prb_flush_wait;                                       // keep	
		            
		    prb_ack_w_data           <=
		            probe_req_done                        ?   1'b0    :   // negate    
		            prb_idle_st & probe_req & !prb_ack_mode?   1'b1   :   // assert
		            prb_ack_w_data;	                                      // keep
		            
		    prb_ack_no_data           <=
		            probe_req_done                        ?   1'b0    :   // negate    
		            prb_idle_st & probe_req & prb_ack_mode?   1'b1    :   // assert
		            prb_ack_no_data;	                                  // keep
		    
		    c_prb_ack_size           <=   b_size      ;                
		    c_prb_ack_source         <=   b_source    ;
		    c_prb_ack_address        <=   b_address   ;
		                    		
			end
	end
	
//synopsys translate_off
reg [16*8-1:0] ascii_prb_state;

always@(prb_state)
begin
	case(prb_state)
    PRB_IDLE		: 	ascii_prb_state = "PRB_IDLE"		;
    PRB_CACHE_RD	:	ascii_prb_state = "PRB_CACHE_RD"	;
    PRB_DATA_WT		:	ascii_prb_state = "PRB_DATA_WT"		; 
    PRB_DONE		:	ascii_prb_state = "PRB_DONE"		;
	default			:	ascii_prb_state = "Unknown"			;			
	endcase
end

//synopsys translate_on
	
	
endmodule