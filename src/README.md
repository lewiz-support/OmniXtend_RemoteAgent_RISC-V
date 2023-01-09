# OmniXtend Bridge

For testing of OX Core using "new" endpoint.
Endpoint contains data as specified in `code/src/endpoint/memoryconfig.hex`

## Directories
- code: Project Code
- docs: Project Documentation
- proj: Vivado Project Files (initially empty or absent)

See the Readme within these directories for further details

## Vivado project
To open Vivado project:

- Open Vivado and select "Tools -> Run TCL Script..."
- Open the TCL script `setup.tcl`
- The project will be generated and opened automatically

Currently, only Vivado version 2021.2.1 is supported.
Other versions may work, but success is not guaranteed.

## Simulations/Testbenches

Testbench 'core_tb' 
- set as top by default
- Requires hand-verification
- `run all` to ensure bench runs to completion

Module 'core_fpga'
- Run simulation on 'core_fpga' and source `code/sim/core_fpga/core_fpga.tcl`
- Debug CGMII TX data is written to `code/src/fpga/core_fpga.TX.mem`
- Debug CGMII RX data is read from  `code/src/fpga/core_fpga.RX.mem`

## Simulation Scripts

Each simulation script within `code/sim/core_tb/script` controls the NoC Master Emulator to to send packets 
contain in its data file. This is achieved by forcing the control signals to NOC_MASTER. Signal 'gen_en' 
enables the emulator, wile 'pkt_gen_addr' and 'pkt_gen_cnt' respectively specify the packet's staring address 
within the file and number of flits in the packet (counting leading and trailing zeros). 
NOTE: 'core_tb's Auto-NoC must be disabled when running one of these scripts.

The simulation script `code/sim/core_fpga/core_fpga.tcl` generates clocks and control signals to allow 
simulation of the FPGA level module 'core_fpga' prior to synthesis.


## NoC Master Emulator (NOC_MASTER)

Data files for NOC_MASTER are `code/sim/utility/NOC_MASTER/mem/*.txt`
Select a data file using NOC_MASTER's parameter "MEM_FILE"

Each data file contains NoC packets for the emulator to send on the NoC Bus. Within these files, commands
are listed with each flit (1 QWord) on a separate line, preceded by a byte to indicate validity. Format of
each flit is described in the data files and in project documentation. Each command is padded before and
after with a line of zeros.


## Notes

-In `core_tb.wcfg`, the 'OUT' group of one module matches the 'IN' group of its connected module. For example, NOC_MASTER's "NOC OUT" is the "NOC IN" for OX_CORE

- The RISC-V CPU this will be connecting to only makes naturally aligned requests and expects a whole 64 byte block in response (block is also naturally aligned)
  e.g. request bytes  8-15 -> get bytes 0-63
    request bytes 16-31 -> get bytes 0-63
    request bytes  8-23 -> NOT ALLOWED (not naturally aligned)