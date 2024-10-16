wvSetPosition -win $_nWave1 {("G1" 0)}
wvOpenFile -win $_nWave1 \
           {/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dump.fsdb}
verdiSetActWin -win $_nWave1
wvResizeWindow -win $_nWave1 0 23 2560 1377
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/tb_total_gradient"
wvSetPosition -win $_nWave1 {("G1" 49)}
wvSetPosition -win $_nWave1 {("G1" 49)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb_total_gradient/G\[15:0\]} \
{/tb_total_gradient/H\[11:0\]} \
{/tb_total_gradient/T_first\[15:0\]} \
{/tb_total_gradient/T_first_valid} \
{/tb_total_gradient/W\[11:0\]} \
{/tb_total_gradient/alpha_in\[15:0\]} \
{/tb_total_gradient/clk} \
{/tb_total_gradient/clk_cnt\[31:0\]} \
{/tb_total_gradient/conic_opacity\[63:0\]} \
{/tb_total_gradient/counter\[31:0\]} \
{/tb_total_gradient/dL_dcolor\[47:0\]} \
{/tb_total_gradient/dL_dconic\[63:0\]} \
{/tb_total_gradient/dL_ddepth\[15:0\]} \
{/tb_total_gradient/dL_dmean2D\[31:0\]} \
{/tb_total_gradient/dL_dopacity\[15:0\]} \
{/tb_total_gradient/dL_dpixel\[47:0\]} \
{/tb_total_gradient/dL_dpixel_depth\[15:0\]} \
{/tb_total_gradient/d\[31:0\]} \
{/tb_total_gradient/file_handle\[31:0\]} \
{/tb_total_gradient/gaussian_color\[47:0\]} \
{/tb_total_gradient/gaussian_depth\[15:0\]} \
{/tb_total_gradient/gradient_valid_out} \
{/tb_total_gradient/gradient_valid_out_reg} \
{/tb_total_gradient/i\[31:0\]} \
{/tb_total_gradient/i_valid} \
{/tb_total_gradient/mem_G\[1023:0\]} \
{/tb_total_gradient/mem_T_in\[1023:0\]} \
{/tb_total_gradient/mem_alpha\[1023:0\]} \
{/tb_total_gradient/mem_conic_opacity\[4095:0\]} \
{/tb_total_gradient/mem_dL_dcolor\[3071:0\]} \
{/tb_total_gradient/mem_dL_dconic\[4095:0\]} \
{/tb_total_gradient/mem_dL_ddepth\[1023:0\]} \
{/tb_total_gradient/mem_dL_dmean2D\[2047:0\]} \
{/tb_total_gradient/mem_dL_dopacity\[1023:0\]} \
{/tb_total_gradient/mem_dL_dpixel\[3071:0\]} \
{/tb_total_gradient/mem_dL_dpixel_depth\[1023:0\]} \
{/tb_total_gradient/mem_d\[2047:0\]} \
{/tb_total_gradient/mem_gaussian_color\[3071:0\]} \
{/tb_total_gradient/mem_gaussian_depth\[1023:0\]} \
{/tb_total_gradient/mem_skip\[1023:0\]} \
{/tb_total_gradient/ref_dL_dcolor\[47:0\]} \
{/tb_total_gradient/ref_dL_dconic\[63:0\]} \
{/tb_total_gradient/ref_dL_ddepth\[15:0\]} \
{/tb_total_gradient/ref_dL_dmean2D\[31:0\]} \
{/tb_total_gradient/ref_dL_dopacity\[15:0\]} \
{/tb_total_gradient/ref_valid} \
{/tb_total_gradient/rst_n} \
{/tb_total_gradient/start} \
{/tb_total_gradient/start_ready\[31:0\]} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 \
           18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 \
           40 41 42 43 44 45 46 47 48 49 )} 
