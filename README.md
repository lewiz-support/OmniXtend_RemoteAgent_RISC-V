# OmniXtend_RemoteAgent_RISC-V

Author: LeWiz Communications, Inc.

www.LeWiz.com

---------- Dec 12, 2022

Restructured the directories:

DOCS: Contains document(s) to describe the release. Please read this doc first

OX_CORE_INFO: Contains the source and all files related to OmniXtend (OX) Remote Agent IP core written in Verilog. OmniXtend is useful for clustering of large number of processors (or servers) with endpoints such as network based storage or memory systems.

FPGA: This directory contains FPGA implementation specific releases. 

VCU118* contains the implementation of RISC-V CPU with OX_CORE networked with remote OX endpoint. This implementation demonstrates the clustering of RISC-V CPU(s) with remote networked memory system(s). Its CPU fetches and executes programs stored remotely not on its CPU's external local memory. This was implemented on Xilinx's VCU118 board with UltraScale+ FPGA chip.

U50* contains specific implementation of OmniXtend Endpoint on Alveo U50 board. To be used with the VCU118* implementation. This remote endpoint contains the actual program that the RISC-V CPU executes.



--------- November 28, 2022

This repository contains the open source and documentation for OmniXtend protocol with RISC-V CPU as the initiator.
An OmniXtend Endpoint was used as a target. The RISC-V CPU fetches program code from a remote network endpoint (not
on its local memory) and executes a simple C-program. The design contains:

RISC-V64 <==> OmniXtend Core <==> LeWiz LMAC3 <==> PHY <==> NETWORK SWITCH <==> Endpoint

RISC-V64 to PHY was implemented on a VCU118 Xilinx board and the Endpoint was implemented on a U50 Xilinx board.
LeWiz LMAC cores are available on Github in lewiz-support repository (Here)

The RISC-V CPU are also available in open source and released by its developer under its own open source license
(Link to RISC-V core:   )

The OmniXtend core (developed by LeWiz) is released under Apache 2.0 license

https://www.apache.org/licenses/LICENSE-2.0

Any other work(s) not mentioned above which had been developed by LeWiz and contained in this release are also released under Apache 2.0 license.
As such this work is released on an AS-IS basis and 

NO WARRANTY of ANY KIND is provided and 

NO LIABILITY of ANY KIND is assumed by LeWiz.

