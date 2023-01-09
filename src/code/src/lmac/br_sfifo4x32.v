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
// Project: LMAC 3
// Comments: N/A
//
//********************************
// File history:
//   N/A
//****************************************************************

// synopsys translate_off
`timescale 1ns/1ps
// synopsys translate_on

module br_sfifo4x32

(
			 aclr,

			wrclk,     	   	//i,Clk for writing data 
			wrreq,     	   	//i, request to write 
			data,          	//i, Data coming in           
			wrfull,    	   	//o,indicates fifo is full or not (To avoid overiding)
                           	
		    rdclk,     	   	//i, Clk for reading data
			rdreq,     	   	//i, Request to read from FIFO
			q, 	    	  	//o, Data coming out
			rdempty,  	   	//o, indicates fifo is empty or not (to avoid underflow)
			rdusedw    	   	//o, number of slots currently in use for reading

);	  //setting default values
	parameter WIDTH = 32,
			  DEPTH = 4,
			  PTR	= 2;
			  
			  
			input wire aclr;

			input  wire 				wrclk;   	// Clk for writing data
			input  wire 				wrreq;   	// request to write
			input  wire [WIDTH-1 : 0]	data;    	// Data coming in 
			output wire					wrfull;  	// indicates fifo is full or not (To avoid overiding)
		                                         
		    input  wire 				rdclk;   	// Clk for reading data
			input  wire 				rdreq;   	// Request to read from FIFO 
			output wire [WIDTH-1 : 0]	q; 	    	// Data coming out
			output wire 				rdempty; 	// indicates fifo is empty or not (to avoid underflow)
			output wire [PTR  : 0] 		rdusedw; 	// number of slots currently in use for reading



			asynch_fifo	#(.WIDTH (WIDTH),		 
					  	  .DEPTH (DEPTH),
					 	  .PTR	 (PTR) )		 
 											
asynch_br4x32		  (
			.reset_	(~aclr),
			
			.wrclk	(wrclk),		//i, Clk to write data
			.wren	(wrreq),		//i, write enable
			.datain	(data),			//i, write data
			.wrfull	(wrfull),		//o, indicates fifo is full or not (To avoid overiding)
			.wrempty(),			
			.wrusedw(),			


			.rdclk	(rdclk),		// i-1, Clk to read data
			.rden	(rdreq),		// i-1, read enable of data FIFO
			.dataout(q),			// Dataout of data FIFO
			.rdfull	(),			
			.rdempty(rdempty),		// indicates fifo is empty or not (to avoid underflow)
			.rdusedw(rdusedw),		// rdusedw -number of locations filled in fifo (not used )

			.dbg()

		 );
endmodule