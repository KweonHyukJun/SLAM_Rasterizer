wvSetPosition -win $_nWave1 {("G1" 0)}
wvOpenFile -win $_nWave1 \
           {/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dump.fsdb}
verdiSetActWin -win $_nWave1
wvResizeWindow -win $_nWave1 0 23 2560 1377
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/tb_gradient_compare_unit"
wvSetPosition -win $_nWave1 {("G1" 38)}
wvSetPosition -win $_nWave1 {("G1" 38)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb_gradient_compare_unit/clk} \
{/tb_gradient_compare_unit/clk_cnt\[31:0\]} \
{/tb_gradient_compare_unit/counter\[31:0\]} \
{/tb_gradient_compare_unit/dL_dcolor_in_A\[0:0\]} \
{/tb_gradient_compare_unit/dL_dcolor_in_B\[0:0\]} \
{/tb_gradient_compare_unit/dL_dcolor_out\[1:0\]} \
{/tb_gradient_compare_unit/dL_dconic_in_A\[0:0\]} \
{/tb_gradient_compare_unit/dL_dconic_in_B\[0:0\]} \
{/tb_gradient_compare_unit/dL_dconic_out\[1:0\]} \
{/tb_gradient_compare_unit/dL_ddepth_in_A\[0:0\]} \
{/tb_gradient_compare_unit/dL_ddepth_in_B\[0:0\]} \
{/tb_gradient_compare_unit/dL_ddepth_out\[1:0\]} \
{/tb_gradient_compare_unit/dL_dmean2D_in_A\[0:0\]} \
{/tb_gradient_compare_unit/dL_dmean2D_in_B\[0:0\]} \
{/tb_gradient_compare_unit/dL_dmean2D_out\[1:0\]} \
{/tb_gradient_compare_unit/dL_dopacity_in_A\[0:0\]} \
{/tb_gradient_compare_unit/dL_dopacity_in_B\[0:0\]} \
{/tb_gradient_compare_unit/dL_dopacity_out\[1:0\]} \
{/tb_gradient_compare_unit/data_A_in\[0:0\]} \
{/tb_gradient_compare_unit/data_B_in\[0:0\]} \
{/tb_gradient_compare_unit/data_in} \
{/tb_gradient_compare_unit/data_out\[1:0\]} \
{/tb_gradient_compare_unit/file_handle\[31:0\]} \
{/tb_gradient_compare_unit/file_size\[31:0\]} \
{/tb_gradient_compare_unit/gaussian_id_in_A\[0:0\]} \
{/tb_gradient_compare_unit/gaussian_id_in_B\[0:0\]} \
{/tb_gradient_compare_unit/gaussian_id_out\[1:0\]} \
{/tb_gradient_compare_unit/j\[31:0\]} \
{/tb_gradient_compare_unit/mem_dL_dcolor\[3071:0\]} \
{/tb_gradient_compare_unit/mem_dL_dconic\[4095:0\]} \
{/tb_gradient_compare_unit/mem_dL_ddepth\[1023:0\]} \
{/tb_gradient_compare_unit/mem_dL_dmean2D\[2047:0\]} \
{/tb_gradient_compare_unit/mem_dL_dopacity\[1023:0\]} \
{/tb_gradient_compare_unit/mem_gaussian_id\[1023:0\]} \
{/tb_gradient_compare_unit/rst_n} \
{/tb_gradient_compare_unit/stall_cnt\[31:0\]} \
{/tb_gradient_compare_unit/stall_to_controller} \
{/tb_gradient_compare_unit/start} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 \
           18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 )} \
           
wvSetPosition -win $_nWave1 {("G1" 38)}
wvZoomAll -win $_nWave1
wvSetCursor -win $_nWave1 1619.027016 -snap {("G2" 0)}
wvSetCursor -win $_nWave1 1514.573660 -snap {("G1" 20)}
wvSetCursor -win $_nWave1 2002.733221 -snap {("G1" 13)}
wvSetCursor -win $_nWave1 468.974251 -snap {("G1" 6)}
wvSetCursor -win $_nWave1 1421.844660 -snap {("G1" 9)}
wvSetCursor -win $_nWave1 505.213170 -snap {("G1" 10)}
wvSetCursor -win $_nWave1 1512.441959 -snap {("G1" 2)}
wvSetCursor -win $_nWave1 495.620515 -snap {("G1" 2)}
wvSetCursor -win $_nWave1 1550.812579 -snap {("G1" 1)}
wvSetCursor -win $_nWave1 476.435205 -snap {("G1" 2)}
wvSetCursor -win $_nWave1 1510.310257 -snap {("G1" 2)}
wvSetCursor -win $_nWave1 133.231321 -snap {("G2" 0)}
wvSelectSignal -win $_nWave1 {( "G1" 37 )} 
wvResizeWindow -win $_nWave1 0 23 2560 1377
wvSelectSignal -win $_nWave1 {( "G1" 37 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G2" 0)}
wvSetPosition -win $_nWave1 {("G1" 37)}
wvSelectSignal -win $_nWave1 {( "G1" 19 )} 
wvSelectSignal -win $_nWave1 {( "G1" 20 )} 
wvSelectSignal -win $_nWave1 {( "G1" 22 )} 
wvSelectSignal -win $_nWave1 {( "G1" 23 )} 
wvSelectSignal -win $_nWave1 {( "G1" 22 )} 
wvSelectSignal -win $_nWave1 {( "G1" 22 )} 
wvSetPosition -win $_nWave1 {("G1" 22)}
wvExpandBus -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 39)}
wvSetCursor -win $_nWave1 1438.279774 -snap {("G2" 0)}
wvZoomAll -win $_nWave1
wvZoomAll -win $_nWave1
wvSetCursor -win $_nWave1 1553.588781 -snap {("G2" 0)}
wvExit
