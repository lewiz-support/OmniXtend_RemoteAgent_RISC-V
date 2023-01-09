[![Issues][issues-shield]][issues-url]
[![Apache 2.0 License][license-shield]][license-url]

<br />
<div align="center">

  <h3 align="center">OmniXtend_RemoteAgent_RISC-V</h3>

  <p align="center">
    OpenPiton to OmniXtend 1.0.3 bridge. Attaches CVA6 coherently to the Network.
    <br />
    <br />
    by <a href="https://www.LeWiz.com">LeWiz Communications, Inc.</a>
    <br />
    <br />
    <a href="https://github.com/lewiz-support/OmniXtend_RemoteAgent_RISC-V/issues">Report Bug</a>
    ·
    <a href="https://github.com/lewiz-support/OmniXtend_RemoteAgent_RISC-V/issues">Request Feature</a>
  </p>
</div>

## About The Project

This repository contains a version of OpenPiton coherently attached to remote main memory. A bridge module is attached to the OpenPiton NoC. This module translates the native OpenPiton coherence protocol to TileLink and wraps these messages into OmniXtend for Ethernet transmission. Our open source [LMAC3][lmac] provides 10G/25G/40G/50G/100G Ethernet.

The open source [OmniXtend endpoint][oxendpoint] implements the remote main memory.

### Features
- CVA6 accesses remote memory transparent and coherent.
- Support for the OpenPiton infrastructure for debugging/UART etc.
- Written in Verilog.
- Full system simulation.

The current implementation uses the Xilinx VCU118 for our OpenPiton fork. The endpoint runs on a wider variety of cores but has been tested on Xilinx Alveo U50 by us.

![system_overview](https://user-images.githubusercontent.com/451732/211386729-f1bc360f-a483-4571-b0d1-72d11af0e03d.png)

## Directory Structure
- docs: Contains a detailed description of this project in [OmniXtend_Remote_Agent.pdf][oxradoc].
- src: Verilog source code of the OmniXtend Remote Agent IP.
- infrastructure/bridge: Implementation details for the OmniXtend Remote Agent IP on Xilinx VCU118.
- infrastructure/endpoint: Information related to the [OmniXtend endpoint][oxendpoint] FPGA bitstream and simulation.

[issues-shield]: https://img.shields.io/github/issues/lewiz-support/OmniXtend_RemoteAgent_RISC-V.svg?style=for-the-badge
[issues-url]: https://github.com/lewiz-support/OmniXtend_RemoteAgent_RISC-V/issues
[license-shield]: https://img.shields.io/github/license/lewiz-support/OmniXtend_RemoteAgent_RISC-V.svg?style=for-the-badge
[license-url]: https://github.com/lewiz-support/OmniXtend_RemoteAgent_RISC-V/blob/master/LICENSE
[oxspec]: https://github.com/chipsalliance/omnixtend/blob/master/OmniXtend-1.0.3/spec/OmniXtend-1.0.3.pdf
[tlspec]: https://github.com/chipsalliance/omnixtend/blob/master/OmniXtend-1.0.3/spec/TileLink-1.8.0.pdf
[lewiz]: https://www.LeWiz.com
[oxendpoint]: https://github.com/westerndigitalcorporation/OmnixtendEndpoint
[lmac]: https://github.com/lewiz-support/LMAC_CORE3
[oxradoc]: https://github.com/lewiz-support/OmniXtend_RemoteAgent_RISC-V/blob/main/DOCS/OmniXtend_Remote_Agent.pdf

