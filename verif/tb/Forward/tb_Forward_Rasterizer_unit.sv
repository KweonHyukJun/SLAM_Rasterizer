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

module tb_Forward_Rasterizer_unit #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 16 , mantissa_bit = 7, gaussian_inputs = 4, GID_bit = 24) ();
    //input
    //reset and clock

    reg clk, rst_n;

    reg i_valid [gaussian_inputs-1:0];

    reg start;

    reg [15:0] block_id;
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] pixel_id;

    reg stall_backpressure;
    reg last_input [gaussian_inputs-1:0];

    reg [(2 * precision) - 1:0] mean2D [gaussian_inputs-1:0];
    reg [(4 * precision) - 1:0] conic_opacity [gaussian_inputs-1:0];

    reg [GID_bit-1:0] gaussian_id_in [gaussian_inputs-1:0];
    reg [(3 * precision) - 1:0] gaussian_color [gaussian_inputs-1:0];
    reg [precision - 1:0] gaussian_depth [gaussian_inputs-1:0];

    // Output
    reg [GID_bit-1:0] gaussian_id_out;
    reg [(3 * precision)-1:0] pixel_color_out;
    reg [precision-1:0] pixel_depth_out;
    reg [11:0] n_contrib_out;
    reg [precision-1:0] pixel_opacity_out;
    reg [precision-1:0] T_first_out;
    reg pixel_valid_out;
    reg stall_to_controller;




    parameter N_TEST = 1024;
    integer stall_cnt = 0;

    reg data_in;

    // Input Mem
    reg [precision -1:0] mem_conic_opacity [4 * N_TEST - 1 :0];
    reg [precision -1:0] mem_gaussian_color [3 * N_TEST -1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];
    reg [precision -1:0] mem_mean2D [2 * N_TEST -1 :0];

    reg [GID_bit-1:0] mem_gaussian_id [N_TEST -1 :0];

    reg mem_i_valid [N_TEST -1 :0];
    reg mem_last_input [N_TEST -1 :0];


    reg [7:0] mem_block_id [1:0];
    reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    integer j;

    // Output Mem
    reg mem_skip [N_TEST -1 :0];
    
    integer counter;
    integer file_handle;

    // reg [precision -1:0] ref_dL_dopacity;
    // reg [(2 * precision) -1:0] ref_dL_dmean2D;
    // reg [(4 * precision) -1:0] ref_dL_dconic;
    // reg ref_valid;

    localparam stage1_latency = 7;
    localparam stage2_latency = 9;
    localparam arbiter_latency = 1;
    integer latency = stage1_latency + stage2_latency + arbiter_latency;

    integer file_size = 40;


    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_Forward_Rasterizer_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Forward_Rasterizer_unit #( .BLOCK_SIZE(BLOCK_SIZE), .exponent_bit(exponent_bit), .mantissa_bit(mantissa_bit), .precision(precision), .gaussian_inputs(gaussian_inputs), .GID_bit(GID_bit)) 
    uut  (
        .clk(clk),
        .rst_n(rst_n),

        .i_valid(i_valid),

        .start(start),
        
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
        .pixel_color_out(pixel_color_out),
        .pixel_depth_out(pixel_depth_out),
        .n_contrib_out(n_contrib_out),
        .pixel_opacity_out(pixel_opacity_out),
        .T_first_out(T_first_out),
        .pixel_valid_out(pixel_valid_out),

        .stall_to_controller(stall_to_controller)
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
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/conic_opacity.hex", mem_conic_opacity);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/mean2D.hex", mem_mean2D);

            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_id_changed.hex", mem_gaussian_id);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/last_input.hex", mem_last_input);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp16_target_block_620/i_valid.hex", mem_i_valid);
        end

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/conic_opacity.hex", mem_conic_opacity);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/mean2D.hex", mem_mean2D);

            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/gaussian_id_changed.hex", mem_gaussian_id);

            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/last_input.hex", mem_last_input);

            $readmemh("../HEX_TB/hex/Forward/forward_rgbd_dataset_freiburg1_desk_fp32_target_block_620/i_valid.hex", mem_i_valid);
        end
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
        stall_backpressure <= 1'b0;

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
        

        counter <= 0;
        start <= 1'b0;
        data_in <= 1'b0;
        

        @(posedge clk);
        rst_n <= 1'b1;
        start <= 1'b1;
        pixel_id <= 'd0;
        
        block_id <= {8'd20, 8'd15};
        

        @(posedge clk);
        start <= 1'b0;
        data_in <= 1'b1;
        pixel_id <= 'd0;
        block_id <= 'h0;


    end


        always @(posedge clk) begin

            if (!pixel_valid_out && data_in) begin

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
                            if (counter + j <= file_size) begin
                                conic_opacity[j] <= {mem_conic_opacity[4 * (counter + j) + 0], mem_conic_opacity[4 * (counter + j) + 1], mem_conic_opacity[4 * (counter + j) + 2], mem_conic_opacity[4 * (counter + j) + 3]};
                                mean2D[j] <= {mem_mean2D[2 * (counter + j) + 0], mem_mean2D[2* (counter + j) + 1]};
                                gaussian_id_in[j] <= mem_gaussian_id[counter + j];
                                i_valid[j] <= mem_i_valid[counter + j];
                                gaussian_color[j] <= {mem_gaussian_color[3 * (counter + j) + 0], mem_gaussian_color[3 * (counter + j) + 1], mem_gaussian_color[3 * (counter + j) + 2]};
                                gaussian_depth[j] <= mem_gaussian_depth[counter + j];
                                last_input[j] <= mem_last_input[counter + j];
                            end
                            else begin
                                conic_opacity[j] <= 'h0;
                                mean2D[j] <= 'h0;
                                gaussian_id_in[j] <= 'h0;
                                i_valid[j] <= 1'b0;
                                gaussian_color[j] <= 'h0;
                                gaussian_depth[j] <= 'h0;
                                last_input[j] <= 1'b0;
                            end

                        end
                        if (last_input[j]) begin
                            data_in <= 1'b0;
                            
                        end
                        counter <= counter + gaussian_inputs;
                    end
                end

            end

            else if (pixel_valid_out) begin
                repeat (10) @(posedge clk);
                $fclose(file_handle); // Close the file when simulation is done
                $finish;
            end
        end


    always @ (posedge clk) begin
        if (!pixel_valid_out && !stall_backpressure) begin
            $fwrite(file_handle, "%h\n", gaussian_id_out);
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
