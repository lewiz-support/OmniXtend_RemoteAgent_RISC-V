# OmniXtend_RemoteAgent_RISC-V

--------- November 28, 2022
This repository contains the open source and documentation for OmniXtend protocol with RISC-V CPU as the initiator.
An OmniXtend Endpoint was used as a target. The RISC-V CPU fetches program code from a remote network endpoint (not
on its local memory) and executed a simple C-program. The design contains:
RISC-V64 <==> OmniXtend Core <==> LeWiz LMAC3 <==> PHY <==> NETWORK SWITCH <==> Endpoint

RISC-V64 to PHY was implemented on a VCU118 Xilinx board and the Endpoint was implemented on a U50 Xilinx board.
LeWiz LMAC cores are available on Github in lewiz-support repository (Here)
The RISC-V CPU are also available in open source and released by its developer under its own open source license
(Link to RISC-V core:   )
The OmniXtend core is released under Apache 2.0 license

