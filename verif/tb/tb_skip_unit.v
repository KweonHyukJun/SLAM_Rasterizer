//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/09/19 11:25:32
// Design Name: 
// Module Name: tb_INT_tester
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_skip_and_alpha #(BLOCK_SIZE = 16, exponent_bit = 8, mantissa_bit= 23, precision = 32)();
    
    //input
    reg clk, rst_n;

    reg [15:0] block_id;
    reg i_valid;

    reg [( 2 * precision )-1:0] mean2D;
    reg [(4 * precision) - 1:0] conic_opacity;
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] pixel_id;

    wire skip_out;
    wire [precision-1:0] alpha_out;

    wire [precision-1:0] G_out;
    wire [( 2 * precision )-1:0] d_out;

    wire skip_and_alpha_done_out;

    localparam latency = 6;
    integer i = 0;

    parameter N_TEST = 1024;

    // Input Mem
    reg [precision -1:0] mem_conic_opacity [4 * N_TEST - 1 :0];
    reg [precision -1:0] mem_gaussian_color [3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];
    reg [precision -1:0] mem_T_in [N_TEST -1 :0];
    reg [precision -1:0] mem_dL_dpixel [3 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dpixel_depth [N_TEST-1:0];
    reg [precision -1:0] mem_d [2 * N_TEST -1 :0];
    reg [precision -1:0] mem_G [N_TEST -1 :0];

    reg [precision -1:0] mem_alpha [N_TEST -1 :0];
    reg mem_skip [N_TEST -1 :0];


    // Output Mem
    reg [precision -1:0] mem_dL_dcolor [3 * N_TEST -1 :0];
    reg [precision -1:0] mem_dL_ddepth [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dopacity [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dmean2D [2 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dconic [4 * N_TEST - 1:0];
    
    integer counter;

    integer file_handle;

    reg [(3 * precision) -1:0] ref_dL_dcolor;
    reg [precision -1:0] ref_dL_ddepth;
    reg [precision -1:0] ref_dL_dopacity;
    reg [(2 * precision) -1:0] ref_dL_dmean2D;
    reg [(4 * precision) -1:0] ref_dL_dconic;
    reg ref_valid;

    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_skip_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    skip_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),

        .block_id(block_id),

        .mean2D(mean2D),
        .conic_opacity(conic_opacity),
        .pixel_id(pixel_id),

        .skip_out(skip_out),
        .alpha_out(alpha_out),        

        .G_out(G_out),
        .d_out(d_out),

        .conic_opacity_out(conic_opacity_out),


        .skip_and_alpha_done_out(skip_and_alpha_done_out)
    );


    initial begin
        //for FP 16
        if (precision == 16 && mantissa_bit == 7) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/conic_opacityhex", mem_conic_opacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/T_in.hex", mem_T_in);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dpixel.hex", mem_dL_dpixel);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dpixel_depth.hex", mem_dL_dpixel_depth);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/d.hex", mem_d);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/G.hex", mem_G);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/alpha.hex", mem_alpha);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/skip.hex", mem_skip);
            

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_ddepths.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dconic.hex", mem_dL_dconic);
        end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/conic_opacity.hex", mem_conic_opacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/T_in.hex", mem_T_in);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_dpixel.hex", mem_dL_dpixel);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_dpixel_depth.hex", mem_dL_dpixel_depth);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/d.hex", mem_d);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/G.hex", mem_G);            

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/alpha.hex", mem_alpha);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/skip.hex", mem_skip);
            
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_ddepths.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp32/dL_dconic.hex", mem_dL_dconic);
        end

        //for FP 24
        if (precision == 24 && mantissa_bit == 15) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/conic_opacity.hex", mem_conic_opacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/T_in.hex", mem_T_in);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dpixel.hex", mem_dL_dpixel);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dpixel_depth.hex", mem_dL_dpixel_depth);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/d.hex", mem_d);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/G.hex", mem_G);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/alpha.hex", mem_alpha);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/skip.hex", mem_skip);
            
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_ddepths.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dconic.hex", mem_dL_dconic);
        end
    end
    
    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        block_id = 'h0;
        mean2D = 'b0;
        conic_opacity = 'b0;    
        pixel_id = 'b0;
        // pixel_id = 8'h00; // 0 , 0
        i_valid = 1'b0;

        #1;

        rst_n = 1'b1;    



    always @(posedge clk) begin
        
        if (counter < N_TEST) begin
            conic_opacity <= {mem_conic_opacity[4 * counter + 0], mem_conic_opacity[4 * counter + 1], mem_conic_opacity[4 * counter + 2], mem_conic_opacity[4 * counter + 3]};
            gaussian_color <= {mem_gaussian_color[3 * counter + 0], mem_gaussian_color[3 * counter + 1], mem_gaussian_color[3 * counter + 2]};
            gaussian_depth <= mem_gaussian_depth[counter];
            dL_dpixel <= {mem_dL_dpixel[3 * counter + 0], mem_dL_dpixel[3 * counter + 1], mem_dL_dpixel[3 * counter + 2]};
            dL_dpixel_depth <= {mem_dL_dpixel_depth[counter]};
            alpha_in <= mem_alpha[counter];
            d <= {mem_d[2*counter + 0], mem_d[2*counter +1]};
            G <= mem_G[counter];
            i_valid <= !mem_skip[counter];


            // ref_dL_dcolor <= {mem_dL_dcolor[3 * (counter) + 0 ], mem_dL_dcolor[3 * (counter) + 1 ], mem_dL_dcolor[3 * (counter) + 2]};
            // ref_dL_ddepth <= mem_dL_ddepth;
            // ref_dL_dopacity <= mem_dL_dopacity;
            // ref_dL_dmean2D <= {mem_dL_dmean2D[2* counter + 0], mem_dL_dmean2D[2* counter + 1]};
            // ref_dL_dconic <= {mem_dL_dconic[4 * counter + 0], mem_dL_dconic[4 * counter + 1], mem_dL_dconic[4 * counter + 2], mem_dL_dconic[4 * counter + 3]};
            // ref_skip <= mem_skip[counte];

            counter <= counter + 1;

            if (counter > 7) begin
            ref_dL_dcolor <= {mem_dL_dcolor[3 * (counter-8) + 0 ], mem_dL_dcolor[3 * (counter-8) + 1 ], mem_dL_dcolor[3 * (counter-8) + 2]};
            ref_dL_ddepth <= mem_dL_ddepth[counter-8];
            ref_dL_dopacity <= mem_dL_dopacity[counter-8];
            ref_dL_dmean2D <= {mem_dL_dmean2D[2 * (counter-8) + 0], mem_dL_dmean2D[2* (counter-8) + 1]};
            ref_dL_dconic <= {mem_dL_dconic[4 * (counter-8) + 0], mem_dL_dconic[4 * (counter-8) + 1], mem_dL_dconic[4 * (counter-8) + 2], mem_dL_dconic[4 * (counter-8) + 3]};
            ref_valid <= !mem_skip[counter-8];

                // if ((i_valid != ref_valid) && (dL_dcolor != ref_dL_dcolor) || (dL_ddepth != ref_dL_ddepth) || (dL_dopacity != ref_dL_dopacity) || (dL_dmean2D != ref_dL_dmean2D) || (dL_dconic != ref_dL_dconic)) begin
                //     // $display("#######################################################");
                //     // $display("At counter %d\n", counter);
                //     // $display("dL_dcolor = 0x%x, dL_dcolor_ref = 0x%x\n", dL_dcolor, ref_dL_dcolor);
                //     // $display("dL_ddepth = 0x%x, dL_ddepth_ref = 0x%x\n", dL_ddepth, ref_dL_ddepth);
                //     // $display("dL_dopacity = 0x%x, dL_dopacity_ref = 0x%x\n", dL_dopacity, ref_dL_dopacity);
                //     // $display("dL_dmean2D = 0x%x, dL_dmean2D_ref = 0x%x\n", dL_dmean2D, ref_dL_dmean2D);
                //     // $display("dL_dconic = 0x%x, dL_dconic_ref = 0x%x\n", dL_dconic, ref_dL_dconic);
                //     // $display("#######################################################\n");

                //         // Write comparison results to the text file
                //         $fwrite(file_handle, "##############################################################################################################\n");

                //         $fwrite(file_handle, "At counter %d valid : %h ref valid %h\n\n", counter, i_valid, ref_valid);
                //         $fwrite(file_handle, "dL_dcolor R : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(3*precision)-1: 2*precision], ref_dL_dcolor[(3*precision)-1: 2*precision], $signed(dL_dcolor[(3*precision)-1: 2*precision]) - $signed(ref_dL_dcolor[(3*precision)-1: 2*precision]));
                //         $fwrite(file_handle, "dL_dcolor G : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(2*precision)-1: precision], ref_dL_dcolor[(2*precision)-1: 1*precision], $signed(dL_dcolor[(2*precision)-1: precision]) - $signed(ref_dL_dcolor[(2*precision)-1: 1*precision]));
                //         $fwrite(file_handle, "dL_dcolor B : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(precision)-1: 0], ref_dL_dcolor[(precision)-1: 0], $signed(dL_dcolor[(precision)-1: 0]) - $signed(ref_dL_dcolor[(precision)-1: 0]));
                //         $fwrite(file_handle, "dL_ddepth = %d, dL_ddepth_ref = %d, difference = %d\n", dL_ddepth, ref_dL_ddepth, $signed(dL_ddepth) - $signed(ref_dL_ddepth));
                //         $fwrite(file_handle, "dL_dopacity = %d, dL_dopacity_ref = %d, difference = %d\n", dL_dopacity, ref_dL_dopacity, $signed(dL_dopacity) - $signed(ref_dL_dopacity));
                //         $fwrite(file_handle, "dL_dmean2D X: dL_dmean2D = %d, dL_dmean2D_ref = %d, difference = %d\n", dL_dmean2D[(2*precision)-1: precision], ref_dL_dmean2D[(2*precision)-1: precision], $signed(dL_dmean2D[(2*precision)-1: precision]) - $signed(ref_dL_dmean2D[(2*precision)-1: precision]));
                //         $fwrite(file_handle, "dL_dmean2D Y: dL_dmean2D = %d, dL_dmean2D_ref = %d, difference = %d\n", dL_dmean2D[(precision)-1: 0], ref_dL_dmean2D[(precision)-1: 0], $signed(dL_dmean2D[(precision)-1: 0]) - $signed(ref_dL_dmean2D[(precision)-1: 0]));
                //         $fwrite(file_handle, "dL_dconic X : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(4*precision)-1: 3*precision], ref_dL_dconic[(4*precision)-1: 3*precision], $signed(dL_dconic[(4*precision)-1: 3*precision]) - $signed(ref_dL_dconic[(4*precision)-1: 3*precision]));
                //         $fwrite(file_handle, "dL_dconic Y : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(3*precision)-1: 2*precision], ref_dL_dconic[(3*precision)-1: 2*precision], $signed(dL_dconic[(3*precision)-1: 2*precision]) - $signed(ref_dL_dconic[(3*precision)-1: 2*precision]));
                //         $fwrite(file_handle, "dL_dconic Z : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(2*precision)-1: precision], ref_dL_dconic[(2*precision)-1: precision], $signed(dL_dconic[(2*precision)-1: precision]) - $signed(ref_dL_dconic[(2*precision)-1: precision]));
                //         $fwrite(file_handle, "dL_dconic W : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(precision)-1: 0], ref_dL_dconic[(precision)-1: 0], $signed(dL_dconic[(precision)-1: 0]) - $signed(ref_dL_dconic[(precision)-1: 0]));
                //         $fwrite(file_handle, "##############################################################################################################\n\n");
                //         end
                // else begin
                //     $fwrite(file_handle, "Correct Results\n");
                // end

                // Write comparison results to the text file
                $fwrite(file_handle, "##############################################################################################################\n");
                $fwrite(file_handle, "At counter %d valid : %h ref valid %h\n\n", counter, gradient_valid_out, ref_valid);
                $fwrite(file_handle, "dL_dcolor R : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(3*precision)-1: 2*precision], ref_dL_dcolor[(3*precision)-1: 2*precision], $signed(dL_dcolor[(3*precision)-1: 2*precision]) - $signed(ref_dL_dcolor[(3*precision)-1: 2*precision]));
                $fwrite(file_handle, "dL_dcolor G : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(2*precision)-1: precision], ref_dL_dcolor[(2*precision)-1: 1*precision], $signed(dL_dcolor[(2*precision)-1: precision]) - $signed(ref_dL_dcolor[(2*precision)-1: 1*precision]));
                $fwrite(file_handle, "dL_dcolor B : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(precision)-1: 0], ref_dL_dcolor[(precision)-1: 0], $signed(dL_dcolor[(precision)-1: 0]) - $signed(ref_dL_dcolor[(precision)-1: 0]));
                $fwrite(file_handle, "dL_ddepth = %d, dL_ddepth_ref = %d, difference = %d\n", dL_ddepth, ref_dL_ddepth, $signed(dL_ddepth) - $signed(ref_dL_ddepth));
                $fwrite(file_handle, "dL_dopacity = %d, dL_dopacity_ref = %d, difference = %d\n", dL_dopacity, ref_dL_dopacity, $signed(dL_dopacity) - $signed(ref_dL_dopacity));
                $fwrite(file_handle, "dL_dmean2D X: dL_dmean2D = %d, dL_dmean2D_ref = %d, difference = %d\n", dL_dmean2D[(2*precision)-1: precision], ref_dL_dmean2D[(2*precision)-1: precision], $signed(dL_dmean2D[(2*precision)-1: precision]) - $signed(ref_dL_dmean2D[(2*precision)-1: precision]));
                $fwrite(file_handle, "dL_dmean2D Y: dL_dmean2D = %d, dL_dmean2D_ref = %d, difference = %d\n", dL_dmean2D[(precision)-1: 0], ref_dL_dmean2D[(precision)-1: 0], $signed(dL_dmean2D[(precision)-1: 0]) - $signed(ref_dL_dmean2D[(precision)-1: 0]));
                $fwrite(file_handle, "dL_dconic X : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(4*precision)-1: 3*precision], ref_dL_dconic[(4*precision)-1: 3*precision], $signed(dL_dconic[(4*precision)-1: 3*precision]) - $signed(ref_dL_dconic[(4*precision)-1: 3*precision]));
                $fwrite(file_handle, "dL_dconic Y : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(3*precision)-1: 2*precision], ref_dL_dconic[(3*precision)-1: 2*precision], $signed(dL_dconic[(3*precision)-1: 2*precision]) - $signed(ref_dL_dconic[(3*precision)-1: 2*precision]));
                $fwrite(file_handle, "dL_dconic Z : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(2*precision)-1: precision], ref_dL_dconic[(2*precision)-1: precision], $signed(dL_dconic[(2*precision)-1: precision]) - $signed(ref_dL_dconic[(2*precision)-1: precision]));
                $fwrite(file_handle, "dL_dconic W : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(precision)-1: 0], ref_dL_dconic[(precision)-1: 0], $signed(dL_dconic[(precision)-1: 0]) - $signed(ref_dL_dconic[(precision)-1: 0]));
                $fwrite(file_handle, "##############################################################################################################\n\n");
            end
        end

        else begin
            i_valid <= 1'b0;
            $fclose(file_handle); // Close the file when simulation is done
            $finish;
        end
    end

endmodule
