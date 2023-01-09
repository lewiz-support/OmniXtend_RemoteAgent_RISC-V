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

set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/pre_eof_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/pre_sof_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/s2p10/x_bcnt_we_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/s2p10/x_we_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/sof0_dly_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/sof0_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/sof1_dly_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/sof1_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/x_bcnt_we_reg}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/x_we_reg}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[.+\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[0\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[1\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[2\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[3\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[4\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[5\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[6\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[7\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[32\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[33\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[34\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[35\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[36\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[37\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[38\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[39\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[40\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[41\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[42\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[43\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[44\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[45\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[46\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[47\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[48\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[49\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[50\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[51\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[52\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[53\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[54\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[55\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[56\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[57\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[58\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[59\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[60\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[61\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[62\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/cgmii_dout_reg_reg\[63\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txc_reg\[.+\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[0\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[1\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[2\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[3\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[4\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[5\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[6\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[7\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[32\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[33\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[34\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[35\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[36\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[37\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[38\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[39\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[40\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[41\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[42\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[43\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[44\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[45\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[46\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[47\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[48\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[49\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[50\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[51\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[52\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[53\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[54\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[55\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[56\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[57\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[58\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[59\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[60\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[61\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[62\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/core/tx_10G_wrap/tx_xgmii/xgmii_txd_reg\[63\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/pre_br_ctrl_reg\[.+\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/pre_br_data_reg\[.+\]}]


set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[18\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[19\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[20\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[21\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[22\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[23\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[24\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[25\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[26\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[27\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[28\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[29\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[30\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly1_reg\[31\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[18\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[19\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[20\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[21\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[22\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[23\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[24\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[25\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[26\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[27\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[28\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[29\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[30\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_in_dly2_reg\[31\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_out_reg\[32\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_100G/ctrl_out_reg\[34\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/x_byte_cnt_10g_reg_reg\[24\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/x_byte_cnt_10g_reg_reg\[25\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/x_byte_cnt_reg\[24\]}]
set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/rx_50G/x_byte_cnt_reg\[25\]}]



set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/x2c_ctrl/ctrl_out_reg\[.+\]}]


set_property ASYNC_REG true [get_cells -regexp -nocase -hier {.*LMAC[^/]*/x2c_ctrl/data_out_reg\[.+\]}]


#create_pblock pblock_ila_fpga
##add_cells_to_pblock [get_pblocks pblock_ila_fpga] [get_cells -quiet [list ila_fpga]]
#add_cells_to_pblock [get_pblocks pblock_ila_fpga] [get_cells -quiet [list oxbridge/ila_fpga]]
#resize_pblock [get_pblocks pblock_ila_fpga] -add {SLICE_X0Y658:SLICE_X59Y899}
#resize_pblock [get_pblocks pblock_ila_fpga] -add {BUFG_GT_X0Y264:BUFG_GT_X0Y359}
#resize_pblock [get_pblocks pblock_ila_fpga] -add {BUFG_GT_SYNC_X0Y165:BUFG_GT_SYNC_X0Y224}
#resize_pblock [get_pblocks pblock_ila_fpga] -add {DSP48E2_X0Y264:DSP48E2_X7Y359}
#resize_pblock [get_pblocks pblock_ila_fpga] -add {RAMB18_X0Y264:RAMB18_X4Y359}
#resize_pblock [get_pblocks pblock_ila_fpga] -add {RAMB36_X0Y132:RAMB36_X4Y179}
#resize_pblock [get_pblocks pblock_ila_fpga] -add {URAM288_X0Y176:URAM288_X0Y239}

set_property C_CLK_INPUT_FREQ_HZ 156250000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets gt_refclk]
