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

module tb_total_gradient #(BLOCK_SIZE = 16, exponent_bit = 8, mantissa_bit= 7, precision = 16)();
    
    //input
    reg clk, rst_n;

    reg [11:0] W, H;
    reg i_valid;

    reg [precision-1:0] G;
    reg [( 2 * precision )-1:0] d;
    reg [(4 * precision) - 1:0] conic_opacity;
    reg [precision-1:0] alpha_in;

    reg [precision-1:0] T_first;
    reg T_first_valid;

    reg [(3 * precision)-1:0] gaussian_color; // | R | G | B |
    reg [precision-1:0] gaussian_depth;

    reg [(3 * precision)-1:0] dL_dpixel; // dL_dpixel
    reg [precision-1:0] dL_dpixel_depth;

    wire [(3 * precision)-1:0] dL_dcolor;
    wire [precision-1:0] dL_ddepth;
    wire [(2 * precision) - 1:0] dL_dmean2D;
    wire [(4 * precision) - 1:0] dL_dconic;
    wire [precision - 1:0] dL_dopacity; //tracking시 불필요

    wire gradient_valid_out;
 
    localparam latency = 9;
    integer i = 0;
    reg start;
    integer start_ready;
    
    parameter file_size = 82;
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
    reg gradient_valid_out_reg;


    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_gradient_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    // Instantiate the DUT (Device Under Test)
    gradient_unit #(   .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision)) 
    uut (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),

        .G(G),
        .d(d),

        .W(W),
        .H(H),

        .T_first(T_first),
        .T_first_valid(T_first_valid),

        .conic_opacity(conic_opacity),
        .alpha_in(alpha_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),
        .dL_dpixel(dL_dpixel),
        .dL_dpixel_depth(dL_dpixel_depth),

        .dL_dcolor(dL_dcolor),
        .dL_ddepth(dL_ddepth),
        .dL_dmean2D(dL_dmean2D),
        .dL_dconic(dL_dconic),
        .dL_dopacity(dL_dopacity),

        .gradient_valid_out(gradient_valid_out)
    );

    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end    

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 10000) $finish;
    end


    initial begin
        //for FP 16
        if (precision == 16 && mantissa_bit == 7) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/conic_opacity.hex", mem_conic_opacity);
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
    
    initial begin
        file_handle = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/Testbench_output.txt", "w");
        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        clk = 1'b0;
        rst_n = 1'b0;
        i_valid = 1'b0;

        H = 'd480;
        W = 'd640;

        G = 'h0;  // Example: 1.0 in IEEE 754
        d = 'h0;  // Example: Double precision value
        conic_opacity = 'h0;  // Example: Fully opaque

        T_first = 'h0;
        T_first_valid = 1'b0;

        alpha_in = 'h0;  // Example: 0.5 in IEEE 754
        gaussian_color = 'h0;  // Example: RGB = 1.0
        gaussian_depth = 'h0;  // Example: 0.5

        dL_dpixel = 'h0;  // Example: Gradient of pixel
        dL_dpixel_depth = 'h0;  // Example: Small gradient

        counter = 0;
        start = 1'b0;
        start_ready = 0;
        @(posedge clk);
        @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        T_first <= mem_T_in[0];
        T_first_valid <= 1'b1;
        start = 1'b1;

        @(posedge clk);
        T_first_valid <= 1'b0;


        // Simulation: Reset at first posedge, apply inputs at second
        // @(posedge clk);
        // rst_n <= 1'b1;  // Deassert reset
        // T_first <= mem_T_in[0];
        // T_first_valid <= 1'b1;

        // @(posedge clk);
        // T_first <= 'h0;
        // T_first_valid <= 1'b0;
        // start <= 1'b1;

    end


    always @(posedge clk) begin
            if (counter <= file_size + latency + 1 && start) begin
                conic_opacity <= {mem_conic_opacity[4 * counter + 0], mem_conic_opacity[4 * counter + 1], mem_conic_opacity[4 * counter + 2], mem_conic_opacity[4 * counter + 3]};
                gaussian_color <= {mem_gaussian_color[3 * counter + 0], mem_gaussian_color[3 * counter + 1], mem_gaussian_color[3 * counter + 2]};
                gaussian_depth <= mem_gaussian_depth[counter];
                dL_dpixel <= {mem_dL_dpixel[3 * counter + 0], mem_dL_dpixel[3 * counter + 1], mem_dL_dpixel[3 * counter + 2]};
                dL_dpixel_depth <= {mem_dL_dpixel_depth[counter]};

                alpha_in <= mem_alpha[counter];
                d <= {mem_d[2*counter + 0], mem_d[2*counter +1]};
                G <= mem_G[counter];
                i_valid <= !mem_skip[counter];


                counter <= counter + 1;

                if (counter >= latency) begin
                ref_dL_dcolor <= {mem_dL_dcolor[3 * (counter - latency) + 0 ], mem_dL_dcolor[3 * (counter-latency) + 1 ], mem_dL_dcolor[3 * (counter-latency) + 2]};
                ref_dL_ddepth <= mem_dL_ddepth[counter-latency];
                ref_dL_dopacity <= mem_dL_dopacity[counter-latency];
                ref_dL_dmean2D <= {mem_dL_dmean2D[2 * (counter-latency) + 0], mem_dL_dmean2D[2* (counter-latency) + 1]};
                ref_dL_dconic <= {mem_dL_dconic[4 * (counter-latency) + 0], mem_dL_dconic[4 * (counter-latency) + 1], mem_dL_dconic[4 * (counter-latency) + 2], mem_dL_dconic[4 * (counter-latency) + 3]};
                ref_valid <= !mem_skip[counter-latency];


                    if ( // 둘다 11인데 값이 다르거나, 둘의 valid 값이 다른경우
                        ((ref_valid && gradient_valid_out) && ((dL_dcolor != ref_dL_dcolor) || (dL_ddepth != ref_dL_ddepth) || (dL_dopacity != ref_dL_dopacity) || (dL_dmean2D != ref_dL_dmean2D) || (dL_dconic != ref_dL_dconic)))
                        || ((ref_valid && gradient_valid_out) != (ref_valid || gradient_valid_out)) 
                    ) begin
                    // Write comparison results to the text file
                        $fwrite(file_handle, "##############################################################################################################\n");
                        $fwrite(file_handle, "At counter %d, gradient valid : %h ref gradient valid %h\n\n", counter, gradient_valid_out, ref_valid);
                        $fwrite(file_handle, "dL_dcolor R : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(3*precision)-1: 2*precision], ref_dL_dcolor[(3*precision)-1: 2*precision], $signed(dL_dcolor[(3*precision)-1: 2*precision]) - $signed(ref_dL_dcolor[(3*precision)-1: 2*precision]));
                        $fwrite(file_handle, "dL_dcolor G : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(2*precision)-1: precision], ref_dL_dcolor[(2*precision)-1: 1*precision], $signed(dL_dcolor[(2*precision)-1: precision]) - $signed(ref_dL_dcolor[(2*precision)-1: 1*precision]));
                        $fwrite(file_handle, "dL_dcolor B : dL_dcolor = %d, dL_dcolor_ref = %d, difference = %d\n", dL_dcolor[(precision)-1: 0], ref_dL_dcolor[(precision)-1: 0], $signed(dL_dcolor[(precision)-1: 0]) - $signed(ref_dL_dcolor[(precision)-1: 0]));
                        $fwrite(file_handle, "dL_ddepth = %d, dL_ddepth_ref = %d, difference = %d\n", dL_ddepth, ref_dL_ddepth, $signed(dL_ddepth) - $signed(ref_dL_ddepth));
                        $fwrite(file_handle, "dL_dopacity = %d, dL_dopacity_ref = %d, difference = %d\n", dL_dopacity, ref_dL_dopacity, $signed(dL_dopacity) - $signed(ref_dL_dopacity));
                        $fwrite(file_handle, "dL_dmean2D X: dL_dmean2D = %d, dL_dmean2D_ref = %d, difference = %d\n", dL_dmean2D[(2*precision)-1: precision], ref_dL_dmean2D[(2*precision)-1: precision], $signed(dL_dmean2D[(2*precision)-1: precision]) - $signed(ref_dL_dmean2D[(2*precision)-1: precision]));
                        $fwrite(file_handle, "dL_dmean2D Y: dL_dmean2D = %d, dL_dmean2D_ref = %d, difference = %d\n", dL_dmean2D[(precision)-1: 0], ref_dL_dmean2D[(precision)-1: 0], $signed(dL_dmean2D[(precision)-1: 0]) - $signed(ref_dL_dmean2D[(precision)-1: 0]));
                        $fwrite(file_handle, "dL_dconic X : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(4*precision)-1: 3*precision], ref_dL_dconic[(4*precision)-1: 3*precision], $signed(dL_dconic[(4*precision)-1: 3*precision]) - $signed(ref_dL_dconic[(4*precision)-1: 3*precision]));
                        $fwrite(file_handle, "dL_dconic Y : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(3*precision)-1: 2*precision], ref_dL_dconic[(3*precision)-1: 2*precision], $signed(dL_dconic[(3*precision)-1: 2*precision]) - $signed(ref_dL_dconic[(3*precision)-1: 2*precision]));
                        // $fwrite(file_handle, "dL_dconic Z : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(2*precision)-1: precision], ref_dL_dconic[(2*precision)-1: precision], $signed(dL_dconic[(2*precision)-1: precision]) - $signed(ref_dL_dconic[(2*precision)-1: precision]));
                        $fwrite(file_handle, "dL_dconic W : dL_dconic= %d, dL_dconic_ref = %d, difference = %d\n", dL_dconic[(precision)-1: 0], ref_dL_dconic[(precision)-1: 0], $signed(dL_dconic[(precision)-1: 0]) - $signed(ref_dL_dconic[(precision)-1: 0]));
                        $fwrite(file_handle, "##############################################################################################################\n\n");
                    end
                end
            end

            else if (counter >= latency + file_size + 2) begin
                i_valid <= 1'b0;  // Stop sending inputs
                $fclose(file_handle);  // Close the file
                $finish;  // End simulation
            end
        end

endmodule
