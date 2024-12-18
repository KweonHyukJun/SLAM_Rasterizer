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
`define MAX_MEMBER_SIZE 400000
`define MAX_CLOCK_COUNT 2000000

// 1M cycles

module tb_Backward_Rasterizer_group_unit_to_frame #(BLOCK_SIZE = 16, exponent_bit = 8, precision = 16 , mantissa_bit = 7, gaussian_inputs = 4, num_pixels = 16, GID_bit = 24) ();

    integer max_clock_count = `MAX_CLOCK_COUNT;


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
    
    reg gradient_valid_out [num_pixels-1:0];
    reg stall_to_controller [num_pixels-1:0];
    reg last_input_done [num_pixels-1:0];

    reg controller_ready_to_start;

    // Frame size에 따라 바꿔야 함..
    parameter W_BLOCK = 40;
    parameter H_BLOCK = 30;

    // 이거 왜 안되지
    // reg [7:0] target_block_x = target_block / W_BLOCK;
    // reg [7:0] target_block_y = target_block % W_BLOCK;
    reg [7:0] target_block_x;
    reg [7:0] target_block_y;

    // reg [7:0] target_block_x = 'd20;
    // reg [7:0] target_block_y = 'd15;


    integer stall_cnt = 0;

    // reg data_in;
    // reg done_for_work;

    reg started_flag [num_pixels-1:0];

    parameter N_GAUSSIANS = 31985;
    parameter DUPLICATE_GAUSSIANS = 174597;
    parameter N_BLOCKS = 1200;
    parameter N_PIXELS = 307200;


    // Control Mem
    reg [GID_bit-1:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
    reg [23:0] mem_range [(2 * N_BLOCKS) -1 :0];
    reg [23:0] mem_n_contrib [N_PIXELS -1 :0];
    reg [precision -1:0] mem_T_in [N_PIXELS -1 :0];
    reg [precision -1:0] mem_dL_dpixel [(3 * N_PIXELS) -1 :0];
    reg [precision -1:0] mem_dL_dpixel_depth [N_PIXELS -1 :0];

    // Gaussians Mem
    reg [precision -1:0] mem_conic_opacity [(4 * N_GAUSSIANS) -1 :0];
    reg [precision -1:0] mem_gaussian_color [(3 * N_GAUSSIANS) -1 :0];
    reg [precision -1:0] mem_gaussian_depth [N_GAUSSIANS -1 :0];
    reg [precision -1:0] mem_mean2D [(2 * N_GAUSSIANS) -1 :0];

    
    // reg [7:0] mem_block_id [1:0];
    // reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    reg [23:0] current_n_contrib [num_pixels-1:0];
    reg [23:0] current_touches [num_pixels-1:0];

    reg [23:0] current_index [num_pixels-1:0];

    reg all_last_input_done_before;
    reg all_last_input_done;
    
    wire i_valid_wire [gaussian_inputs * num_pixels - 1:0];

    integer j;
    integer i;
    integer max_member_size = `MAX_MEMBER_SIZE;

    integer row_done;


    integer file_handle;

    reg [15:0] block_index_for_control;


    reg [2:0] which_loop [num_pixels-1:0];


    // localparam stage1_latency = 7;
    // localparam stage2_latency = 9;
    // localparam arbiter_latency = 1;
    // integer latency = stage1_latency + stage2_latency + arbiter_latency;


    initial begin
        $fsdbDumpfile("./output/dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_Rasterizer_group_unit_to_frame, "+all");
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
        if (clk_cnt == max_clock_count) $finish;
    end


    initial begin

        //for FP 32
        if (precision == 32 && mantissa_bit == 23) begin

            // Gaussian Information
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/conic_opacity.hex", mem_conic_opacity);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/mean2D.hex", mem_mean2D);

            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/point_list.hex", mem_gaussian_id_in);

            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/gaussian_depth.hex", mem_gaussian_depth);

            // Pixel Information
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/final_Ts.hex", mem_T_in);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/dL_dcolor.hex", mem_dL_dpixel);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/dL_ddepths.hex", mem_dL_dpixel_depth);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/n_contrib.hex", mem_n_contrib);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/ranges.hex", mem_range);

            // $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/i_valid.hex", mem_i_valid);            
        end

        if (precision == 16 && mantissa_bit == 7) begin

            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/conic_opacity.hex", mem_conic_opacity);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/mean2D.hex", mem_mean2D);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/point_list.hex", mem_gaussian_id_in);

            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/gaussian_depth.hex", mem_gaussian_depth);

            // Pixel Information
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/final_Ts.hex", mem_T_in);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/dL_dcolor.hex", mem_dL_dpixel);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/dL_ddepths.hex", mem_dL_dpixel_depth);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/n_contrib.hex", mem_n_contrib);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/ranges.hex", mem_range);

        end
    end

    initial begin
        
        file_handle = $fopen("/home/hyukjun/Projects/MonoGS_HW/SLAM_Rasterizer/output/Testbench_output.txt", "w");

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end
        

        clk <= 1'b0;
        rst_n <= 1'b0;

        H <= 'd480;
        W <= 'd640;

        row_done <= 'd0;

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
            started_flag[j] <= 1'b0;
            current_n_contrib[j] <= 'h0;
            
            current_touches[j] <= 'd0;

            which_loop[j] <= 3'd0;
            
        end

        block_index_for_control <= 'd0;
        

        target_block_x <= 'h0;
        target_block_y <= 'h0; 
        // reg [7:0] target_block_x = target_block / W_BLOCK;
        // reg [7:0] target_block_y = target_block % W_BLOCK;

        controller_ready_to_start <= 1'b0;

        block_id <= 'h0;
        
        // data_in <= 1'b0;
        // done_for_work <= 1'b0;
        // data_in <= 1'b0;

        @(posedge clk);
            // First Start cycles
            rst_n <= 1'b1;
        
        @(posedge clk);
            block_id <= {target_block_x, target_block_y};

            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                T_first[j] <= mem_T_in[j + row_done * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                dL_dpixel[j] <= {mem_dL_dpixel[j + row_done * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0], mem_dL_dpixel[j + row_done * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][1], mem_dL_dpixel[j + row_done * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][2]};
                dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + row_done * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                pixel_id[j] <= j;
                
                start[j] <= 1'b1;
                started_flag[j] <= 1'b1;
                current_n_contrib[j] <= mem_n_contrib[j + row_done * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
            end
        

        @(posedge clk);

            block_id <= 'h0;
            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                T_first[j] <= 'h0;
                dL_dpixel[j] <= 'h0;
                dL_dpixel_depth[j] <= 'h0;
                start[j] <= 1'b0;
                pixel_id[j] <= 'h0;
            end
            controller_ready_to_start <= 1'b1;
    end


    genvar l, k ;
    generate
        for (l = 0; l < num_pixels; l = l + 1) begin
            for (k = 0; k < gaussian_inputs; k = k + 1) begin
                assign i_valid_wire[l * gaussian_inputs + k] = (current_n_contrib[l] <= k)? 1'b0 : 1'b1;
            end
        end
    endgenerate
    

    always @ (posedge clk) begin

        // if (!stall_backpressure) begin // stall backpressure는 pixel group unit 에서는 얘가 주는 거임 (컨트롤러 + FIFO 단에서의 stall 신호까지 준다고 생각)

        for (int j = 0; j < num_pixels; j = j + 1) begin

            if (started_flag[j]) begin  
                start[j] <= 1'b0;


                if (!stall_to_controller[j]) begin

                    if (current_n_contrib[j] > current_touches[j]) begin

                        if (current_n_contrib[j] > gaussian_inputs + current_touches[j]) begin // 남는 상황
                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                // conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 0], mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 1], mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 2], mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 3]};
                                // mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 0], mem_mean2D[2 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 1]};
                                // gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)];
                                // i_valid[j * gaussian_inputs + i] <= i_valid_wire[j * gaussian_inputs + i];
                                // gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 0], mem_gaussian_color[3 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 1], mem_gaussian_color[3 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 2]};
                                // gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)];

                                gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)];

                                conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 0], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 1], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 2], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 3]};
                                mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 0], mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 1]};
                                
                                i_valid[j * gaussian_inputs + i] <= i_valid_wire[j * gaussian_inputs + i];
                                gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 0], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 1], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 2]};
                                gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)]];

                                

                                if (current_touches[j] + i + 1 == current_n_contrib[j]) begin
                                    last_input[j * gaussian_inputs + i] <= 1'b1;
                                end

                                else begin
                                    last_input[j * gaussian_inputs + i] <= 1'b0;
                                end

                            end

                            current_index[j] <= (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + 1));

                            // current_n_contrib[j] <= current_n_contrib[j] - gaussian_inputs;
                            current_touches[j] <= current_touches[j] + gaussian_inputs;

                            which_loop[j] <= 3'd1;
                            
                        end

                        else if ((current_n_contrib[j] <= gaussian_inputs + current_touches[j]) && !(current_n_contrib[j] == current_touches[j])) begin

                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                if (current_touches[j] + i < current_n_contrib[j]) begin
                                    
                                    // conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 0], mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 1], mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 2], mem_conic_opacity[4 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 3]};
                                    // mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 0], mem_mean2D[2 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 1]};
                                    // gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)];
                                    // i_valid[j * gaussian_inputs + i] <= i_valid_wire[j * gaussian_inputs + i];
                                    // gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 0], mem_gaussian_color[3 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 1], mem_gaussian_color[3 * (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)) + 2]};
                                    // gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)];

                                    gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)];

                                    conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 0], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 1], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 2], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 3]};
                                    mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 0], mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 1]};
                                    
                                    i_valid[j * gaussian_inputs + i] <= i_valid_wire[j * gaussian_inputs + i];
                                    gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 0], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 1], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)] + 2]};
                                    gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + i + 1)]];


                                    if (current_touches[j] + i + 1 == current_n_contrib[j]) begin
                                        last_input[j * gaussian_inputs + i] <= 1'b1;
                                    end

                                    else begin
                                        last_input[j * gaussian_inputs + i] <= 1'b0;
                                    end
                                end

                                else if (current_touches[j] + i >= current_n_contrib[j]) begin
                                    last_input[j * gaussian_inputs + i] <= 1'b0;
                                    conic_opacity[j * gaussian_inputs + i] <= 'h0;
                                    mean2D[j * gaussian_inputs + i] <= 'h0;
                                    gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                                    i_valid[j * gaussian_inputs + i] <= 1'b0;
                                    gaussian_color[j * gaussian_inputs + i] <= 'h0;
                                    gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                                end
                            end

                            current_index[j] <= (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + 1));
                            current_touches[j] <= current_n_contrib[j];
                            which_loop[j] <= 3'd2;
                        end
                    end

                    else if (current_n_contrib[j] == current_touches[j]) begin
                        
                        for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                            conic_opacity[j * gaussian_inputs + i] <= 'h0;
                            mean2D[j * gaussian_inputs + i] <= 'h0;
                            gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                            i_valid[j * gaussian_inputs + i] <= 1'b0;
                            gaussian_color[j * gaussian_inputs + i] <= 'h0;
                            gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                            last_input[j * gaussian_inputs + i] <= 1'b0;
                        end
                        which_loop[j] <= 3'd3;
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
                    
                // current_n_contrib[j] <= mem_n_contrib[j + (row_done + 1) * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                // dL_dpixel[j] <= {mem_dL_dpixel[j + (row_done + 1) * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0], 
                //                     mem_dL_dpixel[j + (row_done + 1) * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][1], 
                //                     mem_dL_dpixel[j + (row_done + 1) * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][2]};
                // dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + (row_done + 1) * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0];
                // pixel_id[j] <= num_pixels * row_done + j;
                // T_first[j] <= mem_T_in[j + (row_done + 1) * BLOCK_SIZE + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                current_n_contrib[j] <= mem_n_contrib[j + (row_done + 1) * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                dL_dpixel[j] <= {mem_dL_dpixel[j + (row_done + 1) * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0], 
                                    mem_dL_dpixel[j + (row_done + 1) * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][1], 
                                    mem_dL_dpixel[j + (row_done + 1) * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][2]};
                dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + (row_done + 1) * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0];
                pixel_id[j] <= num_pixels * row_done + j;
                T_first[j] <= mem_T_in[j + (row_done + 1) * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];

                
                current_touches[j] <= 'd0;

            end
            block_id <= {target_block_x, target_block_y};
            row_done <= row_done + 1;


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

    // always @ (posedge clk) begin
    //     if (row_done == 16 && all_last_input_done) begin
            
    //         controller_ready_to_start <= 1'b0;

            
    //         @(posedge clk);

    //         $finish;
    //     end
    // end

    always @ (posedge clk) begin
        if (row_done == 16 && all_last_input_done) begin
            
            controller_ready_to_start <= 1'b0;
            
            
            if ((target_block_x == (W_BLOCK - 1)) && (target_block_y == (H_BLOCK - 1))) begin
                @(posedge clk);
                $display("All blocks are done at %d", clk_cnt);
                $finish;
            end

            else begin

                block_index_for_control <= block_index_for_control + 1;

                for (int j = 0; j < num_pixels; j = j + 1) begin
                    current_touches[j] <= 'd0;
                end

                if (target_block_x == W_BLOCK - 1) begin
                    block_id <= {{$clog2(BLOCK_SIZE)-1{1'b0}}, target_block_y + 1};
                    target_block_x <= 'd0;
                    target_block_y <= target_block_y + 1;
                    row_done <= 'd0;
                    
                end
                else begin
                    block_id <= {target_block_x + 1, target_block_y};
                    target_block_x <= target_block_x + 1;
                    row_done <= 'd0;
                end    
            end
        end
    end


    always @ (negedge all_last_input_done) begin
        repeat(5) @(posedge clk);
            
            controller_ready_to_start <= 1'b1;
        
            
        end

    initial begin
        // Set composite fast draw member size
        $value$plusargs("SET_COMPOSITE_FAST_DRAW_MEMBER_SIZE=%d", max_member_size);
    end

    reg [31:0] prev_clk_cnt;
    reg [15:0] prev_block_index;
    
    always @ (posedge clk) begin
        if (block_index_for_control != prev_block_index) begin
            $fwrite(file_handle, "Block %d complete, clock_cycle: %d\n", block_index_for_control, clk_cnt);
            $fwrite(file_handle, "Block %d Accumulated_cycle : %d\n\n", block_index_for_control, clk_cnt - prev_clk_cnt);
            prev_clk_cnt <= clk_cnt;
            prev_block_index <= block_index_for_control;
        end
    end




    // always @ (posedge clk) begin

    //     for (int j = 0; j < num_pixels; j = j + 1) begin
    //         if (!stall_backpressure[j] && gradient_valid_out[j]) begin
    //             $fwrite(out_gaussian_id_file[j], "%h\n", gaussian_id_out[j]);
    //             $fwrite(out_dL_dcolor_file[j], "%h %h %h\n", dL_dcolor_out[j][(3 * precision)-1: 2 * precision], dL_dcolor_out[j][(2 * precision)-1: precision], dL_dcolor_out[j][precision-1: 0]);
    //             $fwrite(out_dL_ddepth_file[j], "%h\n", dL_ddepth_out[j]);
    //             $fwrite(out_dL_dopacity_file[j], "%h\n", dL_dopacity_out[j]);
    //             $fwrite(out_dL_dmean2D_file[j], "%h %h\n", dL_dmean2D_out[j][(2 * precision)-1: precision], dL_dmean2D_out[j][precision-1: 0]);
    //             $fwrite(out_dL_dconic_file[j], "%h %h %h %h\n", dL_dconic_out[j][(4 * precision)-1: 3 * precision], dL_dconic_out[j][(3 * precision)-1: 2 * precision],  dL_dconic_out[j][(2 * precision)-1: precision], dL_dconic_out[j][precision-1:0]);


    //         end
    //     end

    // end

    // // // // save per clock
    // // always @ (posedge clk) begin

    // //     if (clk_cnt >= 18 && clk_cnt <= 46) begin
    // //         out_gaussian_file = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gid_result/cycle_%0d.hex", clk_cnt), "w");
    // //         out_gaussian_file = $fopen($sformatf("../HEX_TB/hex/pixel_group/rgbd_dataset_freiburg1_desk_fp32/gid_resout_valid_file", clk_cnt), "w");
    



    // //         for (int j = 0; j < num_pixels; j = j + 1) begin
    // //             $fwrite(out_gaussian_file, "%h\n", gaussian_id_out[j]);
    // //             $fwrite(out_gaussianout_valid_fileussian_id_out[j]);


    // //         end

    // //     end
    // // end


    // // // // Save for Merge sort data
    // // always @ (posedge clk) begin
        

    // //     if (clk_cnt >= 18 && clk_cnt <= 50) begin
    // //         for (int j = 0; j < num_pixels; j = j + 1) begin
    // //             $fwrite(out_gaussian_file[j], "%h\n", gaussian_id_out[j]);
    // //             $fwrite(out_valid_file[j], "%h\n", gradient_valid_out[j]);
    // //             $fwrite(out_dL_dcolor_file[j], "%h %h %h\n", dL_dcolor_out[j][(3 * precision)-1: 2 * precision], dL_dcolor_out[j][(2 * precision)-1: precision], dL_dcolor_out[j][precision-1: 0]);
    // //             $fwrite(out_dL_ddepth_file[j], "%h\n", dL_ddepth_out[j]);
    // //             $fwrite(out_dL_dopacity_file[j], "%h\n", dL_dopacity_out[j]);
    // //             $fwrite(out_dL_dmean2D_file[j], "%h %h\n", dL_dmean2D_out[j][(2 * precision)-1: precision], dL_dmean2D_out[j][precision-1: 0]);
    // //             $fwrite(out_dL_dconic_file[j], "%h %h %h %h\n", dL_dconic_out[j][(4 * precision)-1: 3 * precision], dL_dconic_out[j][(3 * precision)-1: 2 * precision],  dL_dconic_out[j][(2 * precision)-1: precision], dL_dconic_out[j][precision-1:0]);
    // //         end
    // //     end

    // //     if (clk_cnt == 51) begin
    // //         for (int j = 0; j < num_pixels; j = j + 1) begin
    // //             $fclose(out_gaussian_file[j]);
    // //             $fclose(out_valid_file[j]);
    // //             $fclose(out_dL_dcolor_file[j]);
    // //             $fclose(out_dL_ddepth_file[j]);
    // //             $fclose(out_dL_dopacity_file[j]);
    // //             $fclose(out_dL_dmean2D_file[j]);
    // //             $fclose(out_dL_dconic_file[j]);
    // //         end
    // //         $finish;
    // //     end
    // // end


endmodule

