wvSetPosition -win $_nWave1 {("G1" 0)}
wvOpenFile -win $_nWave1 \
           {/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output_shared_submodules/shared_submodules_dump.fsdb}
verdiSetActWin -win $_nWave1
wvResizeWindow -win $_nWave1 0 23 2560 1377
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/tb_push_pop_FIFO"
wvSetPosition -win $_nWave1 {("G1" 9)}
wvSetPosition -win $_nWave1 {("G1" 9)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb_push_pop_FIFO/clk} \
{/tb_push_pop_FIFO/clk_cnt\[31:0\]} \
{/tb_push_pop_FIFO/empty_out} \
{/tb_push_pop_FIFO/full_out} \
{/tb_push_pop_FIFO/pop_data_out\[175:0\]} \
{/tb_push_pop_FIFO/pop_valid_in} \
{/tb_push_pop_FIFO/push_data_in\[175:0\]} \
{/tb_push_pop_FIFO/push_valid_in} \
{/tb_push_pop_FIFO/rst_n} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 1 2 3 4 5 6 7 8 9 )} 
wvSetPosition -win $_nWave1 {("G1" 9)}
wvSetPosition -win $_nWave1 {("G1" 27)}
wvSetPosition -win $_nWave1 {("G1" 27)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb_push_pop_FIFO/clk} \
{/tb_push_pop_FIFO/clk_cnt\[31:0\]} \
{/tb_push_pop_FIFO/empty_out} \
{/tb_push_pop_FIFO/full_out} \
{/tb_push_pop_FIFO/pop_data_out\[175:0\]} \
{/tb_push_pop_FIFO/pop_valid_in} \
{/tb_push_pop_FIFO/push_data_in\[175:0\]} \
{/tb_push_pop_FIFO/push_valid_in} \
{/tb_push_pop_FIFO/rst_n} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/clk} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/data\[15:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/empty} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/empty_next} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/empty_out} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/full} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/full_next} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/full_out} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/i\[31:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/pop_data_out\[175:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/pop_pointer\[4:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/pop_pointer_next\[4:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/pop_valid_in} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/push_data_in\[175:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/push_pointer\[4:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/push_pointer_next\[4:0\]} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/push_valid_in} \
{/tb_push_pop_FIFO/push_pop_FIFO_inst/rst_n} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 10 11 12 13 14 15 16 17 18 19 20 21 22 23 \
           24 25 26 27 )} 
wvSetPosition -win $_nWave1 {("G1" 27)}
wvSetPosition -win $_nWave1 {("G1" 19)}
wvSetPosition -win $_nWave1 {("G1" 23)}
wvSetPosition -win $_nWave1 {("G2" 0)}
wvMoveSelected -win $_nWave1
wvSetPosition -win $_nWave1 {("G2" 18)}
wvSetPosition -win $_nWave1 {("G2" 18)}
wvSetCursor -win $_nWave1 8111.514961 -snap {("G3" 0)}
wvSelectSignal -win $_nWave1 {( "G2" 2 )} 
wvSetPosition -win $_nWave1 {("G2" 2)}
wvExpandBus -win $_nWave1
wvSetPosition -win $_nWave1 {("G2" 34)}
wvSetCursor -win $_nWave1 12898.412396 -snap {("G2" 27)}
wvZoomAll -win $_nWave1
wvSetCursor -win $_nWave1 56438.706205 -snap {("G1" 5)}
wvSetCursor -win $_nWave1 55621.411988 -snap {("G1" 5)}
wvSetCursor -win $_nWave1 54667.902068 -snap {("G1" 6)}
wvSetCursor -win $_nWave1 54123.039257 -snap {("G1" 5)}
wvSetCursor -win $_nWave1 55394.385817 -snap {("G1" 4)}
wvSelectSignal -win $_nWave1 {( "G1" 4 )} 
wvSelectSignal -win $_nWave1 {( "G1" 2 )} 
wvSelectSignal -win $_nWave1 {( "G1" 6 )} 
wvResizeWindow -win $_nWave1 0 23 2560 1377
wvSelectSignal -win $_nWave1 {( "G1" 5 )} 
wvSelectSignal -win $_nWave1 {( "G1" 5 )} 
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvSearchNext -win $_nWave1
wvExit
