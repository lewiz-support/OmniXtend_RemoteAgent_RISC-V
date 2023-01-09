#Set core_fpga as top, run a simulation, then source this script

restart

# Create 156.25 MHz Ref clock
add_force {/core_fpga/gt_refclk_p} -radix hex {1 0ns} {0 3200000fs} -repeat_every 6400000fs
add_force {/core_fpga/gt_refclk_n} -radix hex {0 0ns} {1 3200000fs} -repeat_every 6400000fs
# add_force {/core_fpga/gt_refclk_n} -radix hex {1 0ns} {0 3200000fs} -repeat_every 6400000fs

# Create 90 MHz 'Free-running' clock
add_force {/core_fpga/mclk} -radix hex {1 0ns} {0 5500000fs} -repeat_every 11000000fs

# Set Default RX input to PHY
add_force {/core_fpga/gt_rxp_in} -radix hex {1 0ns}
add_force {/core_fpga/gt_rxn_in} -radix hex {0 0ns}

# Keep VIO signals at zero
add_force {/core_fpga/vio_reset_all} -radix hex {0 0ns}
add_force {/core_fpga/vio_reset_mii} -radix hex {0 0ns}
add_force {/core_fpga/vio_reset_sys} -radix hex {0 0ns}
add_force {/core_fpga/vio_reset_oxc} -radix hex {0 0ns}
add_force {/core_fpga/vio_enable} -radix hex {0 0ns}

# Reset then enable
add_force {/core_fpga/GPIO_SW_N} -radix hex {1 0ns} {0   800ns}
add_force {/core_fpga/GPIO_SW_C} -radix hex {0 0ns}
add_force {/core_fpga/GPIO_SW_E} -radix hex {0 0ns}
add_force {/core_fpga/GPIO_SW_W} -radix hex {0 0ns}
add_force {/core_fpga/GPIO_SW_S} -radix hex {0 0ns} {1 15000ns}

#add_force {/core_fpga/cgmii_rxd} -radix hex {0 0ns} -cancel_after 10000ns
#add_force {/core_fpga/cgmii_rxc} -radix hex {0 0ns} -cancel_after 10000ns

#add_force {/core_fpga/m2ox_rxi_empty} -radix hex {1 0ns}
#add_force {/core_fpga/m2ox_rxp_empty} -radix hex {1 0ns}


run 28000ns

add_force {/core_fpga/file_close} -radix hex {1 0ns}
run 10ns