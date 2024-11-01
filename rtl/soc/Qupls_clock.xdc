## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project


#Clock Signal
#create_clock -period 5.000 -name sysclk_p -waveform {0.000 2.500} -add [get_ports sysclk_p]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets ucg1/inst/clk_in1_WXGA800x600_clkgen]
#create_generated_clock -name clk20 -source [get_pins ucg1/clk_in1] -divide_by 32 -multiply_by 8 [get_pins ucg1/clk20]
#create_generated_clock -name clk40 -source [get_pins ucg1/clk_in1] -divide_by 16 -multiply_by 8 [get_pins ucg1/clk40]
#create_generated_clock -name clk50 -source [get_pins ucg1/clk_in1] -divide_by 16 -multiply_by 8 [get_pins ucg1/clk50]
#create_generated_clock -name clk80 -source [get_pins ucg1/clk_in1] -divide_by 10 -multiply_by 8 [get_pins ucg1/clk80]
# CLKOUT0 = clk200
# CLKOUT1 = clk100
# CLKOUT3 = clk40
# CLKOUT2 = clk33
# CLKOUT4 = clk20

set_clock_groups -asynchronous -group {clk_pll_i clk429_WXGA1366x768_clkgen} -group clk86_WXGA1366x768_clkgen -group clk86_WXGA1366x768_clkgen -group clk21_WXGA1366x768_clkgen -group clk17_WXGA1366x768_clkgen -group clk200_WXGA800x600_clkgen -group clk100_WXGA800x600_clkgen -group clk50_WXGA800x600_clkgen -group clk40_WXGA800x600_clkgen -group clk20_WXGA800x600_clkgen -group clk17_WXGA800x600_clkgen -group clk_pll_i_1 -group clk100_cpuClkgen_1 -group clk84_cpuClkgen_1 -group clk43_cpuClkgen_1 -group clk21_cpuClkgen_1 -group clk17_cpuClkgen_1 -group clk100_cpuClkgen -group clk50_cpuClkgen -group clk40_cpuClkgen -group clk20_cpuClkgen -group clk17_cpuClkgen

#set_clock_groups -asynchronous #-group { #uddr3/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKIN1 #ucg1/inst/mmcm_adv_inst/CLKOUT0 #ucg1/inst/mmcm_adv_inst/CLKOUT1 #} #-group { #ucg1/inst/mmcm_adv_inst/CLKOUT3 #} #-group { #ucg1/inst/mmcm_adv_inst/CLKOUT2 #ucg1/inst/mmcm_adv_inst/CLKOUT6 #}

#-group { #clk400_NexysVideoClkgen2 #clk57_NexysVideoClkgen2 #clk19_NexysVideoClkgen2 #} #-group { #clk14_NexysVideoClkgen #}
# #-group { #clk100_NexysVideoClkgen #clk14_NexysVideoClkgen #clk160_NexysVideoClkgen #clk200_NexysVideoClkgen #clk20_NexysVideoClkgen #clk40_NexysVideoClkgen #clk80_NexysVideoClkgen #} #-group { #clk100_NexysVideoCpuClkgen #clk25_NexysVideoCpuClkgen #clk50_NexysVideoCpuClkgen #}

#set_false_path -from [get_clocks ucg1/clk20] -to [get_clocks ucg1/clk80]
#set_false_path -from [get_clocks ucg1/clk80] -to [get_clocks ucg1/clk20]
#set_false_path -from [get_clocks ucg1/clk80] -to [get_clocks clk50]
#set_false_path -from [get_clocks clk50] -to [get_clocks ucg1/clk80]
#set_false_path -from [get_clocks ucg1/clk80] -to [get_clocks ucg1/clk40]
#set_false_path -from [get_clocks ucg1/clk40] -to [get_clocks ucg1/clk80]
#set_false_path -from [get_clocks ucg1/clk20] -to [get_clocks ucg1/clk40]
#set_false_path -from [get_clocks ucg1/clk40] -to [get_clocks ucg1/clk20]
#set_false_path -from [get_clocks clk_pll_i] -to [get_clocks ucg1/clk20]
#set_false_path -from [get_clocks ucg1/clk20] -to [get_clocks clk_pll_i]
#et_false_path -from [get_clocks clk_pll_i] -to [get_clocks ucg1/clk40]
#et_false_path -from [get_clocks ucg1/clk40] -to [get_clocks clk_pll_i]

set_false_path -from [get_clocks clk40_NexysVideoClkgen] -to [get_clocks clk25_cpuClkgen]
set_false_path -from [get_clocks clk25_cpuClkgen] -to [get_clocks clk40_NexysVideoClkgen]

#set_false_path -from [get_clocks ucg1/clk40] -to [get_clocks clk20_NexysVideoClkgen]

#set_false_path -from [All_clocks] -to [All_clocks]

#set_false_path -from [get_clocks mem_ui_clk] -to [get_clocks cpu_clk]
#set_false_path -from [get_clocks clk100u] -to [get_clocks mem_ui_clk]
#set_false_path -from [get_clocks clk200u] -to [get_clocks mem_ui_clk]

### Clock constraints ###
# rgb2dvi
#create_clock -period 11.666 [get_ports PixelClk]
#create_generated_clock -source [get_ports PixelClk] -multiply_by 5 [get_ports SerialClk]
#create_clock -period 5 [get_ports clk200]
#create_clock -period 5 [get_ports sys_clk_i]
### Asynchronous clock domain crossings ###
#set_false_path -through [get_pins -filter {NAME =~ */SyncAsync*/oSyncStages*/PRE || NAME =~ */SyncAsync*/oSyncStages*/CLR} -hier]
#set_false_path -through [get_pins -filter {NAME =~ *SyncAsync*/oSyncStages_reg[0]/D} -hier]




connect_debug_port u_ila_0/probe1 [get_nets [list {umpmc1/app_addr[0]} {umpmc1/app_addr[1]} {umpmc1/app_addr[2]} {umpmc1/app_addr[3]} {umpmc1/app_addr[4]} {umpmc1/app_addr[5]} {umpmc1/app_addr[6]} {umpmc1/app_addr[7]} {umpmc1/app_addr[8]} {umpmc1/app_addr[9]} {umpmc1/app_addr[10]} {umpmc1/app_addr[11]} {umpmc1/app_addr[12]} {umpmc1/app_addr[13]} {umpmc1/app_addr[14]} {umpmc1/app_addr[15]} {umpmc1/app_addr[16]} {umpmc1/app_addr[17]} {umpmc1/app_addr[18]} {umpmc1/app_addr[19]} {umpmc1/app_addr[20]} {umpmc1/app_addr[21]} {umpmc1/app_addr[22]} {umpmc1/app_addr[23]} {umpmc1/app_addr[24]} {umpmc1/app_addr[25]} {umpmc1/app_addr[26]} {umpmc1/app_addr[27]} {umpmc1/app_addr[28]}]]

set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets mem_ui_clk]
