// Rasterizer만 하고, Block Controller와 SRAM의 역할을 Testbench가 수행
`define MAX_MEMBER_SIZE 400000
`define MAX_CLOCK_COUNT 500

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

    reg [$clog2(num_pixels):0] current_row_from_block_controller;
    reg [$clog2(num_pixels):0] next_row_from_block_controller;

    wire pixel_values_to_block_control_ready;
    wire gaussian_window_values_to_block_control_ready;

    reg stall_to_controller_from_rasterizer [num_pixels-1:0];
    reg last_input_done_from_rasterizer [num_pixels-1:0];


    // Output to Block controller


    // Input from Backward Pixel Group Unit

    // Output to Backward Pixel Group Unit
    wire start [num_pixels-1:0];
    wire [(3 * precision) -1:0] dL_dpixel [num_pixels-1:0]; //fp32 | R | G | B |
    wire [precision -1:0] dL_dpixel_depth [num_pixels-1:0]; //fp32
    wire [precision - 1:0] T_first [num_pixels-1:0];
    wire [2 * $clog2(num_pixels)-1:0] pixel_id_to_pixel [num_pixels-1:0];


    wire i_valid [gaussian_inputs * num_pixels - 1:0];
    wire last_input_done_to_pixel [gaussian_inputs * num_pixels - 1:0];

    wire [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    wire [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0];
    

    // Input from SRAM, Pixel values
    reg [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0];
    reg [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0];
    reg [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0];
    reg [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0];

    // Input from SRAM, Window values
    reg [GID_bit-1:0] gaussian_id_from_SRAM [WINDOW_SIZE-1:0];
    reg [(3 * precision)-1:0] gaussian_color_from_SRAM [WINDOW_SIZE-1:0];
    reg [precision-1:0] gaussian_depth_from_SRAM [WINDOW_SIZE-1:0];
    reg [(2 * precision)-1:0] mean2D_from_SRAM [WINDOW_SIZE-1:0];
    reg [(4 * precision)-1:0] conic_opacity_from_SRAM [WINDOW_SIZE-1:0];


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


    // reg controller_ready_to_start;

    integer stall_cnt = 0;

    reg simulation_started;

    // reg data_in;
    // reg done_for_work;

    // reg started_flag [num_pixels-1:0];

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

    


    // // internal control signal for block controller (testbench)

    wire block_pixel_ready_to_group;
    wire block_gaussian_ready_to_group;

    logic [$clog2(num_pixels):0] pixel_pointer;
    logic [$clog2(WINDOW_SIZE):0] gaussian_pointer;

    reg [GID_bit-1:0] max_n_contrib;
    reg [GID_bit-1:0] max_window_index;
    reg pixel_data_fetched;

    reg [15:0] block_index_for_control;


    integer last_input_counter [num_pixels-1:0];


    // reg [GID_bit -1:0] ID_double_check;


    integer first_pixel_index;

    // reg all_last_input_done_before;
    // reg all_last_input_done;
    
    integer j;
    integer i;
    integer max_member_size = `MAX_MEMBER_SIZE;


    initial begin
        $fsdbDumpfile("../output_backward/backward_dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_Rasterizer_pixel_controller_before_SRAM, "+all");
    end

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

        .last_input_done_from_rasterizer(last_input_done_from_rasterizer),

        .start(start),

        .dL_dpixel(dL_dpixel),
        .dL_dpixel_depth(dL_dpixel_depth),
        .T_first(T_first),
        .i_valid(i_valid),
        .pixel_id_to_pixel(pixel_id_to_pixel),
        .last_input_done_to_pixel(last_input_done_to_pixel),

        .gaussian_id_to_rasterizer(gaussian_id_to_rasterizer),
        .gaussian_color_to_rasterizer(gaussian_color_to_rasterizer),
        .gaussian_depth_to_rasterizer(gaussian_depth_to_rasterizer),
        .mean2D_to_rasterizer(mean2D_to_rasterizer),
        .conic_opacity_to_rasterizer(conic_opacity_to_rasterizer),

        .next_n_contrib_from_SRAM(next_n_contrib_from_SRAM),
        .next_T_first_from_SRAM(next_T_first_from_SRAM),
        .next_dL_dpixel_from_SRAM(next_dL_dpixel_from_SRAM),
        .next_dL_dpixel_depth_from_SRAM(next_dL_dpixel_depth_from_SRAM),

        .gaussian_id_from_SRAM(gaussian_id_from_SRAM),
        .gaussian_color_from_SRAM(gaussian_color_from_SRAM),
        .gaussian_depth_from_SRAM(gaussian_depth_from_SRAM),
        .mean2D_from_SRAM(mean2D_from_SRAM),
        .conic_opacity_from_SRAM(conic_opacity_from_SRAM)
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

        target_block_x <= 'd0;
        target_block_y <= 'd0;

        target_block_x_next <= 'd1;
        target_block_y_next <= 'd0;

        current_row_from_block_controller <= 'd0;
        next_row_from_block_controller <= 'd0;

        first_pixel_index <= 'd0;

        pixel_pointer <= 'd0;
        gaussian_pointer <= 'd0;
        pixel_data_fetched <= 'b0;




        simulation_started <= 'b0;
        block_index_for_control <= 'd0;

        for (int i = 0; i < num_pixels; i++) begin 
            stall_to_controller_from_rasterizer[i] <= 'd0;
            last_input_done_from_rasterizer[i] <= 'd0;


            next_n_contrib_from_SRAM[i] <= 'd0;
            next_T_first_from_SRAM[i] <= 'd0;
            next_dL_dpixel_from_SRAM[i] <= 'd0;
            next_dL_dpixel_depth_from_SRAM[i] <= 'd0;

            last_input_counter[i] <= 'd0;
        end

        for (int i = 0 ; i< WINDOW_SIZE; i++) begin
            gaussian_id_from_SRAM[i] <= 'd0;
            gaussian_color_from_SRAM[i] <= 'd0;
            gaussian_depth_from_SRAM[i] <= 'd0;
            mean2D_from_SRAM[i] <= 'd0;
            conic_opacity_from_SRAM[i] <= 'd0;
        end


        @(posedge clk);
        rst_n <= 1'b1;
        simulation_started <= 1'b1;

        W <= 'd640;
        H <= 'd480;
        block_id <= 'd0;
    end



    // // Group Controller에서 Rasterizer에 입력하는 Gaussian Data window 처리 
    // gaussian_window_values_from_block_control_valid
    // gaussian_window_values_to_block_control_ready
    // 2개의 컨트롤 관할

    always @ (posedge clk) begin

        if (!rst_n) begin
            
            gaussian_pointer <= 'd0;
            max_window_index <= 'd0;

            for (int i=0 ; i< WINDOW_SIZE; i++) begin
                gaussian_id_from_SRAM[i] <= 'd0;
                gaussian_color_from_SRAM[i] <= 'd0;
                gaussian_depth_from_SRAM[i] <= 'd0;
                mean2D_from_SRAM[i] <= 'd0;
                conic_opacity_from_SRAM[i] <= 'd0;
            end
        end


        else if (simulation_started) begin

        
            // Pixel이 끝나야 Gaussian 입력 지점 파악 가능
            if (pixel_values_from_block_control_valid && !pixel_data_fetched) begin
                
                pixel_data_fetched <= 'b1;
                max_window_index <= max_n_contrib;
            end            

            





            // Handshake시 다음 보낼 데이터 리셋
            if (gaussian_window_values_from_block_control_valid && gaussian_window_values_to_block_control_ready) begin

                // gaussian_window_values_from_block_control_valid <= 1'b0;
                gaussian_pointer <= 'd0;
                if (max_window_index >= WINDOW_SIZE) begin
                    max_window_index <= max_window_index - WINDOW_SIZE;
                end
                else begin
                    max_window_index <= 'd0;
                end

                for (int i=0; i <WINDOW_SIZE; i++) begin
                    gaussian_id_from_SRAM[i] <= 'd0;
                    gaussian_color_from_SRAM[i] <= 'd0;
                    gaussian_depth_from_SRAM[i] <= 'd0;
                    mean2D_from_SRAM[i] <= 'd0;
                    conic_opacity_from_SRAM[i] <= 'd0;
                end
            end


            // else if (gaussian_pointer < 'd32) begin
            // Gaussian Data 준비

            // gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)];


            // 다음 데이터 모으는 준비 기간
            else if ((gaussian_pointer < WINDOW_SIZE) && pixel_data_fetched) begin

                    // Window 사이즈에 모든 데이터 다 못 넣는 경우
                    if (max_window_index > gaussian_pointer) begin
                        // gaussian_id_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= max_window_index - gaussian_pointer;
                        // gaussian_color_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= {mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 2]};
                        // gaussian_depth_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]];
                        // mean2D_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= {mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1]};
                        // conic_opacity_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= {mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 2], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 3]};


                        gaussian_id_from_SRAM[gaussian_pointer] <= max_window_index - gaussian_pointer;
                        gaussian_color_from_SRAM[gaussian_pointer] <= {mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 2]};
                        gaussian_depth_from_SRAM[gaussian_pointer] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]];
                        mean2D_from_SRAM[gaussian_pointer] <= {mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1]};
                        conic_opacity_from_SRAM[gaussian_pointer] <= {mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 2], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 3]};


                        gaussian_pointer <= gaussian_pointer + 1;
                    end

                    // 초기에 n_touched가 부족하거나 데이터가 충분히 들어가서 마지막 window 인 경우
                    // max_window_index 
                    else begin
                        if (max_window_index <= gaussian_pointer ) begin

                            gaussian_id_from_SRAM[gaussian_pointer] <= 'h0;
                            gaussian_color_from_SRAM[gaussian_pointer] <= 'h0;
                            gaussian_depth_from_SRAM[gaussian_pointer] <= 'h0;
                            mean2D_from_SRAM[gaussian_pointer] <= 'h0;
                            conic_opacity_from_SRAM[gaussian_pointer] <= 'h0;
                        end
                        gaussian_pointer <= WINDOW_SIZE;
                    end

                    // // Window 사이즈에 모든 데이터 다 못 넣는 경우
                    // if (max_window_index >= WINDOW_SIZE) begin
                    //     gaussian_id_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= max_window_index - gaussian_pointer + 1;
                    //     gaussian_color_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= {mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1], mem_gaussian_color[3 * (mem_gaussian_id_in[mem_range[2 * block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 2]};
                    //     gaussian_depth_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]];
                    //     mean2D_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= {mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_mean2D[2 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1]};
                    //     conic_opacity_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= {mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 0], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 1], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 2], mem_conic_opacity[4 * (mem_gaussian_id_in[mem_range[2* block_index_for_control] + max_window_index - (gaussian_pointer + 1)]) + 3]};

                    //     gaussian_pointer <= gaussian_pointer + 1;
                    // end

                    // // 초기에 n_touched가 부족하거나 데이터가 충분히 들어가서 마지막 window 인 경우
                    // // max_window_index 
                    // else begin
                        
                    //     if (max_window_index == gaussian_pointer ) begin

                    //         gaussian_id_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= 'h0;
                    //         gaussian_color_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= 'h0;
                    //         gaussian_depth_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= 'h0;
                    //         mean2D_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= 'h0;
                    //         conic_opacity_from_SRAM[WINDOW_SIZE - (gaussian_pointer + 1)] <= 'h0;
                    //     end
                    //     gaussian_pointer <= gaussian_pointer + 1;
                    // end
            end

        end

    end

    assign gaussian_window_values_from_block_control_valid = gaussian_pointer[$clog2(WINDOW_SIZE)];


    // // Group Controller에서 Rasterizer에 입력하는 Pixel Data 처리
    // // 이게 Group 종료시와 동일 역할
    // pixel_values_from_block_control_valid
    // pixel_values_to_block_control_ready
    // 2개의 컨트롤 관할

    always @ (posedge clk) begin
        if (!rst_n) begin
            pixel_pointer <= 'd0;
            current_row_from_block_controller <= 'd0;
            next_row_from_block_controller <= 'd1;

            max_n_contrib <= 'd0;

            for (int i=0; i <num_pixels; i++) begin
                next_n_contrib_from_SRAM[i] <= 'd0;
                next_T_first_from_SRAM[i] <= 'd0;
                next_dL_dpixel_from_SRAM[i] <= 'd0;
                next_dL_dpixel_depth_from_SRAM[i] <= 'd0;
                pixel_pointer <= 'd0;
            end            
        end 
        
        else if (simulation_started) begin
            // handshake 시 다음 pixel 값을 받기 위한 초기화
            if (pixel_values_from_block_control_valid && pixel_values_to_block_control_ready) begin
                pixel_data_fetched <= 'b0;

                pixel_pointer <= 'd0;
                current_row_from_block_controller <= next_row_from_block_controller;
                next_row_from_block_controller <= next_row_from_block_controller + 'd1;

                first_pixel_index <= next_row_from_block_controller * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W;


                max_n_contrib <= 'd0;
                // next pixel 값 처리
                // Block의 마지막
                if (next_row_from_block_controller[$clog2(num_pixels)]) begin

                    block_index_for_control <= block_index_for_control + 1;

                    next_row_from_block_controller <= 'd0;
                    current_row_from_block_controller <= 'd0;

                    target_block_x <= target_block_x_next;
                    target_block_y <= target_block_y_next;

                    if (target_block_x == W_BLOCK -1) begin
                        target_block_x_next <= 'd0;
                        target_block_y_next <= target_block_y_next + 'd1;

                        block_id <= {target_block_x_next, target_block_y_next};
                    end
                    else begin
                        target_block_x_next <= target_block_x_next + 'd1;
                        block_id <= {target_block_x_next, target_block_y};
                    end
                end

                for (int i = 0; i <num_pixels; i++) begin
                    next_n_contrib_from_SRAM[i] <= 'd0;
                    next_T_first_from_SRAM[i] <= 'd0;
                    next_dL_dpixel_from_SRAM[i] <= 'd0;
                    next_dL_dpixel_depth_from_SRAM[i] <= 'd0;
                    pixel_pointer <= 'd0;
                end
            end

            
            // 다음 handshake 전 데이터 수집
            // first pixel index 이거로 픽셀 데이터 줘야할듯
            // else if (pixel_pointer < 'd16) begin
            else if (pixel_pointer < num_pixels) begin
                next_n_contrib_from_SRAM[pixel_pointer] <= mem_n_contrib[first_pixel_index + pixel_pointer];

                // 새로 Read 하는 값을 기준으로 비교
                if (max_n_contrib < mem_n_contrib[first_pixel_index + pixel_pointer]) begin
                    max_n_contrib <= mem_n_contrib[first_pixel_index + pixel_pointer];
                end

                next_T_first_from_SRAM[pixel_pointer] <= mem_T_in[first_pixel_index + pixel_pointer];
                next_dL_dpixel_from_SRAM[pixel_pointer] <= {
                    mem_dL_dpixel[3 * (first_pixel_index + pixel_pointer) + 0],
                    mem_dL_dpixel[3 * (first_pixel_index + pixel_pointer) + 1], 
                    mem_dL_dpixel[3 * (first_pixel_index + pixel_pointer) + 2]
                };
                next_dL_dpixel_depth_from_SRAM[pixel_pointer] <= mem_dL_dpixel_depth[first_pixel_index + pixel_pointer];
                pixel_pointer <= pixel_pointer + 1;
            end
        end 
    end

    // valid 신호
    assign pixel_values_from_block_control_valid = pixel_pointer[$clog2(num_pixels)];

    // 픽셀 시작시 Gaussian 입력 시작점

    


    // last input 입력

    always @(posedge clk) begin
        for (int i = 0; i < num_pixels; i++) begin
            if (last_input_done_to_pixel[i] && last_input_counter[i] < 'd10) begin
                last_input_counter[i] <= last_input_counter[i] + 1;
            end

            if (last_input_counter[i] == 'd10) begin
                last_input_done_from_rasterizer[i] <= 'b1;
                last_input_counter[i] <= 'd0;
            end

            if (last_input_counter[i] =='d0) begin
                last_input_done_from_rasterizer[i] <= 'b0;
            end

        end

        
    end

endmodule