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

module tb_Rasterizer_unit #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 32 , mantissa_bit = 23, gaussian_inputs = 4, GID_bit = 24) ();
    //input
    //reset and clock
    reg clk;
    reg rst_n;
    
    // // Backward input and output << move up to block controller
    // reg [(2 * precision) -1:0] block_gaussian_range; // int32 x and y
    // reg [31:0] block_point_list;


    // reg skip;

    reg [11:0] W;
    reg [11:0] H;

    reg i_valid [gaussian_inputs-1:0];

    reg last_input [gaussian_inputs-1:0];

    reg stall_backpressure;

    reg [15:0] block_id ; // block index x at [0] y at [1]
    reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id;

    reg [precision-1 :0] T_first;
    
    // reg [(3 * precision) -1:0] background_color; //fp32 | R | G | B |

    reg [(2 * precision) -1:0] mean2D [gaussian_inputs-1:0]; //fp32 | X | Y | 
    reg [(4 * precision) -1:0] conic_opacity [gaussian_inputs-1:0]; // fp32 | X | Y | Z | W |

    

    reg [31:0] gaussian_id_in [gaussian_inputs-1:0];
    reg [(3 * precision) -1:0] gaussian_color [gaussian_inputs-1:0]; //fp32 | R | G | B |
    reg [precision -1:0] gaussian_depth [gaussian_inputs-1:0]; //fp32

    // reg [precision -1:0] n_contrib; //int32

    reg [(3 * precision) -1:0] dL_dpixel; //fp32 | R | G | B |
    reg [precision -1:0] dL_dpixel_depth; //fp32

    reg [(2 * precision) -1:0] dL_dmean2D_out; // fp32 | X | Y |
    reg [(4 * precision) -1:0] dL_dconic_out; // fp32 | X | Y | Z | W |
    reg [precision -1:0] dL_dopacity_out; // fp32 
    reg [(3 * precision) -1:0] dL_dcolor_out; // fp32 | R | G | B |
    reg [precision -1:0] dL_ddepth_out; // fp32

    reg gradient_valid_out;
    reg [31:0] gaussian_id_out;
    reg stall_to_controller;

    reg last_input_done;
    
    parameter N_TEST = 1024;
    integer stall_cnt = 0;

    reg data_in;
    reg done_for_work;

    // Input Mem
    reg [precision -1:0] mem_conic_opacity [4 * N_TEST - 1 :0];
    reg [precision -1:0] mem_gaussian_color [3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];
    reg [precision -1:0] mem_mean2D [2 * N_TEST -1 :0];

    reg [precision -1:0] mem_T_in [N_TEST -1 :0];
    reg [precision -1:0] mem_dL_dpixel [3 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dpixel_depth [N_TEST-1:0];
    reg [31:0] mem_gaussian_id [N_TEST -1 :0];

    reg mem_i_valid [N_TEST -1 :0];
    reg mem_last_input [N_TEST -1 :0];


    reg [7:0] mem_block_id [1:0];
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    integer j;

    // Output Mem
    reg [precision -1:0] mem_dL_dcolor [3 * N_TEST -1 :0];
    reg [precision -1:0] mem_dL_ddepth [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dopacity [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dmean2D [2 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dconic [4 * N_TEST - 1:0];
    reg mem_skip [N_TEST -1 :0];
    
    integer counter;
    integer file_handle;
    integer file_dL_dcolor;
    integer file_dL_ddepth;
    integer file_dL_dopacity;
    integer file_dL_dmean2D;
    integer file_dL_dconic;

    // reg [(3 * precision) -1:0] ref_dL_dcolor;
    // reg [precision -1:0] ref_dL_ddepth;
    // reg [precision -1:0] ref_dL_dopacity;
    // reg [(2 * precision) -1:0] ref_dL_dmean2D;
    // reg [(4 * precision) -1:0] ref_dL_dconic;
    // reg ref_valid;

    localparam stage1_latency = 7;
    localparam stage2_latency = 9;
    localparam arbiter_latency = 1;
    integer latency = stage1_latency + stage2_latency + arbiter_latency;

    integer file_size = 72;

    reg start;

    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_Rasterizer_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Rasterizer_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .gaussian_inputs(gaussian_inputs), .GID_bit(GID_bit)) 
    uut  (
        .clk(clk),
        .rst_n(rst_n),

        .W(W),
        .H(H),

        .i_valid(i_valid),
        

        .start(start),
        .dL_dpixel(dL_dpixel),
        .dL_dpixel_depth(dL_dpixel_depth),
        .T_first(T_first),
        
        .block_id(block_id),
        .pixel_id(pixel_id),

        .stall_backpressure(stall_backpressure),
        .last_input(last_input),
        
        .mean2D(mean2D),
        .conic_opacity(conic_opacity),

        .gaussian_id(gaussian_id_in),
        .gaussian_color(gaussian_color),
        .gaussian_depth(gaussian_depth),

        .gaussian_id_out(gaussian_id_out),
        .dL_dmean2D_out(dL_dmean2D_out),
        .dL_dconic_out(dL_dconic_out),
        .dL_dopacity_out(dL_dopacity_out),
        .dL_dcolor_out(dL_dcolor_out),
        .dL_ddepth_out(dL_ddepth_out),

        .gradient_valid_out(gradient_valid_out),
        .stall_to_controller(stall_to_controller),
        .last_input_done(last_input_done)
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
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/conic_opacity.hex", mem_conic_opacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/mean2D.hex", mem_mean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/T_in.hex", mem_T_in);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_dpixel.hex", mem_dL_dpixel);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_dpixel_depth.hex", mem_dL_dpixel_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/gaussian_id.hex", mem_gaussian_id);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/skip.hex", mem_skip);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/last_input.hex", mem_last_input);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_ddepths.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp16/dL_dconic.hex", mem_dL_dconic);
        end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/conic_opacity_pixel.hex", mem_conic_opacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/gaussian_color_pixel.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/gaussian_depth_pixel.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/mean2D_pixel.hex", mem_mean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/T_in.hex", mem_T_in);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_dpixel.hex", mem_dL_dpixel);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_dpixel_depth.hex", mem_dL_dpixel_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/gaussian_id.hex", mem_gaussian_id);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/skip.hex", mem_skip);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/pixel_id.hex", mem_pixel_id);        
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/block_id.hex", mem_block_id);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/last_input.hex", mem_last_input);

            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_ddepths.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/dL_dconic.hex", mem_dL_dconic);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp32_v2/i_valid.hex", mem_i_valid);
        end

        //for FP 24
        if (precision == 24 && mantissa_bit == 15) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/conic_opacity.hex", mem_conic_opacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/gaussian_color.hex", mem_gaussian_color);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/mean2D.hex", mem_mean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/T_in.hex", mem_T_in);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_dpixel.hex", mem_dL_dpixel);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_dpixel_depth.hex", mem_dL_dpixel_depth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/gaussian_id.hex", mem_gaussian_id);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/skip.hex", mem_skip);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/last_input.hex", mem_last_input);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_ddepths.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/HEX_TB/hex/fp24/dL_dconic.hex", mem_dL_dconic);
        end

    end


    initial begin
        // Open the results file for writing
        file_handle = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/Testbench_output.txt", "w");

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        file_dL_dcolor = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dL_dcolor_output.txt", "w");
        if (file_dL_dcolor == 0) begin
            $display("Error: Could not open dL_dcolor file for writing!");
            $finish;
        end

        file_dL_ddepth = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dL_ddepth_output.txt", "w");
        if (file_dL_ddepth == 0) begin
            $display("Error: Could not open dL_ddepth file for writing!");
            $finish;
        end

        file_dL_dopacity = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dL_dopacity_output.txt", "w");
        if (file_dL_dopacity == 0) begin
            $display("Error: Could not open dL_dopacity file for writing!");
            $finish;
        end

        file_dL_dmean2D = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dL_dmean2D_output.txt", "w");
        if (file_dL_dmean2D == 0) begin
            $display("Error: Could not open dL_dmean2D file for writing!");
            $finish;
        end

        file_dL_dconic = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/dL_dconic_output.txt", "w");
        if (file_dL_dconic == 0) begin
            $display("Error: Could not open dL_dconic file for writing!");
            $finish;
        end



        clk <= 1'b0;
        rst_n <= 1'b0;
        stall_backpressure <= 1'b0;

        H <= 'd0;
        W <= 'd0;
        for (j = 0 ; j < gaussian_inputs ; j = j + 1) begin
            mean2D[j] <= 'h0;
            conic_opacity[j] <= 'h0;    
            i_valid[j] <= 1'b0;
            gaussian_id_in[j] <= 'h0;
            gaussian_color[j] <= 'h0;
            gaussian_depth[j] <= 'h0;
            last_input[j] <= 1'b0;
        end
        // pixel_id <= 'd144;
        // block_id <= 16'h2007;

        pixel_id <= 'd0;
        block_id <= 16'h0;
        
        dL_dpixel <= 'h0;
        dL_dpixel_depth <='h0;

        counter <= 0;
        start <= 1'b0;
        data_in <= 1'b0;
        

        @(posedge clk);
        rst_n <= 1'b1;
        start <= 1'b1;
        H <= 'd480;
        W <= 'd640;
        T_first <= mem_T_in[0];
        dL_dpixel <= {mem_dL_dpixel[0], mem_dL_dpixel[1], mem_dL_dpixel[2]};
        dL_dpixel_depth <= {mem_dL_dpixel_depth[0]};
        pixel_id <= mem_pixel_id[0];
        block_id <= {mem_block_id[0], mem_block_id[1]};
        

        @(posedge clk);
        start <= 1'b0;
        data_in <= 1'b1;
        T_first <= 'h0;
        dL_dpixel <= 'h0;
        dL_dpixel_depth <= 'h0;
        W <= 'd0;
        H <= 'd0;
        pixel_id <= 'd0;
        block_id <= 'h0;


    end


        always @(posedge clk) begin

            if (!last_input_done && data_in) begin

                if (clk_cnt == 20) begin
                    stall_backpressure <= 1'b1;
                end

                if (clk_cnt == 23) begin
                    stall_backpressure <= 1'b0;
                end

                if (stall_backpressure) begin
                    stall_cnt <= stall_cnt + 'd1;
                end


                else if (!stall_backpressure) begin

                    if (!stall_to_controller) begin
                        
                        for (int j = 0; j < gaussian_inputs ; j = j + 1) begin
                            conic_opacity[j] <= {mem_conic_opacity[4 * (counter + j) + 0], mem_conic_opacity[4 * (counter + j) + 1], mem_conic_opacity[4 * (counter + j) + 2], mem_conic_opacity[4 * (counter + j) + 3]};
                            mean2D[j] <= {mem_mean2D[2 * (counter + j) + 0], mem_mean2D[2* (counter + j) + 1]};
                            gaussian_id_in[j] <= mem_gaussian_id[counter + j];
                            i_valid[j] <= mem_i_valid[counter + j];
                            gaussian_color[j] <= {mem_gaussian_color[3 * (counter + j) + 0], mem_gaussian_color[3 * (counter + j) + 1], mem_gaussian_color[3 * (counter + j) + 2]};
                            gaussian_depth[j] <= mem_gaussian_depth[counter + j];
                            last_input[j] <= mem_last_input[counter + j];


                        end
                        if (last_input[j]) begin
                            data_in <= 1'b0;
                            
                        end
                        counter <= counter + gaussian_inputs;
                    end
                end

            end

            else if (last_input_done) begin
                repeat (10) @(posedge clk);
                start <= 1'b1;
                repeat (10) @(posedge clk);
                $fclose(file_handle); // Close the file when simulation is done
                $finish;
            end
        end


    always @ (posedge clk) begin
        if (!last_input_done) begin
            if (gradient_valid_out && !stall_backpressure) begin
                $fwrite(file_handle, "%h\n", gaussian_id_out);
                $fwrite(file_dL_dcolor, "%h %h %h\n", dL_dcolor_out[3*precision-1:2*precision], dL_dcolor_out[2*precision-1:precision], dL_dcolor_out[precision-1:0]);
                $fwrite(file_dL_ddepth, "%h\n", dL_ddepth_out);
                $fwrite(file_dL_dopacity, "%h\n", dL_dopacity_out);
                $fwrite(file_dL_dmean2D, "%h %h\n", dL_dmean2D_out[2*precision-1:precision], dL_dmean2D_out[precision-1:0]);
                $fwrite(file_dL_dconic, "%h %h %h %h\n", dL_dconic_out[4*precision-1:3*precision], dL_dconic_out[3*precision-1:2*precision], dL_dconic_out[2*precision-1:precision], dL_dconic_out[precision-1:0]);
            end

        end
    end

    //         if (counter <= file_size + gaussian_inputs && data_in) begin
    
    //             if (clk_cnt == 20) begin
    //                 stall_backpressure <= 1'b1;
    //             end

    //             if (clk_cnt == 23) begin
    //                 stall_backpressure <= 1'b0;
    //             end

    //             if (stall_backpressure) begin
    //                 stall_cnt <= stall_cnt + 'd1;
    //             end


    //             else if (!stall_backpressure) begin

    //                 if (!stall_to_controller) begin
                        
    //                     for (int j = 0; j < gaussian_inputs ; j = j + 1) begin
    //                         conic_opacity[j] <= {mem_conic_opacity[4 * (counter + j) + 0], mem_conic_opacity[4 * (counter + j) + 1], mem_conic_opacity[4 * (counter + j) + 2], mem_conic_opacity[4 * (counter + j) + 3]};
    //                         mean2D[j] <= {mem_mean2D[2 * (counter + j) + 0], mem_mean2D[2* (counter + j) + 1]};
    //                         gaussian_id_in[j] <= mem_gaussian_id[counter + j];
    //                         i_valid[j] <= mem_i_valid[counter + j];
    //                         gaussian_color[j] <= {mem_gaussian_color[3 * (counter + j) + 0], mem_gaussian_color[3 * (counter + j) + 1], mem_gaussian_color[3 * (counter + j) + 2]};
    //                         gaussian_depth[j] <= mem_gaussian_depth[counter + j];
    //                     end
    //                     counter <= counter + gaussian_inputs;
    //                 end
    //             end
    //         end

    //         else if (counter > file_size) begin
    //             for (int j = 0 ; j < gaussian_inputs ; j = j + 1 ) begin
    //                 i_valid[j] <= 1'b0;
    //             end
    //             data_in <= 1'b0;

    //             repeat (60) @(posedge clk);
                

    //             $fclose(file_handle); // Close the file when simulation is done
    //             $finish;
    //         end

    //     end

    // always @ (posedge clk) begin
    //     if (!last_input_done) begin
    //         if (gradient_valid_out) begin
    //             $fwrite(file_handle, "%h\n", gaussian_id_out);
    //             $fwrite(file_dL_dcolor, "%h %h %h\n", dL_dcolor_out[3*precision-1:2*precision], dL_dcolor_out[2*precision-1:precision], dL_dcolor_out[precision-1:0]);
    //             $fwrite(file_dL_ddepth, "%h\n", dL_ddepth_out);
    //             $fwrite(file_dL_dopacity, "%h\n", dL_dopacity_out);
    //             $fwrite(file_dL_dmean2D, "%h %h\n", dL_dmean2D_out[2*precision-1:precision], dL_dmean2D_out[precision-1:0]);
    //             $fwrite(file_dL_dconic, "%h %h %h %h\n", dL_dconic_out[4*precision-1:3*precision], dL_dconic_out[3*precision-1:2*precision], dL_dconic_out[2*precision-1:precision], dL_dconic_out[precision-1:0]);
    //         end

    //     end

endmodule
