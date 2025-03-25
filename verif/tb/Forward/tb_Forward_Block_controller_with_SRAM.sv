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
// `define MAX_CLOCK_COUNT 100000000 // 천만
`define MAX_CLOCK_COUNT 7000000
// `define MAX_CLOCK_COUNT 5000



module tb_Forward_Block_controller_with_SRAM 
    #(
        BLOCK_SIZE = 16,
        exponent_bit = 8, 
        precision = 32, 
        mantissa_bit = 23, 
        gaussian_inputs = 4, 
        num_pixels = 16, 
        GID_bit = 11,
        WINDOW_SIZE = 32,
        target_count = 15000
    ) ();

    integer max_clock_count = `MAX_CLOCK_COUNT;


    // Input
    reg clk;
    reg rst_n;

    // wire Block_data_valid;
    wire pixel_out_value_ready;
    wire Block_data_done;

    // wire gradient_data_done;
    
    reg [11:0] W_in;
    reg [11:0] H_in;

    reg [15:0] block_id_in; // block index x at [0] y at [1]

    reg [GID_bit-1:0] last_gaussian_index_in;
    

    // Output to TOP controller
    wire Block_data_ready;
    wire pixel_out_value_valid; // FIFO에 Push
    wire pixel_out_value_done;

    // From External DDR Memory to SRAM
    // mem ~~ 에서 하나씩 가져오는 변수
    wire [(3 * precision) -1:0] gaussian_color_from_DDR [gaussian_inputs-1:0];
    wire [precision-1:0] gaussian_depth_from_DDR [gaussian_inputs-1:0];
    wire [(2 * precision)-1:0] mean2D_from_DDR [gaussian_inputs-1:0];
    wire [(4 * precision)-1:0] conic_opacity_from_DDR [gaussian_inputs-1:0];
    wire [GID_bit-1:0] gaussian_id_from_DDR [gaussian_inputs-1:0];


    wire [GID_bit-1:0] pixel_id_from_DDR [num_pixels-1:0];


    // 입력 SRAM 컨트롤 신호
    wire Gaussian_SRAM_WEB [gaussian_inputs-1:0];





    // Output to External DDR Memory
    wire pixel_out_value_valid_to_Top [num_pixels-1:0];
    wire [(6 * precision + GID_bit)-1:0] pixel_out_value_to_Top [num_pixels-1:0];
    
    wire Pixel_SRAM_REB_from_Top_control [num_pixels-1:0];

    wire [$clog2(num_pixels)-1:0] pixel_id_to_SRAM_from_Top_control [num_pixels-1:0];

    reg [7:0] target_block_x;
    reg [7:0] target_block_y;

    reg [7:0] target_block_x_next;
    reg [7:0] target_block_y_next;

    reg [7:0] W_BLOCK;
    reg [7:0] H_BLOCK;

    wire [7:0] W_BLOCK_wire;
    wire [7:0] H_BLOCK_wire;

    

    parameter N_GAUSSIANS = 50000;
    parameter DUPLICATE_GAUSSIANS = 300000;
    parameter N_BLOCKS = 1200;
    parameter N_PIXELS = 307200;


    // External DDR Memory
    reg [23:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
    // reg [GID_bit-1:0] mem_gaussian_id_in [DUPLICATE_GAUSSIANS -1 :0];
    reg [23:0] mem_range [(2 * N_BLOCKS) -1 :0];
    reg [23:0] mem_n_contrib [N_PIXELS -1 :0];
    // reg [precision -1:0] mem_T_in [N_PIXELS -1 :0];
    // reg [precision -1:0] mem_dL_dpixel [(3 * N_PIXELS) -1 :0];
    // reg [precision -1:0] mem_dL_dpixel_depth [N_PIXELS -1 :0];

    // Gaussians Mem
    reg [precision -1:0] mem_conic_opacity [(4 * N_GAUSSIANS) -1 :0];
    reg [precision -1:0] mem_gaussian_color [(3 * N_GAUSSIANS) -1 :0];
    reg [precision -1:0] mem_gaussian_depth [N_GAUSSIANS -1 :0];
    reg [precision -1:0] mem_mean2D [(2 * N_GAUSSIANS) -1 :0];

    // Gradient Memory Destination in DDR

    // reg [precision - 1:0] mem_dL_dcolor [(3 * N_GAUSSIANS) -1 :0];
    // reg [precision - 1:0] mem_dL_ddepth [N_GAUSSIANS -1 :0];
    // reg [precision - 1:0] mem_dL_dopacity [N_GAUSSIANS -1 :0];
    // reg [precision - 1:0] mem_dL_dmean2D [(2 * N_GAUSSIANS) -1 :0];
    // reg [precision - 1:0] mem_dL_dconic [(4 * N_GAUSSIANS) -1 :0];

    reg [precision - 1:0] mem_pixel_color [(3 * N_PIXELS)-1:0];
    reg [precision - 1:0] mem_pixel_depth [N_PIXELS-1:0];
    reg [precision - 1:0] mem_pixel_opacity [N_PIXELS-1:0];
    reg [GID_bit-1:0] mem_n_contrib_out [N_PIXELS-1:0];
    
    // reg [7:0] mem_block_id [1:0];
    // reg [(2 * $clog2(BLOCK_SIZE) - 1):0] mem_pixel_id [0:0];

    // internal signals
    reg Block_data_done_reg; // Valid 주기 위한 combinational 신호
    reg pixel_out_value_ready_reg; // Ready 주기 위한 combinational 신호

    wire Block_data_handshake; 

    reg [1:0] Pixel_state_current;
    reg [1:0] Pixel_state_next;

    localparam  PIXEL_IDLE = 2'd0,
                PIXEL_BUSY = 2'd1,
                PIXEL_FETCHING = 2'd2;

    reg [1:0] Top_block_value_state_current;
    reg [1:0] Top_block_value_state_next;

    localparam  TOP_BLOCK_IDLE = 2'd0,
                TOP_BLOCK_FETCHING = 2'd1,
                TOP_BLOCK_DONE = 2'd2;

    reg Frame_start_valid; // 전단계 컨트롤러로부터 완료 신호시 처음 신호
    wire Frame_start_ready;
    wire Frame_start_handshake;

    reg Forward_operating;
    
    
    reg [15:0] max_block_index;

    reg [GID_bit-1:0] max_n_contrib;



    // Pixel fetching index
    // reg [$clog2(N_PIXELS)-1:0] pixel_fetching_index;
    // reg [$clog2(N_PIXELS)-1:0] pixel_fetching_index_next;

    // reg [$clog2(num_pixels)-1:0] pixel_fetching_row;
    // reg [$clog2(num_pixels)-1:0] pixel_fetching_row_next;

    reg [$clog2(num_pixels)-1:0] pixel_fetching_line;
    reg [$clog2(num_pixels)-1:0] pixel_fetching_line_next;

    reg [2 * $clog2(num_pixels):0] pixel_fetching_count;

    // Gaussian fetching index
    reg [GID_bit-1:0] gaussian_fetching_index;
    reg [$clog2(num_pixels):0] pixel_fetching_index;
    reg [$clog2(num_pixels):0] pixel_fetching_index_before;

    

    integer max_member_size = `MAX_MEMBER_SIZE;

    integer file_handle;

    integer pixel_color_file [num_pixels-1:0];
    integer pixel_depth_file [num_pixels-1:0];
    integer pixel_opacity_file [num_pixels-1:0];
    integer pixel_n_touched_file [num_pixels-1:0];



    reg [15:0] block_index_for_control;
    reg [15:0] block_index_for_control_next;
    
    wire pixel_handshake;
    

    wire pixel_fetching_done;
    reg pixel_fetching_done_register;


    // Result to Gradient
    wire [(3 * precision)-1:0] dL_dcolor_out_from_block;
    wire [precision-1:0] dL_ddepth_out_from_block;
    wire [precision-1:0] dL_dopacity_out_from_block;
    wire [(2 * precision)-1:0] dL_dmean2D_out_from_block;
    wire [(4 * precision)-1:0] dL_dconic_out_from_block;

    wire [23:0] original_gaussian_id;

    reg [31:0] prev_clk_cnt;
    reg [15:0] prev_block_index;
    


    initial begin
        $fsdbDumpfile("../output_forward_control/forward_control_dump.fsdb");
        $fsdbDumpvars(0, tb_Forward_Block_controller_with_SRAM, "+all");
    end


    // Instantiate the DUT (Device Under Test)
    Forward_Block_controller_with_SRAM #( 
        .BLOCK_SIZE(BLOCK_SIZE), 
        .exponent_bit(exponent_bit), 
        .mantissa_bit(mantissa_bit), 
        .precision(precision), 
        .gaussian_inputs(gaussian_inputs), 
        .num_pixels(num_pixels),
        .GID_bit(GID_bit),
        .WINDOW_SIZE(WINDOW_SIZE)
        ) 
    Forward_Block_controller_with_SRAM_inst (
        .clk(clk),
        .rst_n(rst_n),
    
        // .Block_data_valid(Block_data_valid),
        .Block_data_done(Block_data_done),
        .pixel_out_value_ready(pixel_out_value_ready),
        // .gradient_data_done(gradient_data_done),

        .block_id_in(block_id_in),
        
        .last_gaussian_index_in(last_gaussian_index_in),

        .Block_data_ready(Block_data_ready),
        .pixel_out_value_valid(pixel_out_value_valid),
        // .pixel_out_value_done(pixel_out_value_done),

        .gaussian_color_from_DDR(gaussian_color_from_DDR),
        .gaussian_depth_from_DDR(gaussian_depth_from_DDR),
        .mean2D_from_DDR(mean2D_from_DDR),
        .conic_opacity_from_DDR(conic_opacity_from_DDR),
        .gaussian_id_from_DDR(gaussian_id_from_DDR),
        .pixel_id_from_DDR(pixel_id_from_DDR),

        .Gaussian_SRAM_WEB(Gaussian_SRAM_WEB),

        

        // .Gradient_SRAM_REB_from_Top_control(Gradient_SRAM_REB_from_Top_control),
        // .gradient_id_to_SRAM_from_Top_control(gradient_id_to_SRAM_from_Top_control),

        .pixel_out_value_SRAM_REB_from_Top_control(Pixel_SRAM_REB_from_Top_control),
        .pixel_out_value_SRAM_Read_address_from_Top_control(pixel_id_to_SRAM_from_Top_control),

        .pixel_out_value_valid_to_Top(pixel_out_value_valid_to_Top),
        .pixel_out_value_to_Top(pixel_out_value_to_Top)

        // .Gradient_SRAM_WEB_from_Top_control(Gradient_SRAM_WEB_from_Top_control)
    );

    // Initial reg example
    // uut.T0 = 32'h1;
    always begin
        #0.5 clk = !clk;  // Toggle clock every half period
    end

    integer clk_cnt = 0;

    always @(posedge clk) begin
        clk_cnt <= clk_cnt + 1;
        if (clk_cnt == max_clock_count) $finish;
    end


    initial begin

        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/conic_opacity.hex", target_count, precision), mem_conic_opacity);
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/mean2D.hex", target_count, precision), mem_mean2D);

        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/gaussian_color.hex", target_count, precision), mem_gaussian_color);
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/gaussian_depth.hex", target_count, precision), mem_gaussian_depth);

        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/point_list.hex", target_count, precision), mem_gaussian_id_in);
        $readmemh($sformatf("../HEX_TB/hex/Combined/Forward_and_Backward_Test/TUM1_%0d_fp%0d/ranges.hex", target_count, precision), mem_range);      
    end

    initial begin
        
        // file_handle = $fopen("../simulation_output/Testbench_output_from_block_controller_new_encoder_with_%0d.txt", "w");
        
        // Create directory if it doesn't exist
        void'($system($sformatf("mkdir -p ../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d", target_count, precision)));

        file_handle = $fopen($sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/Testbench_output_from_block_controller_gaussian_inputs_%0d_fp%0d.txt", target_count, precision, gaussian_inputs, precision), "w");

        if (file_handle == 0) begin
            $display("Error: Could not open file for writing!");
            $display("Attempted to write to: %s", $sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/Testbench_output_from_block_controller_gaussian_inputs_%0d_fp%0d.txt", target_count, precision, gaussian_inputs, precision));
            $finish;
        end

        // file_handle = $fopen($sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/Testbench_output_from_block_controller_gaussian_inputs_%0d_fp%0d.txt", target_count, precision, gaussian_inputs, precision), "w");

        // if (file_handle == 0) begin
        //     $display("Error: Could not open file for writing!");
        //     $finish;
        // end


        for (int i = 0 ; i < num_pixels; i++) begin
            pixel_color_file[i] = $fopen($sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/pixel_color_file_%0d_fp%0d.txt", target_count, precision, i, precision), "w");
            pixel_depth_file[i] = $fopen($sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/pixel_depth_file_%0d_fp%0d.txt", target_count, precision, i, precision), "w");
            pixel_opacity_file[i] = $fopen($sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/pixel_opacity_file_%0d_fp%0d.txt", target_count, precision, i, precision), "w");
            pixel_n_touched_file[i] = $fopen($sformatf("../simulation_output/Forward_pixel/target_count_%0d_with_control_fp_%0d/pixel_n_touched_file_%0d_fp%0d.txt", target_count, precision, i, precision), "w");
        end


        $display("Forward Block Controller with SRAM Test Start : Target count : %0d, gaussian inputs : %0d, precision : %0d", target_count, gaussian_inputs, precision);        

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

        Frame_start_valid <= 1'b0;

        // pixel_fetching_index <= 'd0;
        // pixel_fetching_line <= 'd0;
        // pixel_fetching_row <= 'd0;

        pixel_fetching_count <= 'd0;


        Pixel_state_current <= PIXEL_IDLE;
        Top_block_value_state_current <= TOP_BLOCK_IDLE;

        last_gaussian_index_in <= 'd0;

        
        
        H_BLOCK <= 'd0;
        W_BLOCK <= 'd0;
        block_id_in <= 'd0;

        max_block_index <= 'd0;

        max_n_contrib <= 'd0;

        @(posedge clk);

            // First Start cycles
            rst_n <= 1'b1;
            Frame_start_valid <= 1'b1;

            block_id_in <= {target_block_x, target_block_y};

            W_in <= 'd640;
            H_in <= 'd480;


        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
            Frame_start_valid <= 1'b0;
        
    end


    genvar pix;
    generate
        for (pix = 0; pix < num_pixels; pix = pix + 1) begin : Pixel_SRAM_REB_control_inst
            // assign Gradient_SRAM_REB_from_Top_control[Bnk] = (Gradient_state_current == GRADIENT_FETCHING && (pixel_fetching_index >> $clog2(Banks)) == Bnk) ? 1'b0 : 1'b1;

            assign Pixel_SRAM_REB_from_Top_control[pix] = (Pixel_state_current == PIXEL_FETCHING) && (!pixel_fetching_index[$clog2(num_pixels)])  ? 1'b0 : 1'b1;
            assign pixel_id_to_SRAM_from_Top_control[pix] = (Pixel_state_current == PIXEL_FETCHING) ? pixel_fetching_index : 'd0;

            // assign Gradient_SRAM_WEB_from_Top_control[Bnk] = (Gradient_state_current == GRADIENT_FETCHING) ? 1'b0 : 1'b1;

        end
    endgenerate 


    assign pixel_fetching_done = pixel_fetching_done_register;

    assign pixel_handshake = pixel_out_value_valid && pixel_out_value_ready;

    assign Frame_start_ready = (Top_block_value_state_current == TOP_BLOCK_IDLE) && (Pixel_state_current == PIXEL_IDLE);

    assign Frame_start_handshake = Frame_start_valid && Frame_start_ready;

    assign Block_data_handshake = Block_data_done && Block_data_ready;

    assign Block_data_done = Block_data_done_reg;

    assign pixel_out_value_ready = pixel_out_value_ready_reg;

    assign W_BLOCK_wire = W_in[$clog2(num_pixels)-1:0] == 'd0 ? W_in >> $clog2(num_pixels) : (W_in >> $clog2(num_pixels)) + 1;
    assign H_BLOCK_wire = H_in[$clog2(num_pixels)-1:0] == 'd0 ? H_in >> $clog2(num_pixels) : (H_in >> $clog2(num_pixels)) + 1;

    
    genvar g, p;
    generate 

        // gaussian 처리
        for (g = 0; g < gaussian_inputs; g++) begin : gaussian_to_SRAM_inst

            assign gaussian_id_from_DDR[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? (gaussian_fetching_index + 1) >> $clog2(gaussian_inputs): 'h0;

            assign gaussian_color_from_DDR[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in)) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 
                            {mem_gaussian_color[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 3 + 0],
                            mem_gaussian_color[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 3 + 1],
                            mem_gaussian_color[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 3 + 2]} : 'h0;

            assign gaussian_depth_from_DDR[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? mem_gaussian_depth[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index]] : 'h0;

            assign mean2D_from_DDR[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 
                            { mem_mean2D[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 2 + 0],
                            mem_mean2D[mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] * 2 + 1]} : 'h0;

            assign conic_opacity_from_DDR[g] = ((Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in )) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 
                            {mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 0],
                            mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 1],
                            mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 2],
                            mem_conic_opacity[4 * mem_gaussian_id_in[mem_range[block_index_for_control * 2] + gaussian_fetching_index] + 3]} : 'h0;

            assign Gaussian_SRAM_WEB[g] = (Top_block_value_state_current == TOP_BLOCK_FETCHING) && (gaussian_fetching_index < last_gaussian_index_in ) && ((gaussian_fetching_index + 1) % gaussian_inputs == g) ? 1'b0 : 1'b1;                            
        end
    endgenerate

    // 초기 조건?
    always @ (posedge clk) begin

        if (Frame_start_handshake) begin
            W_BLOCK <= W_BLOCK_wire;
            H_BLOCK <= H_BLOCK_wire;

            block_id_in <= 'd0;

            block_index_for_control <= 'd0;
            
            target_block_x <= 'd0;
            target_block_y <= 'd0;

            target_block_x_next <= 'd1;
            target_block_y_next <= 'd0;

            max_block_index <= W_BLOCK_wire * H_BLOCK_wire;

            last_gaussian_index_in <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)] - 1;
            gaussian_fetching_index <= 'd0;

        end
    end


    // Gradient 받는 상황
    always @ (posedge clk) begin
        if (Forward_operating) begin


            // 이번 BLock이 끝났다고 Block controller에서 신호가 오면
            // 1. 다음 Block의 데이터 받기
            // 2. gradient 모으기
            if (pixel_handshake) begin

                block_index_for_control <= block_index_for_control + 1;
                target_block_x <= target_block_x_next;
                target_block_y <= target_block_y_next;

                block_id_in <= {target_block_x_next, target_block_y_next};

                max_n_contrib <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];
                last_gaussian_index_in <= mem_range[2 * (block_index_for_control) + 1] - mem_range[2 * (block_index_for_control)];

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

    // Gaussian 
    always @ (posedge clk) begin

        if (Forward_operating) begin

            if (Top_block_value_state_current == TOP_BLOCK_FETCHING) begin
                if (gaussian_fetching_index < last_gaussian_index_in) begin
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
            Pixel_state_current <= PIXEL_IDLE;
        end

        else begin
            if (Pixel_state_current == PIXEL_BUSY && Pixel_state_next == PIXEL_IDLE) begin
                block_index_for_control <= block_index_for_control_next; 
            end

            Top_block_value_state_current <= Top_block_value_state_next;
            Pixel_state_current <= Pixel_state_next;

        end

    end

    // Top and Gradient FSM
    always_comb begin
        Pixel_state_next = Pixel_state_current;
        Forward_operating = 1'b0;
        pixel_out_value_ready_reg = 1'b0;
        

        case (Pixel_state_current)

            PIXEL_IDLE: begin

                if (Frame_start_handshake) begin
                    Pixel_state_next = PIXEL_BUSY;
                end
            end


            // 한 Block 작동 중
            PIXEL_BUSY : begin
                Forward_operating = 1'b1;
                pixel_out_value_ready_reg = 1'b1; // FIFO 달면서 로직이 약간 달라질 예정

            
                // if ((block_index_for_control == max_block_index) && pixel_out_value_done) begin
                if (block_index_for_control == max_block_index) begin                    
                    Pixel_state_next = PIXEL_IDLE;
                end

                else if (pixel_handshake) begin
                    Pixel_state_next = PIXEL_FETCHING;
                end
            end

            // 한 BLock이 끝나고 Gradient 모으는 state
            PIXEL_FETCHING : begin
                Forward_operating = 1'b1;
                if (pixel_fetching_done) begin
                    Pixel_state_next = PIXEL_BUSY;
                end


            end

            default : begin
                Pixel_state_next = PIXEL_IDLE;
            end
        endcase
    end


    // Block FSM
    always_comb begin
        Top_block_value_state_next = Top_block_value_state_current;
        Block_data_done_reg = 1'b0;

        block_index_for_control_next = block_index_for_control;

        case (Top_block_value_state_current)

        // Loss 대기
        // 'd0
        TOP_BLOCK_IDLE : begin
            if (Frame_start_handshake) begin
                Top_block_value_state_next = TOP_BLOCK_FETCHING;
            end

        end


        // Block 데이터 받고 SRAM Cache에 입력
        // 'd1
        TOP_BLOCK_FETCHING : begin

            // Max에 해당하는 데이터 전부 전송시 반환
            // if (pixel_fetching_count[2 * $clog2(num_pixels)] && gaussian_fetching_index == max_n_contrib + 1) begin
            if (gaussian_fetching_index >= last_gaussian_index_in) begin                
                Block_data_done_reg = 1'b1;
                Top_block_value_state_next = TOP_BLOCK_DONE;
                block_index_for_control_next = block_index_for_control_next + 1;                
            end
        end

        // Rasterizer Block Data 끝나기 대기
        // 'd2

        TOP_BLOCK_DONE : begin
            
            // Gradient 관련 종료시 로 반환
            // if ((block_index_for_control == max_block_index) && pixel_out_value_done) begin
            if ((block_index_for_control == max_block_index) && pixel_fetching_done) begin                
                Top_block_value_state_next = TOP_BLOCK_IDLE;
            end

            // 다음 Block 데이터 반환 필요 요청시
            // 타이밍 주의
            // else if (Block_data_ready) begin
            else if (pixel_fetching_done) begin                
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

        // if (block_index_for_control == 'd1 && Pixel_state_current == PIXEL_BUSY) begin
        if (block_index_for_control == 'd1200 && Pixel_state_current == PIXEL_BUSY) begin

            // $fwrite(state_report, "State 0: %d\n State 1: %d\n State 2: %d\n State 3: %d\n", block_state_0, block_state_1, block_state_2, block_state_3);
            @(posedge clk);
            @(posedge clk);
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
            pixel_fetching_done_register <= 1'b0;
            pixel_fetching_index <= 'd0;
            pixel_fetching_index_before <= 'd0;
        end
        else begin

            if (Pixel_state_current == PIXEL_BUSY && Pixel_state_next == PIXEL_FETCHING) begin
                pixel_fetching_index <= 'd0;
                pixel_fetching_index_before <= 'd0;
            end

            if (Pixel_state_current == PIXEL_FETCHING) begin

                if (!pixel_fetching_index[$clog2(num_pixels)]) begin
                    pixel_fetching_index_before <= pixel_fetching_index;
                    pixel_fetching_index <= pixel_fetching_index + 1;
                end



                // if (pixel_fetching_index == (mem_range[2 * (block_index_for_control - 1) + 1] - mem_range[2 * (block_index_for_control - 1)] - 2)) begin
                if (pixel_fetching_index[$clog2(num_pixels)]) begin
                    pixel_fetching_done_register <= 1'b1;
                end

            end
            else begin
                pixel_fetching_done_register <= 1'b0;
            end
        end
    end


    always @ (posedge clk) begin

        // push to Top FIFO 시 gradient Data 저장
        // 이후 Gradient 데이터 비교
        for (int i = 0; i < num_pixels; i++) begin
            if (pixel_out_value_valid_to_Top[i]) begin
                $fwrite(pixel_color_file[i], "%h %h %h\n", pixel_out_value_to_Top[i][GID_bit + (6 * precision)-1 : GID_bit + (5 *precision)], pixel_out_value_to_Top[i][GID_bit + (5 * precision)-1 : GID_bit + (4 * precision)], pixel_out_value_to_Top[i][GID_bit + (4 * precision)-1 : GID_bit + (3 * precision)]);
                $fwrite(pixel_depth_file[i], "%h\n", pixel_out_value_to_Top[i][GID_bit + (3 * precision) - 1 : GID_bit + (2 * precision)]);
                $fwrite(pixel_opacity_file[i], "%h\n", pixel_out_value_to_Top[i][GID_bit + (2 * precision) - 1 : GID_bit + precision]);
                $fwrite(pixel_n_touched_file[i], "%h\n", pixel_out_value_to_Top[i][GID_bit-1:0]);
                // {pixel_color_out_from_rasterizer[pixel], pixel_depth_out_from_rasterizer[pixel], pixel_opacity_out_from_rasterizer[pixel], T_first_out_from_rasterizer[pixel], n_contrib_out_from_rasterizer[pixel]}
            end
        end
    end


    always @ (posedge clk) begin
        if (block_index_for_control != prev_block_index) begin
            $fwrite(file_handle, "Block %0d complete, clock_cycle: %0d\n", block_index_for_control - 'd1, clk_cnt - prev_clk_cnt);
            $fwrite(file_handle, "Block %0d Accumulated_cycle : %0d\n\n", block_index_for_control - 'd1, clk_cnt);
            prev_clk_cnt <= clk_cnt;
            prev_block_index <= block_index_for_control;


            if (block_index_for_control % 50 == 0) begin
                $display("Block %0d complete, clock_cycle: %0d", block_index_for_control - 'd1, clk_cnt);
            end
        end

        if (clk_cnt % 50000  == 0) begin
            $display("Now, Block %0d, clock_cycle: %0d", block_index_for_control, clk_cnt);
        end
    end


endmodule

