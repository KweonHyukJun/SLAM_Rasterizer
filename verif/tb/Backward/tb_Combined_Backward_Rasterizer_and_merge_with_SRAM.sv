`define MAX_MEMBER_SIZE 400000
`define MAX_CLOCK_COUNT 3000000
// `define MAX_CLOCK_COUNT 5000
// `define MAX_CLOCK_COUNT 30000

// 1M cycles

module tb_Combined_Backward_Rasterizer_and_merge_with_SRAM 
#(
    parameter BLOCK_SIZE = 16, 
    parameter exponent_bit = 8, 
    parameter precision = 16 , 
    parameter mantissa_bit = 7, 
    parameter gaussian_inputs = 4, 
    parameter num_pixels = 16, 
    parameter GID_bit = 24,
    parameter First_FIFO_depth = 8,
    parameter Last_FIFO_depth = 16,
    parameter Banks = 16,
    parameter Encoder_outs = 4,
    parameter Bank_depth = 2048
) ();

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
    
    reg stall_backpressure;

    reg last_input [gaussian_inputs * num_pixels - 1:0];

    reg [(2 * precision) -1:0] mean2D [gaussian_inputs * num_pixels - 1:0]; //fp32 | X | Y | 
    reg [(4 * precision) -1:0] conic_opacity [gaussian_inputs * num_pixels - 1:0]; // fp32 | X | Y | Z | W |

    reg [GID_bit-1:0] gaussian_id_in [gaussian_inputs * num_pixels - 1:0];
    reg [(3 * precision) -1:0] gaussian_color [gaussian_inputs * num_pixels - 1:0]; //fp32 | R | G | B |
    reg [precision -1:0] gaussian_depth [gaussian_inputs * num_pixels - 1:0]; //fp32


    // Output and SRAM Control Signal
    reg stall_to_controller_from_rasterizer [num_pixels-1:0];
    wire last_input_done_out [Banks-1:0];

    wire SRAM_WEB [Banks-1:0];
    reg SRAM_WEB_temp [Banks-1:0];
    wire SRAM_REB [Banks-1:0];
    wire FIFO_pop_ready_out [Banks-1:0];
    reg [GID_bit-1:0] Write_address_FF [Banks-1:0];
    wire [GID_bit-1:0] Read_address_before_add [Banks-1:0];
    wire FIFO_pop_valid_in [Banks-1:0];

    reg controller_ready_to_start;

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

    integer first_pixel_index;
    
    wire i_valid_wire [gaussian_inputs * num_pixels - 1:0];

    integer j;
    integer i;
    integer max_member_size = `MAX_MEMBER_SIZE;

    integer row_done;
    integer row_done_next;
    reg row_done_16_flag;


    integer file_handle;
    integer SRAM_file_handle [Banks-1:0];

    reg [15:0] block_index_for_control;




    reg [31:0] prev_clk_cnt;
    reg [15:0] prev_block_index;

    integer stall_by_encoder = 0;
    integer stall_by_4x_fifo = 0;
    integer stall_by_1x_fifo = 0;
    integer stall_by_serializer = 0;

    // integer bank_conflict_count[Banks-1:0];

    integer stall_report;

    // // Internal Signal
    // reg [$clog2(BLOCK_SIZE)<<$clog2(BLOCK_SIZE):0] last_input_done_counter_next;
    // reg [$clog2(BLOCK_SIZE)<<$clog2(BLOCK_SIZE):0] last_input_done_counter_FF;

    // last input_done_counter 형식으로
    reg [$clog2(BLOCK_SIZE):0] last_input_done_counter_next;
    reg [$clog2(BLOCK_SIZE):0] last_input_done_counter_FF;

    initial begin
        $fsdbDumpfile("../output_combined_backward/combined_backward_dump.fsdb");
        $fsdbDumpvars(0, tb_Combined_Backward_Rasterizer_and_merge_with_SRAM, "+all");
    end

    // Instantiate the DUT (Device Under Test)
    Combined_Backward_Rasterizer_and_merge_with_SRAM #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .First_FIFO_depth(First_FIFO_depth),
        .Last_FIFO_depth(Last_FIFO_depth),
        .Banks(Banks),
        .Encoder_outs(Encoder_outs),
        .Bank_depth(Bank_depth)
        )
    combined_backward_inst  (
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid),

        .W(W),
        .H(H),

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

        .stall_to_controller_from_rasterizer(stall_to_controller_from_rasterizer),

        .FIFO_pop_valid_in(FIFO_pop_valid_in),
        .SRAM_REB(SRAM_REB),
        .SRAM_WEB(SRAM_WEB),

        .Read_address_before_add(Read_address_before_add),
        
        .FIFO_pop_ready_out(FIFO_pop_ready_out),
        .last_input_done_out(last_input_done_out)
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
        file_handle = $fopen($sformatf("../simulation_output/Combined_Testbench_output_4xFIFO_%0d_1xFIFO_%0d_Bank_%0d.txt", First_FIFO_depth, Last_FIFO_depth, Banks), "w");

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end
        for (int i=0; i<Banks; i++) begin
            SRAM_file_handle[i] = $fopen($sformatf("../output_combined_backward/SRAM_output_%0d.txt", i), "w");

            if (SRAM_file_handle[i] == 0) begin
                $display("Error: Could not open file for writing!");
                $finish;
            end
        end

        stall_report = $fopen($sformatf("../simulation_output/stall_report_4xFIFO_%0d_1xFIFO_%0d_Bank_%0d.txt", First_FIFO_depth, Last_FIFO_depth, Banks), "w");

        if (stall_report == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end




        prev_clk_cnt <= 0;
        prev_block_index <= 0;

        clk <= 1'b0;
        rst_n <= 1'b0;

        H <= 'd480;
        W <= 'd640;

        row_done <= 'd0;
        row_done_next <= 'd0;
        row_done_16_flag <= 1'b0;

        last_input_done_counter_FF <= 'd0;
        controller_ready_to_start <= 1'b0;

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

            current_index[j] <= 'h0;

            
        end

        // for (int j = 0; j < Banks; j = j + 1) begin
        //     bank_conflict_count[j] <= 'd0;
        // end

        block_index_for_control <= 'd0;
        first_pixel_index <= 'd0;
        

        target_block_x <= 'h0;
        target_block_y <= 'h0; 

        target_block_x_next <= 'd0;
        target_block_y_next <= 'd0;

        // reg [7:0] target_block_x = target_block / W_BLOCK;
        // reg [7:0] target_block_y = target_block % W_BLOCK;

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
                
                T_first[j] <= mem_T_in[j + row_done_next * BLOCK_SIZE + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W];
                dL_dpixel[j] <= {mem_dL_dpixel[3 * (j + row_done_next * BLOCK_SIZE + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W) + 0],
                                 mem_dL_dpixel[3 * (j + row_done_next * BLOCK_SIZE + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W) + 1],
                                 mem_dL_dpixel[3 * (j + row_done_next * BLOCK_SIZE + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W) + 2]};

                dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + row_done_next * BLOCK_SIZE + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W];                
                current_n_contrib[j] <= mem_n_contrib[j + row_done_next * BLOCK_SIZE + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W];


                pixel_id[j] <= j;
                
                start[j] <= 1'b1;
                started_flag[j] <= 1'b1;
                
            end
            row_done_next <= 'd1;
            target_block_x_next <= 'd1;
            target_block_y_next <= 'd0;        

        @(posedge clk);

            block_id <= 'h0;
            for (j = 0 ; j < num_pixels ; j = j + 1) begin
                // T_first[j] <= 'h0;
                // dL_dpixel[j] <= 'h0;
                // dL_dpixel_depth[j] <= 'h0;
                start[j] <= 1'b0;
                // pixel_id[j] <= 'h0;
            end
            controller_ready_to_start <= 1'b1;
    end


    genvar l, k ;
    generate
        for (l = 0; l < num_pixels; l = l + 1) begin
            for (k = 0; k < gaussian_inputs; k = k + 1) begin
                assign i_valid_wire[l * gaussian_inputs + k] = (current_n_contrib[l] <= k) ? 1'b0 : 1'b1;
            end
        end
    endgenerate
    

    always @ (posedge clk) begin

        // if (!stall_backpressure) begin // stall backpressure는 pixel group unit 에서는 얘가 주는 거임 (컨트롤러 + FIFO 단에서의 stall 신호까지 준다고 생각)

        for (int j = 0; j < num_pixels; j = j + 1) begin

            if (started_flag[j]) begin  
                start[j] <= 1'b0;


                if (!stall_to_controller_from_rasterizer[j]) begin

                    // 도달하지 않은 상황
                    if (current_n_contrib[j] > current_touches[j]) begin

                        if (current_n_contrib[j] > gaussian_inputs + current_touches[j]) begin // 남는 상황
                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)];
                                // gaussian_id_in[j * gaussian_inputs + i] <= current_n_contrib[j] -  (current_touches[j] + i);

                                conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 0], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 1], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 2], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 3]};
                                mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 0], mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 1]};
                                
                                i_valid[j * gaussian_inputs + i] <= i_valid_wire[j * gaussian_inputs + i];
                                gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 0], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 1], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 2]};
                                gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)]];


                                if (current_touches[j] + i + 1 == current_n_contrib[j]) begin
                                    last_input[j * gaussian_inputs + i] <= 1'b1;
                                end

                                else begin
                                    last_input[j * gaussian_inputs + i] <= 1'b0;
                                end

                            end

                            current_index[j] <= (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + 1));
                            current_touches[j] <= current_touches[j] + gaussian_inputs;

                        end

                        else if ((current_n_contrib[j] <= gaussian_inputs + current_touches[j]) && !(current_n_contrib[j] == current_touches[j])) begin

                            for (int i = 0; i < gaussian_inputs; i = i + 1) begin

                                if (current_touches[j] + i < current_n_contrib[j]) begin
                                    
                                    gaussian_id_in[j * gaussian_inputs + i] <= mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)];
                                    // gaussian_id_in[j * gaussian_inputs + i] <= current_n_contrib[j] -  (current_touches[j] + i);

                                    conic_opacity[j * gaussian_inputs + i] <= {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 0], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 1], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 2], mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 3]};
                                    mean2D[j * gaussian_inputs + i] <= {mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 0], mem_mean2D[2 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 1]};
                                    
                                    i_valid[j * gaussian_inputs + i] <= i_valid_wire[j * gaussian_inputs + i];
                                    gaussian_color[j * gaussian_inputs + i] <= {mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 0], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 1], mem_gaussian_color[3 * mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)] + 2]};
                                    gaussian_depth[j * gaussian_inputs + i] <= mem_gaussian_depth[mem_gaussian_id_in[mem_range[2 * block_index_for_control] + current_n_contrib[j] -  (current_touches[j] + i + 1)]];


                                    if (current_touches[j] + i + 1 == current_n_contrib[j]) begin
                                        last_input[j * gaussian_inputs + i] <= 1'b1;
                                    end

                                    else begin
                                        last_input[j * gaussian_inputs + i] <= 1'b0;
                                    end
                                end

                                else if (current_touches[j] + i >= current_n_contrib[j]) begin

                                    gaussian_id_in[j * gaussian_inputs + i] <= 'h0;


                                    last_input[j * gaussian_inputs + i] <= 1'b0;
                                    conic_opacity[j * gaussian_inputs + i] <= 'h0;
                                    mean2D[j * gaussian_inputs + i] <= 'h0;
                                    gaussian_id_in[j * gaussian_inputs + i] <= 'h0;
                                    i_valid[j * gaussian_inputs + i] <= 1'b0;
                                    gaussian_color[j * gaussian_inputs + i] <= 'h0;
                                    gaussian_depth[j * gaussian_inputs + i] <= 'h0;
                                    // started_flag[j] <= 1'b0;
                                end
                            end

                            current_index[j] <= (mem_range[2 * block_index_for_control + 1] -  (current_touches[j] + 1));
                            current_touches[j] <= current_n_contrib[j];
                           
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
                            // started_flag[j] <= 1'b0;
                        end
                        
                    end

                    // if (last_input_done_out[j]) begin
                    //     started_flag[j] <= 1'b0;
                    // end

                end

            end


            // end
            else begin

                // if (last_input_done[j] && start[j]) begin 
                // last_input_done[j] 이 handshake전까지 1이라는 가정하 성립

                // started flag 가 필요한가
                if (start[j]) begin
                    started_flag[j] <= 1'b1;
                end
            end

        end
    end



    // 이거는 한 줄 끝날때마다 업데이트

    always @ (posedge clk) begin

        // all_last_input_done_before was all_last_input_done
        // if (all_last_input_done_before && controller_ready_to_start) begin
        // if ( last_input_done_counter_FF[$clog2(BLOCK_SIZE)] && controller_ready_to_start) begin       
        if (last_input_done_counter_next[$clog2(BLOCK_SIZE)] && controller_ready_to_start) begin            

            // for (int j = 0; j < num_pixels; j = j + 1) begin

            // 평상시
            if (row_done_next != 0) begin
                for (int j = 0; j < num_pixels; j = j + 1) begin
                    start[j] <= 1'b1;
                        
                    current_n_contrib[j] <= mem_n_contrib[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                    // dL_dpixel[j] <= {mem_dL_dpixel[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0], 
                    //                     mem_dL_dpixel[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][1], 
                    //                     mem_dL_dpixel[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][2]};
                    // dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W][0];

                    dL_dpixel[j] <= {mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W) + 0], 
                                        mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W) + 1], 
                                        mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W) + 2]};
                    dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];

                    pixel_id[j] <= num_pixels * row_done_next + j;
                    T_first[j] <= mem_T_in[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                    
                    current_touches[j] <= 'd0;
                end
                block_id <= {target_block_x, target_block_y};
                first_pixel_index <= row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W;
            end

            // 블럭의 마지막 Row 처리
            else if (row_done_next == 0 && target_block_x != W_BLOCK -1) begin
                for (int j = 0; j < num_pixels; j = j + 1) begin
                    start[j] <= 1'b1;
                        
                    current_n_contrib[j] <= mem_n_contrib[j + row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                    dL_dpixel[j] <= {mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W) + 0], 
                                        mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W) + 1], 
                                        mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W) + 2]};
                    dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                    pixel_id[j] <= num_pixels * row_done_next + j;
                    T_first[j] <= mem_T_in[j + row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W];
                    
                    current_touches[j] <= 'd0;
                end
                block_id <= {target_block_x_next, target_block_y};
                first_pixel_index <= row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W;
            end

            // 블럭의 마지막 Row 처리 && 블럭이 마지막 X 블럭인 경우
            else if (row_done_next == 0 && target_block_x == W_BLOCK -1) begin
                for (int j = 0; j < num_pixels; j = j + 1) begin
                    start[j] <= 1'b1;
                        
                    current_n_contrib[j] <= mem_n_contrib[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W];
                    dL_dpixel[j] <= {mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W) + 0], 
                                        mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W) + 1], 
                                        mem_dL_dpixel[3 * (j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W) + 2]};
                    dL_dpixel_depth[j] <= mem_dL_dpixel_depth[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W];

                    // pixel id = Block 내부 pixel id
                    pixel_id[j] <= num_pixels * row_done_next + j;
                    T_first[j] <= mem_T_in[j + row_done_next * W + target_block_x * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W];
                    
                    current_touches[j] <= 'd0;
                end
                block_id <= {target_block_x_next, target_block_y_next};
                first_pixel_index <= row_done_next * W + target_block_x_next * BLOCK_SIZE + target_block_y_next * BLOCK_SIZE * W;
            end



            // end
            // block_id <= {target_block_x, target_block_y};
            row_done <= row_done_next;
            row_done_next <= (row_done_next + 1) % 16;

            if (row_done == 15) begin
                row_done_16_flag <= 1'b1;
            end
            else begin
                row_done_16_flag <= 1'b0;
            end

            controller_ready_to_start <= 1'b0;

            end
        end

    always @ (posedge clk) begin
        if (!last_input_done_counter_FF[$clog2(BLOCK_SIZE)]) begin
            last_input_done_counter_FF <= last_input_done_counter_next;
        end

        else begin
            last_input_done_counter_FF <= 'd0;
        end
    end

    always_comb begin

        // last_input_done_counter 형식으로
        last_input_done_counter_next = last_input_done_counter_FF;
        for (int i = 0; i < num_pixels; i++) begin

            // if (last_input_done_out[i] ) begin 
            // // 기존 조건은 0번인 last_input_done_out 일때 그냥 읽는데, 이러면 0번이 아닌 last_input_done 시 pop이 아니어도 지속적으로 읽게 됨.

            // 조건 1. last_input_done_out이고 0번, 조건 2. last_input_done_out이고 0번이 아닌 경우 Pop을 확인
            if ((last_input_done_out[i] && Read_address_before_add[i] == 0) || (last_input_done_out[i] && (Read_address_before_add[i] != 0 && FIFO_pop_valid_in[i]))) begin                
                last_input_done_counter_next = last_input_done_counter_next + 1;
            end
        end
    end


    // always @ (posedge clk) begin
    //     all_last_input_done <= all_last_input_done_before;
    // end

    always @ (posedge clk) begin

        // if (row_done == 16 && all_last_input_done) begin
        // if (row_done_16_flag && all_last_input_done_before) begin
        if (row_done_16_flag && (last_input_done_counter_next == num_pixels)) begin
            
            controller_ready_to_start <= 1'b0;
            row_done_16_flag <= 1'b0;
            
            if ((target_block_x == (W_BLOCK - 1)) && (target_block_y == (H_BLOCK - 1))) begin
                @(posedge clk);
                $display("----------------------------------------------------------------------------------------------------");
                $display("All blocks are done at %d", clk_cnt);
                $display("----------------------------------------------------------------------------------------------------");
                $fclose(file_handle);

                $fwrite(stall_report, "End Time : %0d\n\n", clk_cnt);
            
                $fwrite(stall_report, "encoder stall time (Too much valid output or 4X FIFO full): %0d\n", stall_by_encoder);
                $fwrite(stall_report, "4X stall time  (4X FIFO Full): %0d\n\n", stall_by_4x_fifo);
                $fwrite(stall_report, "1X stall time  (1X FIFO Full): %0d\n\n", stall_by_1x_fifo);
                $fwrite(stall_report, "serializer stall time (Too much valid output or 4X FIFO full): %0d\n", stall_by_serializer);


                // for (int i = 0; i < Banks; i++) begin
                //     $fwrite(stall_report, "Bank[%0d] conflict time: %0d\n", i, bank_conflict_count[i]);
                // end
                $fwrite(stall_report, "\n");
                $fclose(stall_report);



                $finish;
            end

            else begin

                block_index_for_control <= block_index_for_control + 1;
                

                for (int j = 0; j < num_pixels; j = j + 1) begin
                    current_touches[j] <= 'd0;  
                end

                if (target_block_x == W_BLOCK - 1) begin
                    // block_id <= {{$clog2(BLOCK_SIZE)-1{1'b0}}, target_block_y + 1};
                    block_id <= {{$clog2(BLOCK_SIZE)-1{1'b0}}, target_block_y};
                    // target_block_x <= 'd0;
                    // target_block_y <= target_block_y + 1;

                    target_block_x <= 'd0;
                    target_block_y <= target_block_y_next;

                    target_block_x_next <= 'd1;
                    // target_block_y_next <= target_block_y;

                    row_done <= 'd0;
                    
                end

                else begin
                    block_id <= {target_block_x_next, target_block_y_next};
                    target_block_x <= target_block_x_next;

                    if (target_block_x_next == W_BLOCK - 1) begin
                        target_block_x_next <= 'd0;
                        target_block_y_next <= target_block_y_next + 'd1;
                    end

                    else begin
                        target_block_x_next <= target_block_x_next + 'd1;
                        target_block_y_next <= target_block_y_next;
                    end


                    // target_block_x_next <= target_block_x_next + 'd1;
                    // target_block_y_next <= target_block_y_next;
                    row_done <= 'd0;
                end    
            end
        end
    end


    
    // always @ (negedge all_last_input_done) begin        
    always @ (posedge last_input_done_counter_FF[$clog2(BLOCK_SIZE)]) begin
        repeat(5) @(posedge clk);
            
            controller_ready_to_start <= 1'b1;
        
            
        end

    initial begin
        // Set composite fast draw member size
        $value$plusargs("SET_COMPOSITE_FAST_DRAW_MEMBER_SIZE=%d", max_member_size);
    end


    
    always @ (posedge clk) begin
        if (block_index_for_control != prev_block_index) begin
            $fwrite(file_handle, "Block %d complete, clock_cycle: %d\n", block_index_for_control, clk_cnt - prev_clk_cnt);
            $fwrite(file_handle, "Block %d Accumulated_cycle : %d\n\n", block_index_for_control, clk_cnt);
            prev_clk_cnt <= clk_cnt;
            prev_block_index <= block_index_for_control;
        end
    end
  


    // Backward Grad merge 부분
    genvar m;
    generate 
        for (m = 0; m < Banks; m++) begin : SRAM_WEB_gen
            assign SRAM_WEB[m] = SRAM_WEB_temp[m];
            assign SRAM_REB[m] = FIFO_pop_ready_out[m] && (Write_address_FF[m] != Read_address_before_add[m]) ? 1'b0 : 1'b1;
            // assign FIFO_pop_valid_in[k] = FIFO_pop_ready_out[k] && (Write_address_FF[k] != Read_address_before_add[k]) ? 1'b1 : 1'b0;
            assign FIFO_pop_valid_in[m] = (FIFO_pop_ready_out[m]) && ((Write_address_FF[m] != Read_address_before_add[m]) || Read_address_before_add[m] == 0) ? 1'b1 : 1'b0;
        end
    endgenerate


    // FIFO read control
    always @ (posedge clk) begin

        if (!stall_backpressure) begin

            for (int j = 0; j < Banks; j++) begin

                // FIFO_pop_valid_in[j] <= 1'b1;
                // SRAM_WEB[j] <= SRAM_WEB_temp[j];
                
                // 충돌 확인 후 다음 사이클에 데이터 전송
                // if (FIFO_pop_ready_out[j] && FIFO_pop_valid_in[j]) begin
                if (FIFO_pop_ready_out[j]) begin

                    if (Write_address_FF[j] != Read_address_before_add[j]) begin
                        // SRAM_REB[j] <= 1'b0; // Active low
                        SRAM_WEB_temp[j] <= 1'b0;
                        Write_address_FF[j] <= Read_address_before_add[j];
                        // FIFO_pop_valid_in[j] <= 1'b1;
                    end

                    // 충돌시 REB를 안띄우는 대신 Write Addr도 삭제
                    // Bank Conflict 카운트
                    else begin
                        // bank_conflict_count[j] <= bank_conflict_count[j] + 1;
                        // SRAM_REB[j] <= 1'b1;
                        SRAM_WEB_temp[j] <= 1'b1;
                        Write_address_FF[j] <= 'h0;
                        // FIFO_pop_valid_in[j] <= 1'b0;
                    end

                    
                end

                // 새로 들어오는 신호와 이전 신호가 같으면 Read / Write 충돌

                else begin
                    // SRAM_REB[j] <= 1'b1;
                    SRAM_WEB_temp[j] <= 1'b1;
                    Write_address_FF[j] <= 'h0;
                    // FIFO_pop_valid_in[j] <= 1'b0;
                end
            end
        end
    end

    // stall 기록용

    always @ (posedge clk) begin
        if (combined_backward_inst.Combined_Backward_Rasterizer_and_merge_inst.Gradient_merge_unit_by_majority_with_add_inst.stall_from_encoder_comb) begin
            stall_by_encoder <= stall_by_encoder + 1;
        end

        if (combined_backward_inst.Combined_Backward_Rasterizer_and_merge_inst.Gradient_merge_unit_by_majority_with_add_inst.stall_from_1x_fifo_comb) begin
            stall_by_1x_fifo <= stall_by_1x_fifo + 1;
        end

        if (combined_backward_inst.Combined_Backward_Rasterizer_and_merge_inst.Gradient_merge_unit_by_majority_with_add_inst.stall_from_4x_fifo_comb) begin
            stall_by_4x_fifo <= stall_by_4x_fifo + 1;
        end

        if (combined_backward_inst.Combined_Backward_Rasterizer_and_merge_inst.Gradient_merge_unit_by_majority_with_add_inst.stall_from_serializer_comb) begin
            stall_by_serializer <= stall_by_serializer + 1;
        end
    end

    // always @ (posedge clk) begin
    //     if (block_index_for_control == 'd15) begin
    //         repeat(5) begin
    //             $display("\n");
    //         end
    //         $display("----------------------------------------------------------------------------------------------------");
    //         $display("Until %d", block_index_for_control);
    //         $display("End Time : %d", clk_cnt);
            
    //         $display("----------------------------------------------------------------------------------------------------");

    //         repeat(5) begin
    //             $display("\n");
    //         end

    //         $finish;
    //     end
    // end

endmodule