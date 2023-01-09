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

`timescale 1ns / 1ns


module tx_pkt_fifo_8192x256 (
			reset_,
		
			wrclk,	
			wren,	
			datain,	
			wrfull,	
			wrusedw,

			rdclk,	
			rden,	
			dataout,
			rdempty,
			rdusedw 
);


	parameter WIDTH = 256,
			  DEPTH = 1024,
			  PTR	= 10;
			  
			  
			input 	wire 				reset_;

			input  	wire 				wrclk;          	// Clk for writing data                              
			input  	wire 				wren;          		// request to write                                  
			input  	wire [WIDTH-1 : 0]	datain;          	// Data coming in                                                   
			output 	wire				wrfull;           	// indicates fifo is full or not (To avoid overiding)
		    output	wire [PTR -1: 0]		wrusedw;            // number of slots currently in use for writing
		    
			input  	wire 				rdclk;           	// Clk for read data                                     
			input  	wire 				rden;            	// Request to read from FIFO                            
			output 	wire [WIDTH-1 : 0]	dataout; 	        // Data coming out                                      
			output 	wire 				rdempty;          	// indicates fifo is empty or not (to avoid underflow)  
			output 	wire [PTR  -1 : 0] 	rdusedw;          	// number of slots currently in use for reading         


asynch_fifo	#(.WIDTH (WIDTH),		  			
			  .DEPTH (DEPTH),
			  .PTR	 (PTR) )		 
		asynch_1024x256		  (
		
			.reset_		(reset_),                                                                       
			                                           		                                                 
			.wrclk		(wrclk),		                   	// Clk to write data                                                   
			.wren		(wren),	   	                   		// write enable          
			.datain		(datain),			                // write data          
			.wrfull		(wrfull),			                // indicates fifo is full or not (To avoid overiding)                  
			.wrempty	(),				                    // indicates fifo is empty or not (to avoid underflow)                                                               
			.wrusedw	(wrusedw),				            // wrusedw -number of locations filled in fifo                                                                        
                                                       		                                        
			.rdclk		(rdclk),		                   	// i-1, Clk to read data                               
			.rden		(rden),		                   		// i-1, read enable of data FIFO                                          
			.dataout	(dataout),			                // Dataout of data FIFO
			.rdfull		(),				                   	// indicates fifo is full or not (To avoid overiding) (Not used)         
			.rdempty	(rdempty),		                   	// indicates fifo is empty or not (to avoid underflow)      
			.rdusedw	(rdusedw),		                    // rdusedw -number of locations filled in fifo (not used ) 

			.dbg()

		 );
endmodule
