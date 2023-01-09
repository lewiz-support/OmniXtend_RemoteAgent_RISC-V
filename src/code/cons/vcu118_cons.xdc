# ****************************************************************
#  December 6, 2022
# 
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#  
#    http://www.apache.org/licenses/LICENSE-2.0
#  
#  Unless required by applicable law or agreed to in writing,
#  software distributed under the License is distributed on an
#  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#  KIND, either express or implied.  See the License for the
#  specific language governing permissions and limitations
#  under the License.
# 
#  Date: N/A
#  Project: OmniXtend Core
#  Comments: N/A
# 
# ********************************
#  File history:
#    N/A
# ****************************************************************


#90 MHz dclk FPGA_EMCCLK
set_property PACKAGE_PIN AL20 [get_ports mclk]
create_clock -period 11.000 [get_ports mclk]
set_property IOSTANDARD LVCMOS18 [get_ports mclk]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets ibuf_mclk/O]
# ^ to handle special routing requirements


#156.25 MHz Differential Ref clock, From QSFP_SI570_CLOCK_C_P/N
set_property PACKAGE_PIN W8 [get_ports gt_refclk_n]
set_property PACKAGE_PIN W9 [get_ports gt_refclk_p]


set_clock_groups -asynchronous -group [get_clocks mclk] -group [get_clocks gt_refclk_p]


#GT I/O
set_property PACKAGE_PIN Y2 [get_ports {gt_rxp_in[0]}]
set_property PACKAGE_PIN Y1 [get_ports {gt_rxn_in[0]}]
set_property PACKAGE_PIN V7 [get_ports {gt_txp_out[0]}]
set_property PACKAGE_PIN V6 [get_ports {gt_txn_out[0]}]



#GPIO Button North
set_property PACKAGE_PIN BB24                                           [get_ports GPIO_SW_N]
set_property IOSTANDARD LVCMOS18                                        [get_ports GPIO_SW_N]
set_input_delay -clock [get_clocks gt_refclk_p] -min -add_delay 3.200   [get_ports GPIO_SW_N]
set_input_delay -clock [get_clocks gt_refclk_p] -max -add_delay 3.200   [get_ports GPIO_SW_N]
set_input_delay -clock [get_clocks mclk]        -min -add_delay 3.200   [get_ports GPIO_SW_N]
set_input_delay -clock [get_clocks mclk]        -max -add_delay 7.800   [get_ports GPIO_SW_N]

#GPIO Button South
set_property PACKAGE_PIN BE22                                           [get_ports GPIO_SW_S]
set_property IOSTANDARD LVCMOS18                                        [get_ports GPIO_SW_S]
set_input_delay -clock [get_clocks gt_refclk_p] -min -add_delay 3.200   [get_ports GPIO_SW_S]
set_input_delay -clock [get_clocks gt_refclk_p] -max -add_delay 3.200   [get_ports GPIO_SW_S]
set_input_delay -clock [get_clocks mclk]        -min -add_delay 3.200   [get_ports GPIO_SW_S]
set_input_delay -clock [get_clocks mclk]        -max -add_delay 7.800   [get_ports GPIO_SW_S]

#GPIO Button East
set_property PACKAGE_PIN BE23                                           [get_ports GPIO_SW_E]
set_property IOSTANDARD  LVCMOS18                                       [get_ports GPIO_SW_E]
set_input_delay -clock [get_clocks gt_refclk_p] -min -add_delay 3.200   [get_ports GPIO_SW_E]
set_input_delay -clock [get_clocks gt_refclk_p] -max -add_delay 3.200   [get_ports GPIO_SW_E]
set_input_delay -clock [get_clocks mclk]        -min -add_delay 3.200   [get_ports GPIO_SW_E]
set_input_delay -clock [get_clocks mclk]        -max -add_delay 7.800   [get_ports GPIO_SW_E]

#GPIO Button West
set_property PACKAGE_PIN BF22                                           [get_ports GPIO_SW_W]
set_property IOSTANDARD  LVCMOS18                                       [get_ports GPIO_SW_W]
set_input_delay -clock [get_clocks gt_refclk_p] -min -add_delay 3.200   [get_ports GPIO_SW_W]
set_input_delay -clock [get_clocks gt_refclk_p] -max -add_delay 3.200   [get_ports GPIO_SW_W]
set_input_delay -clock [get_clocks mclk]        -min -add_delay 3.200   [get_ports GPIO_SW_W]
set_input_delay -clock [get_clocks mclk]        -max -add_delay 7.800   [get_ports GPIO_SW_W]

#GPIO Button Center
set_property PACKAGE_PIN BD23                                           [get_ports GPIO_SW_C]
set_property IOSTANDARD LVCMOS18                                        [get_ports GPIO_SW_C]
set_input_delay -clock [get_clocks gt_refclk_p] -min -add_delay 3.200   [get_ports GPIO_SW_C]
set_input_delay -clock [get_clocks gt_refclk_p] -max -add_delay 3.200   [get_ports GPIO_SW_C]
set_input_delay -clock [get_clocks mclk]        -min -add_delay 3.200   [get_ports GPIO_SW_C]
set_input_delay -clock [get_clocks mclk]        -max -add_delay 7.800   [get_ports GPIO_SW_C]



#GPIO LEDs
#set_property PACKAGE_PIN AT32     [get_ports "GPIO_LED0"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED0"]
#set_property PACKAGE_PIN AV34     [get_ports "GPIO_LED1"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED1"]
#set_property PACKAGE_PIN AY30     [get_ports "GPIO_LED2"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED2"]
#set_property PACKAGE_PIN BB32     [get_ports "GPIO_LED3"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED3"]
#set_property PACKAGE_PIN BF32     [get_ports "GPIO_LED4"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED4"]
#set_property PACKAGE_PIN AU37     [get_ports "GPIO_LED5"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED5"]
#set_property PACKAGE_PIN AV36     [get_ports "GPIO_LED6"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED6"]
#set_property PACKAGE_PIN BA37     [get_ports "GPIO_LED7"]
#set_property IOSTANDARD  LVCMOS12 [get_ports "GPIO_LED7"]



#Debug Hub
#set_property C_CLK_INPUT_FREQ_HZ 90000000 [get_debug_cores dbg_hub]
#set_property C_CLK_INPUT_FREQ_HZ 156250000 [get_debug_cores dbg_hub]
#set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
#set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
#connect_debug_port dbg_hub/clk [get_nets gt_refclk]
#connect_debug_port dbg_hub/clk [get_nets sclk]
#connect_debug_port dbg_hub/clk [get_nets mclk_buf]