wvSetPosition -win $_nWave1 {("G1" 49)}
wvGetSignalClose -win $_nWave1
wvZoomAll -win $_nWave1
wvSetCursor -win $_nWave1 2417.349092 -snap {("G1" 1)}
wvSelectSignal -win $_nWave1 {( "G1" 3 )} 
wvSelectSignal -win $_nWave1 {( "G1" 5 )} 
wvSelectSignal -win $_nWave1 {( "G1" 5 )} 
wvSelectSignal -win $_nWave1 {( "G1" 6 )} 
wvResizeWindow -win $_nWave1 0 23 2560 1377
wvGetSignalOpen -win $_nWave1
wvGetSignalSetScope -win $_nWave1 "/tb_total_gradient"
wvGetSignalSetScope -win $_nWave1 "/tb_total_gradient"
wvGetSignalSetScope -win $_nWave1 "/tb_total_gradient/uut"
wvSetPosition -win $_nWave1 {("G1" 50)}
wvSetPosition -win $_nWave1 {("G1" 50)}
wvAddSignal -win $_nWave1 -clear
wvAddSignal -win $_nWave1 -group {"G1" \
{/tb_total_gradient/G\[15:0\]} \
{/tb_total_gradient/H\[11:0\]} \
{/tb_total_gradient/T_first\[15:0\]} \
{/tb_total_gradient/T_first_valid} \
{/tb_total_gradient/W\[11:0\]} \
{/tb_total_gradient/alpha_in\[15:0\]} \
{/tb_total_gradient/clk} \
{/tb_total_gradient/clk_cnt\[31:0\]} \
{/tb_total_gradient/conic_opacity\[63:0\]} \
{/tb_total_gradient/counter\[31:0\]} \
{/tb_total_gradient/dL_dcolor\[47:0\]} \
{/tb_total_gradient/dL_dconic\[63:0\]} \
{/tb_total_gradient/dL_ddepth\[15:0\]} \
{/tb_total_gradient/dL_dmean2D\[31:0\]} \
{/tb_total_gradient/dL_dopacity\[15:0\]} \
{/tb_total_gradient/dL_dpixel\[47:0\]} \
{/tb_total_gradient/dL_dpixel_depth\[15:0\]} \
{/tb_total_gradient/d\[31:0\]} \
{/tb_total_gradient/file_handle\[31:0\]} \
{/tb_total_gradient/gaussian_color\[47:0\]} \
{/tb_total_gradient/gaussian_depth\[15:0\]} \
{/tb_total_gradient/gradient_valid_out} \
{/tb_total_gradient/gradient_valid_out_reg} \
{/tb_total_gradient/i\[31:0\]} \
{/tb_total_gradient/i_valid} \
{/tb_total_gradient/mem_G\[1023:0\]} \
{/tb_total_gradient/mem_T_in\[1023:0\]} \
{/tb_total_gradient/mem_alpha\[1023:0\]} \
{/tb_total_gradient/mem_conic_opacity\[4095:0\]} \
{/tb_total_gradient/mem_dL_dcolor\[3071:0\]} \
{/tb_total_gradient/mem_dL_dconic\[4095:0\]} \
{/tb_total_gradient/mem_dL_ddepth\[1023:0\]} \
{/tb_total_gradient/mem_dL_dmean2D\[2047:0\]} \
{/tb_total_gradient/mem_dL_dopacity\[1023:0\]} \
{/tb_total_gradient/mem_dL_dpixel\[3071:0\]} \
{/tb_total_gradient/mem_dL_dpixel_depth\[1023:0\]} \
{/tb_total_gradient/mem_d\[2047:0\]} \
{/tb_total_gradient/mem_gaussian_color\[3071:0\]} \
{/tb_total_gradient/mem_gaussian_depth\[1023:0\]} \
{/tb_total_gradient/mem_skip\[1023:0\]} \
{/tb_total_gradient/ref_dL_dcolor\[47:0\]} \
{/tb_total_gradient/ref_dL_dconic\[63:0\]} \
{/tb_total_gradient/ref_dL_ddepth\[15:0\]} \
{/tb_total_gradient/ref_dL_dmean2D\[31:0\]} \
{/tb_total_gradient/ref_dL_dopacity\[15:0\]} \
{/tb_total_gradient/ref_valid} \
{/tb_total_gradient/rst_n} \
{/tb_total_gradient/start} \
{/tb_total_gradient/start_ready\[31:0\]} \
{/tb_total_gradient/uut/T2\[15:0\]} \
}
wvAddSignal -win $_nWave1 -group {"G2" \
}
wvSelectSignal -win $_nWave1 {( "G1" 50 )} 
wvSetPosition -win $_nWave1 {("G1" 50)}
wvSetPosition -win $_nWave1 {("G1" 47)}
wvSetPosition -win $_nWave1 {("G1" 36)}
wvSetPosition -win $_nWave1 {("G1" 33)}
wvSetPosition -win $_nWave1 {("G1" 32)}
wvSetPosition -win $_nWave1 {("G1" 29)}
wvSetPosition -win $_nWave1 {("G1" 28)}
wvSetPosition -win $_nWave1 {("G1" 26)}
wvSetPosition -win $_nWave1 {("G1" 24)}
wvSetPosition -win $_nWave1 {("G1" 23)}
wvSetPosition -win $_nWave1 {("G1" 22)}
wvSetPosition -win $_nWave1 {("G1" 21)}
wvSetPosition -win $_nWave1 {("G1" 20)}
wvSetPosition -win $_nWave1 {("G1" 19)}
wvSetPosition -win $_nWave1 {("G1" 17)}
wvSetPosition -win $_nWave1 {("G1" 16)}
wvSetPosition -win $_nWave1 {("G1" 15)}
wvSetPosition -win $_nWave1 {("G1" 14)}
wvSetPosition -win $_nWave1 {("G1" 13)}
wvSetPosition -win $_nWave1 {("G1" 12)}
wvSetPosition -win $_nWave1 {("G1" 11)}
wvSetPosition -win $_nWave1 {("G1" 10)}
wvSetPosition -win $_nWave1 {("G1" 9)}
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSetPosition -win $_nWave1 {("G1" 7)}
wvSetPosition -win $_nWave1 {("G1" 6)}
wvMoveSelected -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 6)}
wvSetPosition -win $_nWave1 {("G1" 7)}
wvSetCursor -win $_nWave1 1249.501958 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 604.597722 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 967.356355 -snap {("G1" 8)}
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSetPosition -win $_nWave1 {("G1" 11)}
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSetPosition -win $_nWave1 {("G1" 7)}
wvMoveSelected -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 7)}
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSetCursor -win $_nWave1 3143.908152 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 2499.003916 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 3305.134211 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 4151.571022 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 3869.425418 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 3627.586330 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 2176.551798 -snap {("G1" 11)}
wvSetCursor -win $_nWave1 3022.988608 -snap {("G1" 11)}
wvSetCursor -win $_nWave1 2740.843005 -snap {("G1" 11)}
wvSetCursor -win $_nWave1 3224.521182 -snap {("G1" 11)}
wvSelectSignal -win $_nWave1 {( "G1" 7 )} 
wvSetCursor -win $_nWave1 1894.406194 -snap {("G1" 8)}
wvSetCursor -win $_nWave1 5562.299039 -snap {("G1" 7)}
wvSelectSignal -win $_nWave1 {( "G1" 10 )} 
wvSelectSignal -win $_nWave1 {( "G1" 9 )} 
wvSelectSignal -win $_nWave1 {( "G1" 27 )} 
wvSelectSignal -win $_nWave1 {( "G1" 26 )} 
wvSelectSignal -win $_nWave1 {( "G1" 20 )} 
wvSelectSignal -win $_nWave1 {( "G1" 21 )} 
wvSelectSignal -win $_nWave1 {( "G1" 23 )} 
wvSelectSignal -win $_nWave1 {( "G1" 43 )} 
wvSetCursor -win $_nWave1 4514.329655 -snap {("G1" 7)}
wvSetCursor -win $_nWave1 6005.670701 -snap {("G1" 7)}
wvSetCursor -win $_nWave1 6650.574938 -snap {("G1" 6)}
wvSetCursor -win $_nWave1 4917.394802 -snap {("G1" 6)}
wvZoom -win $_nWave1 0.000000 10479.693841
wvSelectSignal -win $_nWave1 {( "G1" 26 )} 
wvSelectSignal -win $_nWave1 {( "G1" 27 )} 
wvSelectSignal -win $_nWave1 {( "G1" 27 28 29 30 31 32 33 34 35 36 37 38 39 40 \
           41 42 43 44 45 46 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSelectSignal -win $_nWave1 {( "G1" 27 )} 
wvSetCursor -win $_nWave1 3653.298482 -snap {("G2" 0)}
wvZoomAll -win $_nWave1
wvSetCursor -win $_nWave1 5488.301887 -snap {("G1" 6)}
wvSelectSignal -win $_nWave1 {( "G1" 7 )} 
wvZoom -win $_nWave1 7717.924528 8318.207547
wvSetCursor -win $_nWave1 7931.232645 -snap {("G2" 0)}
wvZoomAll -win $_nWave1
wvSetCursor -win $_nWave1 25812.169811 -snap {("G1" 25)}
wvSelectSignal -win $_nWave1 {( "G1" 24 )} 
wvSelectSignal -win $_nWave1 {( "G1" 23 )} 
wvSelectSignal -win $_nWave1 {( "G1" 27 )} 
wvSelectSignal -win $_nWave1 {( "G1" 24 )} 
wvSelectSignal -win $_nWave1 {( "G1" 23 )} 
wvSelectSignal -win $_nWave1 {( "G1" 24 )} 
wvSetCursor -win $_nWave1 27141.367925 -snap {("G1" 24)}
wvSetCursor -win $_nWave1 29113.726415 -snap {("G1" 25)}
wvSetCursor -win $_nWave1 32543.915094 -snap {("G1" 24)}
wvSetCursor -win $_nWave1 34259.009434 -snap {("G1" 24)}
wvSetCursor -win $_nWave1 35545.330189 -snap {("G1" 24)}
wvSetCursor -win $_nWave1 37732.075472 -snap {("G1" 24)}
wvSetCursor -win $_nWave1 47508.113208 -snap {("G1" 25)}
wvSetCursor -win $_nWave1 52138.867925 -snap {("G1" 25)}
wvSetCursor -win $_nWave1 58656.226415 -snap {("G1" 25)}
wvSetCursor -win $_nWave1 65902.500000 -snap {("G1" 26)}
wvSetCursor -win $_nWave1 64701.933962 -snap {("G1" 25)}
wvSetCursor -win $_nWave1 63372.735849 -snap {("G1" 26)}
wvSelectSignal -win $_nWave1 {( "G1" 27 )} 
wvSelectSignal -win $_nWave1 {( "G1" 28 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSelectSignal -win $_nWave1 {( "G1" 26 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSelectSignal -win $_nWave1 {( "G1" 24 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSelectSignal -win $_nWave1 {( "G1" 5 )} 
wvSelectSignal -win $_nWave1 {( "G1" 6 )} 
wvSelectSignal -win $_nWave1 {( "G1" 9 )} 
wvSelectSignal -win $_nWave1 {( "G1" 10 )} 
wvSelectSignal -win $_nWave1 {( "G1" 11 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 )} 
wvSelectSignal -win $_nWave1 {( "G1" 12 13 14 15 16 17 18 19 20 21 22 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSelectSignal -win $_nWave1 {( "G1" 1 )} 
wvSelectSignal -win $_nWave1 {( "G1" 1 2 )} 
wvCut -win $_nWave1
wvSetPosition -win $_nWave1 {("G1" 8)}
wvSetPosition -win $_nWave1 {("G1" 6)}
wvSelectSignal -win $_nWave1 {( "G1" 4 )} 
wvZoom -win $_nWave1 986.179245 15178.584906
wvSetCursor -win $_nWave1 3479.095064 -snap {("G1" 1)}
wvSetCursor -win $_nWave1 3466.343577 -snap {("G1" 2)}
wvSetCursor -win $_nWave1 4531.092788 -snap {("G1" 4)}
wvSetCursor -win $_nWave1 7801.849349 -snap {("G1" 0)}
wvSetCursor -win $_nWave1 5079.406754 -snap {("G1" 4)}
wvSetCursor -win $_nWave1 8745.459429 -snap {("G1" 1)}
wvSetCursor -win $_nWave1 3632.112915 -snap {("G1" 4)}
wvSetCursor -win $_nWave1 2656.624116 -snap {("G1" 2)}
wvSelectSignal -win $_nWave1 {( "G1" 2 )} 
wvSetCursor -win $_nWave1 4652.231920 -snap {("G1" 7)}
wvSetCursor -win $_nWave1 4875.382953 -snap {("G1" 5)}
wvExit
