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

module tb_gradient_compare_unit #(input_size = 16,  exponent_bit = 8, precision = 32 , mantissa_bit = 23) ();
    //input
    //reset and clock
    localparam data_size = precision * 11 + 32;
    reg clk;
    reg rst_n;

    reg [data_size-1:0] data_A_in [input_size-1:0];
    reg [data_size-1:0] data_B_in [input_size-1:0];

    reg [(3 * precision) -1:0] dL_dcolor_in_A [input_size-1:0]; // fp32 | R | G | B |
    reg [precision -1:0] dL_ddepth_in_A [input_size-1:0]; // fp32
    reg [precision -1:0] dL_dopacity_in_A [input_size-1:0]; // fp32 
    reg [(2 * precision) -1:0] dL_dmean2D_in_A [input_size-1:0]; // fp32 | X | Y |
    reg [(4 * precision) -1:0] dL_dconic_in_A [input_size-1:0]; // fp32 | X | Y | Z | W |
    reg [31:0] gaussian_id_in_A [input_size-1:0];
    reg data_A_in_valid;

    reg data_A_in_valid_temp;

    reg [(3 * precision) -1:0] dL_dcolor_in_B [input_size-1:0]; // fp32 | R | G | B |
    reg [precision -1:0] dL_ddepth_in_B [input_size-1:0]; // fp32
    reg [precision -1:0] dL_dopacity_in_B [input_size-1:0]; // fp32 
    reg [(2 * precision) -1:0] dL_dmean2D_in_B [input_size-1:0]; // fp32 | X | Y |
    reg [(4 * precision) -1:0] dL_dconic_in_B [input_size-1:0]; // fp32 | X | Y | Z | W |
    reg [31:0] gaussian_id_in_B [input_size-1:0];
    reg data_B_in_valid;

    reg data_B_in_valid_temp;

    // Output
    wire [(3 * precision) -1:0] dL_dcolor_out [(2 * input_size)-1:0]; // fp32 | R | G | B |
    wire [precision -1:0] dL_ddepth_out [(2 * input_size)-1:0]; // fp32
    wire [precision -1:0] dL_dopacity_out [(2 * input_size)-1:0]; // fp32 
    wire [(2 * precision) -1:0] dL_dmean2D_out [(2 * input_size)-1:0]; // fp32 | X | Y |
    wire [(4 * precision) -1:0] dL_dconic_out [(2 * input_size)-1:0]; // fp32 | X | Y | Z | W |
    wire [31:0] gaussian_id_out [(2 * input_size)-1:0];

    wire [data_size-1:0] data_out [(2 * input_size)-1:0];
    wire data_out_valid;

    // wire stall_to_controller;
    
    parameter N_TEST = 50;
    integer stall_cnt = 0;

    reg data_in;

    

    // Input Mem
    reg [precision -1:0] mem_dL_dcolor_id1 [3 * N_TEST -1 :0];
    reg [precision -1:0] mem_dL_ddepth_id1 [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dopacity_id1 [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dmean2D_id1 [2 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dconic_id1 [4 * N_TEST - 1:0];
    reg [31:0] mem_gaussian_id_id1 [N_TEST -1:0];
    reg mem_i_valid_id1 [N_TEST-1:0];

    // Input Mem
    reg [precision -1:0] mem_dL_dcolor_id2 [3 * N_TEST -1 :0];
    reg [precision -1:0] mem_dL_ddepth_id2 [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dopacity_id2 [N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dmean2D_id2 [2 * N_TEST - 1:0];
    reg [precision -1:0] mem_dL_dconic_id2 [4 * N_TEST - 1:0];
    reg [31:0] mem_gaussian_id_id2 [N_TEST -1 :0];
    reg mem_i_valid_id2 [N_TEST-1:0];

    integer j;

    
    integer counter;
    localparam latency = 1;

    integer file_size = 50;
    integer file_handle;

    reg start;

    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_gradient_compare_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    gradient_id_compare_unit #(.exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .N(input_size), .data_size(data_size)) 
    uut  (
        .clk(clk),
        .rst_n(rst_n),
        
        // .data_A_in(data_A_in),
        // .data_B_in(data_B_in),
        .data_A_in_valid(data_A_in_valid),
        .data_B_in_valid(data_B_in_valid),
        .data_A_in(data_A_in),
        .data_B_in(data_B_in), 

        .data_out_valid(data_out_valid),
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
        if (clk_cnt == 10000) $finish;
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
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_gaussian_id.hex", mem_gaussian_id_id1);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dcolor.hex", mem_dL_dcolor_id1);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_ddepth.hex", mem_dL_ddepth_id1);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dopacity.hex", mem_dL_dopacity_id1);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dmean2D.hex", mem_dL_dmean2D_id1);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_dL_dconic.hex", mem_dL_dconic_id1);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_valid.hex", mem_i_valid_id1);


            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id2_gaussian_id.hex", mem_gaussian_id_id2);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id2_dL_dcolor.hex", mem_dL_dcolor_id2);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id2_dL_ddepth.hex", mem_dL_ddepth_id2);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id2_dL_dopacity.hex", mem_dL_dopacity_id2);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id2_dL_dmean2D.hex", mem_dL_dmean2D_id2);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id2_dL_dconic.hex", mem_dL_dconic_id2);
            $readmemh("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/verif/hex/gradient_merge_submodule_test/id1_valid.hex", mem_i_valid_id2);

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
    
        for (j = 0 ; j < input_size ; j = j + 1) begin
            dL_dcolor_in_A[j] <= 'h0;
            dL_ddepth_in_A[j] <= 'h0;
            dL_dopacity_in_A[j] <= 'h0;
            dL_dmean2D_in_A[j] <= 'h0;
            dL_dconic_in_A[j] <= 'h0;
            gaussian_id_in_A[j] <= 'h0;

            dL_dcolor_in_B[j] <= 'h0;
            dL_ddepth_in_B[j] <= 'h0;
            dL_dopacity_in_B[j] <= 'h0;
            dL_dmean2D_in_B[j] <= 'h0;
            dL_dconic_in_B[j] <= 'h0;
            gaussian_id_in_B[j] <= 'h0;

            data_A_in[j] <= 'h0;
            data_B_in[j] <= 'h0;
        end
        // pixel_id <= 'd144;
        // block_id <= 16'h2007;


        counter <= 0;
        start <= 1'b0;
        data_in <= 1'b0;
    

        @(posedge clk);
        rst_n <= 1'b1;
        data_in <= 1'b1;
        
    end

    
    genvar k;
    generate
        for (k = 0; k < 2 * input_size; k = k + 1) begin : output_decompose
            assign dL_dcolor_out[k] = data_out[k][((11 * precision) - 1) + 32:(8 * precision) + 32];
            assign dL_ddepth_out[k] = data_out[k][((8 * precision) - 1) + 32:(7 * precision) + 32];
            assign dL_dopacity_out[k] = data_out[k][((7 * precision) - 1) + 32:(6 * precision) + 32];
            assign dL_dmean2D_out[k] = data_out[k][((6 * precision) - 1) + 32 : (4 * precision) + 32];
            assign dL_dconic_out[k] = data_out[k][((4 * precision) - 1) + 32:32];
            assign gaussian_id_out[k] = data_out[k][31:0];
        end
    endgenerate     

    // always_comb begin
    //     for (int j = 0; j < (2 *input_size) ; j = j + 1) begin
    //         {dL_dcolor_out[j], dL_ddepth_out[j], dL_dopacity_out[j], dL_dmean2D_out[j], dL_dconic_out[j], gaussian_id_out[j]} <= data_out[j];
    //         end       
    // end

    always @ (posedge clk) begin

        if (counter <= file_size && data_in) begin

            for (int j = 0; j < input_size ; j = j + 1) begin
                dL_dcolor_in_A[j] <= {mem_dL_dcolor_id1[(3 * (counter + input_size + j)) + 0], mem_dL_dcolor_id1[(3 * (counter + input_size + j)) + 1], mem_dL_dcolor_id1[(3 * (counter + input_size + j)) + 2]};
                dL_ddepth_in_A[j] <= mem_dL_ddepth_id1[(counter + input_size + j)];
                dL_dopacity_in_A[j] <= mem_dL_dopacity_id1[(counter + input_size + j)];
                dL_dmean2D_in_A[j] <= {mem_dL_dmean2D_id1[(2 * (counter + input_size + j)) + 0], mem_dL_dmean2D_id1[(2 * (counter + input_size + j)) + 1]};
                dL_dconic_in_A[j] <= {mem_dL_dconic_id1[(4 * (counter + input_size + j)) + 0], mem_dL_dconic_id1[(4 * (counter + input_size + j)) + 1], mem_dL_dconic_id1[(4 * (counter + input_size + j)) + 2], mem_dL_dconic_id1[(4 * (counter + input_size + j)) + 3]};
                gaussian_id_in_A[j] <= mem_gaussian_id_id1[(counter + input_size + j)];

                // data_A_in_valid_temp[j] <= mem_i_valid_id1[(counter + input_size + j)];
                

                dL_dcolor_in_B[j] <= {mem_dL_dcolor_id2[(3 * (counter + input_size + j)) + 0], mem_dL_dcolor_id2[(3 * (counter + input_size + j)) + 1], mem_dL_dcolor_id2[(3 * (counter + input_size + j)) + 2]};
                dL_ddepth_in_B[j] <= mem_dL_ddepth_id2[(counter + input_size + j)];
                dL_dopacity_in_B[j] <= mem_dL_dopacity_id2[(counter + input_size + j)];
                dL_dmean2D_in_B[j] <= {mem_dL_dmean2D_id2[(2 * (counter + input_size + j)) + 0], mem_dL_dmean2D_id2[(2 * (counter + input_size + j)) + 1]};
                dL_dconic_in_B[j] <= {mem_dL_dconic_id2[(4 * (counter + input_size + j)) + 0], mem_dL_dconic_id2[(4 * (counter + input_size + j)) + 1], mem_dL_dconic_id2[(4 * (counter + input_size + j)) + 2], mem_dL_dconic_id2[(4 * (counter + input_size + j)) + 3]};
                gaussian_id_in_B[j] <= mem_gaussian_id_id2[(counter + input_size + j)];
                // data_B_in_valid_temp[j] <= mem_i_valid_id2[(counter + input_size + j)];


                data_A_in[j] <= {dL_dcolor_in_A[j], dL_ddepth_in_A[j], dL_dopacity_in_A[j], dL_dmean2D_in_A[j], dL_dconic_in_A[j], gaussian_id_in_A[j]};
                data_B_in[j] <= {dL_dcolor_in_B[j], dL_ddepth_in_B[j], dL_dopacity_in_B[j], dL_dmean2D_in_B[j], dL_dconic_in_B[j], gaussian_id_in_B[j]};
                // data_A_in_valid[j] <= mem_i_valid_id1[(counter + input_size + j)];
                // data_B_in_valid[j] <= mem_i_valid_id2[(counter + input_size + j)];

            end
            data_A_in_valid_temp <= mem_i_valid_id1[(counter + input_size)];
            data_B_in_valid_temp <= mem_i_valid_id2[(counter + input_size)];
            data_A_in_valid <= data_A_in_valid_temp;
            data_B_in_valid <= data_B_in_valid_temp;

            counter <= counter + input_size;
        end

        else if (counter > file_size) begin
            data_in <= 1'b0;
            repeat (60) @(posedge clk);
            $fclose(file_handle); // Close the file when simulation is done
            $finish;
        end

    end

endmodule
