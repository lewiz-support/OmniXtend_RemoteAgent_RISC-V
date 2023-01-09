# Example Files

### OX Agent System Bitstream
A ready to program bitstream for the VCU118 containing the complete OmniXtend Remote Agent system with a single Ariane CPU core. Expects Endpoint to have MAC address `00:12:32:FF:FF:FA`. System reset may be issued either by VIO or onboard button "SW5 CPU_RESET". See [OX Agent Doc](https://github.com/lewiz-support/OmniXtend_RemoteAgent_RISC-V/blob/main/DOCS/OmniXtend%20Remote%20Agent.pdf) Section 6.4 for further details on system operation.
 - `ox_agent.bit`: Complete OX Agent System bitstream for VCU118.
 - `ox_agent.ltx`: Debug probe listing file for above bitstream.


### Example Execution Captures
Sample ILA and network captures showing execution of the UART "Hello World" program. Vivado is required to open `.ila` files.
 - `hello_uart.ila`: Program execution showing primarily NoC requests and responses.
 - `hello_uart_zoom.ila`: Program execution showing NoC, TLoE and CGMII stages in both directions for two NoC requests/responses.
 - `hello_uart.pcapng`: Traffic between OX Agent and Endpoint.