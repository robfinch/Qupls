## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project


#Clock Signal
#create_clock -period 5.000 -name sysclk_p -waveform {0.000 2.500} -add [get_ports sysclk_p]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets ucg1/inst/clk_in1_NexysVideoClkgen]
#create_generated_clock -name clk20 -source [get_pins ucg1/clk_in1] -divide_by 32 -multiply_by 8 [get_pins ucg1/clk20]
#create_generated_clock -name clk40 -source [get_pins ucg1/clk_in1] -divide_by 16 -multiply_by 8 [get_pins ucg1/clk40]
#create_generated_clock -name clk50 -source [get_pins ucg1/clk_in1] -divide_by 16 -multiply_by 8 [get_pins ucg1/clk50]
#create_generated_clock -name clk80 -source [get_pins ucg1/clk_in1] -divide_by 10 -multiply_by 8 [get_pins ucg1/clk80]
# CLKOUT0 = clk200
# CLKOUT1 = clk100
# CLKOUT3 = clk40
# CLKOUT2 = clk33
# CLKOUT4 = clk20

set_clock_groups -asynchronous \
-group { \
clk_pll_i \
clk200_NexysVideoClkgen \
clk100_NexysVideoClkgen \
clk20_NexysVideoClkgen \
} \
-group { \
clk17_NexysVideoClkgen \
} \
-group { \
clk40_NexysVideoClkgen \
} \
-group { \
clk50_NexysVideoClkgen \
clk67_NexysVideoClkgen \
} \
-group { \
clk100_cpuClkgen_1 \
} \
-group { \
clk40_cpuClkgen_1 \
} \
-group { \
clk20_cpuClkgen_1 \
} \
-group { \
clk100_cpuClkgen \
} \
-group { \
clk40_cpuClkgen \
} \
-group { \
clk20_cpuClkgen \
}

#set_clock_groups -asynchronous \
#-group { \
#uddr3/u_mig_7series_0_mig/u_ddr3_infrastructure/gen_mmcm.mmcm_i/CLKIN1 \
#ucg1/inst/mmcm_adv_inst/CLKOUT0 \
#ucg1/inst/mmcm_adv_inst/CLKOUT1 \
#} \
#-group { \
#ucg1/inst/mmcm_adv_inst/CLKOUT3 \
#} \
#-group { \
#ucg1/inst/mmcm_adv_inst/CLKOUT2 \
#ucg1/inst/mmcm_adv_inst/CLKOUT6 \
#}

#-group { \
#clk400_NexysVideoClkgen2 \
#clk57_NexysVideoClkgen2 \
#clk19_NexysVideoClkgen2 \
#} \
#-group { \
#clk14_NexysVideoClkgen \
#}
# \
#-group { \
#clk100_NexysVideoClkgen \
#clk14_NexysVideoClkgen \
#clk160_NexysVideoClkgen \
#clk200_NexysVideoClkgen \
#clk20_NexysVideoClkgen \
#clk40_NexysVideoClkgen \
#clk80_NexysVideoClkgen \
#} \
#-group { \
#clk100_NexysVideoCpuClkgen \
#clk25_NexysVideoCpuClkgen \
#clk50_NexysVideoCpuClkgen \
#}

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

