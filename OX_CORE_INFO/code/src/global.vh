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

`ifndef GUARD_ULTILITY_GLOBAL
`define GUARD_ULTILITY_GLOBAL

    //Force use of IP FIFOs even in simulations
    `define USEIPFIFO

    //Force use of LMAC and PHY IP even in simulations
    //`define USEIPNET

    //Halt simulations on lower-level errors
    `define HALTONERROR
    
    //Speed up simulation of some Xilinx IPs
    //Project setting "IP/Use precompiled IP simulation libraries" must be disabled
    //`define SIM_SPEED_UP

    //Define to enable use of ILAs in design
    `define ILA_ENABLE
    
    //Maximum FIFO Depth
    `define FIFO_MAXDEPTH 1024
    
    //Uncomment for RTL elaboration to make it run faster
    //MUST NOT BE DEFINED FOR SIMULATION OR SYNTHESIS
    //`define B_RTL_ELAB

`endif