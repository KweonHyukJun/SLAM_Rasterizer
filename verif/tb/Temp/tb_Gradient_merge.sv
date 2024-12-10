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

module tb_Gradient_merge #(pixel_size = 2,  exponent_bit = 8, precision = 32 , mantissa_bit = 23) ();
    //input
    //reset and clock
    localparam data_size = precision * 11 + 32;

    reg clk;
    reg rst_n;
    reg [data_size - 1 : 0] data_in [pixel_size - 1:0];
    reg data_in_valid [pixel_size - 1:0];

    wire gradient_out_valid;
    wire [data_size - 1 : 0] data_out [pixel_size -1 : 0];


    wire [(3 * precision) -1:0] dL_dcolor_out [pixel_size-1:0]; // fp32 | R | G | B |
    wire [precision -1:0] dL_ddepth_out [pixel_size-1:0]; // fp32
    wire [precision -1:0] dL_dopacity_out [pixel_size-1:0]; // fp32 
    wire [(2 * precision) -1:0] dL_dmean2D_out [pixel_size-1:0]; // fp32 | X | Y |
    wire [(4 * precision) -1:0] dL_dconic_out [pixel_size-1:0]; // fp32 | X | Y | Z | W |
    wire [31:0] gaussian_id_out [pixel_size-1:0];


    // reg [(3 * precision) -1:0] dL_dcolor_in [pixel_size-1:0]; // fp32 | R | G | B |
    // reg [precision -1:0] dL_ddepth_in [pixel_size-1:0]; // fp32
    // reg [precision -1:0] dL_dopacity_in [pixel_size-1:0]; // fp32 
    // reg [(2 * precision) -1:0] dL_dmean2D_in [pixel_size-1:0]; // fp32 | X | Y |
    // reg [(4 * precision) -1:0] dL_dconic_in [pixel_size-1:0]; // fp32 | X | Y | Z | W |
    // reg [31:0] gaussian_id_in [pixel_size-1:0];
    // reg data_in_valid_in [pixel_size-1:0];


    // wire stall_to_controller;
    
    parameter N_TEST = 50;
    integer stall_cnt = 0;

    reg data_input;

    // Input Mem
    reg [precision -1:0] mem_dL_dcolor [3 * N_TEST -1 :0];
    reg [precision -1:0] mem_dL_ddepth [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dopacity [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dmean2D [2 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dconic [4 * N_TEST - 1:0];
    reg [31:0] mem_gaussian_id [N_TEST -1:0];
    reg mem_i_valid [N_TEST -1:0];
    

    integer j;

    
    integer counter;
    localparam latency = 1;

    integer file_size = 50;
    integer file_handle;


    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_Gradient_merge, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Gradient_merge #(.exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .N(pixel_size), .data_size(data_size)) 
    uut  (
        .clk(clk),
        .rst_n(rst_n),
        
        .data_in(data_in),
        // .gradient_ready(),
        .data_in_valid(data_in_valid),

        .gradient_out_valid(gradient_out_valid),
        .data_out(data_out)
    );


    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == 500) $finish;
    end


    initial begin
        //for FP 16
        // if (precision == 16 && mantissa_bit == 7) begin
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/conic_opacity.hex", mem_conic_opacity);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_color.hex", mem_gaussian_color);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_depth.hex", mem_gaussian_depth);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/mean2D.hex", mem_mean2D);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/T_in.hex", mem_T_in);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dpixel.hex", mem_dL_dpixel);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dpixel_depth.hex", mem_dL_dpixel_depth);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/gaussian_id.hex", mem_gaussian_id);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/skip.hex", mem_skip);

        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dcolor.hex", mem_dL_dcolor);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_ddepths.hex", mem_dL_ddepth);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dopacity.hex", mem_dL_dopacity);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dmean2D.hex", mem_dL_dmean2D);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp16/dL_dconic.hex", mem_dL_dconic);
        // end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_gaussian_id.hex", mem_gaussian_id);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dcolor.hex", mem_dL_dcolor);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_ddepth.hex", mem_dL_ddepth);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dopacity.hex", mem_dL_dopacity);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dmean2D.hex", mem_dL_dmean2D);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dconic.hex", mem_dL_dconic);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_valid.hex", mem_i_valid);
        end

        // //for FP 24
        // if (precision == 24 && mantissa_bit == 15) begin
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/conic_opacity.hex", mem_conic_opacity);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_color.hex", mem_gaussian_color);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_depth.hex", mem_gaussian_depth);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/mean2D.hex", mem_mean2D);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/T_in.hex", mem_T_in);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dpixel.hex", mem_dL_dpixel);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dpixel_depth.hex", mem_dL_dpixel_depth);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/gaussian_id.hex", mem_gaussian_id);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/skip.hex", mem_skip);
            
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dcolor.hex", mem_dL_dcolor);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_ddepths.hex", mem_dL_ddepth);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dopacity.hex", mem_dL_dopacity);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dmean2D.hex", mem_dL_dmean2D);
        //     $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/fp24/dL_dconic.hex", mem_dL_dconic);
        // end

    end


    initial begin
        // Open the results file for writing
        file_handle = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/Testbench_output.txt", "w");

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        clk <= 1'b0;
        rst_n <= 1'b0;
    
        for (j = 0 ; j < pixel_size ; j = j + 1) begin
            data_in[j] <= 'h0;
            data_in[j + pixel_size] <= 'h0;

            data_in_valid[j] <= 1'b0;
        end
        
        counter <= 0;
        data_input <= 1'b0;
    
        @(posedge clk);
        rst_n <= 1'b1;
        data_input <= 1'b1;

    end


    
    genvar k;
    generate // k : gradient list들임
        for (k = 0; k < pixel_size; k = k + 1) begin : output_decompose
            assign dL_dcolor_out[k] = data_out[k][((11 * precision) - 1) + 32:(8 * precision) + 32];
            assign dL_ddepth_out[k] = data_out[k][((8 * precision) - 1) + 32:(7 * precision) + 32];
            assign dL_dopacity_out[k] = data_out[k][((7 * precision) - 1) + 32:(6 * precision) + 32];
            assign dL_dmean2D_out[k] = data_out[k][((6 * precision) - 1) + 32 : (4 * precision) + 32];
            assign dL_dconic_out[k] = data_out[k][((4 * precision) - 1) + 32:32];
            assign gaussian_id_out[k] = data_out[k][31:0];
        end
    endgenerate     

    always @ (posedge clk) begin

        if (counter <= file_size && data_input) begin

            for (int j = 0; j < pixel_size ; j = j + 1) begin
                // latency = $clog2(N)
                // data_in[j] <= {dL_dcolor_in[j], dL_ddepth_in[j], dL_dopacity_in[j], dL_dmean2D_in[j], dL_dconic_in[j], gaussian_id_in[j]};                
                data_in[j] <= {mem_dL_dcolor[(3 * mem_gaussian_id[(counter + j)]) + 0], mem_dL_dcolor[(3 * mem_gaussian_id[(counter + j)]) + 1], mem_dL_dcolor[(3 * mem_gaussian_id[(counter + j)]) + 2], 
                            mem_dL_ddepth[mem_gaussian_id[(counter + j)]], mem_dL_dopacity[mem_gaussian_id[(counter + j)]],
                            mem_dL_dmean2D[(2 * mem_gaussian_id[(counter + j)]) + 0], mem_dL_dmean2D[(2 * mem_gaussian_id[(counter + j)]) + 1],
                            mem_dL_dconic[(4 * mem_gaussian_id[(counter + j)]) + 0], mem_dL_dconic[(4 * mem_gaussian_id[(counter + j)]) + 1], mem_dL_dconic[(4 * mem_gaussian_id[(counter + j)]) + 2], mem_dL_dconic[(4 * mem_gaussian_id[(counter + j)]) + 3], 
                            mem_gaussian_id[(counter + j)], mem_i_valid[mem_gaussian_id[(counter + j)]]};                
            end

            counter <= counter + pixel_size;
        end

        else if (counter > file_size) begin
            data_input <= 1'b0;
            repeat (60) @(posedge clk);
            $fclose(file_handle); // Close the file when simulation is done
            $finish;
        end

    end

endmodule
