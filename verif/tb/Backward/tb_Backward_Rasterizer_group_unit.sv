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

module tb_Backward_Rasterizer_group_unit #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 32 , mantissa_bit = 23, target_block = 620, gaussian_inputs = 4, num_pixels = 16, GID_bit = 24) ();

    // Input
    reg clk;
    reg rst_n;

    reg i_valid [gaussian_inputs * num_pixels - 1:0];

    reg [11:0] W;
    reg [11:0] H;

    reg start [num_pixels-1:0];
    reg [(3 * precision) -1:0] dL_dpixel [num_pixels-1:0]; //fp32 | R | G | B |
    reg [precision -1:0] dL_dpixel_depth [num_pixels-1:0]; //fp32
    reg [precision - 1:0] T_first [num_pixels-1:0];

    reg [15:0] block_id ; // block index x at [0] y at [1]
    reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0];
    
    reg stall_backpressure [num_pixels-1:0];

    reg last_input [gaussian_inputs * num_pixels - 1:0];

    reg [(2 * precision) -1:0] mean2D [gaussian_inputs * num_pixels - 1:0]; //fp32 | X | Y | 
    reg [(4 * precision) -1:0] conic_opacity [gaussian_inputs * num_pixels - 1:0]; // fp32 | X | Y | Z | W |

    reg [GID_bit-1:0] gaussian_id_in [gaussian_inputs * num_pixels - 1:0];
    reg [(3 * precision) -1:0] gaussian_color [gaussian_inputs * num_pixels - 1:0]; //fp32 | R | G | B |
    reg [precision -1:0] gaussian_depth [gaussian_inputs * num_pixels - 1:0]; //fp32


    //Output 
    wire [(3 * precision) -1:0] dL_dcolor_out[num_pixels-1:0]; // fp32 | R | G | B |
    wire [precision -1:0] dL_ddepth_out[num_pixels-1:0]; // fp32
    wire [precision -1:0] dL_dopacity_out[num_pixels-1:0]; // fp32 
    wire [(2 * precision) -1:0] dL_dmean2D_out[num_pixels-1:0]; // fp32 | X | Y |
    wire [(4 * precision) -1:0] dL_dconic_out[num_pixels-1:0]; // fp32 | X | Y | Z | W |
    wire [GID_bit-1:0] gaussian_id_out [num_pixels-1:0];


    // Compare
    wire [(3 * precision) -1:0] ref_dL_dcolor_out[num_pixels-1:0]; // fp32 | R | G | B |
    wire [precision -1:0] ref_dL_ddepth_out[num_pixels-1:0]; // fp32
    wire [precision -1:0] ref_dL_dopacity_out[num_pixels-1:0]; // fp32 
    wire [(2 * precision) -1:0] ref_dL_dmean2D_out[num_pixels-1:0]; // fp32 | X | Y |
    wire [(4 * precision) -1:0] ref_dL_dconic_out[num_pixels-1:0]; // fp32 | X | Y | Z | W |

    
    reg gradient_valid_out [num_pixels-1:0];
    reg stall_to_controller [num_pixels-1:0];
    reg last_input_done [num_pixels-1:0];

    reg controller_ready_to_start;


    parameter N_TEST = (target_block == 0) ? 35 :
                        (target_block == 620) ? 84 : 0;


    // Frame size에 따라 바꿔야 함..
    parameter W_BLOCK = 40;
    parameter H_BLOCK = 30;

    // 이거 왜 안되지
    reg [7:0] target_block_x = target_block / W_BLOCK;
    reg [7:0] target_block_y = target_block % W_BLOCK;

    // reg [7:0] target_block_x = 'd20;
    // reg [7:0] target_block_y = 'd15;


    integer stall_cnt = 0;

    // reg data_in;
    // reg done_for_work;


    // Input Mem
    // reg [precision -1:0] mem_conic_opacity [num_pixels-1:0][4 * N_TEST - 1 :0];
    // reg [precision -1:0] mem_gaussian_color [num_pixels-1:0][3 * N_TEST -1 : 0];
    // reg [precision -1:0] mem_gaussian_depth [num_pixels-1:0][N_TEST - 1:0];
    // reg [precision -1:0] mem_mean2D [num_pixels-1:0][2 * N_TEST -1 :0];

    reg [precision -1:0] mem_conic_opacity [(4 * N_TEST) - 1 : 0];
    reg [precision -1:0] mem_gaussian_color [(3 * N_TEST) - 1 : 0];
    reg [precision -1:0] mem_gaussian_depth [N_TEST - 1:0];
    reg [precision -1:0] mem_mean2D [(2 * N_TEST) -1 :0];

    reg [precision -1:0] mem_T_in [255:0];
    reg [precision -1:0] mem_dL_dpixel [255:0][2:0];
    reg [precision -1:0] mem_dL_dpixel_depth [255:0];


    reg [GID_bit-1:0] mem_gaussian_id_in [N_TEST -1 :0];
    reg [16:0] mem_n_contrib [255:0];


    // reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] temp_pixel_id [num_pixels-1:0];
    


    
    reg mem_i_valid [N_TEST - 1:0];
    
    // reg [7:0] mem_block_id [1:0];
    // reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    reg started_flag [num_pixels-1:0];
    reg signed [16:0] current_n_contrib [num_pixels-1:0];
    reg all_last_input_done_before;
    reg all_last_input_done;
    

    integer j;
    integer i;

    integer all_done;

    // Output Mem
    // reg [precision -1:0] mem_dL_dcolor [3 * N_TEST -1 :0];
    // reg [precision -1:0] mem_dL_ddepth [N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dopacity [N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dmean2D [2 * N_TEST - 1:0];
    // reg [precision -1:0] mem_dL_dconic [4 * N_TEST - 1:0];
    // reg mem_skip [N_TEST -1 :0];
    
    integer counter [num_pixels-1:0];
    // integer out_gaussian_file [num_pixels-1:0];
    // integer out_valid_file [num_pixels-1:0];
    // integer out_dL_dcolor_file [num_pixels-1:0];
    // integer out_dL_ddepth_file [num_pixels-1:0];
    // integer out_dL_dopacity_file [num_pixels-1:0];
    // integer out_dL_dmean2D_file [num_pixels-1:0];
    // integer out_dL_dconic_file [num_pixels-1:0];


    // integer file_dL_dcolor;
    // integer file_dL_ddepth;
    // integer file_dL_dopacity;
    // integer file_dL_dmean2D;
    // integer file_dL_dconic;

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

    integer out_gaussian_id_file[num_pixels-1:0];
    integer out_dL_dcolor_file[num_pixels-1:0];
    integer out_dL_ddepth_file[num_pixels-1:0];
    integer out_dL_dopacity_file[num_pixels-1:0];
    integer out_dL_dmean2D_file[num_pixels-1:0];
    integer out_dL_dconic_file[num_pixels-1:0];


    initial begin
        $fsdbDumpfile("../output_backward_unit/backward_unit_dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_Rasterizer_group_unit, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Backward_Rasterizer_group_unit #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
        ) 
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

        .gaussian_id_in(gaussian_id_in),
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
        if (clk_cnt == 2000) $finish;
    end


    initial begin

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin
            // for (int i = 0; i < num_pixels; i++) begin
            //     string skip_file, conic_file, gid_in_file, gid_out_file, gcolor_file, gdepth_file, mean2D_file, T_in_file, dL_dpixel_file, dL_dpixel_depth_file, pixel_id_file, i_valid_file;
            //     // skip_file = $sformatf(".../HEX_TB/hex/skip_%0d.hex", i);
            //     conic_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/conic_opacity_%0d.hex", i);
            //     gid_in_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_id_in_%0d.hex", i);
            //     gid_out_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_id_out_%0d.hex", i);
            //     gcolor_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_color_%0d.hex", i);
            //     gdepth_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gaussian_depth_%0d.hex", i);
            //     mean2D_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/mean2D_%0d.hex", i);
            //     T_in_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/T_in_%0d.hex", i);

            //     dL_dpixel_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/dL_dpixel_%0d.hex", i);
            //     dL_dpixel_depth_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/dL_dpixel_depth_%0d.hex", i);
            //     // pixel_id_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/pixel_id_%0d.hex", i);
            //     i_valid_file = $sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/i_valid_%0d.hex", i);



            //     $readmemh(conic_file, mem_conic_opacity[i]);
            //     $readmemh(gid_in_file, mem_gaussian_id_in[i]);
            //     $readmemh(gid_out_file, mem_gaussian_id_out[i]);
            //     $readmemh(gcolor_file, mem_gaussian_color[i]);
            //     $readmemh(gdepth_file, mem_gaussian_depth[i]);
            //     $readmemh(mean2D_file, mem_mean2D[i]);
            //     $readmemh(T_in_file, mem_T_in[i]);
            //     $readmemh(dL_dpixel_file, mem_dL_dpixel[i]);
            //     $readmemh(dL_dpixel_depth_file, mem_dL_dpixel_depth[i]);
            //     // $readmemh(pixel_id_file, mem_pixel_id);
            //     $readmemh(i_valid_file, mem_i_valid[i]);

            // end
            // $readmemh("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/pixel_id.hex", mem_pixel_id);
            
            if (target_block == 0) begin
                // Gaussian Information
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/conic_opacity.hex", mem_conic_opacity);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/mean2D.hex", mem_mean2D);

                // $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/point_list.hex", mem_gaussian_id_in);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/gaussian_id_changed.hex", mem_gaussian_id_in);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/gaussian_color.hex", mem_gaussian_color);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/gaussian_depth.hex", mem_gaussian_depth);

                // Pixel Information
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/final_Ts.hex", mem_T_in);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/dL_dcolor.hex", mem_dL_dpixel);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/dL_ddepths.hex", mem_dL_dpixel_depth);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/n_contrib.hex", mem_n_contrib);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_0/i_valid.hex", mem_i_valid);
            
            end
            
            else if (target_block == 620) begin
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/conic_opacity.hex", mem_conic_opacity);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/mean2D.hex", mem_mean2D);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/point_list.hex", mem_gaussian_id_in);
                // $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_id_changed.hex", mem_gaussian_id_in);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/gaussian_color.hex", mem_gaussian_color);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/gaussian_depth.hex", mem_gaussian_depth);

                // Pixel Information
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/final_Ts.hex", mem_T_in);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/dL_dcolor.hex", mem_dL_dpixel);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/dL_ddepths.hex", mem_dL_dpixel_depth);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/n_contrib.hex", mem_n_contrib);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp32_target_block_620/i_valid.hex", mem_i_valid);
            end
            
            
        end

        if (precision == 16 && mantissa_bit == 7) begin

            if (target_block == 0) begin
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/conic_opacity.hex", mem_conic_opacity);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/mean2D.hex", mem_mean2D);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/point_list.hex", mem_gaussian_id_in);
                // $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/gaussian_id_changed.hex", mem_gaussian_id_in);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/gaussian_color.hex", mem_gaussian_color);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/gaussian_depth.hex", mem_gaussian_depth);

                // Pixel Information
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/final_Ts.hex", mem_T_in);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/dL_dcolor.hex", mem_dL_dpixel);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/dL_ddepths.hex", mem_dL_dpixel_depth);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/n_contrib.hex", mem_n_contrib);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_0/i_valid.hex", mem_i_valid);
            end

            else if (target_block == 620) begin
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/conic_opacity.hex", mem_conic_opacity);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/mean2D.hex", mem_mean2D);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/point_list.hex", mem_gaussian_id_in);
                // $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_id_changed.hex", mem_gaussian_id_in);

                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_color.hex", mem_gaussian_color);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/gaussian_depth.hex", mem_gaussian_depth);

                // Pixel Information
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/final_Ts.hex", mem_T_in);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/dL_dcolor.hex", mem_dL_dpixel);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/dL_ddepths.hex", mem_dL_dpixel_depth);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/n_contrib.hex", mem_n_contrib);
                $readmemh("../HEX_TB/hex/pixel_group_to_block/rgbd_dataset_freiburg1_desk_fp16_target_block_620/i_valid.hex", mem_i_valid);   
            end

        end
    end


    initial begin

        // for (int j = 0; j < num_pixels; j = j + 1) begin
        //     out_gaussian_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/gid_%0d.hex", j), "w");    
        //     if (out_gaussian_file[j] == 0) $display("Error opening out_gaussian_file[%0d]", j);
            
        //     out_valid_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/valid_%0d.hex", j), "w");
        //     if (out_valid_file[j] == 0) $display("Error opening out_valid_file[%0d]", j);

        //     out_dL_dcolor_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/dL_dcolor_result_%0d.hex", j), "w");
        //     if (out_dL_dcolor_file[j] == 0) $display("Error opening out_dL_dcolor_file[%0d]", j);

        //     out_dL_ddepth_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/dL_ddepth_result_%0d.hex", j), "w");
        //     if (out_dL_ddepth_file[j] == 0) $display("Error opening out_dL_ddepth_file[%0d]", j);

        //     out_dL_dopacity_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/dL_dopacity_result_%0d.hex", j), "w");
        //     if (out_dL_dopacity_file[j] == 0) $display("Error opening out_dL_dopacity_file[%0d]", j);

        //     out_dL_dmean2D_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/dL_dmean2D_result_%0d.hex", j), "w");
        //     if (out_dL_dmean2D_file[j] == 0) $display("Error opening out_dL_dmean2D_file[%0d]", j);

        //     out_dL_dconic_file[j] = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/merge_input/dL_dconic_result_%0d.hex", j), "w");
        //     if (out_dL_dconic_file[j] == 0) $display("Error opening out_dL_dconic_file[%0d]", j);
        // end
        
        // // Create output directory if it doesn't exist
        // void'($system("mkdir -p ../output_backward"));

        for (int j = 0; j < num_pixels; j = j + 1) begin
            out_gaussian_id_file[j] = $fopen($sformatf("../output_backward_unit/gaussian_id_out_by_testbench_%0d.hex", j), "w");    
            if (out_gaussian_id_file[j] == 0) begin 
                $display("Error opening out_gaussian_file[%0d]", j);
                $finish;
            end

            out_dL_dcolor_file[j] = $fopen($sformatf("../output_backward_unit/dL_dcolor_out_by_testbench_%0d.hex", j), "w");
            if (out_dL_dcolor_file[j] == 0) begin
                $display("Error opening out_dL_dcolor_file[%0d]", j);
                $finish;
            end

            out_dL_ddepth_file[j] = $fopen($sformatf("../output_backward_unit/dL_ddepth_out_by_testbench_%0d.hex", j), "w");
            if (out_dL_ddepth_file[j] == 0) begin
                $display("Error opening out_dL_ddepth_file[%0d]", j);
                $finish;
            end

            out_dL_dopacity_file[j] = $fopen($sformatf("../output_backward_unit/dL_dopacity_out_by_testbench_%0d.hex", j), "w");
            if (out_dL_dopacity_file[j] == 0) begin
                $display("Error opening out_dL_dopacity_file[%0d]", j);
                $finish;
            end

            out_dL_dmean2D_file[j] = $fopen($sformatf("../output_backward_unit/dL_dmean2D_out_by_testbench_%0d.hex", j), "w");
            if (out_dL_dmean2D_file[j] == 0) begin
                $display("Error opening out_dL_dmean2D_file[%0d]", j);
                $finish;
            end

            out_dL_dconic_file[j] = $fopen($sformatf("../output_backward_unit/dL_dconic_out_by_testbench_%0d.hex", j), "w");
            if (out_dL_dconic_file[j] == 0) begin
                $display("Error opening out_dL_dconic_file[%0d]", j);
                $finish;
            end
        end

        clk <= 1'b0;
        rst_n <= 1'b0;

        H <= 'd0;
        W <= 'd0;

        all_done <= 'd0;

        for (j = 0 ; j < gaussian_inputs * num_pixels ; j = j + 1) begin
            mean2D[j] <= 'h0;
            conic_opacity[j] <= 'h0;    
            i_valid[j] <= 1'b0;
            gaussian_id_in[j] <= 'h0;
            gaussian_color[j] <= 'h0;
            gaussian_depth[j] <= 'h0;
            last_input[j] <= 1'b0;
        end


        for (j = 0 ; j < num_pixels ; j = j + 1) begin
            start[j] <= 1'b0;
            dL_dpixel[j] <= 'h0;
            dL_dpixel_depth[j] <= 'h0;
            T_first[j] <= 'h0;
            pixel_id[j] <= 'h0;
            // temp_pixel_id[j] <= j;
            stall_backpressure[j] <= 1'b0;
            counter[j] <= 0;
            started_flag[j] <= 1'b0;
            current_n_contrib[j] <= 'h0;
            last_input[j] <= 1'b0;
            
        end

        controller_ready_to_start <= 1'b0;

        block_id <= 'h0;
        
        // data_in <= 1'b0;
        // done_for_work <= 1'b0;
        // data_in <= 1'b0;

        @(posedge clk);

            rst_n <= 1'b1;
        
        @(posedge clk);
            H <= 'd480;
            W <= 'd640;
            // data_in <= 1'b1;

            block_id <= {target_block_x, target_block_y};

            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                T_first[j] <= mem_T_in[j];
                dL_dpixel[j] <= {mem_dL_dpixel[j][0], mem_dL_dpixel[j][1], mem_dL_dpixel[j][2]};
                dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j];
                pixel_id[j] <= j;
                
                start[j] <= 1'b1;
                started_flag[j] <= 1'b1;
                current_n_contrib[j] <= mem_n_contrib[j];
                
            end
        

        @(posedge clk);

            block_id <= 'h0;
            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                T_first[j] <= 'h0;
                dL_dpixel[j] <= 'h0;
                dL_dpixel_depth[j] <= 'h0;
                pixel_id[j] <= 'h0;
                
            end
            controller_ready_to_start <= 1'b1;
    end



    always @ (posedge clk) begin

        // if (!stall_backpressure) begin // stall backpressure는 pixel group unit 에서는 얘가 주는 거임 (컨트롤러 + FIFO 단에서의 stall 신호까지 준다고 생각)

        for (int j = 0; j < num_pixels; j = j + 1) begin

            if (started_flag[j]) begin  
                start[j] <= 1'b0;


                if (!stall_to_controller[j]) begin

                    if (current_n_contrib[j] > 0) begin

                        if (current_n_contrib[j] >= gaussian_inputs) begin
                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * (current_n_contrib[j] - i) + 0], mem_conic_opacity[4 * (current_n_contrib[j] - i) + 1], mem_conic_opacity[4 * (current_n_contrib[j] - i) + 2], mem_conic_opacity[4 * (current_n_contrib[j] - i) + 3]};
                                mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (current_n_contrib[j] - i) + 0], mem_mean2D[2 * (current_n_contrib[j] - i) + 1]};
                                gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[current_n_contrib[j] - i];
                                i_valid[j * gaussian_inputs + i] <= mem_i_valid[current_n_contrib[j] - i];
                                gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (current_n_contrib[j] - i) + 0], mem_gaussian_color[3 * (current_n_contrib[j] - i) + 1], mem_gaussian_color[3 * (current_n_contrib[j] - i) + 2]};
                                gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[current_n_contrib[j] - i];

                                if (current_n_contrib[j] - i == 1) begin
                                    last_input[j * gaussian_inputs + i] <= 1'b1;
                                end
                                else begin
                                    last_input[j * gaussian_inputs + i] <= 1'b0;
                                end

                            end

                            current_n_contrib[j] <= current_n_contrib[j] - gaussian_inputs;
                        end

                        else if (current_n_contrib[j] < gaussian_inputs) begin
                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                if (current_n_contrib[j] > i) begin
                                    
                                    conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * (current_n_contrib[j] - i) + 0], mem_conic_opacity[4 * (current_n_contrib[j] - i) + 1], mem_conic_opacity[4 * (current_n_contrib[j] - i) + 2], mem_conic_opacity[j][4 * (current_n_contrib[j] - i) + 3]};
                                    mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (current_n_contrib[j] - i) + 0], mem_mean2D[2 * (current_n_contrib[j] - i) + 1]};
                                    gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[current_n_contrib[j] - i];
                                    i_valid[j * gaussian_inputs + i] <= mem_i_valid[current_n_contrib[j] - i];
                                    gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (current_n_contrib[j] - i) + 0], mem_gaussian_color[3 * (current_n_contrib[j] - i) + 1], mem_gaussian_color[3 * (current_n_contrib[j] - i) + 2]};
                                    gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[current_n_contrib[j] - i];

                                    if (current_n_contrib[j] - i == 1) begin
                                        last_input[j * gaussian_inputs + i] <= 1'b1;
                                    end
                                    else begin
                                        last_input[j * gaussian_inputs + i] <= 1'b0;
                                    end
                                end

                                else if (current_n_contrib[j] <= i ) begin
                                    last_input[j * gaussian_inputs + i] <= 1'b0;
                                    conic_opacity[j * gaussian_inputs + i] <= 'h0;
                                    mean2D[j * gaussian_inputs + i] <= 'h0;
                                    gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                                    i_valid[j * gaussian_inputs + i] <= 1'b0;
                                    gaussian_color[j * gaussian_inputs + i] <= 'h0;
                                    gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                                end
                            end

                            current_n_contrib[j] <= 'd0;
                        end
                    end

                    else begin
                        
                        for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                            conic_opacity[j * gaussian_inputs + i] <= 'h0;
                            mean2D[j * gaussian_inputs + i] <= 'h0;
                            gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                            i_valid[j * gaussian_inputs + i] <= 1'b0;
                            gaussian_color[j * gaussian_inputs + i] <= 'h0;
                            gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                            last_input[j * gaussian_inputs + i] <= 1'b0;
                        end
                    end

                    if (last_input_done[j]) begin
                        started_flag[j] <= 1'b0;
                    end

                end

            end


            // end
            else begin

                if (last_input_done[j] && start[j]) begin
                    started_flag[j] <= 1'b1;
                end
            end

        end
    end




    always @ (posedge clk) begin
        if (all_last_input_done && controller_ready_to_start) begin
            for (int j = 0; j < num_pixels; j = j + 1) begin
                start[j] <= 1'b1;
                    
                current_n_contrib[j] <= mem_n_contrib[j + (all_done + 1) * 16];
                dL_dpixel[j] <= {mem_dL_dpixel[j + (all_done + 1) * 16][0], 
                                    mem_dL_dpixel[j + (all_done + 1) * 16][1], 
                                    mem_dL_dpixel[j + (all_done + 1) * 16][2]};
                dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + (all_done + 1) * 16][0];
                pixel_id[j] <= num_pixels * all_done + j;
                T_first[j] <= mem_T_in[j + (all_done + 1) * 16];
                H <= 'd480;
                W <= 'd640;
            

                block_id <= {target_block_x, target_block_y};
            end

            all_done <= all_done + 1;


            controller_ready_to_start <= 1'b0;


            end
        end


    always_comb begin
        all_last_input_done_before = 1'b0; // Start with 0
        for (int i = 0; i < num_pixels; i++) begin
            if (i == 0) begin
                all_last_input_done_before = last_input_done[0];
            end
            else begin
                all_last_input_done_before &= last_input_done[i]; // AND with each bit
            end
        end
    end


    always @ (posedge clk) begin
        all_last_input_done <= all_last_input_done_before;
    end

    always @ (posedge clk) begin
        if (all_done == 16 && all_last_input_done) begin
            
            controller_ready_to_start <= 1'b0;
            
            @(posedge clk);

            $finish;
        end
    end

    always @ (negedge all_last_input_done) begin
        repeat(5) @(posedge clk);
            
            controller_ready_to_start <= 1'b1;
        
            
        end


    always @ (posedge clk) begin

        for (int j = 0; j < num_pixels; j = j + 1) begin
            if (!stall_backpressure[j] && gradient_valid_out[j]) begin
                $fwrite(out_gaussian_id_file[j], "%h\n", gaussian_id_out[j]);
                $fwrite(out_dL_dcolor_file[j], "%h %h %h\n", dL_dcolor_out[j][(3 * precision)-1: 2 * precision], dL_dcolor_out[j][(2 * precision)-1: precision], dL_dcolor_out[j][precision-1: 0]);
                $fwrite(out_dL_ddepth_file[j], "%h\n", dL_ddepth_out[j]);
                $fwrite(out_dL_dopacity_file[j], "%h\n", dL_dopacity_out[j]);
                $fwrite(out_dL_dmean2D_file[j], "%h %h\n", dL_dmean2D_out[j][(2 * precision)-1: precision], dL_dmean2D_out[j][precision-1: 0]);
                $fwrite(out_dL_dconic_file[j], "%h %h %h %h\n", dL_dconic_out[j][(4 * precision)-1: 3 * precision], dL_dconic_out[j][(3 * precision)-1: 2 * precision],  dL_dconic_out[j][(2 * precision)-1: precision], dL_dconic_out[j][precision-1:0]);
            end
        end

    end

    // // // save per clock
    // always @ (posedge clk) begin

    //     if (clk_cnt >= 18 && clk_cnt <= 46) begin
    //         out_gaussian_file = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gid_result/cycle_%0d.hex", clk_cnt), "w");
    //         out_gaussian_file = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gid_resout_valid_file", clk_cnt), "w");
    



    //         for (int j = 0; j < num_pixels; j = j + 1) begin
    //             $fwrite(out_gaussian_file, "%h\n", gaussian_id_out[j]);
    //             $fwrite(out_gaussianout_valid_fileussian_id_out[j]);


    //         end

    //     end
    // end


    // // // Save for Merge sort data
    // always @ (posedge clk) begin
        

    //     if (clk_cnt >= 18 && clk_cnt <= 50) begin
    //         for (int j = 0; j < num_pixels; j = j + 1) begin
    //             $fwrite(out_gaussian_file[j], "%h\n", gaussian_id_out[j]);
    //             $fwrite(out_valid_file[j], "%h\n", gradient_valid_out[j]);
    //             $fwrite(out_dL_dcolor_file[j], "%h %h %h\n", dL_dcolor_out[j][(3 * precision)-1: 2 * precision], dL_dcolor_out[j][(2 * precision)-1: precision], dL_dcolor_out[j][precision-1: 0]);
    //             $fwrite(out_dL_ddepth_file[j], "%h\n", dL_ddepth_out[j]);
    //             $fwrite(out_dL_dopacity_file[j], "%h\n", dL_dopacity_out[j]);
    //             $fwrite(out_dL_dmean2D_file[j], "%h %h\n", dL_dmean2D_out[j][(2 * precision)-1: precision], dL_dmean2D_out[j][precision-1: 0]);
    //             $fwrite(out_dL_dconic_file[j], "%h %h %h %h\n", dL_dconic_out[j][(4 * precision)-1: 3 * precision], dL_dconic_out[j][(3 * precision)-1: 2 * precision],  dL_dconic_out[j][(2 * precision)-1: precision], dL_dconic_out[j][precision-1:0]);
    //         end
    //     end

    //     if (clk_cnt == 51) begin
    //         for (int j = 0; j < num_pixels; j = j + 1) begin
    //             $fclose(out_gaussian_file[j]);
    //             $fclose(out_valid_file[j]);
    //             $fclose(out_dL_dcolor_file[j]);
    //             $fclose(out_dL_ddepth_file[j]);
    //             $fclose(out_dL_dopacity_file[j]);
    //             $fclose(out_dL_dmean2D_file[j]);
    //             $fclose(out_dL_dconic_file[j]);
    //         end
    //         $finish;
    //     end
    // end


endmodule

