
// SRAM은 없다고 가정 (추가로 module화 해서 달 예정)
module Backward_Block_controller_pipelining_controller_single_input #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    // parameter gaussian_inputs = 4, // in one pixel unit, gaussians
    parameter num_pixels = 16, // number of pixel units
    // parameter GID_bit = 24,
    parameter GID_bit = 12,
    parameter WINDOW_SIZE = 32,
    parameter Banks = 16,
    parameter LUT_SIZE = 1 << GID_bit
    ) 

    (
    input wire clk,
    input wire rst_n,

    // Input from Top controller
        input wire Block_data_done,

        input wire gradient_value_ready,
        // input wire gradient_data_done, // gradient 관련 handshake에서 모든 데이터를 top에서 처리하였을 경우 반환

        input wire [11:0] W_in,
        input wire [11:0] H_in,
        input wire [15:0] block_id_in,

        // input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리


    // Output to Top Controller
        output wire Block_data_ready,
        output wire gradient_value_valid,

        // Input from Group Rasterizer
        input wire stall_to_controller_from_rasterizer [num_pixels-1:0],

        // Stall from Grad merge to Rasterizer (control for input row)
        input wire stall_to_rasterizer_to_controller,

        // Group Rasterizer's last_input_done
        input wire last_input_done_from_rasterizer [num_pixels-1:0],

        // Gradient merge's last_input_done
        input wire last_input_done_from_gradient_merge [Banks-1:0],

        output wire rasterizer_FIFO_pop_valid_in [Banks-1:0],
        input wire rasterizer_FIFO_pop_ready_out [Banks-1:0],

        output wire stall_to_rasterizer_from_controller,



    // Output to Group Rasterizer

        // Gaussian Window value
        output reg i_valid [num_pixels - 1:0],

        output reg last_input_done_to_rasterizer [num_pixels - 1:0],
        output reg [GID_bit-1:0] gaussian_id_to_rasterizer [num_pixels - 1:0],
        output reg [(3 * precision)-1:0] gaussian_color_to_rasterizer [num_pixels - 1:0],
        output reg [precision-1:0] gaussian_depth_to_rasterizer [num_pixels - 1:0],
        output reg [(2 * precision)-1:0] mean2D_to_rasterizer [num_pixels - 1:0],
        output reg [(4 * precision)-1:0] conic_opacity_to_rasterizer [num_pixels - 1:0],
        

        // pixel value
        output reg start [num_pixels-1:0], // 이거 컨트롤 신호, 유사 리셋의 느낌

        output reg [11:0] H,
        output reg [11:0] W,
        output reg [15:0] block_id,
        output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id [num_pixels-1:0],

        output reg [precision-1:0] T_first_current [num_pixels-1:0],
        output reg [(3 * precision)-1:0] dL_dpixel_current [num_pixels-1:0],
        output reg [precision-1:0] dL_dpixel_depth_current [num_pixels-1:0],
        // output reg [(2 * $clog2(BLOCK_SIZE) - 1): 0] pixel_id_current [num_pixels-1:0],

        

    // Input from input gaussian SRAM
    input wire [(3 * precision) - 1:0] gaussian_color_from_SRAM,
    input wire [precision-1:0] gaussian_depth_from_SRAM,
    input wire [(2 * precision)-1:0] mean2D_from_SRAM,
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM,

    output reg [GID_bit-1:0] gaussian_id_to_SRAM, // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항

    output reg REB_to_gaussian_SRAM,


    // Input from input Pixel SRAM
    input wire [GID_bit-1:0] next_n_contrib_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_T_first_from_SRAM [num_pixels-1:0],
    input wire [(3 * precision)-1:0] next_dL_dpixel_from_SRAM [num_pixels-1:0],
    input wire [precision-1:0] next_dL_dpixel_depth_from_SRAM [num_pixels-1:0],

    // Output to input Pixel SRAM
    output wire [$clog2(num_pixels) - 1:0] Read_address_to_Pixel_SRAM [num_pixels-1:0],
    output wire REB_to_Pixel_SRAM [num_pixels-1:0],


    // Input from gradient merge SRAM
    input wire [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0],
    input wire last_input_done_and_data_zero [Banks-1:0], 

    // Output to gradient merge SRAM
        output wire REB_to_gradient_SRAM [Banks-1:0],
        output wire WEB_to_gradient_SRAM [Banks-1:0],

        // output wire gradient_ID_used [Banks-1:0],
        output reg gradient_ID_used [Banks-1:0],

        output reg [LUT_SIZE-1:0] Gradient_first_used_LUT
    );
    // synopsys template
    

    //////////////////////// Block Control ////////////////////////
    // Gradient Merge SRAM 관련 데이터를 직접 컨트롤
    // Pixel 및, Gaussian Window 관련 데이터는 간접적으로 컨트롤

        // FF Register

        reg [1:0] Block_state_current;
        reg [1:0] Block_state_next;


        // reg [GID_bit-1:0] block_last_gaussian_index; // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리

        reg [$clog2(num_pixels):0] last_input_done_for_output_FF;
        reg [$clog2(num_pixels):0] row_for_output_FF;

        // row & last_input_done 분리
    
        reg [$clog2(num_pixels):0] row_for_input_FF;
        reg [$clog2(num_pixels):0] last_input_done_for_input_FF;

        reg pixel_started;

        // 굳이 16개일 이유가?

            // State
            localparam  BLOCK_IDLE = 2'b00,
                        BLOCK_PIXEL_FETCHING = 2'b01,
                        BLOCK_BUSY = 2'b10;

            // Combinational register (for control signal)
            reg Block_ready;
            wire block_handshake;
            wire gradient_handshake;

            // Combinational Register
        // reg REB_to_gaussian_SRAM_before;
        // reg REB_to_Pixel_SRAM_before;
        reg REB_to_gradient_SRAM_before [Banks-1:0];

        logic row_end_condition;
        logic row_end_condition_temp [num_pixels-1:0];

        reg input_n_contrib_is_zero_and_last_row_input_done;



    // //////////////////////// Window Control ////////////////////////
    // 가동중인 Window에 대한 컨트롤

        // FF Register

            // State
            localparam  WINDOW_IDLE = 2'd0,
                        WINDOW_REQUEST = 2'd1,
                        WINDOW_BUSY = 2'd2;
                        

            reg [1:0] Window_state_current;
            reg [1:0] Window_state_next;

            reg window_request;
        
            wire window_handshake;
            logic window_empty;
            logic window_empty_comb;
            logic window_empty_temp [num_pixels-1:0];
            

        // // Window에 기입해야 하는 최대 index 받아오기

        // reg current_window_max_index_is_zero;

        reg [GID_bit-1:0] gaussian_id_to_SRAM_before;
        reg [GID_bit-1:0] gaussian_id_to_SRAM_original;


    // //////////////////////// Next Window Control ////////////////////////

    // Next Window에 대한 컨트롤

        // State
        localparam  NEXT_WINDOW_IDLE = 2'd0,
                    NEXT_WINDOW_FETCHING = 2'd1,
                    NEXT_WINDOW_READY = 2'd2;

        reg [1:0] Next_window_state_current;
        reg [1:0] Next_window_state_next;

        reg window_valid;

        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer;
        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_FF1;
        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_FF2;

        reg [$clog2(WINDOW_SIZE):0] next_window_fetching_pointer_next; 

        reg stall_to_controller_from_rasterizer_comb;        
        

    // //////////////////////// Pixel Control ////////////////////////
    // // 각 픽셀에 관한 입력


        logic [$clog2(num_pixels):0] row_for_output_next;
        logic [$clog2(num_pixels):0] last_input_done_for_output_next;
        logic last_input_done_for_output_next_condition [Banks-1:0];
        logic [$clog2(Banks):0] last_input_done_for_output_next_temp;

        logic [$clog2(num_pixels):0] row_for_input_next;
        logic [$clog2(num_pixels):0] last_input_done_for_input_next;
        logic [$clog2(num_pixels):0] last_input_done_for_input_next_temp;



        reg REB_to_pixel_SRAM_FF [num_pixels-1:0];

        // Pixel 데이터 겸 hot gaussian window에서의 n_contrib의 역할
        reg [GID_bit-1:0] pixel_n_contrib [num_pixels-1:0];
        reg [GID_bit-1:0] pixel_n_contrib_next [num_pixels-1:0];

    
        wire [GID_bit-1:0] gaussian_id_for_fetching;

        wire [$clog2(num_pixels)-1:0] pixel_id_x [num_pixels-1:0];
        wire [$clog2(num_pixels)-1:0] pixel_id_y [num_pixels-1:0];

                        

    //////////////////////// Gaussian Window ////////////////////////

    // Current Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_window [WINDOW_SIZE-1:0];
        reg [3 *precision -1:0] gaussian_color_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_window [WINDOW_SIZE-1:0];

        // 각 window에서 각 Pixel에 보내는 pointer
        reg [$clog2(WINDOW_SIZE):0] Gaussian_window_pointer_current [num_pixels-1:0];

        
        // 입력 N_contrib가 0인경우 last_input을 반환하기 위한 신호

        // n_contrib 시작이 0 인경우
        reg input_n_contrib_is_zero [num_pixels-1:0];
        logic all_input_n_contrib_is_zero;
        logic all_input_n_contrib_is_zero_temp;
        // 
        reg last_input_from_zero_n_contrib [num_pixels-1:0];
        
        
        // wire over_the_window [num_pixels-1:0];
        // reg all_over_the_window;


        
    // Next Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_for_next_window [WINDOW_SIZE-1:0];
        reg [3 * precision -1:0] gaussian_color_for_next_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_for_next_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_for_next_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_for_next_window [WINDOW_SIZE-1:0];



        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_current;
        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_next;

        

        // 처음 pixel 값에서 부터 가져오는 max 값
        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_first;

        reg REB_to_gaussian_SRAM_FF;


        // Combinational Logic
        reg [GID_bit-1:0] gaussian_id_to_SRAM_original_comb;
        reg [GID_bit-1:0] gaussian_id_to_SRAM_comb;
        reg REB_to_gaussian_SRAM_comb;    
        
    //////////////////////// Pixel Window ////////////////////////




    //////////////////////// Backward Unit Control singal ////////////////////////
    reg [GID_bit-1:0] Write_address_FF [Banks-1:0];
    reg [GID_bit-1:0] Write_address_FF1 [Banks-1:0];

    // reg [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0];

    reg rasterizer_FIFO_pop_valid_in_FF_temp [Banks-1:0];

    reg WEB_to_gradient_SRAM_temp [Banks-1:0];


    // assign gradient_value_valid = (Block_state_current == BLOCK_BUSY) && (row_for_output_FF == num_pixels);
    assign gradient_value_valid = (Block_state_current == BLOCK_IDLE) && (row_for_output_FF[$clog2(num_pixels)]);

    assign block_handshake = Block_data_done && Block_ready;
    assign window_handshake = window_valid && window_request;
    assign gradient_handshake = gradient_value_valid && gradient_value_ready;

    // Block State control
    always_comb begin
        Block_state_next = Block_state_current;
        row_for_output_next = row_for_output_FF;

        row_for_input_next = row_for_input_FF;
        Block_ready = 1'b0;
        input_n_contrib_is_zero_and_last_row_input_done = 1'b0;


        // output row 완료시
        if (last_input_done_for_output_FF[$clog2(num_pixels)]) begin
            row_for_output_next = row_for_output_next + 1;
        end

        
        case (Block_state_current)
            //'d0, Block에 SRAM 데이터가 준비되지 않음 or Top 컨트롤러에서 Gradient 반환 
            
            BLOCK_IDLE: begin
                Block_ready = 1'b1;
                if (Block_data_done) begin
                    Block_state_next = BLOCK_PIXEL_FETCHING;
                end
            end

            //'d1, 다음 pixel에 대한 데이터 가져와야함
            BLOCK_PIXEL_FETCHING: begin
                
                // 픽셀 데이터가 다 차면 반환
                // if (pixel_fetching_pointer[$clog2(num_pixels)]) begin
                
                // Pixel 데이터를 Read 하면 반환
                if (!REB_to_Pixel_SRAM[0]) begin
                    Block_state_next = BLOCK_BUSY;
                end

            end

            //'d2, Pixel 데이터 가져옴
            BLOCK_BUSY: begin

                // 전체 블록 완료시
                // if (gradient_handshake || (row_end_condition && last_input_done_for_output_FF[$clog2(num_pixels)])) begin

                if (gradient_handshake || (row_end_condition && row_for_output_FF[$clog2(num_pixels)])) begin
                // if (gradient_handshake || (row_for_output_FF[$clog2(num_pixels)] && (row_end_condition || ))) begin
                    Block_state_next = BLOCK_IDLE;
                end

                // 다음 픽셀 데이터 필요시

                // input / output 컨트롤 분리 고려해야함

                // input last input done 완료시 다음 row 가져오게끔
                // else if ((last_input_done_for_input_FF[$clog2(num_pixels)] || all_input_n_contrib_is_zero) && !row_for_input_FF[$clog2(num_pixels)]) begin
                else if ((last_input_done_for_input_FF[$clog2(num_pixels)] || all_input_n_contrib_is_zero)) begin
                    row_for_input_next = row_for_input_FF + 1;

                    if (!row_for_input_next[$clog2(num_pixels)]) begin
                        Block_state_next = BLOCK_PIXEL_FETCHING;
                    end

                    // 어떤 flag 띄워서 input_n_contrib_is_zero 0 으로 처리
                    else if (row_for_input_next[$clog2(num_pixels)]) begin
                        input_n_contrib_is_zero_and_last_row_input_done = 1'b1;
                    end

                    if (all_input_n_contrib_is_zero) begin
                        row_for_output_next = row_for_output_next + 1;
                    end
                end

            end

            default : begin
                Block_state_next = BLOCK_IDLE;
            end
        endcase
    end


    // Window State Control
    always_comb begin
        Window_state_next = Window_state_current;
        window_request = 1'b0;

        for (int i = 0; i < num_pixels; i++) begin
            pixel_n_contrib_next[i] = pixel_n_contrib[i];
        end

        case (Window_state_current)
            // BLock 대기 시
            WINDOW_IDLE: begin
                if (block_handshake) begin
                    Window_state_next = WINDOW_REQUEST;
                end
            end

            // Window 요청 시 (hot window 비어있음)
            // window 요청을 다 줘야 last input 그게 된다.
            WINDOW_REQUEST: begin
                window_request = 1'b1;

                // 전체 데이터 완료시 IDLE
                if (gradient_handshake) begin
                    Window_state_next = WINDOW_IDLE;
                end

                // 데이터 수신 완료시 BUSY
                else if (window_handshake) begin
                    Window_state_next = WINDOW_BUSY;
                end
            end

            // Hot Window 존재, 데이터 수신 완료
            WINDOW_BUSY : begin

                // 다음 window 필요할 시 상태 변경
                // 모든 픽셀에서의 window pointer가 WINDOW SIZE 초과시 
                // 혹은 window pointer가 0까지 내려간 경우 (이 경우에 대한 보완 필요)

                // if (window_empty) begin
                if ((window_empty && !stall_to_controller_from_rasterizer_comb)) begin
                    Window_state_next = WINDOW_REQUEST;
                end

                for (int i = 0; i < num_pixels; i++) begin
                    

                    if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]] && pixel_n_contrib_next[i] > 'd0) begin
                        pixel_n_contrib_next[i] = pixel_n_contrib_next[i] - 'd1;
                    end
                
            
                end

            end

            default: begin
                Window_state_next = WINDOW_IDLE;
            end

        endcase     

    end

    // Next window state control

    always_comb begin
        Next_window_state_next = Next_window_state_current;
        window_valid = 1'b0;
        next_window_fetching_pointer_next = next_window_fetching_pointer;
        max_pixel_n_contrib_for_next_window_next = max_pixel_n_contrib_for_next_window_current;


        case (Next_window_state_current)
            NEXT_WINDOW_IDLE: begin
                if (block_handshake) begin
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            NEXT_WINDOW_FETCHING: begin

                // State가 중간에 넘어가기 위한 조건 - 중간 지점에서 끝나는 경우에 대비해야 함.

                // if (gradient_handshake ) begin
                if (gradient_handshake || row_for_input_FF[$clog2(num_pixels)]) begin
                    Next_window_state_next = NEXT_WINDOW_IDLE;
                end

                else if (next_window_fetching_pointer_FF1[$clog2(WINDOW_SIZE)] && gaussian_id_for_next_window[0] != 'd0) begin                                        
                    Next_window_state_next = NEXT_WINDOW_READY;
                end

                else if (!next_window_fetching_pointer[$clog2(WINDOW_SIZE)]) begin
                // else begin
                
                    // 다 채우지 못하고 남은게 0 인경우 (약간 초기 상황도 포함이네)
                    // 여기서 후반 조건에 대한 transition 해야함

                    if (next_window_fetching_pointer_FF2 + 1 < WINDOW_SIZE) begin
                        next_window_fetching_pointer_next = next_window_fetching_pointer + 1;
                    end

                    if (max_pixel_n_contrib_for_next_window_current < 1) begin
                        max_pixel_n_contrib_for_next_window_next = 'd0;
                    end

                    // 아직 window가 다 차지 않은 경우
                    else begin
                        max_pixel_n_contrib_for_next_window_next = max_pixel_n_contrib_for_next_window_current - 1;

                    end

                end

            end

            NEXT_WINDOW_READY: begin
                window_valid = 1'b1;

                // window handshake시 fetching 상태로 변경
                if (row_for_input_FF[$clog2(num_pixels)]) begin
                    Next_window_state_next = NEXT_WINDOW_IDLE;
                end

                else if (window_request) begin
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            default: begin
                Next_window_state_next = NEXT_WINDOW_IDLE;
            end

        endcase
    end



    // always_comb begin
    //     max_pixel_n_contrib_for_next_window_first = 'd0;

    //     for (int i = 0; i < num_pixels; i++) begin
    //         if (!REB_to_pixel_SRAM_FF[i] && (next_n_contrib_from_SRAM[i] > max_pixel_n_contrib_for_next_window_first)) begin
    //             max_pixel_n_contrib_for_next_window_first = next_n_contrib_from_SRAM[i];
    //         end            

    //     end
    // end


    tree_logic_wire_max #(
        .num_pixels(num_pixels),
        .GID_bit(GID_bit)
    ) tree_logic_wire_max_inst (
        .REB_signal(REB_to_pixel_SRAM_FF),
        .value_in(next_n_contrib_from_SRAM),
        .max_value_out(max_pixel_n_contrib_for_next_window_first)
    );



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Block State control FF

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Block_state_current <= BLOCK_IDLE;
            row_for_output_FF <= 'd0;
            row_for_input_FF <= 'd0;

            last_input_done_for_output_FF <= 'd0;
            last_input_done_for_input_FF <= 'd0;

            H <= 'd0;
            W <= 'd0;
            block_id <= 'd0;


            for (int i = 0; i < num_pixels; i++) begin
                REB_to_pixel_SRAM_FF[i] <= 1'b1;

                T_first_current[i] <= 'd0;
                dL_dpixel_current[i] <= 'd0;
                dL_dpixel_depth_current[i] <= 'd0;
                pixel_id[i] <= 'd0;
                start[i] <= 'd0;
            end

            Gradient_first_used_LUT <= 'd0;

            pixel_started <= 1'b0;

            for (int j = 0; j < Banks; j++) begin
                Write_address_FF[j] <= 'h0;
                Write_address_FF1[j] <= 'h0;
                rasterizer_FIFO_pop_valid_in_FF_temp[j] <= 'h0;
                WEB_to_gradient_SRAM_temp[j] <= 'b1;

                REB_to_gradient_SRAM_before[j] <= 'b1;

                gradient_ID_used[j] <= 1'b0;
            end

        end

        else begin

            Block_state_current <= Block_state_next;
            row_for_output_FF <= row_for_output_next;
            row_for_input_FF <= row_for_input_next;
            
            // last_input_done_for_output_FF <= last_input_done_for_output_next;

            // gradient handshake 시 (gradient를 받아도 된다)의 상황에서 gradient first used LUT하면 초기화 후 받는 문제가 생김
            if (Block_state_next == BLOCK_PIXEL_FETCHING && Block_state_current == BLOCK_IDLE) begin
                Gradient_first_used_LUT <= 'h0;
            end



            // last_input_done_for_input_FF 초기화
            if (
                (Block_state_next == BLOCK_PIXEL_FETCHING && Block_state_current == BLOCK_BUSY)
                // BLock idle 시 0 초기화 안해서 생기는 문제 발생
                || Block_state_next == BLOCK_IDLE
                || row_for_input_FF[$clog2(num_pixels)]
            ) begin
                last_input_done_for_input_FF <= 'd0;
                
            end
            
            else begin
                last_input_done_for_input_FF <= last_input_done_for_input_next;
            end

            // last_input_done_for_output_FF 초기화
            // 이게 0채널 1채널 합쳐지는 경우가 존재하므로 이렇게 받아야함.
            if (last_input_done_for_output_FF[$clog2(num_pixels)]) begin
                last_input_done_for_output_FF[$clog2(num_pixels)] <= 1'b0;
                last_input_done_for_output_FF[$clog2(num_pixels)-1:0] <= last_input_done_for_output_next[$clog2(num_pixels)-1:0];
            end

            else begin
                last_input_done_for_output_FF <= last_input_done_for_output_next;
            end



            if (block_handshake) begin 
                H <= H_in;
                W <= W_in;
                block_id <= block_id_in;
                row_for_input_FF <= 'd0;
                row_for_output_FF <= 'd0;
                last_input_done_for_input_FF <= 'd0;
                last_input_done_for_output_FF <= 'd0;
            end

            if (gradient_handshake) begin
                row_for_output_FF <= 'd0;
                row_for_input_FF <= 'd0;

                // Gradient_first_used_LUT <= 'd0;
                pixel_started <= 1'b0;

                for (int i = 0; i < num_pixels; i++) begin
                    REB_to_pixel_SRAM_FF[i] <= 1'b1;
                end
            end


            for (int i = 0; i < num_pixels; i++) begin
                REB_to_pixel_SRAM_FF[i] <= REB_to_Pixel_SRAM[i];


                // // 기존 픽셀
                // pixel_id[i] <= {row_for_input_FF[$clog2(num_pixels)-1:0], i[$clog2(num_pixels)-1:0]};

                //인접 픽셀
                // pixel_id { y, x}
                // x = (row % 4) * 4 + (i % 4)
                // y = (row / 4) * 4 + (i / 4)


                // pixel_id[i] <= {(i[$clog2($clog2(num_pixels))] + (row_for_input_FF[$clog2(num_pixels)-1:0]) * $clog2(num_pixels)) + (i % $clog2($clog2(num_pixels))) +  (row_for_input_FF[$clog2(num_pixels)-1:0] * $clog2(num_pixels))};

                // pixel_id[i] <= {(i[$clog2($clog2(num_pixels))] + (row_for_input_FF[$clog2(num_pixels)-1:0]) * $clog2(num_pixels)) + (i[$clog2($clog2(num_pixels))-1:0]) +  (row_for_input_FF[$clog2($clog2(num_pixels))-1:0] * $clog2(num_pixels))};
                pixel_id[i] <= {pixel_id_y[i], pixel_id_x[i]};

                // 이전 사이클에 Pixel REB 신호시
                // 다음 사이클에 픽셀 데이터 가져옴 + start 신호 반환
                if (!REB_to_pixel_SRAM_FF[i]) begin
                    // pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i];
                    T_first_current[i] <= next_T_first_from_SRAM[i];
                    dL_dpixel_current[i] <= next_dL_dpixel_from_SRAM[i];
                    dL_dpixel_depth_current[i] <= next_dL_dpixel_depth_from_SRAM[i];
                    start[i] <= 1'b1;
                end

                else begin
                    start[i] <= 1'b0;
                end     
            end

            if (start[0]) begin
                pixel_started <= 1'b1;
            end

            if (last_input_done_for_output_FF[$clog2(num_pixels)]) begin
                pixel_started <= 1'b0;
            end


            for (int j = 0; j < Banks; j++) begin
                Write_address_FF1[j] <= Read_address_from_rasterizer_to_gradient_SRAM[j];
                Write_address_FF[j] <= Write_address_FF1[j];

                rasterizer_FIFO_pop_valid_in_FF_temp[j] <= rasterizer_FIFO_pop_valid_in[j] && !last_input_done_and_data_zero[j];

                WEB_to_gradient_SRAM_temp[j] <= !rasterizer_FIFO_pop_valid_in_FF_temp[j];

                REB_to_gradient_SRAM_before[j] <= REB_to_gradient_SRAM[j];

                Gradient_first_used_LUT[Write_address_FF[j]] <= 1'b1;

                gradient_ID_used[j] <= Gradient_first_used_LUT[Read_address_from_rasterizer_to_gradient_SRAM[j]] && !REB_to_gradient_SRAM[j];

            end   

        end
    end

    // Window State control FF

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Window_state_current <= WINDOW_IDLE;
            

            for (int i = 0; i < num_pixels; i++) begin
                Gaussian_window_pointer_current[i] <= 'd0;
                pixel_n_contrib[i] <= 'd0;

                input_n_contrib_is_zero[i] <= 1'b0;
                last_input_from_zero_n_contrib[i] <= 1'b0;

                last_input_done_to_rasterizer[i] <= 1'b0;
                gaussian_id_to_rasterizer[i] <= 'd0;
                gaussian_color_to_rasterizer[i] <= 'd0;
                gaussian_depth_to_rasterizer[i] <= 'd0;
                mean2D_to_rasterizer[i] <= 'd0;
                conic_opacity_to_rasterizer[i] <= 'd0;
                i_valid[i] <= 1'b0;

                
                
            end

            for (int i = 0; i < WINDOW_SIZE; i++) begin
                gaussian_id_window[i] <= 'd0;
                gaussian_color_window[i] <= 'd0;
                gaussian_depth_window[i] <= 'd0;
                mean2D_window[i] <= 'd0;
                conic_opacity_window[i] <= 'd0;
            end
        end

        else begin

            if (Block_state_next == BLOCK_IDLE
                || (Block_state_next == BLOCK_PIXEL_FETCHING && Block_state_current == BLOCK_BUSY)
                || input_n_contrib_is_zero_and_last_row_input_done
            ) begin
                for (int i = 0; i < num_pixels; i++) begin
                    input_n_contrib_is_zero[i] <= 1'b0;
                    last_input_from_zero_n_contrib[i] <= 1'b0;
                end
            end


            Window_state_current <= Window_state_next;

            if (window_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_window[i] <= gaussian_id_for_next_window[i];
                    gaussian_color_window[i] <= gaussian_color_for_next_window[i];
                    gaussian_depth_window[i] <= gaussian_depth_for_next_window[i];
                    mean2D_window[i] <= mean2D_for_next_window[i];
                    conic_opacity_window[i] <= conic_opacity_for_next_window[i];

                    Gaussian_window_pointer_current[i] <= 'd0;

                    
                end
            end


            // 추가됨 
            if (gradient_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_window[i] <= 'h0;
                    gaussian_color_window[i] <= 'h0;
                    gaussian_depth_window[i] <= 'h0;
                    mean2D_window[i] <= 'h0;
                    conic_opacity_window[i] <= 'h0;

                    Gaussian_window_pointer_current[i] <= 'd0;
                end
            end
            

            case (Window_state_current)
                WINDOW_BUSY: begin
                    for (int i = 0; i < num_pixels; i++) begin

                        if (!stall_to_controller_from_rasterizer[i]) begin
                            pixel_n_contrib[i] <= pixel_n_contrib_next[i];


                            //입력 N_contrib가 0 인경우
                            if (input_n_contrib_is_zero[i] && !last_input_from_zero_n_contrib[i]) begin
                                last_input_from_zero_n_contrib[i] <= 1'b1;
                                last_input_done_to_rasterizer[i] <= 1'b1;
                            end


                            else begin 

                                if (!Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)]) begin
                                    Gaussian_window_pointer_current[i] <= Gaussian_window_pointer_current[i] + 1;
                                end

                                // Input 조건 
                                if (Gaussian_window_pointer_current[i] < WINDOW_SIZE) begin

                                    if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]] && pixel_n_contrib[i] > 0) begin
                                        i_valid[i] <= 1'b1;
                                    end

                                    else begin
                                        i_valid[i] <= 1'b0;
                                    end



                                    if (pixel_n_contrib[i] == 1) begin
                                        last_input_done_to_rasterizer[i] <= 1'b1;
                                    end

                                    else begin
                                        last_input_done_to_rasterizer[i] <= 1'b0;
                                    end
                                    
                                    gaussian_id_to_rasterizer[i] <= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]];
                                    gaussian_color_to_rasterizer[i] <= gaussian_color_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]];
                                    gaussian_depth_to_rasterizer[i] <= gaussian_depth_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]];
                                    mean2D_to_rasterizer[i] <= mean2D_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]];
                                    conic_opacity_to_rasterizer[i] <= conic_opacity_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0]];

                                end

                                else begin
                                    i_valid[i] <= 1'b0;

                                    last_input_done_to_rasterizer[i] <= 1'b0;
                                    gaussian_id_to_rasterizer[i] <= 'd0;
                                    gaussian_color_to_rasterizer[i] <= 'd0;
                                    gaussian_depth_to_rasterizer[i] <= 'd0;
                                    mean2D_to_rasterizer[i] <= 'd0;
                                    conic_opacity_to_rasterizer[i] <= 'd0;
                                end

                                
                            end


                        end

                    end
                end

                default : begin
                    for (int i = 0; i < num_pixels; i++) begin
                        i_valid[i] <= 1'b0;
                        last_input_done_to_rasterizer[i] <= 1'b0;
                        gaussian_id_to_rasterizer[i] <= 'd0;
                        gaussian_color_to_rasterizer[i] <= 'd0;
                        gaussian_depth_to_rasterizer[i] <= 'd0;
                        mean2D_to_rasterizer[i] <= 'd0;
                        conic_opacity_to_rasterizer[i] <= 'd0;

                        Gaussian_window_pointer_current[i] <= 'd0;
                    end

                    for (int i=0; i< num_pixels ; i++)begin
                        if (!REB_to_pixel_SRAM_FF[i]) begin
                            // pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i] - 'd1;
                            // pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i];

                            if (next_n_contrib_from_SRAM[i] == 'd0 || ((next_dL_dpixel_from_SRAM[i] == 'h0) && (next_dL_dpixel_depth_from_SRAM[i] == 'h0))) begin
                            // if (next_n_contrib_from_SRAM[i] == 'd0) begin
                                input_n_contrib_is_zero[i] <= 1'b1;
                                pixel_n_contrib[i] <= 'd0;
                            end

                            else begin
                                input_n_contrib_is_zero[i] <= 1'b0;
                                pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i];
                            end
                        end
                        
                    end
                end
            endcase
        end
    end

    // Next Window State control FF

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Next_window_state_current <= NEXT_WINDOW_IDLE;
            next_window_fetching_pointer <= 'd0;
            next_window_fetching_pointer_FF1 <= 'd0;
            next_window_fetching_pointer_FF2 <= 'd0;

            max_pixel_n_contrib_for_next_window_current <= 'd0;

            REB_to_gaussian_SRAM_FF <= 1'b1;
            gaussian_id_to_SRAM_before <= 'd0;


            gaussian_id_to_SRAM <= 'd0;
            REB_to_gaussian_SRAM <= 1'b1;

            
            // gaussian_index_FF1 <= 'd0;
            // gaussian_index_FF2 <= 'd0;
        

            for (int i = 0; i < WINDOW_SIZE; i++) begin
                gaussian_id_for_next_window[i] <= 'h0;
                gaussian_color_for_next_window[i] <= 'h0;
                gaussian_depth_for_next_window[i] <= 'h0;
                mean2D_for_next_window[i] <= 'h0;
                conic_opacity_for_next_window[i] <= 'h0;
            end

        end

        else begin
            Next_window_state_current <= Next_window_state_next;
            next_window_fetching_pointer <= next_window_fetching_pointer_next;
            next_window_fetching_pointer_FF1 <= next_window_fetching_pointer;
            next_window_fetching_pointer_FF2 <= next_window_fetching_pointer_FF1;


            if (gradient_handshake) begin
    
                REB_to_gaussian_SRAM_FF <= 1'b1;
                gaussian_id_to_SRAM_before <= 'd0;


                gaussian_id_to_SRAM <= 'd0;
                REB_to_gaussian_SRAM <= 1'b1;

                
                // gaussian_index_FF1 <= 'd0;
                // gaussian_index_FF2 <= 'd0;
    


                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'h0;
                    gaussian_color_for_next_window[i] <= 'h0;
                    gaussian_depth_for_next_window[i] <= 'h0;
                    mean2D_for_next_window[i] <= 'h0;
                    conic_opacity_for_next_window[i] <= 'h0;
                end

                next_window_fetching_pointer <= 'd0;
                next_window_fetching_pointer_FF1 <= 'd0;
                next_window_fetching_pointer_FF2 <= 'd0;

                max_pixel_n_contrib_for_next_window_current <= 'd0;
            end


            gaussian_id_to_SRAM_before <= gaussian_id_to_SRAM_original;

            gaussian_id_to_SRAM_original <= gaussian_id_to_SRAM_original_comb;
            gaussian_id_to_SRAM <= gaussian_id_to_SRAM_comb;
            REB_to_gaussian_SRAM <= REB_to_gaussian_SRAM_comb;

            // gaussian_index_FF1 <= gaussian_index;
            // gaussian_index_FF2 <= gaussian_index_FF1;
            


            if (window_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'h0;
                    gaussian_color_for_next_window[i] <= 'h0;
                    gaussian_depth_for_next_window[i] <= 'h0;
                    mean2D_for_next_window[i] <= 'h0;
                    conic_opacity_for_next_window[i] <= 'h0;
                end        

                REB_to_gaussian_SRAM <= 1'b1;
                REB_to_gaussian_SRAM_FF <= 1'b1;

                next_window_fetching_pointer <= 'd0;
                next_window_fetching_pointer_FF1 <= 'd0;
                next_window_fetching_pointer_FF2 <= 'd0;
            end


            // Max Winodw value
            if (!REB_to_pixel_SRAM_FF[0]) begin
                max_pixel_n_contrib_for_next_window_current <= max_pixel_n_contrib_for_next_window_first;
                next_window_fetching_pointer <= 'd0;
                next_window_fetching_pointer_FF1 <= 'd0;
                next_window_fetching_pointer_FF2 <= 'd0;
            end

            // Max Window value 업데이트
            else begin
                max_pixel_n_contrib_for_next_window_current <= max_pixel_n_contrib_for_next_window_next;
            end




            // Next window fetching
            if (Next_window_state_current == NEXT_WINDOW_FETCHING) begin

                REB_to_gaussian_SRAM_FF <= REB_to_gaussian_SRAM;

                if (next_window_fetching_pointer_FF2 < WINDOW_SIZE && !REB_to_gaussian_SRAM_FF) begin

                    gaussian_id_for_next_window[next_window_fetching_pointer_FF2] <= gaussian_id_to_SRAM_before;
                    gaussian_color_for_next_window[next_window_fetching_pointer_FF2] <= gaussian_color_from_SRAM;
                    gaussian_depth_for_next_window[next_window_fetching_pointer_FF2] <= gaussian_depth_from_SRAM;
                    mean2D_for_next_window[next_window_fetching_pointer_FF2] <= mean2D_from_SRAM;
                    conic_opacity_for_next_window[next_window_fetching_pointer_FF2] <= conic_opacity_from_SRAM;
                        
                    end
                
            end




        end
    end    



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  

    // l=0 에서의 remainder

    // 약간 이게 shifting amount의 기능을 하도록 barrel shifter 구현해야함
    

    assign stall_to_rasterizer_from_controller = 1'b0;

    assign Block_data_ready = Block_ready;

    genvar k,l , m ;
    generate 
        for (k = 0; k < num_pixels; k++) begin : pixel_control

            // Pixel SRAM Read, Address = pixel_id % num_pixels 의 의미 
            assign REB_to_Pixel_SRAM[k] = (Block_state_current == BLOCK_PIXEL_FETCHING) ? 1'b0 : 1'b1;
            // assign Read_address_to_Pixel_SRAM[k] = pixel_id[k][$clog2(num_pixels)-1:0];
            // assign Read_address_to_Pixel_SRAM[k] = row_for_output_FF[$clog2(num_pixels)-1:0];
            assign Read_address_to_Pixel_SRAM[k] = row_for_input_FF[$clog2(num_pixels)-1:0];

            assign row_end_condition_temp[k] = (Write_address_FF[k] == 'd0) && (WEB_to_gradient_SRAM[k]);

            // pixel id
            assign pixel_id_x[k] = (k % $clog2(num_pixels)) + (row_for_input_FF % $clog2(num_pixels)) * $clog2(num_pixels);
            assign pixel_id_y[k] = (k / $clog2(num_pixels)) + (row_for_input_FF / $clog2(num_pixels)) * $clog2(num_pixels);

            assign window_empty_temp[k] = Gaussian_window_pointer_current[k][$clog2(WINDOW_SIZE)];
        end


        // for (l =0 ; l < gaussian_inputs; l++) begin : before_indexing
            
            // assign gaussian_index[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) && (max_pixel_n_contrib_for_next_window_current > l) ? (SRAM_shift_amount - l + gaussian_inputs) % gaussian_inputs : 'd0 ;
        assign gaussian_id_for_fetching = (max_pixel_n_contrib_for_next_window_current > 0) && (Next_window_state_current == NEXT_WINDOW_FETCHING) ? max_pixel_n_contrib_for_next_window_current : 'd0;
        // end        

        for (m = 0; m < Banks; m++) begin : Bank_control
            assign WEB_to_gradient_SRAM[m] = WEB_to_gradient_SRAM_temp[m];


            assign last_input_done_for_output_next_condition[m] = last_input_done_from_gradient_merge[m] && rasterizer_FIFO_pop_valid_in[m];
            // FIFO & REB의 조건 : 
            // Read 하고 나서 최소 3사이클이 소요됨
            // cycle 1 : REB (Read_address_from_rasterizer_to_gradient_SRAM)
            // cycle 2 : Adder 진입 (Write_address_FF1)
            // cycle 3:  Adder 출력 (WEB Enable) (Write_address_FF)
            // cycle 4:  SRAM 입력 (REB 허가)

            // + FIFO pop ready out

            assign REB_to_gradient_SRAM[m] = ( rasterizer_FIFO_pop_ready_out[m]
                                            // 추가된 부분
                                            && !last_input_done_and_data_zero[m])
                                            && ( (!((Write_address_FF[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && !WEB_to_gradient_SRAM_temp[m]) && !((Write_address_FF1[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && rasterizer_FIFO_pop_valid_in_FF_temp[m])) 
                                            || Read_address_from_rasterizer_to_gradient_SRAM[m] == 0)

                                            ? 1'b0 : 1'b1;
            
            assign rasterizer_FIFO_pop_valid_in[m] = rasterizer_FIFO_pop_ready_out[m] 
                                                    && ( (!((Write_address_FF[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && !WEB_to_gradient_SRAM_temp[m]) && !((Write_address_FF1[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && rasterizer_FIFO_pop_valid_in_FF_temp[m])) 
                                                    || Read_address_from_rasterizer_to_gradient_SRAM[m] == 0)
                                                     ? 1'b1 : 1'b0;

        end
    endgenerate 

    // gaussian index 와 버퍼 조절?
    always_comb begin
        
        gaussian_id_to_SRAM_original_comb = 'd0;
        gaussian_id_to_SRAM_comb = 'd0;
        REB_to_gaussian_SRAM_comb = 1'b1;      


        if (Next_window_state_current == NEXT_WINDOW_FETCHING) begin
            

            if (gaussian_id_for_fetching > 0) begin
                gaussian_id_to_SRAM_original_comb = gaussian_id_for_fetching;
                gaussian_id_to_SRAM_comb = gaussian_id_for_fetching;
                REB_to_gaussian_SRAM_comb = 1'b0;
            end 
        end    
    end

    tree_logic_wire_last_input_add #(
        .input_dimensions(Banks)
    ) last_input_done_for_output_inst (
        .last_input_done(last_input_done_for_output_next_condition),
        .last_input_done_out(last_input_done_for_output_next_temp)
    );

    assign last_input_done_for_output_next = last_input_done_for_output_next_temp + last_input_done_for_output_FF;


    tree_logic_wire_last_input_add #(
        .input_dimensions(num_pixels)
    ) last_input_done_for_input_inst (
        .last_input_done(last_input_done_from_rasterizer),
        .last_input_done_out(last_input_done_for_input_next_temp)
    );


    assign last_input_done_for_input_next = !stall_to_rasterizer_to_controller ? last_input_done_for_input_next_temp + last_input_done_for_input_FF : last_input_done_for_input_FF;
    tree_logic_wire_or #(
        .input_dimensions(num_pixels)
    ) stall_to_controller_inst (
        .condition_in(stall_to_controller_from_rasterizer),
        .condition_out(stall_to_controller_from_rasterizer_comb)
    );

    tree_logic_wire_and #(
        .input_dimensions(num_pixels)
    ) all_input_n_contrib_is_zero_temp_inst (
        .condition_in(input_n_contrib_is_zero),
        .condition_out(all_input_n_contrib_is_zero_temp)
    ); 

    assign all_input_n_contrib_is_zero = all_input_n_contrib_is_zero_temp && (Block_state_current == BLOCK_BUSY);


    tree_logic_wire_and #(
        .input_dimensions(num_pixels)
    ) row_end_condition_inst (
        .condition_in(row_end_condition_temp),
        .condition_out(row_end_condition)
    );

    tree_logic_wire_and #(
        .input_dimensions(num_pixels)
    ) tree_logic_wire_and_inst (
        .condition_in(window_empty_temp),
        .condition_out(window_empty_comb)
    );

    assign window_empty = window_empty_comb && (Window_state_current == WINDOW_BUSY);
    


endmodule