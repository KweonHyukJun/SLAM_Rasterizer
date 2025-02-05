// Rasterizer만 하고, Block Controller와 SRAM의 역할을 Testbench가 수행
`define MAX_MEMBER_SIZE 400000
`define MAX_CLOCK_COUNT 100

module tb_Backward_Rasterizer_pixel_controller_before_SRAM 
    #(
        BLOCK_SIZE = 16, 
        exponent_bit = 8, 
        precision = 16 , 
        mantissa_bit = 7, 
        gaussian_inputs = 4, 
        num_pixels = 16, 
        GID_bit = 24,
        WINDOW_SIZE = 32
    )
    ();


    integer max_clock_count = `MAX_CLOCK_COUNT;


    // Input from Block controller
    reg clk;
    reg rst_n;

    reg [11:0] W;
    reg [11:0] H;
    reg [15:0] block_id ; // block index x at [0] y at [1]

    reg pixel_values_from_block_control_valid;
    reg gaussian_window_values_from_block_control_valid;

    reg [($clog2(num_pixels)-1):0] current_row_from_block_controller;

    wire pixel_values_to_block_control_ready;
    wire gaussian_window_values_to_block_control_ready;

    reg stall_to_controller_from_rasterizer [num_pixels-1:0];
    reg last_input_done_from_rasterizer [num_pixels-1:0];





    // Output to Block controller
    wire request_pixel_values_out;
    wire request_gaussian_window_values_out;

    // Input from Backward Pixel Group Unit

    // // Output to Backward Pixel Group Unit
    // wire start [num_pixels-1:0];
    // wire [(3 * precision) -1:0] dL_dpixel [num_pixels-1:0]; //fp32 | R | G | B |
    // wire [precision -1:0] dL_dpixel_depth [num_pixels-1:0]; //fp32
    // wire [precision - 1:0] T_first [num_pixels-1:0];
    // wire i_valid [gaussian_inputs * num_pixels - 1:0];
    // wire last_input_done_to_pixel [gaussian_inputs * num_pixels - 1:0];


    // // Input from SRAM, Pixel values
    // reg [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0];
    // reg [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0];
    // reg [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0];
    // reg [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0];

    // // Input from SRAM, Window values
    // reg [GID_bit-1:0] gaussian_id_from_SRAM [WINDOW_SIZE-1:0];
    // reg [(3 * precision)-1:0] gaussian_color_from_SRAM [WINDOW_SIZE-1:0];
    // reg [precision-1:0] gaussian_depth_from_SRAM [WINDOW_SIZE-1:0];
    // reg [(2 * precision)-1:0] mean2D_from_SRAM [WINDOW_SIZE-1:0];
    // reg [(4 * precision)-1:0] conic_opacity_from_SRAM [WINDOW_SIZE-1:0];


    // Frame size에 따라 바꿔야 함..
    parameter W_BLOCK = 40;
    parameter H_BLOCK = 30;

    // 이거 왜 안되지
    // reg [7:0] target_block_x = target_block / W_BLOCK;
    // reg [7:0] target_block_y = target_block % W_BLOCK;
    reg [7:0] target_block_x;
    reg [7:0] target_block_y;

    reg [7:0] target_block_x_next;
    reg [7:0] target_block_y_next;

    

    reg controller_ready_to_start;

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
    reg [GID_bit-1:0] mem_range [(2 * N_BLOCKS) -1 :0];
    reg [GID_bit-1:0] mem_n_contrib [N_PIXELS -1 :0];
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

    // reg [23:0] current_n_contrib [num_pixels-1:0];
    // reg [23:0] current_touches [num_pixels-1:0];

    // reg [23:0] current_index [num_pixels-1:0];

    

    integer first_pixel_index;

    reg all_last_input_done_before;
    reg all_last_input_done;
    
    integer j;
    integer i;
    integer max_member_size = `MAX_MEMBER_SIZE;

    integer row_done;
    integer row_done_next;
    reg row_done_16_flag;


    integer file_handle;

    reg [15:0] block_index_for_control;

    reg [31:0] prev_clk_cnt;
    reg [15:0] prev_block_index;

    initial begin
        $fsdbDumpfile("../output_backward/backward_dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_Rasterizer_pixel_controller_before_SRAM, "+all");
    end

    // // Instantiate the DUT (Device Under Test)
    // Backward_Pixel_group_controller_before_SRAM #( 
    //     .BLOCK_SIZE(BLOCK_SIZE), 
    //     .exponent_bit(exponent_bit), 
    //     .mantissa_bit(mantissa_bit), 
    //     .precision(precision), 
    //     .gaussian_inputs(gaussian_inputs), 
    //     .num_pixels(num_pixels),
    //     .GID_bit(GID_bit),
    //     .WINDOW_SIZE(WINDOW_SIZE)
    //     ) 
    // u_controller  (
    //     .clk(clk),
    //     .rst_n(rst_n),

    //     .W_in(W),
    //     .H_in(H),
    //     .block_id_in(block_id),

    //     .start_from_block_controller(start_from_block_controller),
    //     .window_input_done_from_block_controller(window_input_done_from_block_controller),

    //     .request_pixel_values_out(request_pixel_values_out),
    //     .request_gaussian_window_values_out(request_gaussian_window_values_out),

    //     .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),
    //     .last_input_done_from_rasterizer(last_input_done_from_rasterizer),

    //     .start(start),

    //     .dL_dpixel(dL_dpixel),
    //     .dL_dpixel_depth(dL_dpixel_depth),
    //     .T_first(T_first),
    //     .i_valid(i_valid),
    //     .pixel_id_to_pixel(pixel_id_to_pixel),
    //     .last_input_done_to_pixel(last_input_done_to_pixel),

    //     .next_n_contrib_from_SRAM(next_n_contrib_from_SRAM),
    //     .next_T_first_from_SRAM(next_T_first_from_SRAM),
    //     .next_dL_dpixel_from_SRAM(next_dL_dpixel_from_SRAM),
    //     .next_dL_dpixel_depth_from_SRAM(next_dL_dpixel_depth_from_SRAM),

    //     .gaussian_id_from_SRAM(gaussian_id_from_SRAM),
    //     .gaussian_color_from_SRAM(gaussian_color_from_SRAM),
    //     .gaussian_depth_from_SRAM(gaussian_depth_from_SRAM),
    //     .mean2D_from_SRAM(mean2D_from_SRAM),
    //     .conic_opacity_from_SRAM(conic_opacity_from_SRAM)

    // );

    // Instantiate the DUT (Device Under Test)
    Backward_Pixel_group_controller_before_SRAM #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE)
        ) 
    u_controller  (
        .clk(clk),
        .rst_n(rst_n),

        .W_in(W),
        .H_in(H),
        .block_id_in(block_id),
        

        .pixel_values_from_block_control_valid(pixel_values_from_block_control_valid),
        .gaussian_window_values_from_block_control_valid(gaussian_window_values_from_block_control_valid),

        .current_row_from_block_controller(current_row_from_block_controller),
        
        .pixel_values_to_block_control_ready(pixel_values_to_block_control_ready),
        .gaussian_window_values_to_block_control_ready(gaussian_window_values_to_block_control_ready),

        .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),

        .last_input_done_from_rasterizer(last_input_done_from_rasterizer)
    );


    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) 
        $finish;
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

        clk <= 'b0;
        rst_n <= 'b0;
        W <= 'd0;
        H <= 'd0;
        block_id <= 'd0;

        pixel_values_from_block_control_valid <= 'b0;
        gaussian_window_values_from_block_control_valid <= 'b0;


        controller_ready_to_start <= 1'b0;

        row_done <= 'd0;
        row_done_next <= 'd0;
        current_row_from_block_controller <= 'd0;

        




        for (int i = 0; i < num_pixels; i++) begin 
            stall_to_controller_from_rasterizer[i] <= 'd0;
            last_input_done_from_rasterizer[i] <= 'd0;


            // next_n_contrib_from_SRAM[i] <= 'd0;
            // next_T_first_from_SRAM[i] <= 'd0;
            // next_dL_dpixel_from_SRAM[i] <= 'd0;
            // next_dL_dpixel_depth_from_SRAM[i] <= 'd0;

            // gaussian_id_from_SRAM[i] <= 'd0;
            // gaussian_color_from_SRAM[i] <= 'd0;
            // gaussian_depth_from_SRAM[i] <= 'd0;
            // mean2D_from_SRAM[i] <= 'd0;
            // conic_opacity_from_SRAM[i] <= 'd0;

        end

        @(posedge clk);

        rst_n <= 1'b1;


        @(posedge clk);

        W <= 'd640;
        H <= 'd480;
        block_id <= 'd0;
        current_row_from_block_controller <= 'd0;
        pixel_values_from_block_control_valid <= 'b1;
        gaussian_window_values_from_block_control_valid <= 'b1;

        @(posedge clk);
        pixel_values_from_block_control_valid <= 'b0;
        gaussian_window_values_from_block_control_valid <= 'b0;

        repeat (10) @(posedge clk);

        for (int i = 0; i < num_pixels; i++) begin 
            last_input_done_from_rasterizer[i] <= 'b1;
        end

        @(posedge clk);
        for (int i = 0; i < num_pixels; i++) begin 
            last_input_done_from_rasterizer[i] <= 'd0;
        end
        
        repeat(10) @(posedge clk);

        pixel_values_from_block_control_valid <= 'b1;

        @(posedge clk);
        @(posedge clk);

        gaussian_window_values_from_block_control_valid <= 'b1;

        @(posedge clk);
        @(posedge clk);

        gaussian_window_values_from_block_control_valid <= 'b0;

        

        @(posedge clk);

        $finish;


    end



    // // Group Controller에서 Rasterizer에 입력하는 Gaussian Data window 처리 
    // always @ (posedge clk) begin

    //     if () begin

    //     end
        
    //     else begin

    //     end
        

    // end




    // // Group Controller에서 Rasterizer에 입력하는 Pixel Data 처리
    // // 이게 Group 종료시와 동일 역할
    // always @ (posedge clk) begin


    // end


endmodule