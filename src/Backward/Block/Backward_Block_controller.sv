
// SRAM은 없다고 가정 (추가로 module화 해서 달 예정)
module Backward_Block_controller #(
    parameter BLOCK_SIZE = 16,
    parameter exponent_bit = 8,
    parameter mantissa_bit = 7,
    parameter precision = 16,
    parameter gaussian_inputs = 4, // in one pixel unit, gaussians
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

        input wire [GID_bit-1:0] last_gaussian_index_in, // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리


    // Output to Top Controller
        output wire Block_data_ready,
        output wire gradient_value_valid,
        // output wire gradient_value_done,


        // Input from Group Rasterizer
        input wire stall_to_controller_from_rasterizer [num_pixels-1:0],
        input wire last_input_done_from_rasterizer [Banks-1:0],

        output wire rasterizer_FIFO_pop_valid_in [Banks-1:0],
        input wire rasterizer_FIFO_pop_ready_out [Banks-1:0],

        output wire stall_to_rasterizer_from_controller,



    // Output to Group Rasterizer

        // Gaussian Window value
        output reg i_valid [gaussian_inputs * num_pixels - 1:0],

        output reg last_input_done_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [GID_bit-1:0] gaussian_id_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(3 * precision)-1:0] gaussian_color_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [precision-1:0] gaussian_depth_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(2 * precision)-1:0] mean2D_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        output reg [(4 * precision)-1:0] conic_opacity_to_rasterizer [gaussian_inputs * num_pixels - 1:0],
        

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
    input wire [(3 * precision) - 1:0] gaussian_color_from_SRAM [gaussian_inputs-1:0],
    input wire [precision-1:0] gaussian_depth_from_SRAM [gaussian_inputs-1:0],
    input wire [(2 * precision)-1:0] mean2D_from_SRAM [gaussian_inputs-1:0],
    input wire [(4 * precision)-1:0] conic_opacity_from_SRAM [gaussian_inputs-1:0],

    output reg [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0], // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항
    // output wire [GID_bit-1:0] gaussian_id_to_SRAM [gaussian_inputs-1:0], // 이거 그냥 hash? 그거 처리를 어디서 해야되는지는 추후 고민해야 할 사항

        
    // Output to input gaussian SRAM
    // output wire REB_to_gaussian_SRAM [gaussian_inputs-1:0],
    output reg REB_to_gaussian_SRAM [gaussian_inputs-1:0],


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


    // Output to gradient merge SRAM
        output wire REB_to_gradient_SRAM [Banks-1:0],
        output wire WEB_to_gradient_SRAM [Banks-1:0],

        // output wire gradient_ID_used [Banks-1:0],
        output reg gradient_ID_used [Banks-1:0],

        output reg [LUT_SIZE-1:0] Gradient_first_used_LUT
    );


    // localparam LUT_SIZE = 1 << GID_bit;

    //////////////////////// Block Control ////////////////////////
    // Gradient Merge SRAM 관련 데이터를 직접 컨트롤
    // Pixel 및, Gaussian Window 관련 데이터는 간접적으로 컨트롤

        // FF Register

        reg [1:0] Block_state_current;
        reg [1:0] Block_state_next;


        // reg [GID_bit-1:0] block_last_gaussian_index; // SRAM에서의 Gaussian 범위를 알아낼 수 있도록 제작 0번은 NULL로 처리

        reg [$clog2(num_pixels):0] last_input_done_FF;
        reg [$clog2(num_pixels):0] row_FF;

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
            reg window_empty;
            

        // // Window에 기입해야 하는 최대 index 받아오기

        // reg current_window_max_index_is_zero;

        reg [GID_bit-1:0] gaussian_id_to_SRAM_before [gaussian_inputs-1:0];
        reg [GID_bit-1:0] gaussian_id_to_SRAM_original [gaussian_inputs-1:0];


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


        reg [$clog2(num_pixels):0] row_next;
        reg [$clog2(num_pixels):0] last_input_done_next;

        // SRAM에서 받는 max_index
        // Gaussian Window 시작점
        // reg [GID_bit-1:0] pixel_max_index_from_SRAM;
        // reg [GID_bit-1:0] pixel_max_index_from_SRAM_next;

        reg REB_to_pixel_SRAM_FF [num_pixels-1:0];

        // Pixel 데이터 겸 hot gaussian window에서의 n_contrib의 역할
        reg [GID_bit-1:0] pixel_n_contrib [num_pixels-1:0];
        reg [GID_bit-1:0] pixel_n_contrib_next [num_pixels-1:0];

    

        wire [$clog2(gaussian_inputs)-1:0] gaussian_index [gaussian_inputs-1:0];
        reg [$clog2(gaussian_inputs)-1:0] gaussian_index_FF1 [gaussian_inputs-1:0];
        reg [$clog2(gaussian_inputs)-1:0] gaussian_index_FF2 [gaussian_inputs-1:0];

        wire [GID_bit-1:0] gaussian_id_for_fetching [gaussian_inputs-1:0];

                        

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


        // wire over_the_window [num_pixels-1:0];
        // wire pixel_is_not_finished [gaussian_inputs * num_pixels-1:0];
        // wire pixel_starting_condition [gaussian_inputs * num_pixels-1:0];

        
        // 입력 N_contrib가 0인경우 last_input을 반환하기 위한 신호

        // n_contrib 시작이 0 인경우
        reg input_n_contrib_is_zero [num_pixels-1:0];
        reg all_input_n_contrib_is_zero;

        // 
        reg last_input_from_zero_n_contrib [num_pixels-1:0];
        
        




        
    // Next Window
        // FF Register
        reg [GID_bit-1:0] gaussian_id_for_next_window [WINDOW_SIZE-1:0];
        reg [3 * precision -1:0] gaussian_color_for_next_window [WINDOW_SIZE-1:0];
        reg [precision -1 :0] gaussian_depth_for_next_window [WINDOW_SIZE-1:0];
        reg [(2 * precision)-1 :0] mean2D_for_next_window [WINDOW_SIZE-1:0];
        reg [(4 * precision)-1 :0] conic_opacity_for_next_window [WINDOW_SIZE-1:0];



        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_current;
        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_next;

        wire [GID_bit-1:0] SRAM_shift_amount;

        // 처음 pixel 값에서 부터 가져오는 max 값
        reg [GID_bit-1:0] max_pixel_n_contrib_for_next_window_first;

        reg REB_to_gaussian_SRAM_FF [gaussian_inputs-1:0];


        // Combinational Logic
        reg [GID_bit-1:0] gaussian_id_to_SRAM_original_comb [gaussian_inputs-1:0];
        reg [GID_bit-1:0] gaussian_id_to_SRAM_comb [gaussian_inputs-1:0];
        reg REB_to_gaussian_SRAM_comb [gaussian_inputs-1:0];    
        
    //////////////////////// Pixel Window ////////////////////////




    //////////////////////// Backward Unit Control singal ////////////////////////
    reg [GID_bit-1:0] Write_address_FF [Banks-1:0];
    reg [GID_bit-1:0] Write_address_FF1 [Banks-1:0];

    // reg [GID_bit-1:0] Read_address_from_rasterizer_to_gradient_SRAM [Banks-1:0];

    reg rasterizer_FIFO_pop_valid_in_FF_temp [Banks-1:0];

    reg WEB_to_gradient_SRAM_temp [Banks-1:0];


    // assign gradient_value_valid = (Block_state_current == BLOCK_BUSY) && (row_FF == num_pixels);
    assign gradient_value_valid = (Block_state_current == BLOCK_IDLE) && (row_FF == num_pixels);

    assign block_handshake = Block_data_done && Block_ready;
    assign window_handshake = window_valid && window_request;
    assign gradient_handshake = gradient_value_valid && gradient_value_ready;


    // Block State control
    always_comb begin
        Block_state_next = Block_state_current;
        row_next = row_FF;
        Block_ready = 1'b0;
        
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
                if (gradient_handshake) begin
                    Block_state_next = BLOCK_IDLE;
                end

                // 다음 pixel 데이터가 필요시
                
                // else if (last_input_done_FF[$clog2(num_pixels)] && !row_FF[$clog2(num_pixels)]) begin
                //     Block_state_next = BLOCK_PIXEL_FETCHING;
                //     row_next = row_FF + 1;
                // end

                // else if (last_input_done_FF[$clog2(num_pixels)]) begin
                else if (last_input_done_FF[$clog2(num_pixels)] || all_input_n_contrib_is_zero) begin
                    row_next = row_FF + 1;

                    if (row_next[$clog2(num_pixels)]) begin
                        Block_state_next = BLOCK_IDLE;
                    end

                    else begin
                        Block_state_next = BLOCK_PIXEL_FETCHING;
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
                if (window_empty && !stall_to_controller_from_rasterizer_comb) begin
                    Window_state_next = WINDOW_REQUEST;
                end

                for (int i = 0; i < num_pixels; i++) begin
                    for (int j = 0; j < gaussian_inputs; j++) begin

                        if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j] && pixel_n_contrib_next[i] > 'd0) begin
                            pixel_n_contrib_next[i] = pixel_n_contrib_next[i] - 'd1;
                        end
                    
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

                if (gradient_handshake) begin
                    Next_window_state_next = NEXT_WINDOW_IDLE;
                end

                else if (next_window_fetching_pointer_FF1[$clog2(WINDOW_SIZE)] && gaussian_id_for_next_window[0] != 'd0) begin                                        
                    Next_window_state_next = NEXT_WINDOW_READY;
                end

                else if (!next_window_fetching_pointer[$clog2(WINDOW_SIZE)]) begin
                // else begin
                
                    // 다 채우지 못하고 남은게 0 인경우 (약간 초기 상황도 포함이네)
                    // 여기서 후반 조건에 대한 transition 해야함

                    if (next_window_fetching_pointer_FF2 + gaussian_inputs < WINDOW_SIZE) begin
                        next_window_fetching_pointer_next = next_window_fetching_pointer + gaussian_inputs;
                    end

                    if (max_pixel_n_contrib_for_next_window_current < gaussian_inputs) begin

                        // if (next_window_fetching_pointer_FF2 + max_pixel_n_contrib_for_next_window_current < WINDOW_SIZE) begin
                        //     next_window_fetching_pointer_next = next_window_fetching_pointer + gaussian_inputs;
                        // end

                        max_pixel_n_contrib_for_next_window_next = 'd0;
                    end

                    // 아직 window가 다 차지 않은 경우
                    else begin
                        max_pixel_n_contrib_for_next_window_next = max_pixel_n_contrib_for_next_window_current - gaussian_inputs;
                        // if (next_window_fetching_pointer_FF2 + gaussian_inputs < WINDOW_SIZE) begin
                        //     next_window_fetching_pointer_next = next_window_fetching_pointer + gaussian_inputs;
                        // end
                    end

                end

            end

            NEXT_WINDOW_READY: begin
                window_valid = 1'b1;

                // window handshake시 fetching 상태로 변경
                if (window_request) begin
                    Next_window_state_next = NEXT_WINDOW_FETCHING;
                    next_window_fetching_pointer_next = 'd0;
                end
            end

            default: begin
                Next_window_state_next = NEXT_WINDOW_IDLE;
            end

        endcase
    end


    // Next window max n_contrib >> 그걸 알아야 다음에 뭘 가져올 지 아니까
    always_comb begin
        max_pixel_n_contrib_for_next_window_first = 'd0;

        for (int i = 0; i < num_pixels; i++) begin
            if (!REB_to_pixel_SRAM_FF[i] && (next_n_contrib_from_SRAM[i] > max_pixel_n_contrib_for_next_window_first)) begin
                max_pixel_n_contrib_for_next_window_first = next_n_contrib_from_SRAM[i];
            end            

        end
    end



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Block State control FF

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            Block_state_current <= BLOCK_IDLE;
            row_FF <= 'd0;
            last_input_done_FF <= 'd0;
            
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
            row_FF <= row_next;
            
            // last_input_done_FF <= last_input_done_next;

            // gradient handshake 시 (gradient를 받아도 된다)의 상황에서 gradient first used LUT하면 초기화 후 받는 문제가 생김
            if (Block_state_next == BLOCK_PIXEL_FETCHING && Block_state_current == BLOCK_IDLE) begin
                Gradient_first_used_LUT <= 'h0;
            end

            if (Block_state_next == BLOCK_PIXEL_FETCHING && Block_state_current == BLOCK_BUSY) begin
                last_input_done_FF <= 'd0;

                // for (int i = 0; i < num_pixels; i++) begin
                //     input_n_contrib_is_zero[i] <= 1'b0;
                //     last_input_from_zero_n_contrib[i] <= 1'b0;
                // end

            end

            else begin
                last_input_done_FF <= last_input_done_next;
            end

            if (block_handshake) begin 
                H <= H_in;
                W <= W_in;
                block_id <= block_id_in;
            end

            if (gradient_handshake) begin
                row_FF <= 'd0;
                // Gradient_first_used_LUT <= 'd0;
                pixel_started <= 1'b0;

                for (int i = 0; i < num_pixels; i++) begin
                    REB_to_pixel_SRAM_FF[i] <= 1'b1;
                end
            end


            for (int i = 0; i < num_pixels; i++) begin
                REB_to_pixel_SRAM_FF[i] <= REB_to_Pixel_SRAM[i];

                pixel_id[i] <= {row_FF[$clog2(num_pixels)-1:0], i[$clog2(num_pixels)-1:0]};

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

            if (last_input_done_FF[$clog2(num_pixels)]) begin
                pixel_started <= 1'b0;
            end


            for (int j = 0; j < Banks; j++) begin
                Write_address_FF1[j] <= Read_address_from_rasterizer_to_gradient_SRAM[j];
                Write_address_FF[j] <= Write_address_FF1[j];
                rasterizer_FIFO_pop_valid_in_FF_temp[j] <= rasterizer_FIFO_pop_valid_in[j];
                WEB_to_gradient_SRAM_temp[j] <= !rasterizer_FIFO_pop_valid_in_FF_temp[j];

                REB_to_gradient_SRAM_before[j] <= REB_to_gradient_SRAM[j];
                // Gradient_first_used_LUT[Read_address_from_rasterizer_to_gradient_SRAM[j]] <= 1'b1;
                // Gradient_first_used_LUT[Write_address_FF1[j]] <= 1'b1;
                Gradient_first_used_LUT[Write_address_FF[j]] <= 1'b1;

                // gradient_ID_used[j] <= Gradient_first_used_LUT[Write_address_FF1[j]] && !REB_to_gradient_SRAM_before[j];


                // gradient_ID_used[j] <= Gradient_first_used_LUT[Write_address_FF[j]] && !REB_to_gradient_SRAM[j];
                // gradient_ID_used[j] <= Gradient_first_used_LUT[Write_address_FF1[j]] && !REB_to_gradient_SRAM[j];
                // gradient_ID_used[j] <= Gradient_first_used_LUT[Write_address_FF1[j]] && !REB_to_gradient_SRAM[j];
                gradient_ID_used[j] <= Gradient_first_used_LUT[Read_address_from_rasterizer_to_gradient_SRAM[j]] && !REB_to_gradient_SRAM[j];

            end   

        end
    end

    // Window State control FF

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            Window_state_current <= WINDOW_IDLE;
            

            for (int i = 0; i < num_pixels; i++) begin
                Gaussian_window_pointer_current[i] <= 'd0;
                pixel_n_contrib[i] <= 'd0;

                input_n_contrib_is_zero[i] <= 1'b0;
                last_input_from_zero_n_contrib[i] <= 1'b0;
                
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


            if (Block_state_next == BLOCK_PIXEL_FETCHING && Block_state_current == BLOCK_BUSY) begin
                
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

                    
                    // input_n_contrib_is_zero[i] <= 1'b0;
                    
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

                                for (int j = 0; j < gaussian_inputs; j++) begin
                                    if (j == 0) begin
                                        last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b1;
                                    end
                                    else begin
                                        last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                                    end
                                end

                            end


                            else begin 

                                if (!Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)]) begin
                                    Gaussian_window_pointer_current[i] <= Gaussian_window_pointer_current[i] + gaussian_inputs;
                                end

                                for (int j = 0; j < gaussian_inputs; j++) begin

                                    // Input 조건 
                                    if (Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) begin


                                        // if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j]) begin
                                        if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j] && pixel_n_contrib[i] > j) begin
                                            i_valid[i * gaussian_inputs + j] <= 1'b1;
                                        end

                                        else begin
                                            i_valid[i * gaussian_inputs + j ] <= 1'b0;
                                        end



                                        if (pixel_n_contrib[i] == j + 1) begin
                                            last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b1;
                                        end

                                        else begin
                                            last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                                        end
                                        
                                        gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                        gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= gaussian_color_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                        gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= gaussian_depth_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                        mean2D_to_rasterizer[i * gaussian_inputs + j] <= mean2D_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                                        conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= conic_opacity_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];

                                    end

                                    else begin
                                        i_valid[i * gaussian_inputs + j] <= 1'b0;

                                        last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                                        gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                        conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                                    end

                                end
                            end

                            // if (!Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)]) begin
                            //     Gaussian_window_pointer_current[i] <= Gaussian_window_pointer_current[i] + gaussian_inputs;
                            // end

                            // for (int j = 0; j < gaussian_inputs; j++) begin

                            //     // Input 조건 
                            //     if (Gaussian_window_pointer_current[i] + j < WINDOW_SIZE) begin


                            //         // if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j]) begin
                            //         if (pixel_n_contrib[i] >= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j] && pixel_n_contrib[i] > j) begin
                            //             i_valid[i * gaussian_inputs + j] <= 1'b1;
                            //         end

                            //         else begin
                            //             i_valid[i * gaussian_inputs + j ] <= 1'b0;
                            //         end



                            //         if (pixel_n_contrib[i] == j + 1) begin
                            //             last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b1;
                            //         end

                            //         else begin
                            //             last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                            //         end
                                    
                            //         gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= gaussian_id_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                            //         gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= gaussian_color_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                            //         gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= gaussian_depth_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                            //         mean2D_to_rasterizer[i * gaussian_inputs + j] <= mean2D_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];
                            //         conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= conic_opacity_window[Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)-1:0] + j];

                            //     end

                            //     else begin
                            //         i_valid[i * gaussian_inputs + j] <= 1'b0;

                            //         last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                            //         gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            //         gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            //         gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            //         mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            //         conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            //     end

                            // end


                        end

                    end
                end

                default : begin
                    for (int i = 0; i < num_pixels; i++) begin
                        for (int j = 0; j < gaussian_inputs; j++) begin
                            i_valid[i * gaussian_inputs + j] <= 1'b0;
                            last_input_done_to_rasterizer[i * gaussian_inputs + j] <= 1'b0;
                            gaussian_id_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_color_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            gaussian_depth_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            mean2D_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                            conic_opacity_to_rasterizer[i * gaussian_inputs + j] <= 'd0;
                        end

                        Gaussian_window_pointer_current[i] <= 'd0;
                    end

                    for (int i=0; i< num_pixels ; i++)begin
                        if (!REB_to_pixel_SRAM_FF[i]) begin
                            // pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i] - 'd1;
                            pixel_n_contrib[i] <= next_n_contrib_from_SRAM[i];

                            if (next_n_contrib_from_SRAM[i] == 'd0) begin
                                input_n_contrib_is_zero[i] <= 1'b1;
                            end

                            else begin
                                input_n_contrib_is_zero[i] <= 1'b0;
                            end
                        end
                        
                    end
                end
            endcase
        end
    end

    // Next Window State control FF

    always_ff @ (posedge clk) begin
        if (!rst_n) begin
            Next_window_state_current <= NEXT_WINDOW_IDLE;
            next_window_fetching_pointer <= 'd0;
            next_window_fetching_pointer_FF1 <= 'd0;
            next_window_fetching_pointer_FF2 <= 'd0;

            max_pixel_n_contrib_for_next_window_current <= 'd0;

            for (int i = 0; i < gaussian_inputs; i++) begin
                REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                gaussian_id_to_SRAM_before[i] <= 'd0;


                gaussian_id_to_SRAM[i] <= 'd0;
                REB_to_gaussian_SRAM[i] <= 1'b1;

                
                gaussian_index_FF1[i] <= 'd0;
                gaussian_index_FF2[i] <= 'd0;
            end

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
                for (int i = 0; i < gaussian_inputs; i++) begin
                    REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                    gaussian_id_to_SRAM_before[i] <= 'd0;


                    gaussian_id_to_SRAM[i] <= 'd0;
                    REB_to_gaussian_SRAM[i] <= 1'b1;

                    
                    gaussian_index_FF1[i] <= 'd0;
                    gaussian_index_FF2[i] <= 'd0;
                end

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


            for (int i = 0; i < gaussian_inputs; i++) begin
                gaussian_id_to_SRAM_before[i] <= gaussian_id_to_SRAM_original[i];

                gaussian_id_to_SRAM_original[i] <= gaussian_id_to_SRAM_original_comb[i];
                gaussian_id_to_SRAM[i] <= gaussian_id_to_SRAM_comb[i];
                REB_to_gaussian_SRAM[i] <= REB_to_gaussian_SRAM_comb[i];

                gaussian_index_FF1[i] <= gaussian_index[i];
                gaussian_index_FF2[i] <= gaussian_index_FF1[i];
            end
            


            if (window_handshake) begin
                for (int i = 0; i < WINDOW_SIZE; i++) begin
                    gaussian_id_for_next_window[i] <= 'h0;
                    gaussian_color_for_next_window[i] <= 'h0;
                    gaussian_depth_for_next_window[i] <= 'h0;
                    mean2D_for_next_window[i] <= 'h0;
                    conic_opacity_for_next_window[i] <= 'h0;


                    REB_to_gaussian_SRAM[i] <= 1'b1;
                    REB_to_gaussian_SRAM_FF[i] <= 1'b1;
                end        

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
                // next_window_fetching_pointer <= next_window_fetching_pointer + gaussian_inputs;
                // next_window_fetching_pointer <= next_window_fetching_pointer_next; 

                for (int i = 0; i < gaussian_inputs; i++) begin
                    REB_to_gaussian_SRAM_FF[i] <= REB_to_gaussian_SRAM[i];

                    if (next_window_fetching_pointer_FF2 + i < WINDOW_SIZE && !REB_to_gaussian_SRAM_FF[gaussian_index_FF2[i]]) begin

                        gaussian_id_for_next_window[next_window_fetching_pointer_FF2 + i] <= gaussian_id_to_SRAM_before[gaussian_index_FF2[i]];
                        gaussian_color_for_next_window[next_window_fetching_pointer_FF2 + i] <= gaussian_color_from_SRAM[gaussian_index_FF2[i]];
                        gaussian_depth_for_next_window[next_window_fetching_pointer_FF2 + i] <= gaussian_depth_from_SRAM[gaussian_index_FF2[i]];
                        mean2D_for_next_window[next_window_fetching_pointer_FF2 + i] <= mean2D_from_SRAM[gaussian_index_FF2[i]];
                        conic_opacity_for_next_window[next_window_fetching_pointer_FF2 + i] <= conic_opacity_from_SRAM[gaussian_index_FF2[i]];
                        
                    end
                end
            end




        end
    end    



    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////  

    // l=0 에서의 remainder

    // 약간 이게 shifting amount의 기능을 하도록 barrel shifter 구현해야함
    assign SRAM_shift_amount = max_pixel_n_contrib_for_next_window_current % gaussian_inputs;

    assign stall_to_rasterizer_from_controller = 1'b0;

    assign Block_data_ready = Block_ready;

    genvar k,l , m ;
    generate 
        for (k = 0; k < num_pixels; k++) begin : pixel_control

            // Pixel SRAM Read, Address = pixel_id % num_pixels 의 의미 
            assign REB_to_Pixel_SRAM[k] = (Block_state_current == BLOCK_PIXEL_FETCHING) ? 1'b0 : 1'b1;
            // assign Read_address_to_Pixel_SRAM[k] = pixel_id[k][$clog2(num_pixels)-1:0];
            assign Read_address_to_Pixel_SRAM[k] = row_FF[$clog2(num_pixels)-1:0];
        end


        for (l =0 ; l < gaussian_inputs; l++) begin : before_indexing
            // assign gaussian_index[l] = (SRAM_shift_amount - l + gaussian_inputs) % gaussian_inputs;
            assign gaussian_index[l] = (Next_window_state_current == NEXT_WINDOW_FETCHING) && (max_pixel_n_contrib_for_next_window_current > l) ? (SRAM_shift_amount - l + gaussian_inputs) % gaussian_inputs : 'd0 ;
            assign gaussian_id_for_fetching[l] = (max_pixel_n_contrib_for_next_window_current > l) && (Next_window_state_current == NEXT_WINDOW_FETCHING) ? max_pixel_n_contrib_for_next_window_current - l : 'd0;
        end        

        for (m = 0; m < Banks; m++) begin : Bank_control
            assign WEB_to_gradient_SRAM[m] = WEB_to_gradient_SRAM_temp[m];



            // FIFO & REB의 조건 : 
            // Read 하고 나서 최소 3사이클이 소요됨
            // cycle 1 : REB (Read_address_from_rasterizer_to_gradient_SRAM)
            // cycle 2 : Adder 진입 (Write_address_FF1)
            // cycle 3:  Adder 출력 (WEB Enable) (Write_address_FF)
            // cycle 4:  SRAM 입력 (REB 허가)

            // + FIFO pop ready out

            assign REB_to_gradient_SRAM[m] = rasterizer_FIFO_pop_ready_out[m] 
                                            && ( (!((Write_address_FF[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && !WEB_to_gradient_SRAM_temp[m]) && !((Write_address_FF1[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && rasterizer_FIFO_pop_valid_in_FF_temp[m])) 
                                            || Read_address_from_rasterizer_to_gradient_SRAM[m] == 0)
                                            ? 1'b0 : 1'b1;
            
            assign rasterizer_FIFO_pop_valid_in[m] = rasterizer_FIFO_pop_ready_out[m] 
                                                    && ( (!((Write_address_FF[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && !WEB_to_gradient_SRAM_temp[m]) && !((Write_address_FF1[m] == Read_address_from_rasterizer_to_gradient_SRAM[m]) && rasterizer_FIFO_pop_valid_in_FF_temp[m])) 
                                                    || Read_address_from_rasterizer_to_gradient_SRAM[m] == 0)
                                                     ? 1'b1 : 1'b0;

        end
    endgenerate 


    // Window_empty
    // 모든 픽셀에서의 window pointer가 WINDOW SIZE 초과시 반환
    always_comb begin
        window_empty = Gaussian_window_pointer_current[0][$clog2(WINDOW_SIZE)];
        for (int i = 1; i < num_pixels; i++) begin
            window_empty = window_empty && Gaussian_window_pointer_current[i][$clog2(WINDOW_SIZE)];
        end
    end

    //last_input_done

    always_comb begin
        last_input_done_next = last_input_done_FF;
        for (int i = 0; i < Banks; i++) begin
            // if (last_input_done_from_rasterizer[i]) begin
            // last_input_done인데 FIFO pop ready가 아닌 경우
            if (last_input_done_from_rasterizer[i] && rasterizer_FIFO_pop_valid_in[i]) begin
                last_input_done_next = last_input_done_next + 1;
            end
        end
    end

    always_comb begin
        for (int j = 0; j < gaussian_inputs; j++) begin
            gaussian_id_to_SRAM_original_comb[j] = 'd0;
            gaussian_id_to_SRAM_comb[j] = 'd0;
            REB_to_gaussian_SRAM_comb[j] = 1'b1;      


            if (Next_window_state_current == NEXT_WINDOW_FETCHING) begin
                for (int i = 0; i < gaussian_inputs; i++) begin

                    if (gaussian_index[i] == j[$clog2(gaussian_inputs)-1:0] && gaussian_id_for_fetching[i] > 0) begin
                        gaussian_id_to_SRAM_original_comb[j] = gaussian_id_for_fetching[i];
                        gaussian_id_to_SRAM_comb[j] = gaussian_id_for_fetching[i] / gaussian_inputs;
                        REB_to_gaussian_SRAM_comb[j] = 1'b0;
                    end

                end
            end
        end
    end



    always_comb begin
        stall_to_controller_from_rasterizer_comb = 1'b0;
        for (int i = 0; i < num_pixels; i++) begin
            stall_to_controller_from_rasterizer_comb = stall_to_controller_from_rasterizer_comb || stall_to_controller_from_rasterizer[i];
        end
    end


    always_comb begin
        all_input_n_contrib_is_zero = input_n_contrib_is_zero[0];
        for (int i = 1; i < num_pixels; i++) begin
            all_input_n_contrib_is_zero = all_input_n_contrib_is_zero && input_n_contrib_is_zero[i];
        end
    end

endmodule