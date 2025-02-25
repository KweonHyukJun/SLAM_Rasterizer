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
// `define MAX_CLOCK_COUNT 2000000
`define MAX_CLOCK_COUNT 20000
// `define MAX_CLOCK_COUNT 300000


// Testbench가 Top controller && mem_ ~~는 DDR의 기능

module tb_Backward_Block_controller_with_SRAM 
    #(
        BLOCK_SIZE = 16,
        exponent_bit = 8, 
        precision = 16 , 
        mantissa_bit = 7, 
        gaussian_inputs = 4, 
        num_pixels = 16, 
        GID_bit = 11,
        WINDOW_SIZE = 32,
        GRADIENT_MERGE_TO_TOP_WIDTH = 11 * precision + GID_bit,
        Banks = 16
    ) ();

    integer max_clock_count = `MAX_CLOCK_COUNT;


    // Input
    reg clk;
    reg rst_n;

    // wire Block_data_valid;
    wire gradient_value_ready;
    wire Block_data_done;

    // wire gradient_data_done;
    
    reg [11:0] W_in;
    reg [11:0] H_in;

    reg [15:0] block_id_in; // block index x at [0] y at [1]

    reg [GID_bit-1:0] last_gaussian_index_in;
    

    // Output to TOP controller
    wire Block_data_ready;
    wire gradient_value_valid; // FIFO에 Push
    wire gradient_value_done;

    // From External DDR Memory to SRAM
    // mem ~~ 에서 하나씩 가져오는 변수
    wire [(3 * precision) -1:0] gaussian_color_from_DDR;
    wire [precision-1:0] gaussian_depth_from_DDR;
    wire [(2 * precision)-1:0] mean2D_from_DDR;
    wire [(4 * precision)-1:0] conic_opacity_from_DDR;
    wire [GID_bit-1:0] gaussian_id_from_DDR;


    wire [GID_bit-1:0] pixel_id_from_DDR;
    wire [precision-1:0] T_first_from_DDR;
    wire [precision-1:0] n_contrib_from_DDR;
    wire [(3 * precision)-1:0] dL_dpixel_from_DDR;
    wire [precision-1:0] dL_dpixel_depth_from_DDR;

    // 입력 SRAM 컨트롤 신호
    reg Gaussian_SRAM_WEB;
    reg Pixel_SRAM_WEB;

    // Output to External DDR Memory
    wire push_to_Top_FIFO;
    wire [GRADIENT_MERGE_TO_TOP_WIDTH-1:0] gradient_merge_to_Top_FIFO;
    wire [GID_bit-1:0] gradient_id_to_Top_FIFO;
    
    wire Gradient_SRAM_REB_from_Top_control [Banks-1:0];

    



    // Frame size에 따라 바꿔야 함..
    // parameter W_BLOCK = 40;
    // parameter H_BLOCK = 30;

    // 이거 왜 안되지
    // reg [7:0] target_block_x = target_block / W_BLOCK;
    // reg [7:0] target_block_y = target_block % W_BLOCK;
    reg [7:0] target_block_x;
    reg [7:0] target_block_y;

    reg [7:0] target_block_x_next;
    reg [7:0] target_block_y_next;

    reg [7:0] W_BLOCK;
    reg [7:0] H_BLOCK;

    wire [7:0] W_BLOCK_wire;
    wire [7:0] H_BLOCK_wire;

    
    integer stall_cnt = 0;


    parameter N_GAUSSIANS = 31985;
    parameter DUPLICATE_GAUSSIANS = 174597;
    parameter N_BLOCKS = 1200;
    parameter N_PIXELS = 307200;


    // External DDR Memory
    reg [23:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
    // reg [GID_bit-1:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
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

    // Gradient Memory Destination in DDR

    reg [precision - 1:0] mem_dL_dcolor [(3 * N_GAUSSIANS) -1 :0];
    reg [precision - 1:0] mem_dL_ddepth [N_GAUSSIANS -1 :0];
    reg [precision - 1:0] mem_dL_dopacity [N_GAUSSIANS -1 :0];
    reg [precision - 1:0] mem_dL_dmean2D [(2 * N_GAUSSIANS) -1 :0];
    reg [precision - 1:0] mem_dL_dconic [(4 * N_GAUSSIANS) -1 :0];

    
    // reg [7:0] mem_block_id [1:0];
    // reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    // internal signals
    reg Block_data_done_reg; // Valid 주기 위한 combinational 신호
    reg gradient_value_ready_reg; // Ready 주기 위한 combinational 신호

    wire Block_data_handshake; 

    reg [1:0] Gradient_state_current;
    reg [1:0] Gradient_state_next;

    localparam  GRADIENT_IDLE = 2'd0,
                GRADIENT_BUSY = 2'd1,
                GRADIENT_FETCHING = 2'd2;

    reg [1:0] Top_block_value_state_current;
    reg [1:0] Top_block_value_state_next;

    localparam  TOP_BLOCK_IDLE = 2'd0,
                TOP_BLOCK_FETCHING = 2'd1,
                TOP_BLOCK_DONE = 2'd2;

    reg loss_done_valid; // 전단계 컨트롤러로부터 완료 신호시 처음 신호
    wire loss_done_ready;
    wire loss_done_handshake;

    reg Backward_operating;
    
    
    reg [15:0] max_block_index;

    reg [GID_bit-1:0] max_n_contrib;



    // Pixel fetching index
    reg [$clog2(N_PIXELS)-1:0] pixel_fetching_index;
    reg [$clog2(N_PIXELS)-1:0] pixel_fetching_index_next;

    reg [$clog2(num_pixels)-1:0] pixel_fetching_row;
    reg [$clog2(num_pixels)-1:0] pixel_fetching_row_next;

    reg [$clog2(num_pixels)-1:0] pixel_fetching_line;
    reg [$clog2(num_pixels)-1:0] pixel_fetching_line_next;

    reg [2 * $clog2(num_pixels):0] pixel_fetching_count;

    // Gaussian fetching index
    reg [GID_bit-1:0] gaussian_fetching_index;
    reg [GID_bit-1:0] gradient_fetching_index;
    reg [GID_bit-1:0] gradient_fetching_index_before;

    

    integer max_member_size = `MAX_MEMBER_SIZE;

    integer file_handle;
    integer state_report; 

    integer block_state_0 = 0;
    integer block_state_1 = 0;
    integer block_state_2 = 0;
    integer block_state_3 = 0;


    reg [15:0] block_index_for_control;
    reg [15:0] block_index_for_control_next;
    
    wire gradient_handshake;
    

    wire gradient_fetching_done;
    reg gradient_fetching_done_register;


    // Result to Gradient
    wire [(3 * precision)-1:0] dL_dcolor_out_from_block;
    wire [precision-1:0] dL_ddepth_out_from_block;
    wire [precision-1:0] dL_dopacity_out_from_block;
    wire [(2 * precision)-1:0] dL_dmean2D_out_from_block;
    wire [(4 * precision)-1:0] dL_dconic_out_from_block;

    wire [23:0] original_gaussian_id;
    



    reg [31:0] prev_clk_cnt;
    reg [15:0] prev_block_index;

    wire [GID_bit-1:0] gradient_id_to_SRAM_from_Top_control [Banks-1:0];
    




    initial begin
        $fsdbDumpfile("../output_backward/backward_dump.fsdb");
        $fsdbDumpvars(0, tb_Backward_Block_controller_with_SRAM, "+all");
    end


    // Instantiate the DUT (Device Under Test)
    Backward_Block_controller_with_SRAM #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE),
        .Banks(Banks),
        .GRADIENT_MERGE_TO_TOP_WIDTH(GRADIENT_MERGE_TO_TOP_WIDTH)
        ) 
    Backward_Block_controller_with_SRAM_inst (
        .clk(clk),
        .rst_n(rst_n),
    
        // .Block_data_valid(Block_data_valid),
        .Block_data_done(Block_data_done),
        .gradient_value_ready(gradient_value_ready),
        // .gradient_data_done(gradient_data_done),

        .W_in(W_in),
        .H_in(H_in),
        .block_id_in(block_id_in),
        
        .last_gaussian_index_in(last_gaussian_index_in),

        .Block_data_ready(Block_data_ready),
        .gradient_value_valid(gradient_value_valid),
        // .gradient_value_done(gradient_value_done),

        .gaussian_color_from_DDR(gaussian_color_from_DDR),
        .gaussian_depth_from_DDR(gaussian_depth_from_DDR),
        .mean2D_from_DDR(mean2D_from_DDR),
        .conic_opacity_from_DDR(conic_opacity_from_DDR),
        .gaussian_id_from_DDR(gaussian_id_from_DDR),
        .pixel_id_from_DDR(pixel_id_from_DDR),

        .Gaussian_SRAM_WEB(Gaussian_SRAM_WEB),

        
        .dL_dpixel_from_DDR(dL_dpixel_from_DDR),
        .dL_dpixel_depth_from_DDR(dL_dpixel_depth_from_DDR),
        .T_first_from_DDR(T_first_from_DDR),
        .n_contrib_from_DDR(n_contrib_from_DDR),

        .Pixel_SRAM_WEB(Pixel_SRAM_WEB),


        .Gradient_SRAM_REB_from_Top_control(Gradient_SRAM_REB_from_Top_control),
        .gradient_merge_to_Top_FIFO(gradient_merge_to_Top_FIFO),


        .gradient_id_to_SRAM_from_Top_control(gradient_id_to_SRAM_from_Top_control),
        .push_to_Top_FIFO(push_to_Top_FIFO)
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
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp32/point_list.hex", mem_gaussian_id_in);

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
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/gaussian_color.hex", mem_gaussian_color);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/gaussian_depth.hex", mem_gaussian_depth);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/point_list.hex", mem_gaussian_id_in);

            // Pixel Information
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/final_Ts.hex", mem_T_in);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/dL_dcolor.hex", mem_dL_dpixel);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/dL_ddepths.hex", mem_dL_dpixel_depth);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/n_contrib.hex", mem_n_contrib);
            $readmemh("../HEX_TB/hex/Backward/Backward_Frame_rgbd_dataset_freiburg1_desk_fp16/ranges.hex", mem_range);
        end
    end

    initial begin
        
        file_handle = $fopen("../output_backward/Testbench_output_from_block_controller.txt", "w");

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        state_report = $fopen("../output_backward/Block_controller_state_time.txt", "w");
        if (state_report == 0) begin
            $display("Error: Could not open file for writing!");
            $finish;
        end

        prev_clk_cnt <= 0;
        prev_block_index <= 0;

        clk <= 1'b0;
        rst_n <= 1'b0;

        H_in <= 'd0;
        W_in <= 'd0;

        block_index_for_control <= 'd0;

        target_block_x <= 'd0;
        target_block_y <= 'd0; 

        target_block_x_next <= 'd0;
        target_block_y_next <= 'd0;
        loss_done_valid <= 1'b0;

        pixel_fetching_index <= 'd0;
        pixel_fetching_line <= 'd0;
        pixel_fetching_row <= 'd0;

        pixel_fetching_count <= 'd0;

        // gaussian_fetching_index <= 'd0;
        // Backward_operating <= 1'b0;

        // Gaussian_SRAM_WEB <= 1'b1;
        // Pixel_SRAM_WEB <= 1'b1;


        Gradient_state_current <= GRADIENT_IDLE;
        Top_block_value_state_current <= TOP_BLOCK_IDLE;

        last_gaussian_index_in <= 'd0;

        loss_done_valid <= 1'b0;
        
        H_BLOCK <= 'd0;
        W_BLOCK <= 'd0;
        block_id_in <= 'd0;

        max_block_index <= 'd0;

        max_n_contrib <= 'd0;

        @(posedge clk);

            // First Start cycles

            rst_n <= 1'b1;
            loss_done_valid <= 1'b1;

            block_id_in <= {target_block_x, target_block_y};

            W_in <= 'd640;
            H_in <= 'd480;


        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
            loss_done_valid <= 1'b0;
        
    end

    // assign gradient_id = (Gradient_state_current == GRADIENT_FETCHING) ?   : 'd0;

    genvar Bnk;
    generate
        for (Bnk = 0; Bnk < Banks; Bnk = Bnk + 1) begin : Gradient_SRAM_REB_control_inst
            assign Gradient_SRAM_REB_from_Top_control[Bnk] = (Gradient_state_current == GRADIENT_FETCHING && (gradient_fetching_index >> $clog2(Banks)) == Bnk) ? 1'b0 : 1'b1;
            assign gradient_id_to_SRAM_from_Top_control[Bnk] = (Gradient_state_current == GRADIENT_FETCHING) ? gradient_fetching_index + 1 : 'd0;
        end
    endgenerate 



    // gradient output
    assign dL_dcolor_out_from_block = push_to_Top_FIFO ? gradient_merge_to_Top_FIFO[11 * precision - 1: 8 * precision] : 'h0; 
    assign dL_ddepth_out_from_block = push_to_Top_FIFO ? gradient_merge_to_Top_FIFO[8 * precision - 1: 7 * precision] : 'h0; 
    assign dL_dopacity_out_from_block = push_to_Top_FIFO ? gradient_merge_to_Top_FIFO[7 * precision - 1: 6 * precision] : 'h0; 
    assign dL_dmean2D_out_from_block = push_to_Top_FIFO ? gradient_merge_to_Top_FIFO[6 * precision - 1: 4 * precision] : 'h0; 
    assign dL_dconic_out_from_block = push_to_Top_FIFO ? gradient_merge_to_Top_FIFO[4 * precision - 1: 0] : 'h0; 


    assign original_gaussian_id = push_to_Top_FIFO ? mem_gaussian_id_in[mem_range[2 * (block_index_for_control - 1)] + gradient_fetching_index_before] : 'h0; 


    assign gradient_fetching_done = gradient_fetching_done_register;

    assign gradient_handshake = gradient_value_valid && gradient_value_ready;

    assign loss_done_ready = (Top_block_value_state_current == TOP_BLOCK_IDLE) && (Top_block_value_state_current == TOP_BLOCK_IDLE);

    assign loss_done_handshake = loss_done_valid && loss_done_ready;

    assign Block_data_handshake = Block_data_done && Block_data_ready;
    
    // gradient_value_ready = !FIFO_full

    assign Block_data_done = Block_data_done_reg;

    assign gradient_value_ready = gradient_value_ready_reg;

    assign W_BLOCK_wire = W_in[$clog2(num_pixels)-1:0] == 'd0 ? W_in >> $clog2(num_pixels) : (W_in >> $clog2(num_pixels)) + 1;
    assign H_BLOCK_wire = H_in[$clog2(num_pixels)-1:0] == 'd0 ? H_in >> $clog2(num_pixels) : (H_in >> $clog2(num_pixels)) + 1;


    assign Pixel_SRAM_WEB = (Top_block_value_state_current == TOP_BLOCK_FETCHING && pixel_fetching_count < 'd256) ? 1'b0 : 1'b1;


    assign Gaussian_SRAM_WEB = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in ) ? 1'b0 : 1'b1;

    // 이거도 바꿔야함
    assign gaussian_id_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) ? gaussian_fetching_index + 1: 'h0;

    assign gaussian_color_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) ? 
                    {mem_gaussian_color[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 3 + 0],
                     mem_gaussian_color[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 3 + 1],
                     mem_gaussian_color[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 3 + 2]} : 'h0;

    assign gaussian_depth_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) ? mem_gaussian_depth[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index]] : 'h0;

    assign mean2D_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) ? 
                    { mem_mean2D[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 2 + 0],
                      mem_mean2D[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 2 + 1]} : 'h0;

    assign conic_opacity_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) ? 
                    {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 0],
                     mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 1],
                     mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 2],
                     mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 3]} : 'h0;



    // assign pixel_id_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) ? pixel_fetching_index : 'h0;
    assign pixel_id_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) ? pixel_fetching_row * num_pixels + pixel_fetching_line : 'h0;

    assign dL_dpixel_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) ? 
                    {mem_dL_dpixel[pixel_fetching_index * 3 + 0],
                     mem_dL_dpixel[pixel_fetching_index * 3 + 1],
                     mem_dL_dpixel[pixel_fetching_index * 3 + 2]} : 'h0;
    assign dL_dpixel_depth_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) ? mem_dL_dpixel_depth[pixel_fetching_index] : 'h0;
    assign T_first_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) ? mem_T_in[pixel_fetching_index] : 'h0;
    assign n_contrib_from_DDR = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (pixel_fetching_count < 'd256 )) ? mem_n_contrib[pixel_fetching_index] : 'h0;


    // assign test_for_gaussian_index3 = mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index];

    // 초기 조건?
    always @ (posedge clk) begin

        if (loss_done_handshake) begin
            W_BLOCK <= W_BLOCK_wire;
            H_BLOCK <= H_BLOCK_wire;
            // Backward_operating <= 1'b1;

            block_id_in <= 'd0;

            block_index_for_control <= 'd0;

            target_block_x <= 'd0;
            target_block_y <= 'd0;


            target_block_x_next <= 'd1;
            target_block_y_next <= 'd0;

            

            max_block_index <= W_BLOCK_wire * H_BLOCK_wire - 'd1;

            last_gaussian_index_in <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];
            gaussian_fetching_index <= 'd0;

            // gradient_fetching_index <= 'd1;

            

        end
    end


    // Gradient 받는 상황
    always @ (posedge clk) begin
        if (Backward_operating) begin

            // Gradient handshake시 Gradient 받기 시작
            // FIFO push와 동일한 신호인 gradient_value_valid
            // if (gradient_value_valid) begin
            //     gradient_n_contrib <= gradient_n_contrib + 1;
            // end

            // // Gradient 받는 상황 종료
            // // 그전에 바꿔도 되잖아 걍 Block 입력만 끝나면
            // if (gradient_value_done) begin
            //     gradient_n_contrib <= 'd1;

            //     block_index_for_control <= block_index_for_control + 1;
            //     target_block_x <= target_block_x_next;
            //     target_block_y <= target_block_y_next;

            //     max_n_contrib <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];
            //     last_gaussian_index_in <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];
            //     // gaussian_fetching_index <= 'd1;
            //     gaussian_fetching_index <= 'd0;

            //     if (target_block_x_next == W_BLOCK - 1) begin
            //         target_block_x_next <= 'd0;
            //         target_block_y_next <= target_block_y_next + 1;
            //     end
            //     else begin
            //         target_block_x_next <= target_block_x_next + 1;
            //     end
            // end


            // 이번 BLock이 끝났다고 Block controller에서 신호가 오면
            // 1. 다음 Block의 데이터 받기
            // 2. gradient 모으기
            if (gradient_handshake) begin

                block_index_for_control <= block_index_for_control + 1;
                target_block_x <= target_block_x_next;
                target_block_y <= target_block_y_next;

                max_n_contrib <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];
                last_gaussian_index_in <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];
                // gaussian_fetching_index <= 'd1;
                // gaussian_fetching_index <= 'd0;
                // gradient_fetching_index <= 'd1;

                if (target_block_x_next == W_BLOCK - 1) begin
                    target_block_x_next <= 'd0;
                    target_block_y_next <= target_block_y_next + 1;
                end

                else begin
                    target_block_x_next <= target_block_x_next + 1;
                end

            end
        end
    end

    // Pixel & Gaussian 데이터 받는 경우
    // Pixel 
    always @ (posedge clk) begin

        if (Backward_operating) begin
            if (Top_block_value_state_current == TOP_BLOCK_FETCHING) begin

                pixel_fetching_index <= pixel_fetching_index_next;
                pixel_fetching_line <= pixel_fetching_line_next;
                pixel_fetching_row <= pixel_fetching_row_next;

                if (pixel_fetching_count < 'd256) begin
                    pixel_fetching_count <= pixel_fetching_count + 1;
                end

                // 테스트
                if (Top_block_value_state_next == TOP_BLOCK_DONE) begin
                    pixel_fetching_count <= 'd0;
                    pixel_fetching_index <= 'd0;
                    pixel_fetching_line <= 'd0;
                    pixel_fetching_row <= 'd0;
                end

            end


        end
    end


    // Gaussian 
    always @ (posedge clk) begin

        if (Backward_operating) begin

            if (Top_block_value_state_current == TOP_BLOCK_FETCHING) begin
                if (gaussian_fetching_index < last_gaussian_index_in ) begin
                    gaussian_fetching_index <= gaussian_fetching_index + 'd1;
                end

                if (Top_block_value_state_next == TOP_BLOCK_DONE) begin
                    gaussian_fetching_index <= 'd0;
                end

            end            
        end
    end

    // normal transition
    always @ (posedge clk) begin
        if (!rst_n) begin
            block_index_for_control <= 'd0;
            Top_block_value_state_current <= TOP_BLOCK_IDLE;
            Gradient_state_current <= GRADIENT_IDLE;
        end

        else begin

            if (Gradient_state_current == GRADIENT_BUSY && Gradient_state_next == GRADIENT_IDLE) begin
                block_index_for_control <= block_index_for_control_next; 
            end

            Top_block_value_state_current <= Top_block_value_state_next;
            Gradient_state_current <= Gradient_state_next;

            pixel_fetching_index <= pixel_fetching_index_next;
        end

    end

    // Top and Gradient FSM
    always_comb begin
        Gradient_state_next = Gradient_state_current;
        Backward_operating = 1'b0;
        gradient_value_ready_reg = 1'b0;
        

        case (Gradient_state_current)

            GRADIENT_IDLE: begin

                if (loss_done_handshake) begin
                    Gradient_state_next = GRADIENT_BUSY;
                end
            end


            // 한 Block 작동 중
            GRADIENT_BUSY : begin
                Backward_operating = 1'b1;
                gradient_value_ready_reg = 1'b1; // FIFO 달면서 로직이 약간 달라질 예정

            
                // if ((block_index_for_control == max_block_index) && gradient_value_done) begin
                if (block_index_for_control == max_block_index) begin                    
                    Gradient_state_next = GRADIENT_IDLE;
                end

                else if (gradient_handshake) begin
                    Gradient_state_next = GRADIENT_FETCHING;
                end
            end

            // 한 BLock이 끝나고 Gradient 모으는 state
            GRADIENT_FETCHING : begin
                Backward_operating = 1'b1;
                if (gradient_fetching_done) begin
                    Gradient_state_next = GRADIENT_BUSY;
                end

            end

            default : begin
                Gradient_state_next = GRADIENT_IDLE;
            end
        endcase
    end


    // Block FSM
    always_comb begin
        Top_block_value_state_next = Top_block_value_state_current;
        Block_data_done_reg = 1'b0;

        block_index_for_control_next = block_index_for_control;

        pixel_fetching_index_next = pixel_fetching_index;
        pixel_fetching_line_next = pixel_fetching_line;
        pixel_fetching_row_next = pixel_fetching_row;

        case (Top_block_value_state_current)

        // Loss 대기
        // 'd0
        TOP_BLOCK_IDLE : begin
            if (loss_done_handshake) begin
                Top_block_value_state_next = TOP_BLOCK_FETCHING;
            end

        end


        // Block 데이터 받고 SRAM Cache에 입력
        // 'd1
        TOP_BLOCK_FETCHING : begin

            // Max에 해당하는 데이터 전부 전송시 반환
            // if (pixel_fetching_count[2 * $clog2(num_pixels)] && gaussian_fetching_index == max_n_contrib + 1) begin
            if ((pixel_fetching_count[2 * $clog2(num_pixels)]) && (gaussian_fetching_index >= last_gaussian_index_in)) begin                
                Block_data_done_reg = 1'b1;
                Top_block_value_state_next = TOP_BLOCK_DONE;
                block_index_for_control_next = block_index_for_control_next + 1;
            end
            
            
            if (pixel_fetching_line_next == num_pixels - 1) begin                
                pixel_fetching_line_next = 'd0;
                pixel_fetching_row_next = pixel_fetching_row_next + 1;
                pixel_fetching_index_next = pixel_fetching_row_next * W_in + target_block_x * BLOCK_SIZE + target_block_y * BLOCK_SIZE * W_in;
                

            end
            else begin
                pixel_fetching_line_next = pixel_fetching_line_next + 1;
                pixel_fetching_index_next = pixel_fetching_index_next + 1;
            end
        end

        // Rasterizer Block Data 끝나기 대기
        // 'd2

        TOP_BLOCK_DONE : begin
            
            // Gradient 관련 종료시 로 반환
            // if ((block_index_for_control == max_block_index) && gradient_value_done) begin
            if ((block_index_for_control == max_block_index) && gradient_fetching_done) begin                
                Top_block_value_state_next = TOP_BLOCK_IDLE;
            end

            // 다음 Block 데이터 반환 필요 요청시
            // 타이밍 주의
            // else if (Block_data_ready) begin
            else if (gradient_fetching_done) begin                
                Top_block_value_state_next = TOP_BLOCK_FETCHING;
            end

        end

        default : begin
         Top_block_value_state_next = TOP_BLOCK_IDLE;
        end

        endcase

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


    always @ (posedge clk) begin

        if (clk_cnt < 'd2066) begin
        if (Backward_Block_controller_with_SRAM_inst.Backward_Block_controller_inst.Data_state_current == 'd0) begin
            block_state_0 <= block_state_0 + 1;
        end

        if (Backward_Block_controller_with_SRAM_inst.Backward_Block_controller_inst.Data_state_current == 'd1) begin
            block_state_1 <= block_state_1 + 1;
        end

        if (Backward_Block_controller_with_SRAM_inst.Backward_Block_controller_inst.Data_state_current == 'd2) begin
            block_state_2 <= block_state_2 + 1;
        end

        if (Backward_Block_controller_with_SRAM_inst.Backward_Block_controller_inst.Data_state_current == 'd3) begin
            block_state_3 <= block_state_3 + 1;
        end
        end
    end



    always @ (posedge clk) begin

        if (block_index_for_control == 'd16) begin

            $fwrite(state_report, "State 0: %d\n State 1: %d\n State 2: %d\n State 3: %d\n", block_state_0, block_state_1, block_state_2, block_state_3);

            repeat(5) begin
                $display("\n");
            end

            $display("----------------------------------------------------------------------------------------------------");
            $display("Until %d", block_index_for_control);
            $display("End Time : %d", clk_cnt);
            
            $display("----------------------------------------------------------------------------------------------------");

            repeat(5) begin
                $display("\n");
            end

            $finish;
        end
    end




    // integer gradient_fetching_count;

    always @(posedge clk) begin
        if (!rst_n) begin
            gradient_fetching_done_register <= 1'b0;
            gradient_fetching_index <= 'd0;
            gradient_fetching_index_before <= 'd0;
        end
        else begin

            if (Gradient_state_current == GRADIENT_BUSY && Gradient_state_next == GRADIENT_FETCHING) begin
                gradient_fetching_index <= 'd0;
                gradient_fetching_index_before <= 'd0;
            end

            if (Gradient_state_current == GRADIENT_FETCHING) begin

                gradient_fetching_index_before <= gradient_fetching_index;
                gradient_fetching_index <= gradient_fetching_index + 1;
                if (gradient_fetching_index == (mem_range[2 * (block_index_for_control - 1) + 1] - mem_range[2 * (block_index_for_control - 1)])) begin
                    gradient_fetching_done_register <= 1'b1;
                end
            end
            else begin
                gradient_fetching_done_register <= 1'b0;
            end
        end
    end


    always @ (posedge clk) begin

        // push to Top FIFO 시 gradient Data 저장
        // 이후 Gradient 데이터 비교

        if (push_to_Top_FIFO) begin
            

        end
    end

endmodule

